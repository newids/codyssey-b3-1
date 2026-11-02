# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 저장소는 무엇인가

Codyssey 미션 **B3-1 "내가 만든 웹사이트를 인터넷에 올려 누구나 쓰게 하기"** 의 제출물 저장소다.
AWS 위에 VPC → Public Subnet → Internet Gateway → EC2(웹 서버) 구성을 직접 만들고,
외부 접속 증빙·트러블슈팅·리소스 정리 문서를 남기는 **인프라 실습 과제**이며, 애플리케이션 코드 저장소가 아니다.

유일한 요구사항 원본은 `docs/B3-1 내가 만든 웹사이트를 인터넷에 올려 누구나 쓰게 하기.md` (PDF 동일본 존재)다.
요구사항이 애매하면 이 문서를 먼저 읽고, 문서에 없는 내용은 추측하지 말 것.

현재 저장소에는 빌드/테스트 도구, 패키지 매니저, CI가 없다. `.gitignore` 는 범용 Python 템플릿일 뿐이며
Python 프로젝트가 있다는 뜻은 아니다. 스크립트(헬스체크 서버, 정리 스크립트 등)를 추가하게 되면 그때 이 섹션에 실행 방법을 기록한다.

## 제출물 계약 (파일 경로가 채점 기준)

| 산출물 | 필수 경로 | 포함해야 할 내용 |
|---|---|---|
| 아키텍처 다이어그램 | `docs/architecture.png` 또는 `.pdf` | VPC, Subnet, Internet Gateway, EC2, Security Group + 외부→서비스 트래픽 흐름 |
| 외부 접속 증빙 | `README.md` + 스크린샷 1장 이상 | 선택한 방식 **(A) 브라우저 `http://<퍼블릭IP>`** 또는 **(B) `GET /health` → 200 "OK"** 를 명시, 접속 URL/IP 기재 |
| 트러블슈팅 보고서 | `docs/troubleshooting.md` 또는 `.pdf` | 최소 1건: 증상 → 가설 → 검증 → 조치 → 결과 → 재발방지 |
| 리소스 정리 체크리스트 | `docs/cleanup-checklist.md` | EC2, EBS, Elastic IP, Internet Gateway, VPC 종료/삭제 근거 (+선택: Billing 스크린샷) |

보너스(선택): HTTPS(Let's Encrypt) 적용, Docker 컨테이너로 웹 서비스 배포.
Docker 보너스를 하면 README에 이미지명·실행 방식·포트 매핑·`docker ps` 스크린샷·외부 접속 스크린샷(총 2장 이상)이 추가로 필요하다.

## 절대 위반하면 안 되는 제약 (문서를 쓰거나 AWS 명령을 제안할 때 항상 확인)

- **리전은 `ap-northeast-2`(서울)** 고정. 다른 리전의 리소스·명령 예시를 쓰지 말 것.
- **프리 티어 범위**: micro 급 인스턴스 1대(t2.micro / t3.micro), EBS 8~10GiB, EIP·NAT Gateway·ELB·RDS 는 기본적으로 만들지 않음.
- **루트 계정 사용 금지.** 별도 IAM 사용자/Role 1개만 사용하고, `AdministratorAccess` 부여 금지. 권한은 EC2/VPC/SG 구성에 필요한 범위로 한정하며 S3/RDS 등 무관한 서비스 권한을 넣지 않는다.
- **Security Group 인바운드**: HTTP 80 은 `0.0.0.0/0` 허용, SSH 22 는 **본인 IP(/32) 또는 지정 대역만**. `0.0.0.0/0` 에 전체 포트(0-65535) 허용 규칙은 절대 만들지 않는다.
- Public Subnet 의 Route Table 에 `0.0.0.0/0 → igw-xxxx` 경로가 있어야 하고, 인스턴스는 퍼블릭 IP 자동 할당이 켜져 있어야 한다.
- 실습 종료 후 생성 리소스 전부 삭제. 정리 순서는 의존성 역순: EC2 종료 → EBS/EIP 해제 → IGW detach·삭제 → Subnet/Route Table → VPC.

## 검증 명령 (문서와 보고서에 근거로 남길 것)

인스턴스 내부에서:
```bash
curl -I http://localhost          # 200 이어야 함 (웹 서버 실행 확인)
curl -I https://example.com       # 성공해야 함 (아웃바운드 인터넷 확인)
```

외부(로컬)에서:
```bash
curl -i http://<퍼블릭IP>/        # 방식 A
curl -i http://<퍼블릭IP>/health  # 방식 B, 200 + 고정 문구("OK")
```

## 작업 시 주의

- 스크린샷, 다이어그램 등 바이너리 산출물은 `docs/` 아래에 둔다. 저장소 전체가 제출물이므로 임시 파일을 루트에 남기지 말 것.
- 퍼블릭 IP, 키페어(.pem), 계정 ID, 액세스 키는 문서에 그대로 적지 않는다. IP 는 증빙 스크린샷에 이미 노출되는 범위에서만 README에 기재하고, 키페어 파일은 절대 커밋하지 않는다.
- 트러블슈팅 보고서는 실제로 겪은 장애를 기록해야 한다. 가상의 사례를 만들어 채우지 말 것.
- 커밋 메시지는 기존 관례대로 한국어 `<type>: <설명>` 형식(예: `docs: 트러블슈팅 보고서 추가`).

## 저장소 구조 (2026-10-27 기준)

| 경로 | 역할 |
|---|---|
| `docs/guide/00-수행-가이드.md` | 단계별 수행 절차(콘솔+CLI), 증빙 스크린샷 파일명 규칙(`docs/screenshots/NN-설명.png`) |
| `docs/guide/01-iam-policy-minimal.json` | IAM 최소권한 정책. 서울 리전 조건, micro 외 타입·NAT/ELB/RDS/S3 Deny |
| `docs/guide/02-평가-대비-체크리스트.md` | 요구사항 ↔ 증빙 매핑. 제출 전 전 항목 확인 |
| `docs/guide/03-보너스-https-docker.md` | 보너스 과제 절차 |
| `docs/qa/문제와-답변.md` | 학습 목표 5개 기반 Q&A, 오개념, 시나리오 문제 |
| `docs/architecture.png` / `.md` | 제출용 다이어그램(스크립트 생성) + 해설 |
| `docs/troubleshooting.md`, `docs/cleanup-checklist.md`, `README.md` | 제출 템플릿. `<...>` 자리를 실제 값으로 채워야 함 |
| `scripts/make_architecture_diagram.py` | `python3 scripts/make_architecture_diagram.py` 로 PNG 재생성 (matplotlib) |
| `scripts/user-data.sh` | EC2 user data: Nginx + `/health` 200 "OK" |
| `scripts/create-infra.sh` / `destroy-infra.sh` | AWS CLI 로 전체 생성/역순 삭제. 상태는 `.b3-1-state.env`(gitignore) |
| `scripts/verify.sh <IP>` | 외부 접속 검증, 결과를 `docs/screenshots/verify-*.txt` 로 저장 |
| `scripts/check-leftovers.sh [--all-regions]` | 정리 후 잔여 리소스 0 확인 |

셸 스크립트는 macOS 기본 bash 3.2 에서도 동작해야 한다(`mapfile`, 연관 배열 사용 금지).
