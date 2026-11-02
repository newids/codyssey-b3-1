#!/usr/bin/env bash
# B3-1 인프라 생성 (VPC → Subnet → IGW → Route Table → SG → Key Pair → EC2).
# 생성된 리소스 ID 는 .b3-1-state.env 에 기록되며 destroy-infra.sh 가 이를 읽는다.
# 사전 조건: aws configure 완료(IAM 사용자, region ap-northeast-2), curl 설치.
set -euo pipefail

REGION="${AWS_REGION:-ap-northeast-2}"
AZ="${AZ:-${REGION}a}"
PREFIX="${PREFIX:-b3-1}"
PROJECT_TAG="codyssey-b3-1"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
INSTANCE_TYPE="${INSTANCE_TYPE:-t2.micro}"
KEY_NAME="${PREFIX}-key"
KEY_FILE="${KEY_FILE:-${KEY_NAME}.pem}"
STATE_FILE="${STATE_FILE:-.b3-1-state.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DATA="${SCRIPT_DIR}/user-data.sh"
AMI_PARAM="/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"

export AWS_DEFAULT_REGION="$REGION"

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
tags() { printf 'ResourceType=%s,Tags=[{Key=Name,Value=%s},{Key=Project,Value=%s}]' "$1" "$2" "$PROJECT_TAG"; }
save() { printf '%s=%s\n' "$1" "$2" >> "$STATE_FILE"; }

if [[ -f "$STATE_FILE" ]]; then
  echo "ERROR: $STATE_FILE 가 이미 있습니다. 이전 인프라가 남아 있을 수 있습니다. destroy-infra.sh 를 먼저 실행하세요." >&2
  exit 1
fi

log "호출자 확인 (루트가 아니어야 함)"
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "  $CALLER_ARN"
if [[ "$CALLER_ARN" == *":root" ]]; then
  echo "ERROR: 루트 계정입니다. 미션 제약 위반. IAM 사용자로 다시 configure 하세요." >&2
  exit 1
fi

MY_IP=$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')
log "내 공인 IP: $MY_IP (SSH 는 이 IP/32 만 허용)"
: > "$STATE_FILE"
save REGION "$REGION"
save MY_IP "$MY_IP"

log "1/7 VPC"
VPC_ID=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" \
  --tag-specifications "$(tags vpc "${PREFIX}-vpc")" --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
save VPC_ID "$VPC_ID"; echo "  $VPC_ID"

log "2/7 Public Subnet (퍼블릭 IP 자동할당 ON)"
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SUBNET_CIDR" --availability-zone "$AZ" \
  --tag-specifications "$(tags subnet "${PREFIX}-public-a")" --query Subnet.SubnetId --output text)
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch
save SUBNET_ID "$SUBNET_ID"; echo "  $SUBNET_ID"

log "3/7 Internet Gateway attach"
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "$(tags internet-gateway "${PREFIX}-igw")" --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
save IGW_ID "$IGW_ID"; echo "  $IGW_ID"

log "4/7 Route Table (0.0.0.0/0 → IGW) + subnet 연결"
RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "$(tags route-table "${PREFIX}-public-rt")" --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID" >/dev/null
save RT_ID "$RT_ID"; echo "  $RT_ID"

log "5/7 Security Group (80 ← 0.0.0.0/0, 22 ← ${MY_IP}/32)"
SG_ID=$(aws ec2 create-security-group --group-name "${PREFIX}-web-sg" \
  --description "B3-1 web: 80 from anywhere, 22 from my ip only" --vpc-id "$VPC_ID" \
  --tag-specifications "$(tags security-group "${PREFIX}-web-sg")" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "${MY_IP}/32" >/dev/null
save SG_ID "$SG_ID"; echo "  $SG_ID"

log "6/7 Key Pair → $KEY_FILE"
if [[ -f "$KEY_FILE" ]]; then
  echo "ERROR: $KEY_FILE 가 이미 존재합니다. 덮어쓰지 않습니다." >&2; exit 1
fi
aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type ed25519 --key-format pem \
  --tag-specifications "$(tags key-pair "$KEY_NAME")" --query KeyMaterial --output text > "$KEY_FILE"
chmod 400 "$KEY_FILE"
save KEY_NAME "$KEY_NAME"; save KEY_FILE "$KEY_FILE"

log "7/7 EC2 ($INSTANCE_TYPE, Ubuntu 24.04, 8GiB gp3, IMDSv2, user-data)"
AMI_ID=$(aws ssm get-parameters --names "$AMI_PARAM" --query 'Parameters[0].Value' --output text)
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" \
  --subnet-id "$SUBNET_ID" --security-group-ids "$SG_ID" --associate-public-ip-address \
  --user-data "file://${USER_DATA}" \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=8,VolumeType=gp3,DeleteOnTermination=true}' \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled \
  --tag-specifications "$(tags instance "${PREFIX}-web")" "$(tags volume "${PREFIX}-web-root")" \
  --query 'Instances[0].InstanceId' --output text)
save INSTANCE_ID "$INSTANCE_ID"; echo "  $INSTANCE_ID (AMI $AMI_ID)"

log "인스턴스 상태 검사 통과 대기 (2~3분)"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
save PUBLIC_IP "$PUBLIC_IP"

cat <<MSG

완료. 상태 파일: $STATE_FILE
  퍼블릭 IP : $PUBLIC_IP
  SSH       : ssh -i $KEY_FILE ubuntu@$PUBLIC_IP
  검증      : $SCRIPT_DIR/verify.sh $PUBLIC_IP
  브라우저  : http://$PUBLIC_IP/
user-data 가 nginx 를 설치하는 데 1분 정도 더 걸릴 수 있습니다.
MSG
