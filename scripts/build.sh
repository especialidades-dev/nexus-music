#!/bin/bash
set -e

echo "============================================"
echo "  Nexus Music - Build Script"
echo "  Platforms: Linux (.deb) | Harmony OS (.hap)"
echo "============================================"
echo ""

PLATFORM="${1:-linux}"

case "$PLATFORM" in
  linux)
    echo "==> Building for Linux (Debian)"

    # Check if Docker is available for isolated build
    if command -v docker &>/dev/null && [ -f Dockerfile.build.linux ]; then
      echo "==> Docker detected. Building in isolated container..."
      docker build -t nexus-music-builder -f Dockerfile.build.linux .
      docker run --rm -v "$PWD/dist:/app/dist" nexus-music-builder
      echo "==> Build complete. Packages in dist/"
      ls -lh dist/*.deb 2>/dev/null
      exit 0
    fi

    # Fallback to local build
    echo "==> Local build..."
    for cmd in cmake ninja pkg-config; do
      if ! command -v $cmd &>/dev/null; then
        echo "ERROR: $cmd not found. Install build deps:"
        echo "  sudo apt-get install cmake ninja-build pkg-config libgtk-3-dev libmpv-dev mpv libayatana-appindicator3-dev"
        exit 1
      fi
    done

    flutter pub get
    echo "const updateCheckFlag = true;" > lib/utils/update_check_flag_file.dart
    dart pub global activate flutter_distributor
    flutter_distributor package --platform linux --targets deb
    echo "==> Packages in dist/"
    ls -lh dist/*.deb
    ;;

  harmonyos|ohos)
    echo "==> Building for Harmony OS 6.1.x"

    # Verify OHOS Flutter SDK
    if ! flutter doctor -v 2>&1 | grep -q "ohos"; then
      echo ""
      echo "ERROR: Flutter OHOS SDK not detected."
      echo ""
      echo "Setup:"
      echo "  1. git clone -b oh-3.22.0 https://gitee.com/openharmony-sig/flutter_flutter.git"
      echo "  2. export PATH=\$PATH:/path/to/flutter_flutter/bin"
      echo "  3. flutter config --enable-ohos"
      echo ""
      echo "Or build using Docker:"
      echo "  docker build -f Dockerfile.build.harmonyos -t nexus-music-ohos-builder ."
      exit 1
    fi

    flutter pub get
    flutter build hap --debug --target-platform ohos-arm64
    echo "==> HAP package:"
    find ohos -name "*.hap" -type f
    ;;

  *)
    echo "Usage: $0 {linux|harmonyos}"
    echo ""
    echo "  linux     - Build .deb package for Debian/Ubuntu"
    echo "  harmonyos - Build .hap package for Harmony OS 6.1.x"
    exit 1
    ;;
esac
