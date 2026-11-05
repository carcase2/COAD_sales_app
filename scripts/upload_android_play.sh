#!/usr/bin/env bash
# Android AAB를 Google Play(기본: 내부 테스트 트랙)에 올린다.
# Play Console 서비스 계정 키(JSON)로 Google Play Developer API를 직접 부른다 (curl·openssl·jq).
#
#   scripts/upload_android_play.sh                       # 빌드 → 서명 확인 → 내부 테스트 업로드
#   scripts/upload_android_play.sh --skip-build          # 이미 만든 AAB 업로드
#   scripts/upload_android_play.sh --track alpha --notes "출시 노트"
#   scripts/upload_android_play.sh --notes-file RELEASE_NOTE_v1.16.2.md
#
# 키 위치: $PLAY_SERVICE_ACCOUNT_JSON, 없으면 ~/.config/coad/play-service-account.json
# (저장소에 넣지 않는다.)
set -euo pipefail

cd "$(dirname "$0")/.."

PACKAGE=com.coad.customer_calls
TRACK=internal
SKIP_BUILD=0
NOTES=""
KEY_JSON="${PLAY_SERVICE_ACCOUNT_JSON:-$HOME/.config/coad/play-service-account.json}"
AAB=build/app/outputs/bundle/release/app-release.aab

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --track) TRACK="$2"; shift ;;
    --notes) NOTES="$2"; shift ;;
    --notes-file) NOTES="$(cat "$2")"; shift ;;
    *) echo "모르는 옵션: $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "$*" >&2; exit 1; }

for tool in curl openssl jq; do
  command -v "$tool" >/dev/null || die "$tool 이 필요합니다."
done
[[ -f "$KEY_JSON" ]] || die "Play 서비스 계정 키가 없습니다: $KEY_JSON
Google Cloud 서비스 계정 키(JSON)를 받아 이 위치에 두고,
Play Console > 사용자 및 권한에서 그 계정 이메일을 초대해 출시 권한을 주세요."
[[ "$(jq -r .type "$KEY_JSON")" == service_account ]] || die "서비스 계정 키(JSON)가 아닙니다: $KEY_JSON"

VERSION_LINE=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VER=${VERSION_LINE%%+*}
BUILD=${VERSION_LINE##*+}
echo "버전: v$VER ($BUILD) → 트랙 $TRACK"

# Android Studio에 든 Java 25는 Gradle의 Kotlin 스크립트 컴파일이 못 읽는다. Java 21로 빌드.
JAVA21=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
if [[ $SKIP_BUILD -eq 0 ]]; then
  if [[ -d "$JAVA21" ]]; then
    GRADLE_OPTS="-Dorg.gradle.java.home=$JAVA21" flutter build appbundle --release
  else
    flutter build appbundle --release
  fi
fi
[[ -f "$AAB" ]] || die "AAB가 없습니다: $AAB"

# 서명 확인: AAB 인증서 = android/key.properties 의 업로드 키.
KEYTOOL=keytool
[[ -x "$JAVA21/bin/keytool" ]] && KEYTOOL="$JAVA21/bin/keytool"
PROPS=android/key.properties
if [[ -f "$PROPS" ]]; then
  STORE_FILE=$(grep '^storeFile=' "$PROPS" | cut -d= -f2-)
  KEY_ALIAS=$(grep '^keyAlias=' "$PROPS" | cut -d= -f2-)
  STORE_PASS=$(grep '^storePassword=' "$PROPS" | cut -d= -f2-)
  want=$("$KEYTOOL" -list -v -keystore "android/$STORE_FILE" -alias "$KEY_ALIAS" \
    -storepass "$STORE_PASS" 2>/dev/null | awk '/SHA256:/{print $2; exit}')
  got=$("$KEYTOOL" -printcert -jarfile "$AAB" 2>/dev/null | awk '/SHA256:/{print $2; exit}')
  [[ -n "$got" && "$got" == "$want" ]] || die "AAB 서명이 업로드 키와 다릅니다. (AAB: ${got:-없음})"
  echo "서명 확인: 업로드 키와 같음"
fi

# 액세스 토큰 (JWT → OAuth).
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
umask 077
jq -r .private_key "$KEY_JSON" > "$TMP/key.pem"
now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
claims=$(jq -nc --arg iss "$(jq -r .client_email "$KEY_JSON")" --argjson now "$now" \
  '{iss:$iss, scope:"https://www.googleapis.com/auth/androidpublisher",
    aud:"https://oauth2.googleapis.com/token", iat:$now, exp:($now+3600)}' | b64url)
sig=$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign "$TMP/key.pem" | b64url)
TOKEN=$(curl -sS https://oauth2.googleapis.com/token \
  --data-urlencode grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
  --data-urlencode "assertion=$header.$claims.$sig" | jq -r '.access_token // empty')
[[ -n "$TOKEN" ]] || die "Google 인증에 실패했습니다. 키가 맞는지, Play Console에서 이 계정에 권한을 줬는지 확인하세요."

API=https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE
UPLOAD=https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PACKAGE
auth=(-H "Authorization: Bearer $TOKEN")

call() { # call METHOD URL [curl args...] → 응답 JSON, 오류면 중단
  local out
  out=$(curl -sS -X "$1" "${auth[@]}" "$2" "${@:3}")
  if [[ "$(jq -r '.error.message // empty' <<<"$out")" != "" ]]; then
    echo "Play API 오류: $(jq -r .error.message <<<"$out")" >&2
    [[ -n "${EDIT:-}" ]] && curl -sS -X DELETE "${auth[@]}" "$API/edits/$EDIT" >/dev/null || true
    exit 1
  fi
  printf '%s' "$out"
}

EDIT=$(call POST "$API/edits" -H 'Content-Type: application/json' -d '{}' | jq -r .id)
echo "AAB 올리는 중… ($(du -h "$AAB" | cut -f1))"
VC=$(call POST "$UPLOAD/edits/$EDIT/bundles?uploadType=media" \
  -H 'Content-Type: application/octet-stream' --data-binary "@$AAB" | jq -r .versionCode)
[[ "$VC" == "$BUILD" ]] || echo "주의: 올라간 versionCode $VC (pubspec $BUILD)" >&2

release=$(jq -nc --arg name "v$VER" --arg vc "$VC" --arg notes "$NOTES" '
  {name:$name, versionCodes:[$vc], status:"completed"}
  + (if $notes == "" then {} else {releaseNotes:[{language:"ko-KR", text:$notes}]} end)')
call PUT "$API/edits/$EDIT/tracks/$TRACK" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg t "$TRACK" --argjson r "$release" '{track:$t, releases:[$r]}')" >/dev/null
call POST "$API/edits/$EDIT:commit" >/dev/null
echo "업로드 완료: v$VER ($VC) → Play $TRACK 트랙"
