# 트러블슈팅 보고서

> 제출 규격: 최소 1건 이상, 각 건에 **증상 → 가설 → 검증 → 조치 → 결과 → 재발방지** 가 모두 기록되어야 한다.
> 아래 "사례" 섹션을 **실제로 겪은 문제**로 채운다. 검증 단계에는 실제 명령과 출력(또는 스크린샷 링크)을 붙인다.
> 구축 중 막힌 적이 없다면 `docs/guide/00-수행-가이드.md` §6 의 재현 실험을 수행하고 그 과정을 기록한다.

## 환경 요약

| 항목 | 값 |
|---|---|
| 리전 / AZ | ap-northeast-2 / ap-northeast-2a |
| 인스턴스 | `<i-xxxxxxxx>` t2.micro, Ubuntu 24.04 |
| 퍼블릭 IP | `<x.x.x.x>` |
| 보안 그룹 | `<sg-xxxxxxxx>` b3-1-web-sg |
| 작성일 | `<YYYY-MM-DD>` |

---

## 사례 1. `<제목: 예) 외부에서 HTTP 접속 시 timeout>`

| 단계 | 내용 |
|---|---|
| **증상** | `<언제, 무엇을 했더니, 정확히 어떤 메시지가 났는가. 예: 로컬에서 curl -i http://x.x.x.x/health 실행 → "curl: (28) Connection timed out after 10001 ms". 인스턴스 내부 curl localhost 는 200.>` |
| **원인 가설** | `<계층별로 2~3개. 예: ① SG 인바운드에 80 규칙 없음 ② 서브넷 라우트 테이블에 IGW 경로 없음 ③ 퍼블릭 IP 미할당>` |
| **검증 방법** | `<가설별 명령과 출력. 예: aws ec2 describe-security-groups --group-ids sg-xxx --query 'SecurityGroups[0].IpPermissions' → 22 규칙만 존재, 80 없음 → 가설 ① 확정. ② ③ 은 describe-route-tables / describe-instances 로 정상 확인.>` |
| **조치 내용** | `<정확한 변경. 예: aws ec2 authorize-security-group-ingress --group-id sg-xxx --protocol tcp --port 80 --cidr 0.0.0.0/0>` |
| **결과** | `<재검증 출력. 예: curl -i http://x.x.x.x/health → HTTP/1.1 200 OK, body "OK". 스크린샷: docs/screenshots/08-external-health.png>` |
| **재발 방지** | `<프로세스/체크리스트/자동화. 예: 인스턴스 시작 전 체크리스트에 "SG 80 인바운드 확인" 추가, scripts/create-infra.sh 에서 SG 규칙을 코드로 고정>` |

## 사례 2. `<선택>`

| 단계 | 내용 |
|---|---|
| **증상** | |
| **원인 가설** | |
| **검증 방법** | |
| **조치 내용** | |
| **결과** | |
| **재발 방지** | |

---

## 참고 카탈로그 — 증상별 진단표

실제 사례를 쓸 때 가설·검증 명령을 고르는 데 쓴다. **카탈로그를 그대로 사례로 복사하지 말 것.**

### 1. 증상 분류 (가장 먼저 할 일)

| 클라이언트가 본 메시지 | 의미 | 조사 범위 |
|---|---|---|
| `Connection timed out` / 브라우저 무한 로딩 | 패킷이 **버려짐** | SG, 라우트 테이블/IGW, 퍼블릭 IP, NACL, 내 IP 변경 |
| `Connection refused` | 호스트 도달, **포트에 프로세스 없음** | nginx 상태, listen 주소/포트, Docker 포트 매핑 |
| `Permission denied (publickey)` | SSH 도달, **인증 실패** | 사용자명, 키페어, .pem 권한 |
| `404 Not Found` | 웹 서버 응답, **경로 없음** | nginx location 설정, reload 여부 |
| `502/503` | 프록시 응답, 백엔드 다운 | 컨테이너/앱 상태 |
| `UnauthorizedOperation` / `AccessDenied` | **IAM** 거부 | 정책 액션·조건(리전/인스턴스 타입) |
| `DependencyViolation` | 삭제 순서 오류 | 의존 리소스 먼저 삭제 |

### 2. 네트워크 계층 점검 명령 (로컬 PC)

