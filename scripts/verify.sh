#!/usr/bin/env bash
# 외부 접속 검증. 로컬 PC(AWS 밖)에서 실행한다.
# 사용: scripts/verify.sh <퍼블릭IP 또는 도메인>
# 결과는 docs/screenshots/verify-<timestamp>.txt 에 텍스트 증빙으로 저장된다.
set -uo pipefail

TARGET="${1:?usage: $0 <public-ip-or-host>}"
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs/screenshots"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/verify-$(date +%Y%m%d-%H%M%S).txt"
FAIL=0

{
  echo "=== B3-1 external verification ==="
  echo "date   : $(date -u +%Y-%m-%dT%H:%M:%SZ) (UTC)"
  echo "target : $TARGET"
  echo "from   : $(curl -fsS https://checkip.amazonaws.com 2>/dev/null || echo unknown) (client public IP)"
  echo

  echo "--- (B) GET http://$TARGET/health ---"
  BODY=$(curl -sS --max-time 10 -w '\n__HTTP_CODE__:%{http_code}' "http://$TARGET/health" 2>&1)
  CODE=$(printf '%s' "$BODY" | sed -n 's/^__HTTP_CODE__://p')
  TEXT=$(printf '%s' "$BODY" | sed '/^__HTTP_CODE__:/d')
  echo "status : ${CODE:-none}"
  echo "body   : $TEXT"
  if [[ "$CODE" == "200" && "$(printf '%s' "$TEXT" | tr -d '[:space:]')" == "OK" ]]; then
    echo "result : PASS (200 + 'OK')"
  else
    echo "result : FAIL"; FAIL=1
  fi
  echo

  echo "--- (A) GET http://$TARGET/ (headers) ---"
  if curl -sS -I --max-time 10 "http://$TARGET/"; then
    CODE_A=$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "http://$TARGET/")
    echo "status : $CODE_A"
    [[ "$CODE_A" == "200" ]] && echo "result : PASS" || { echo "result : FAIL"; FAIL=1; }
  else
    echo "result : FAIL (connection error)"; FAIL=1
  fi
  echo

  echo "--- TCP reachability (timeout vs refused 구분) ---"
  for p in 80 22; do
    if command -v nc >/dev/null 2>&1; then
      if nc -z -w 5 "$TARGET" "$p" 2>/dev/null; then echo "port $p : open"; else echo "port $p : closed/filtered"; fi
    else
      echo "port $p : (nc 없음, 생략)"
    fi
  done
  echo "(22 는 내 IP 에서만 open 이어야 정상. 다른 네트워크에서는 filtered 가 정상)"
} | tee "$OUT"

echo
echo "saved: $OUT"
exit $FAIL
