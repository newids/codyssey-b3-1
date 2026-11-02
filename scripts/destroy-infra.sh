#!/usr/bin/env bash
# B3-1 인프라 역순 삭제. create-infra.sh 가 만든 .b3-1-state.env 를 읽는다.
# 순서: EC2 terminate → (잔여 EBS) → (EIP) → SG → IGW detach/delete → Subnet → Route Table → VPC → Key Pair
set -euo pipefail

STATE_FILE="${STATE_FILE:-.b3-1-state.env}"
[[ -f "$STATE_FILE" ]] || { echo "ERROR: $STATE_FILE 없음. 콘솔로 만든 리소스는 cleanup-checklist.md 순서대로 수동 삭제하세요." >&2; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"
export AWS_DEFAULT_REGION="${REGION:-ap-northeast-2}"

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
exists() { [[ -n "${!1:-}" ]]; }

echo "삭제 대상:"; cat "$STATE_FILE"
read -r -p "위 리소스를 모두 삭제합니다. 계속하려면 'yes' 입력: " ANSWER
[[ "$ANSWER" == "yes" ]] || { echo "중단"; exit 1; }

if exists INSTANCE_ID; then
  log "EC2 terminate: $INSTANCE_ID"
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --query 'TerminatingInstances[0].CurrentState.Name' --output text
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
  echo "  terminated"
fi

log "잔여 EBS 볼륨 (Project 태그) 확인"
LEFT_VOLS=$(aws ec2 describe-volumes --filters Name=tag:Project,Values=codyssey-b3-1 Name=status,Values=available \
  --query 'Volumes[].VolumeId' --output text)
for v in $LEFT_VOLS; do echo "  delete-volume $v"; aws ec2 delete-volume --volume-id "$v"; done

log "Elastic IP (Project 태그) 확인"
LEFT_EIPS=$(aws ec2 describe-addresses --filters Name=tag:Project,Values=codyssey-b3-1 --query 'Addresses[].AllocationId' --output text)
for a in $LEFT_EIPS; do echo "  release-address $a"; aws ec2 release-address --allocation-id "$a"; done

if exists SG_ID; then
  log "Security Group: $SG_ID"
  aws ec2 delete-security-group --group-id "$SG_ID"
fi

if exists IGW_ID; then
  log "Internet Gateway detach + delete: $IGW_ID"
  exists VPC_ID && aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
  aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
fi

if exists SUBNET_ID; then
  log "Subnet: $SUBNET_ID"
  aws ec2 delete-subnet --subnet-id "$SUBNET_ID"
fi

if exists RT_ID; then
  log "Route Table: $RT_ID"
  aws ec2 delete-route-table --route-table-id "$RT_ID"
fi

if exists VPC_ID; then
  log "VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id "$VPC_ID"
fi

if exists KEY_NAME; then
  log "Key Pair: $KEY_NAME"
  aws ec2 delete-key-pair --key-name "$KEY_NAME"
  if [[ -n "${KEY_FILE:-}" && -f "$KEY_FILE" ]]; then
    read -r -p "로컬 키 파일 $KEY_FILE 도 삭제할까요? (yes/no): " DELKEY
    [[ "$DELKEY" == "yes" ]] && rm -f "$KEY_FILE" && echo "  removed $KEY_FILE"
  fi
fi

mv "$STATE_FILE" "${STATE_FILE}.destroyed.$(date +%Y%m%d-%H%M%S)"
log "완료. 잔여 점검: $(dirname "$0")/check-leftovers.sh"