```bash
SG=sg-xxxx; SUBNET=subnet-xxxx; VPC=vpc-xxxx; INST=i-xxxx
aws ec2 describe-instances --instance-ids $INST \
  --query 'Reservations[0].Instances[0].{state:State.Name,pub:PublicIpAddress,subnet:SubnetId,sg:SecurityGroups}'
aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissions'
aws ec2 describe-route-tables --filters Name=association.subnet-id,Values=$SUBNET \
  --query 'RouteTables[0].Routes'                      # 0.0.0.0/0 → igw-… 가 있어야 함. 비어 있으면 main 테이블 사용 중
aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC --query 'InternetGateways[0].Attachments'
aws ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[0].MapPublicIpOnLaunch'
aws ec2 describe-network-acls --filters Name=association.subnet-id,Values=$SUBNET --query 'NetworkAcls[0].Entries'
aws ec2 describe-instance-status --instance-ids $INST --query 'InstanceStatuses[0].{sys:SystemStatus.Status,inst:InstanceStatus.Status}'
curl -s https://checkip.amazonaws.com                 # 내 현재 IP 가 SG 22 소스와 같은가
nc -vz -w 5 <퍼블릭IP> 80                              # timeout vs refused 구분
```

### 3. OS/서비스 계층 점검 명령 (EC2 안)

```bash
systemctl status nginx --no-pager
sudo ss -ltnp | grep -E ':80|:22'                     # 0.0.0.0:80 이어야 외부 수신 가능
sudo nginx -t && sudo nginx -T | grep -B2 -A3 health
sudo tail -n 50 /var/log/nginx/error.log
sudo tail -n 80 /var/log/cloud-init-output.log        # user-data 설치 로그
curl -I https://example.com                           # 아웃바운드
sudo journalctl -u ssh --no-pager | tail              # SSH 인증 실패 사유
```

### 4. IAM 계층

```bash
aws sts get-caller-identity
aws sts decode-authorization-message --encoded-message '<UnauthorizedOperation 메시지 안의 긴 문자열>' --query DecodedMessage --output text | python3 -m json.tool
aws iam list-attached-user-policies --user-name b3-1-operator
```

### 5. 대표 사례별 가설 → 검증 → 조치 요약

| 사례 | 유력 가설 | 결정적 검증 | 조치 | 재발 방지 |
|---|---|---|---|---|
| SSH timeout (어제까지 됨) | 내 공인 IP 변경 | `checkip` ≠ SG 22 소스 | SG 22 소스 갱신 | 작업 시작 시 IP 확인 루틴 / Session Manager |
| SSH timeout (처음부터) | SG 22 없음 / 퍼블릭 IP 없음 / 라우팅 | describe-security-groups, describe-instances | 규칙 추가 / EIP 또는 재생성 / 라우트 추가 | 생성 스크립트화 |
| HTTP timeout, localhost OK | SG 80 없음 | describe-security-groups 에 80 없음 | 80 ← 0.0.0.0/0 추가 | 체크리스트 |
| HTTP·SSH 모두 timeout, 내부 curl example.com 실패 | 라우트 테이블에 IGW 경로 없음 / 서브넷 미연결 | describe-route-tables 결과 local 만 | create-route + associate | 커스텀 RT 명시 연결 원칙 |
| HTTP refused | nginx 미실행 / 127.0.0.1 만 listen | `ss -ltnp` | `systemctl start nginx`, listen 수정 | user-data 로 설치, enable |
| /health 404 | location 미적용, default 사이트 우선 | `nginx -T` | conf 수정, default 제거, reload | 설정을 user-data 에 포함 |
| apt 멈춤 | 아웃바운드 라우팅 / SG egress 삭제 | `curl -I example.com`, route 확인 | 라우트/egress 복구 | egress 기본값 유지 |
| `Permission denied (publickey)` | 사용자명/키/권한 | `ssh -v`, `ls -l *.pem` | `ubuntu@`, `chmod 400` | 가이드에 명시 |
| `UnauthorizedOperation` | 정책 액션/조건 누락 | decode-authorization-message | 필요한 액션만 추가 | 정책 버전 관리 |
| `DependencyViolation` | 삭제 순서 | 오류 메시지의 리소스 ID | 의존 리소스 먼저 삭제 | destroy 스크립트 순서 고정 |
| 퍼블릭 IP 가 바뀜 | stop/start | describe-instances | README 갱신 또는 EIP | 중지 대신 유지, 정리 시 EIP release |
