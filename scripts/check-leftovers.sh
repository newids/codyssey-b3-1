#!/usr/bin/env bash
# 정리 후 과금 위험 리소스가 남았는지 점검. 모든 항목이 0 이어야 한다.
# 사용: scripts/check-leftovers.sh            (ap-northeast-2)
#       scripts/check-leftovers.sh --all-regions   (전 리전, 느림)
set -uo pipefail

REGIONS=("${AWS_REGION:-ap-northeast-2}")
if [[ "${1:-}" == "--all-regions" ]]; then
  REGIONS=()
  while IFS= read -r r; do REGIONS+=("$r"); done < <(aws ec2 describe-regions --query 'Regions[].RegionName' --output text | tr '\t' '\n')
fi

TOTAL=0
count() {  # count <label> <aws cli args...>
  local label="$1"; shift
  local n
  n=$(aws "$@" --output text 2>/dev/null | tr '\t' '\n' | grep -c . || true)
  printf '  %-34s %s\n' "$label" "$n"
  TOTAL=$((TOTAL + n))
}

for R in "${REGIONS[@]}"; do
  export AWS_DEFAULT_REGION="$R"
  echo "== region: $R =="
  count "EC2 (not terminated)"   ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId'
  count "EBS volumes"            ec2 describe-volumes --query 'Volumes[].VolumeId'
  count "Elastic IPs"            ec2 describe-addresses --query 'Addresses[].AllocationId'
  count "NAT gateways (active)"  ec2 describe-nat-gateways --filter Name=state,Values=pending,available --query 'NatGateways[].NatGatewayId'
  count "Internet gateways"      ec2 describe-internet-gateways --query 'InternetGateways[].InternetGatewayId'
  count "VPCs (non-default)"     ec2 describe-vpcs --filters Name=is-default,Values=false --query 'Vpcs[].VpcId'
  count "Snapshots (owned)"      ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId'
  count "Key pairs"              ec2 describe-key-pairs --query 'KeyPairs[].KeyName'
  count "Load balancers"         elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn'
  count "RDS instances"          rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
done

echo
if [[ $TOTAL -eq 0 ]]; then
  echo "RESULT: CLEAN — 잔여 리소스 없음 (이 화면을 docs/screenshots/13-check-leftovers.png 로 캡처)"
else
  echo "RESULT: $TOTAL 건 남음 — cleanup-checklist.md 순서대로 삭제 후 재실행"
  exit 1
fi
