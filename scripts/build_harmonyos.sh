#!/bin/bash
set -e

echo "==> Nexus Music - Build Harmony OS 6.1.x (HAP)"
echo ""

# Verify Flutter OHOS SDK
if ! flutter doctor -v 2>&1 | grep -q "ohos"; then
    echo "ERROR: Flutter OHOS SDK not detected."
    echo "Please install: https://gitee.com/openharmony-sig/flutter_flutter"
    echo ""
    echo "Quick setup:"
    echo "  git clone -b oh-3.22.0 https://gitee.com/openharmony-sig/flutter_flutter.git"
    echo "  export PATH=\$PATH:/path/to/flutter_flutter/bin"
    echo "  flutter config --enable-ohos"
    exit 1
fi

echo "==> Installing Flutter packages..."
flutter pub get

echo "==> Building HAP (debug)..."
flutter build hap --debug --target-platform ohos-arm64

echo ""
echo "==> Done! HAP package in ohos/entry/build/"
find ohos -name "*.hap" -type f 2>/dev/null
