# 리소스 정리 체크리스트

> 목적: 실습 종료 후 **과금 위험 항목이 하나도 남지 않았음**을 근거와 함께 기록한다.
> 체크 ☑ 와 함께 **근거 컬럼**(스크린샷 파일명 또는 명령 출력)을 반드시 채운다. 근거 없는 체크는 평가에서 인정되지 않는다.
> CLI 로 일괄 삭제: `scripts/destroy-infra.sh`, 잔여 점검: `scripts/check-leftovers.sh`

| 정리 일시 | `<YYYY-MM-DD HH:MM KST>` |
|---|---|
| 수행자 | `<IAM 사용자명>` |
| 리전 | ap-northeast-2 |

## 1. 과금 발생 리소스 (최우선)

| ☐ | 항목 | 확인 방법 | 기대 상태 | 근거 |
|---|---|---|---|---|
| ☐ | **EC2 인스턴스** Terminate (Stop 아님) | EC2 → Instances, 필터 해제 후 전체 보기 / `aws ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped` | `terminated` 만 남거나 목록 비어 있음 | `docs/screenshots/10-ec2-terminated.png` |
| ☐ | **EBS 볼륨** (미사용 포함) 삭제 | EC2 → Volumes / `aws ec2 describe-volumes` | 0 건 | `11-no-volumes-eips.png` |
| ☐ | **Elastic IP** Release (할당했다면) | EC2 → Elastic IPs / `aws ec2 describe-addresses` | 0 건 | `11-no-volumes-eips.png` |
| ☐ | **NAT Gateway** 삭제 (생성했다면) | VPC → NAT gateways / `aws ec2 describe-nat-gateways --filter Name=state,Values=available,pending` | 0 건 | |
| ☐ | **ELB/ALB** 삭제 (생성했다면) | EC2 → Load Balancers / `aws elbv2 describe-load-balancers` | 0 건 | |
| ☐ | **RDS** 삭제 (생성했다면) | RDS → Databases / `aws rds describe-db-instances` | 0 건 | |
| ☐ | **EBS 스냅샷 / AMI** (만들었다면) | EC2 → Snapshots, AMIs (Owned by me) | 0 건 | |

## 2. 네트워크 리소스 (의존성 역순)

| ☐ | 항목 | 확인 방법 | 기대 상태 | 근거 |
|---|---|---|---|---|
| ☐ | **Internet Gateway** Detach → Delete | VPC → Internet gateways / `aws ec2 describe-internet-gateways` | 0 건 | `12-vpc-deleted.png` |
| ☐ | **Security Group** `b3-1-web-sg` 삭제 | EC2 → Security Groups | default 외 0 건 | |
| ☐ | **Subnet** 삭제 | VPC → Subnets | 0 건 | |
| ☐ | **Route Table** (커스텀) 삭제 | VPC → Route tables | 0 건 | |
| ☐ | **VPC** 삭제 | VPC → Your VPCs / `aws ec2 describe-vpcs --filters Name=is-default,Values=false` | 0 건 | `12-vpc-deleted.png` |
| ☐ | **Key Pair** 삭제 + 로컬 `.pem` 삭제 | EC2 → Key Pairs / `aws ec2 describe-key-pairs` | 0 건, `ls *.pem` 없음 | |

## 3. 계정/자격증명

| ☐ | 항목 | 확인 방법 | 근거 |
|---|---|---|---|
| ☐ | IAM 사용자 액세스 키 비활성화 또는 삭제 (실습 종료 시) | IAM → Users → Security credentials | |
| ☐ | 저장소에 `.pem`, `AKIA…` 문자열 없음 | `git ls-files \| grep -i pem` ; `git grep -n AKIA` | 출력 없음 |

## 4. 최종 확인

| ☐ | 항목 | 근거 |
|---|---|---|
| ☐ | `scripts/check-leftovers.sh` 실행 결과 전 항목 0 | `13-check-leftovers.png` |
| ☐ | 다른 리전에 리소스 없음 (Resource Groups → Tag Editor → All regions, 또는 EC2 Global View) | |
| ☐ | Billing → Bills / Free Tier 에서 예상 외 과금 항목 없음 (권장) | `14-billing.png` |

## 5. 정리 로그

```
<destroy-infra.sh 출력 또는 콘솔에서 삭제한 순서와 시각을 붙여 넣는다>
```

## 6. 정리 순서를 이렇게 한 이유 (평가 대비 요약)

1. **과금되는 것부터**(EC2·EBS·EIP·NAT) 끊어야 정리 작업 중에도 비용이 멈춘다.
2. AWS 는 **의존 리소스가 남아 있으면 삭제를 거부**(`DependencyViolation`)한다. 인스턴스(ENI) → IGW detach → 서브넷 → 라우트 테이블 → VPC 순서는 의존성의 역순이다.
3. Stop 은 EBS/EIP 과금이 계속되므로 **Terminate** 가 정답이고, Terminate 후에도 `DeleteOnTermination=false` 볼륨은 남을 수 있어 Volumes 를 별도 확인한다.
4. 콘솔은 리전별 화면이라 **다른 리전**에 남은 리소스는 보이지 않는다. 전 리전 조회로 마무리한다.
