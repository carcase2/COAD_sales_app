#!/usr/bin/env bash
# Play Console 업로드 키 재설정 시 제출할 PEM을 만듭니다.
# 사용: 프로젝트 루트(sales_app)에서 ./scripts/export_play_upload_certificate.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROPS="android/key.properties"
if [[ ! -f "$PROPS" ]]; then
  echo "android/key.properties 가 없습니다." >&2
  exit 1
fi

# shellcheck source=/dev/null
STORE_FILE="$(grep '^storeFile=' "$PROPS" | cut -d= -f2-)"
KEY_ALIAS="$(grep '^keyAlias=' "$PROPS" | cut -d= -f2-)"
STORE_PASS="$(grep '^storePassword=' "$PROPS" | cut -d= -f2-)"

KS="android/$STORE_FILE"
if [[ ! -f "$KS" ]]; then
  echo "키스토어를 찾을 수 없습니다: $KS" >&2
  exit 1
fi

KEYTOOL="${JAVA_HOME:+${JAVA_HOME}/bin/}keytool"
if ! command -v keytool &>/dev/null; then
  for c in \
    /opt/homebrew/opt/openjdk@17/bin/keytool \
    /opt/homebrew/opt/openjdk@21/bin/keytool \
    /usr/local/opt/openjdk@17/bin/keytool; do
    if [[ -x "$c" ]]; then KEYTOOL="$c"; break; fi
  done
fi
if ! command -v "$KEYTOOL" &>/dev/null && [[ ! -x "$KEYTOOL" ]]; then
  echo "keytool 을 찾지 못했습니다. JDK 설치 또는 JAVA_HOME 설정을 확인하세요." >&2
  exit 1
fi

OUT="upload_certificate.pem"
"$KEYTOOL" -exportcert -rfc \
  -keystore "$KS" \
  -alias "$KEY_ALIAS" \
  -file "$OUT" \
  -storepass "$STORE_PASS"

echo "생성됨: $ROOT/$OUT"
echo "다음으로 SHA1 확인 (Play에 등록할 업로드 키와 일치해야 함):"
"$KEYTOOL" -list -v -keystore "$KS" -alias "$KEY_ALIAS" -storepass "$STORE_PASS" | grep -E 'SHA1:|SHA256:'
