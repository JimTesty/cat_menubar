#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./vendor-assets.sh

swift build -c release

APP="$PWD/build/CoreCat.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/CoreCat"
if [[ ! -x "$BIN" ]]; then
  echo "Could not locate release CoreCat executable at $BIN." >&2
  exit 1
fi
cp "$BIN" "$APP/Contents/MacOS/CoreCat"
cp -R Resources/classic "$APP/Contents/Resources/"
cp -R Resources/ruslan "$APP/Contents/Resources/"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>CoreCat</string>
  <key>CFBundleIdentifier</key><string>local.corecat</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>CoreCat</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signing avoids some launch quirks for hand-built app bundles.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo
echo "Built: $APP"
echo "Run with: open '$APP'"
