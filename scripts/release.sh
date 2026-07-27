#!/bin/bash
# goldstock Mobile 发布脚本
# 用法: ./scripts/release.sh [apk|aab|ios]

set -e

cd "$(dirname "$0")/../mobile"

case "${1:-apk}" in
  apk)
    echo "=== 构建 Android APK (release) ==="
    flutter build apk --release
    echo "APK: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  aab)
    echo "=== 构建 Android App Bundle (release) ==="
    flutter build appbundle --release
    echo "AAB: build/app/outputs/bundle/release/app-release.aab"
    ;;
  ios)
    echo "=== 构建 iOS (release) ==="
    flutter build ios --release --no-codesign
    echo "iOS 构建完成，需通过 Xcode 打包分发"
    ;;
  *)
    echo "用法: $0 [apk|aab|ios]"
    exit 1
    ;;
esac
