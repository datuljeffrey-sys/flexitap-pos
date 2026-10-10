#!/usr/bin/env bash
# FlexiTap Remote Support Helper (macOS)
set -e

SERVER_ID="rustdesk.flexitapapp.com"
SERVER_KEY="DupmnPdDGeoTy26tsw0JqfcU9rmh5hBotMp8mQMsqAg="

echo "========================================="
echo "   FlexiTap POS Support Helper (macOS)   "
echo "========================================="

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  URL="https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-aarch64.dmg"
else
  URL="https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-x86_64.dmg"
fi

TEMP_DMG="/tmp/rustdesk-flexitap.dmg"
echo "Downloading support client for macOS ($ARCH)..."
curl -fSL "$URL" -o "$TEMP_DMG"

echo "Mounting disk image..."
hdiutil attach "$TEMP_DMG" -nobrowse -quiet 2>/dev/null || true

echo "Setup Complete!"
echo "ID Server: $SERVER_ID"
echo "Key:       $SERVER_KEY"
echo "Please open RustDesk and share your 9-digit ID with your support agent."
open /Volumes/RustDesk* 2>/dev/null || true
