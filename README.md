# codyssey-b3-1 — 내가 만든 웹사이트를 인터넷에 올려 누구나 쓰게 하기

AWS 서울 리전(ap-northeast-2)에 VPC → Public Subnet → Internet Gateway → EC2(Nginx) 구성을 직접 구축하고,
보안 그룹·IAM 최소권한을 적용해 외부에서 접속 가능한 웹 서비스를 완성한 미션 제출물입니다.

> `<...>` 로 표시된 곳을 실제 값으로 채우고, 이 안내 블록은 제출 전에 삭제한다.

## 1. 제출물 목록

| # | 결과물 | 경로 |
|---|---|---|
| 1 | 아키텍처 다이어그램 | [`docs/architecture.png`](docs/architecture.png) (대화형: [`docs/architecture.html`](docs/architecture.html), 해설: [`docs/architecture.md`](docs/architecture.md)) |
| 2 | 외부 접속 증빙 | 아래 §3 + [`docs/screenshots/`](docs/screenshots/) |
| 3 | 트러블슈팅 보고서 | [`docs/troubleshooting.md`](docs/troubleshooting.md) |
| 4 | 리소스 정리 체크리스트 | [`docs/cleanup-checklist.md`](docs/cleanup-checklist.md) |

수행 과정 문서: [`docs/guide/00-수행-가이드.md`](docs/guide/00-수행-가이드.md) · 학습 Q&A: [`docs/qa/문제와-답변.md`](docs/qa/문제와-답변.md)

## 2. 구성 요약

| 항목 | 값 |
|---|---|
| 리전 / AZ | ap-northeast-2 / ap-northeast-2a |
| VPC | `<vpc-xxxxxxxx>` 10.0.0.0/16 |
| Public Subnet | `<subnet-xxxxxxxx>` 10.0.1.0/24, 퍼블릭 IP 자동할당 ON |
| Internet Gateway | `<igw-xxxxxxxx>` (VPC attach) |
| Route Table | `<rtb-xxxxxxxx>`: 10.0.0.0/16 → local, 0.0.0.0/0 → igw |
| Security Group | `<sg-xxxxxxxx>`: 80 ← 0.0.0.0/0, 22 ← `<내IP>/32` (전체 포트 개방 규칙 없음) |
| EC2 | `<i-xxxxxxxx>` t2.micro, Ubuntu 24.04 LTS, EBS gp3 8 GiB |
| 웹 서버 | Nginx (`/` → index.html, `/health` → `200 "OK"`) |
| IAM | 사용자 `b3-1-operator` + 정책 [`B3-1-MinimalEC2VPC`](docs/guide/01-iam-policy-minimal.json), AdministratorAccess 없음, 루트 미사용 |

## 3. 외부 접속 검증

- **선택한 방식: `<A 또는 B>`**
  - (A) 브라우저 `http://<퍼블릭IP>/`
  - (B) `GET http://<퍼블릭IP>/health` → `200 OK`, 본문 `OK`
- **접속 정보**: `http://<퍼블릭IP>/` , `http://<퍼블릭IP>/health`
- **검증 일시**: `<YYYY-MM-DD HH:MM KST>` (현재는 리소스 정리 완료로 접속 불가)

```
$ curl -i http://<퍼블릭IP>/health
HTTP/1.1 200 OK
Server: nginx/<버전>
Content-Type: text/plain
...

OK
```

| 증빙 | 파일 |
|---|---|
| 외부 `curl /health` 결과 (B) | ![health](docs/screenshots/08-external-health.png) |
| 브라우저 접속 화면 (A) | ![browser](docs/screenshots/09-external-browser.png) |
| 인스턴스 내부 검증 (`curl localhost`, `curl example.com`, nginx 상태) | ![internal](docs/screenshots/07-ssh-internal-check.png) |

## 4. 요구사항 충족 근거

| 요구사항 | 근거 |
|---|---|
| 네트워크 구성 (VPC/Subnet/IGW/Route) | `docs/screenshots/03-vpc-resource-map.png`, `04-route-table.png` |
| 컴퓨트·웹 서버 (SSH, nginx, curl localhost 200) | `07-ssh-internal-check.png` |
| 보안 그룹 (80 any, 22 내 IP, 전체 포트 없음) | `05-security-group-inbound.png` |
| IAM 최소권한 (사용자 1개, Admin 없음) | `01-iam-user-policy.png`, `02-caller-identity.png` |
| 외부 접속 검증 | §3 |
| 리소스 정리 | `docs/cleanup-checklist.md`, `10~14-*.png` |

## 5. 보너스 (수행한 경우만 남김)

### 보너스 2 — Docker
| 항목 | 값 |
|---|---|
| 컨테이너 이미지 | `<nginx:1.27-alpine 또는 사용한 이미지>` |
| 실행 방식 | `docker run -d --name web --restart unless-stopped -p 80:80 ... <이미지>` |
| 포트 매핑 | 호스트 80 → 컨테이너 80 |
| 검증 | ![docker ps](docs/screenshots/15-docker-ps.png) ![external](docs/screenshots/16-docker-external.png) |

### 보너스 1 — HTTPS
| 항목 | 값 |
|---|---|
| 도메인 | `<xxx.duckdns.org>` |
| 인증서 | Let's Encrypt (certbot --nginx), 자동 갱신 dry-run 성공 |
| SG 추가 | 443 ← 0.0.0.0/0 |
| 검증 | ![https](docs/screenshots/17-https-browser.png) |

## 6. 재현 방법 (CLI)

```bash
aws configure                      # IAM 사용자 자격증명, region ap-northeast-2
scripts/create-infra.sh            # VPC~EC2 생성, 상태를 .b3-1-state.env 에 저장
scripts/verify.sh <퍼블릭IP>        # 외부 접속 검증, 결과를 docs/screenshots/verify-*.txt 로 저장
scripts/destroy-infra.sh           # 역순 삭제
scripts/check-leftovers.sh         # 잔여 리소스 0 확인
```
