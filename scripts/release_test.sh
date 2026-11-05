#!/usr/bin/env bash
# 테스트 배포를 한 번에: iOS(TestFlight) → Android(Play 내부 테스트).
# 같은 폴더에서 Flutter 빌드가 겹치지 않게 차례로 올린다.
#
#   scripts/release_test.sh                         # 지금 pubspec 버전으로 둘 다
#   scripts/release_test.sh --bump                  # 빌드 번호(+N)를 1 올리고 둘 다
#   scripts/release_test.sh --notes "출시 노트"      # Android 출시 노트 (iOS는 TestFlight에서)
#   scripts/release_test.sh --only ios|android
set -uo pipefail

cd "$(dirname "$0")/.."

ONLY=""
BUMP=0
ANDROID_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) BUMP=1 ;;
    --only) ONLY="$2"; shift ;;
    --notes | --notes-file) ANDROID_ARGS+=("$1" "$2"); shift ;;
    *) echo "모르는 옵션: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$ONLY" in "" | ios | android) ;; *) echo "--only 는 ios 또는 android" >&2; exit 2 ;; esac

if [[ $BUMP -eq 1 ]]; then
  line=$(grep '^version:' pubspec.yaml | awk '{print $2}')
  next="${line%%+*}+$(( ${line##*+} + 1 ))"
  sed -i '' "s/^version: .*/version: $next/" pubspec.yaml
  echo "빌드 번호 올림: $line → $next"
fi

line=$(grep '^version:' pubspec.yaml | awk '{print $2}')
meta=$(grep -o "kAppVersion = '[^']*'" lib/core/constants/app_meta.dart | cut -d"'" -f2)
echo "배포: v${line%%+*} (${line##*+})"
if [[ "$meta" != "${line%%+*}" ]]; then
  echo "주의: app_meta.dart 의 kAppVersion($meta)이 pubspec(${line%%+*})과 다릅니다." >&2
fi

ios=-
android=-
if [[ -z "$ONLY" || "$ONLY" == ios ]]; then
  echo; echo "━━ iOS ━━"
  if scripts/upload_ios_testflight.sh; then ios=성공; else ios=실패; fi
fi
if [[ -z "$ONLY" || "$ONLY" == android ]]; then
  echo; echo "━━ Android ━━"
  if scripts/upload_android_play.sh ${ANDROID_ARGS[@]+"${ANDROID_ARGS[@]}"}; then android=성공; else android=실패; fi
fi

echo
echo "결과  iOS: $ios   Android: $android   (v${line%%+*} / ${line##*+})"
[[ "$ios" != 실패 && "$android" != 실패 ]]
