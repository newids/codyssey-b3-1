# 보너스 과제 가이드 (선택)

둘 다 **필수 과제가 완성·증빙된 뒤**에 시작한다. 보너스 작업 중 SG 에 443 을 추가하는 것 외에는 필수 요구사항을 건드리지 않는다.

---

## 보너스 2 — Docker 컨테이너로 웹 서비스 배포 (난이도 낮음, 먼저 추천)

### 목표
EC2 안에서 Docker 로 웹 서비스를 실행하고, 내부(`curl localhost`)와 외부(`http://<IP>/` 또는 `/health`)에서 정상 응답을 확인한다.

### 절차 (Ubuntu 24.04)
```bash
# 1) 기존 Nginx 가 80 을 점유 중이면 중지 (컨테이너가 80 을 쓸 것이므로)
sudo systemctl disable --now nginx

# 2) Docker 설치 (공식 저장소)
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker ubuntu && newgrp docker

# 3) 컨테이너용 콘텐츠 + nginx 설정 (/health 포함)
mkdir -p ~/web && cd ~/web
cat > index.html <<'HTML'
<!doctype html><title>Hello Cloud (Docker)</title><h1>Hello Cloud — served from a Docker container</h1>
HTML
cat > default.conf <<'NGX'
server { listen 80; root /usr/share/nginx/html; index index.html;
  location = /health { default_type text/plain; return 200 "OK\n"; } }
NGX

# 4) 실행: 호스트 80 → 컨테이너 80, 재부팅 시 자동 시작
docker run -d --name web --restart unless-stopped -p 80:80 \
  -v ~/web/index.html:/usr/share/nginx/html/index.html:ro \
  -v ~/web/default.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:1.27-alpine

# 5) 검증
docker ps                              # STATUS: Up ...
curl -i http://localhost/health        # 200 OK
```
외부(로컬 PC)에서 `curl -i http://<퍼블릭IP>/health` 와 브라우저 접속.

### README 에 반드시 포함할 것 (미션 명시)
| 항목 | 예시 |
|---|---|
| 컨테이너 이미지명 | `nginx:1.27-alpine` (또는 이전 미션에서 만든 이미지) |
| 실행 방식 | 위 `docker run` 명령 전문 |
| 포트 매핑 | 호스트 `80` → 컨테이너 `80` (`-p 80:80`) |
| 스크린샷 ≥2장 | `docs/screenshots/15-docker-ps.png` (Up 상태), `16-docker-external.png` (외부 접속) |

### 자주 막히는 곳
- `docker: permission denied` → `usermod -aG docker` 후 재로그인 필요
- 포트 충돌 `bind: address already in use` → 호스트 nginx 가 아직 떠 있음 (`sudo ss -ltnp | grep :80`)
- t2.micro 메모리 1GiB → 이미지는 alpine 계열로, 컨테이너 1개만

---

## 보너스 1 — HTTPS 적용 (Let's Encrypt)

### 사전 조건
- **도메인** 이 필요하다. 무료 서브도메인(예: DuckDNS `xxx.duckdns.org`) 또는 보유 도메인의 A 레코드를 EC2 퍼블릭 IP 로 지정.
- 퍼블릭 IP 는 인스턴스 **중지/시작 시 바뀐다**. 보너스 진행 중에는 중지하지 말거나, Elastic IP 를 할당(단, **정리 시 반드시 Release**).
- SG 인바운드에 **HTTPS 443 ← 0.0.0.0/0** 추가 (이것도 "필요한 포트"이므로 요구사항 위반 아님. README 에 추가 이유를 적는다).

### 절차 (호스트 Nginx 기준)
```bash
# DNS 전파 확인 (내 PC 에서)
dig +short <도메인>          # EC2 퍼블릭 IP 가 나와야 함

# EC2 에서
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d <도메인> --agree-tos -m <이메일> --redirect   # 80→443 리다이렉트 포함
sudo certbot renew --dry-run                                           # 자동 갱신 점검
curl -I https://<도메인>/health                                        # 200
```
Docker 보너스와 함께 하려면 호스트 Nginx 를 리버스 프록시로 두고 컨테이너를 `-p 127.0.0.1:8080:80` 으로 띄우는 구성이 가장 단순하다.

### 증빙
- `docs/screenshots/17-https-browser.png` — 브라우저 자물쇠 + 도메인
- `docs/screenshots/18-certbot.png` — 발급 성공 출력 + `renew --dry-run` 성공
- README 에 도메인, 발급 방식, SG 443 추가 사실 기재

### 정리 시 추가 항목
- Elastic IP Release (할당했다면)
- DNS 레코드 삭제(무료 서브도메인은 방치해도 과금 없음이나 정리 권장)
