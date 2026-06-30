#!/bin/bash
set -e

echo "==> Nexus Music - Build Linux (Debian)"
echo ""

# Check dependencies
echo "==> Checking Linux dependencies..."
PKGS="libmpv-dev mpv libayatana-appindicator3-dev ninja-build libgtk-3-dev"
for pkg in $PKGS; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        echo "Missing: $pkg"
        echo "Install: sudo apt-get install $PKGS"
        exit 1
    fi
done

echo "==> Installing Flutter packages..."
flutter pub get

echo "==> Enabling update check..."
echo "const updateCheckFlag = true;" > lib/utils/update_check_flag_file.dart

echo "==> Building .deb package..."
dart pub global activate flutter_distributor
flutter_distributor package --platform linux --targets deb

echo ""
echo "==> Done! Package in dist/"
ls -la dist/*.deb 2>/dev/null
