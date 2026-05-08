#!/bin/bash
# build.sh — Overpeeped.app バンドルを作る
#
# 1. swift build -c release で実行ファイルをビルド
# 2. .app の Contents/MacOS/, Contents/Info.plist を組み立て
# 3. LSUIElement=YES (Dock に出さないメニューバーアプリ)
# 4. NSAppleEventsUsageDescription を付与 (Ghostty への AppleScript 操作の TCC 説明)
# 5. ad-hoc codesign (署名は自分用、公証なし)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Overpeeped"
APP_BUNDLE="$REPO_DIR/$APP_NAME.app"
BUILD_DIR="$REPO_DIR/.build"

echo "==> swift build -c release"
cd "$REPO_DIR"
swift build -c release

EXEC="$BUILD_DIR/release/$APP_NAME"
if [ ! -f "$EXEC" ]; then
  echo "Error: executable not found at $EXEC" >&2
  exit 1
fi

echo "==> assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$EXEC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Overpeeped</string>
    <key>CFBundleDisplayName</key>
    <string>Overpeeped</string>
    <key>CFBundleIdentifier</key>
    <string>io.otiai10.overpeeped</string>
    <key>CFBundleVersion</key>
    <string>0.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleExecutable</key>
    <string>Overpeeped</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>overpeeped uses AppleScript to bring the Ghostty terminal you clicked to the front, so the chick on your desktop can route you back to its session.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 otiai10</string>
</dict>
</plist>
PLIST

echo "==> ad-hoc codesign"
codesign --force --sign - "$APP_BUNDLE" >/dev/null

echo ""
echo "✨ built: $APP_BUNDLE"
echo ""
echo "次のステップ:"
echo "  - open '$APP_BUNDLE'                       (起動テスト)"
echo "  - bash Scripts/install.sh                  (~/Applications/ と ~/.local/bin/overpeeped に配置)"
