#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

RESTART=true
case "${1-}" in
  "") ;;
  --no-restart) RESTART=false ;;
  *) echo "Usage: $0 [--no-restart]" >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [--no-restart]" >&2
  exit 2
fi

APP_NAME="Cat Menu Bar"
CODE_NAME="cat_menubar"
APP="$PWD/build/$APP_NAME.app"

# Fetch the pinned animation assets if any required frame or animation is absent.
for asset in Resources/kyome/cat{0..4}.png Resources/ruslan/cat-walking.json; do
  if [[ ! -s "$asset" ]]; then
    ./vendor-assets.sh
    break
  fi
done

mkdir -p "$PWD/build/module-cache"
# Stage on the destination filesystem so installation uses directory renames.
STAGING="$(mktemp -d "$PWD/build/.build-app.XXXXXX")"
STAGED_APP="$STAGING/$APP_NAME.app"
BACKUP="$STAGING/previous.app"
cleanup() {
  local status=$?
  if [[ -d "$BACKUP" && ! -e "$APP" ]]; then
    if ! mv "$BACKUP" "$APP"; then
      echo "Could not restore the previous app; it remains at: $BACKUP" >&2
      return 1
    fi
  fi
  rm -rf "$STAGING"
  return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
BIN="$STAGED_APP/Contents/MacOS/$CODE_NAME"

# Compile with the existing macOS toolchain; no package downloads are needed.
SWIFTC_ARGS=(
  -O
  -whole-module-optimization
  -target "$(uname -m)-apple-macosx11.0"
  -module-cache-path "$PWD/build/module-cache"
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

# A fresh bundle avoids retaining previous signature and resource-seal data.
cp -R Resources/kyome Resources/ruslan "$STAGED_APP/Contents/Resources/"
cp Resources/AppIcon.icns LICENSE THIRD_PARTY_NOTICES.md "$STAGED_APP/Contents/Resources/"

cat > "$STAGED_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>cat_menubar</string>
  <key>CFBundleIdentifier</key><string>local.cat-menubar</string>
  <key>CFBundleIconFile</key><string>AppIcon.icns</string>
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
  # Finder/Preview metadata on copied assets is not allowed in a signed bundle.
  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$STAGED_APP"
  fi
  codesign --force --sign - "$STAGED_APP"
fi

RUNNING_PIDS=""
if [[ "$RESTART" == true ]]; then
  RUNNING_PIDS="$(pgrep -x "$CODE_NAME" || true)"
fi
if [[ -n "$RUNNING_PIDS" ]]; then
  # SIGTERM follows the app's normal Quit path.
  kill $RUNNING_PIDS 2>/dev/null || true
  for _ in {1..50}; do
    if ! pgrep -x "$CODE_NAME" >/dev/null; then
      break
    fi
    sleep 0.2
  done
  if pgrep -x "$CODE_NAME" >/dev/null; then
    echo "The running app did not quit within 10 seconds; the previous bundle is preserved. Quit it manually and retry." >&2
    exit 1
  fi
fi

if [[ -e "$APP" ]]; then
  mv "$APP" "$BACKUP"
fi
mv "$STAGED_APP" "$APP"

# Directory replacement can leave Launch Services pointing at the old bundle.
# Refresh this app's registration before reopening it, including manual opens.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP"
fi

echo
echo "Built: $APP"
if [[ -n "$RUNNING_PIDS" ]]; then
  open "$APP"
  echo "Relaunched: $APP"
fi
