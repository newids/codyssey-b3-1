#!/bin/bash
# EC2 User data (Ubuntu 24.04 / 22.04). 첫 부팅 시 root 로 1회 실행된다.
# 로그: /var/log/cloud-init-output.log
# 역할: Nginx 설치 → "/" 는 Hello Cloud 페이지, "/health" 는 200 + "OK" 고정 응답
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y nginx

cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html lang="ko">
<head><meta charset="utf-8"><title>Hello Cloud — Codyssey B3-1</title></head>
<body style="font-family:sans-serif;margin:3rem">
  <h1>Hello Cloud</h1>
  <p>Codyssey B3-1 · ap-northeast-2 · Public Subnet · Nginx on EC2</p>
  <p>Health check: <a href="/health">/health</a></p>
</body>
</html>
HTML

cat > /etc/nginx/conf.d/b3-1.conf <<'NGX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;

    location = /health {
        default_type text/plain;
        add_header Cache-Control "no-store";
        return 200 "OK\n";
    }
}
NGX

# Ubuntu 기본 사이트가 default_server 를 선점하므로 제거
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

# 자체 검증 (cloud-init 로그에 남음)
curl -sS -o /dev/null -w "localhost / -> %{http_code}\n" http://localhost/
curl -sS -w "localhost /health -> %{http_code} body=" http://localhost/health
