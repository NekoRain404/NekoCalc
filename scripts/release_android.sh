#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-/home/nekorain/Projects/flutter/bin/flutter}"
if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "Flutter not found: $FLUTTER_BIN" >&2
  echo "Set FLUTTER_BIN=/path/to/flutter/bin/flutter and retry." >&2
  exit 1
fi

VERSION_LINE="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE##*+}"
DIST_DIR="$ROOT_DIR/dist"
PREFIX="NekoCalc-v${VERSION_NAME}+${BUILD_NUMBER}"

echo "==> Flutter"
"$FLUTTER_BIN" --version

echo "==> Format check"
dart format --set-exit-if-changed lib test

echo "==> Analyze"
"$FLUTTER_BIN" analyze

echo "==> Test"
"$FLUTTER_BIN" test

echo "==> Build split APKs"
FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}" \
  "$FLUTTER_BIN" build apk --release --split-per-abi

echo "==> Build universal APK"
FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}" \
  "$FLUTTER_BIN" build apk --release

mkdir -p "$DIST_DIR"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$DIST_DIR/${PREFIX}-arm64-v8a.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$DIST_DIR/${PREFIX}-armeabi-v7a.apk"
cp build/app/outputs/flutter-apk/app-x86_64-release.apk "$DIST_DIR/${PREFIX}-x86_64.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$DIST_DIR/${PREFIX}-universal.apk"

echo "==> Checksums"
sha256sum \
  "$DIST_DIR/${PREFIX}-arm64-v8a.apk" \
  "$DIST_DIR/${PREFIX}-armeabi-v7a.apk" \
  "$DIST_DIR/${PREFIX}-x86_64.apk" \
  "$DIST_DIR/${PREFIX}-universal.apk" | tee "$DIST_DIR/${PREFIX}-sha256.txt"

echo "==> Done"
ls -lh "$DIST_DIR/${PREFIX}"-*.apk "$DIST_DIR/${PREFIX}-sha256.txt"
