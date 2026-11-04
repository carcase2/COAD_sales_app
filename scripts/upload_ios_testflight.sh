#!/usr/bin/env bash
# iOS 빌드를 App Store Connect(TestFlight)에 올린다.
# Xcode > Settings > Accounts 에 로그인된 Apple 계정으로 올린다 (API 키·issuer 불필요).
#
#   scripts/upload_ios_testflight.sh          # flutter build ipa 후 업로드
#   scripts/upload_ios_testflight.sh --skip-build   # 이미 만든 아카이브를 업로드
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE=build/ios/archive/Runner.xcarchive
OUT=build/ios/upload

if [[ "${1:-}" != "--skip-build" ]]; then
  flutter build ipa --release
fi

if [[ ! -d "$ARCHIVE" ]]; then
  echo "아카이브가 없습니다: $ARCHIVE (먼저 flutter build ipa --release)" >&2
  exit 1
fi

INFO="$ARCHIVE/Info.plist"
VER=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$INFO")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$INFO")
echo "업로드: v$VER ($BUILD)"

rm -rf "$OUT"
mkdir -p "$OUT"
LOG="$OUT/upload.log"
set +e
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ios/ExportOptions-upload.plist \
  -exportPath "$OUT" \
  -allowProvisioningUpdates 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

if [[ $STATUS -ne 0 ]]; then
  if grep -q "Failed to Use Accounts" "$LOG"; then
    echo >&2
    echo "Xcode의 Apple 계정 로그인이 만료됐습니다." >&2
    echo "Xcode > Settings > Accounts 에서 팀 KV6BD88CVV 계정에 다시 로그인한 뒤" >&2
    echo "  scripts/upload_ios_testflight.sh --skip-build" >&2
    echo "로 다시 올리세요. (웹 App Store Connect 로그인과는 별개입니다)" >&2
  elif grep -q "bundle version must be higher" "$LOG"; then
    echo >&2
    echo "빌드 $BUILD 는 이미 App Store Connect에 올라가 있습니다." >&2
    echo "새로 올리려면 pubspec.yaml 의 +N 을 올리고 다시 빌드하세요." >&2
  fi
  exit "$STATUS"
fi
echo "업로드 완료: v$VER ($BUILD) — App Store Connect에서 처리 후 TestFlight에 뜹니다."
