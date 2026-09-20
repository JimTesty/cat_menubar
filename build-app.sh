#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Cat Menu Bar"
CODE_NAME="cat_menubar"
APP="$PWD/build/$APP_NAME.app"
BIN="$PWD/build/bin/$CODE_NAME"

# Fetch the pinned Apache-2.0 animation assets only when they are absent.
if [[ ! -s Resources/kyome/cat0.png || ! -s Resources/ruslan/cat-walking.json ]]; then
  ./vendor-assets.sh
fi

mkdir -p "$PWD/build/bin"
rm -f "$BIN"

# Compile directly with swiftc. xcrun is useful for locating the macOS SDK, but
# is not mandatory if swiftc already has a default SDK configured.
SWIFTC_ARGS=(
  -O
  -whole-module-optimization
  -target "$(uname -m)-apple-macosx11.0"
  -framework AppKit
  -framework QuartzCore
  -framework IOKit
  -o "$BIN"
)

if command -v xcrun >/dev/null 2>&1; then
  SDK="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
  if [[ -n "$SDK" ]]; then
    SWIFTC_ARGS+=( -sdk "$SDK" )
  fi
fi

swiftc "${SWIFTC_ARGS[@]}" Sources/cat_menubar/*.swift

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$CODE_NAME"
cp -R Resources/kyome "$APP/Contents/Resources/"
cp -R Resources/ruslan "$APP/Contents/Resources/"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>cat_menubar</string>
  <key>CFBundleIdentifier</key><string>local.cat-menubar</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Cat Menu Bar</string>
  <key>CFBundleDisplayName</key><string>Cat Menu Bar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Optional ad-hoc signature. No developer certificate is needed.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP"
fi

echo
echo "Built: $APP"
echo "Run with: open '$APP'"
echo "xctest is not used or required."
