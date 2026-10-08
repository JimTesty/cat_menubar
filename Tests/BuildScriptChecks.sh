#!/bin/bash
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/cat-build-checks.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
mkdir -p "$TEMP/stubs"

cat > "$TEMP/stubs/swiftc" <<'STUB'
#!/bin/bash
[[ "${FAIL_COMPILE:-0}" == 0 ]] || exit 31
while [[ $# -gt 0 ]]; do
  if [[ "$1" == -o ]]; then
    printf 'fresh executable\n' > "$2"
    exit 0
  fi
  shift
done
exit 1
STUB
cat > "$TEMP/stubs/codesign" <<'STUB'
#!/bin/bash
[[ "${FAIL_SIGN:-0}" == 0 ]] || exit 32
for app; do :; done
touch "$app/signed"
STUB
cat > "$TEMP/stubs/pgrep" <<'STUB'
#!/bin/bash
touch "$BUILD_FIXTURE/process-checked"
case "${RUNNING_APP:-no}" in
  timeout) echo 999999999 ;;
  quits)
    if [[ ! -f "$BUILD_FIXTURE/process-seen" ]]; then
      touch "$BUILD_FIXTURE/process-seen"
      echo 999999999
    else
      exit 1
    fi
    ;;
  *) exit 1 ;;
esac
STUB
cat > "$TEMP/stubs/open" <<'STUB'
#!/bin/bash
[[ -f "$BUILD_FIXTURE/registered" && "$(cat "$BUILD_FIXTURE/registered")" -ef "$1" ]] || exit 34
printf '%s\n' "$1" > "$BUILD_FIXTURE/launched"
STUB
cat > "$TEMP/stubs/lsregister" <<'STUB'
#!/bin/bash
[[ "$1" == -f && "$2" -ef "$BUILD_FIXTURE/build/Cat Menu Bar.app" ]] || exit 35
[[ -f "$2/Contents/MacOS/cat_menubar" && -f "$2/signed" ]] || exit 36
printf '%s\n' "$2" > "$BUILD_FIXTURE/registered"
STUB
cat > "$TEMP/stubs/mv" <<'STUB'
#!/bin/bash
if [[ "${FAIL_INSTALL:-0}" == 1 && "$1" == */Cat\ Menu\ Bar.app && "$1" == */.build-app.*/* ]]; then
  exit 33
fi
exec /bin/mv "$@"
STUB
for stub in xcrun xattr sleep; do
  printf '#!/bin/bash\nexit 0\n' > "$TEMP/stubs/$stub"
done
chmod +x "$TEMP/stubs/"*

fixture() {
  BUILD_FIXTURE="$TEMP/$1"
  export BUILD_FIXTURE
  mkdir -p "$BUILD_FIXTURE/Sources/cat_menubar" "$BUILD_FIXTURE/build/Cat Menu Bar.app"
  # Stub the OS helper's fixed path along with the commands resolved through PATH.
  sed "s|/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister|$TEMP/stubs/lsregister|" \
    "$PROJECT/build-app.sh" > "$BUILD_FIXTURE/build-app.sh"
  touch "$BUILD_FIXTURE/Sources/cat_menubar/main.swift" "$BUILD_FIXTURE/LICENSE" "$BUILD_FIXTURE/THIRD_PARTY_NOTICES.md"
  mkdir -p "$BUILD_FIXTURE/Resources/kyome" "$BUILD_FIXTURE/Resources/ruslan"
  for frame in {0..4}; do
    printf 'frame\n' > "$BUILD_FIXTURE/Resources/kyome/cat$frame.png"
  done
  printf 'animation\n' > "$BUILD_FIXTURE/Resources/ruslan/cat-walking.json"
  touch "$BUILD_FIXTURE/Resources/AppIcon.icns"
  cat > "$BUILD_FIXTURE/vendor-assets.sh" <<'STUB'
#!/bin/bash
touch "$BUILD_FIXTURE/assets-fetched"
printf 'fetched frame\n' > Resources/kyome/cat3.png
STUB
  chmod +x "$BUILD_FIXTURE/vendor-assets.sh"
  printf 'previous bundle\n' > "$BUILD_FIXTURE/build/Cat Menu Bar.app/previous"
}

run_build() {
  PATH="$TEMP/stubs:$PATH" bash "$BUILD_FIXTURE/build-app.sh" "$@" > "$BUILD_FIXTURE/result.log" 2>&1
}

fail() {
  echo "FAIL: $*" >&2
  cat "$BUILD_FIXTURE/result.log" >&2
  exit 1
}

check_preserved() {
  [[ "$(cat "$BUILD_FIXTURE/build/Cat Menu Bar.app/previous")" == 'previous bundle' ]] || fail "Previous bundle was changed"
  [[ ! -e "$BUILD_FIXTURE/launched" ]] || fail "Failed build launched the app"
  local leftover
  for leftover in "$BUILD_FIXTURE/build/".build-app.*; do
    [[ ! -e "$leftover" ]] || fail "Temporary staging directory was retained"
  done
}

fixture compile_failure
if FAIL_COMPILE=1 run_build; then fail "Compilation failure was ignored"; fi
check_preserved
[[ ! -e "$BUILD_FIXTURE/process-checked" ]] || fail "Compilation failure inspected running processes"

fixture resource_failure
rm "$BUILD_FIXTURE/LICENSE"
if run_build; then fail "Resource failure was ignored"; fi
check_preserved
[[ ! -e "$BUILD_FIXTURE/process-checked" ]] || fail "Resource failure inspected running processes"

fixture signing_failure
if FAIL_SIGN=1 run_build; then fail "Signing failure was ignored"; fi
check_preserved
[[ ! -e "$BUILD_FIXTURE/process-checked" ]] || fail "Signing failure inspected running processes"

fixture install_failure
if FAIL_INSTALL=1 run_build --no-restart; then fail "Installation failure was ignored"; fi
check_preserved

fixture no_restart
RUNNING_APP=timeout run_build --no-restart || fail "Successful build failed"
[[ "$(cat "$BUILD_FIXTURE/build/Cat Menu Bar.app/Contents/MacOS/cat_menubar")" == 'fresh executable' ]] || fail "Fresh executable missing"
[[ -f "$BUILD_FIXTURE/build/Cat Menu Bar.app/signed" ]] || fail "Installed app was not signed"
[[ ! -e "$BUILD_FIXTURE/build/Cat Menu Bar.app/previous" ]] || fail "Stale bundle content survived replacement"
[[ ! -e "$BUILD_FIXTURE/process-checked" && ! -e "$BUILD_FIXTURE/launched" ]] || fail "--no-restart touched process or launch commands"
[[ "$(cat "$BUILD_FIXTURE/registered")" -ef "$BUILD_FIXTURE/build/Cat Menu Bar.app" ]] || fail "Installed app was not registered for later manual opening"

fixture restart
RUNNING_APP=quits run_build || fail "Successful restart failed"
[[ "$(cat "$BUILD_FIXTURE/launched")" -ef "$BUILD_FIXTURE/build/Cat Menu Bar.app" ]] || fail "New app was not relaunched"
[[ -f "$BUILD_FIXTURE/build/Cat Menu Bar.app/signed" ]] || fail "Relaunched app was not signed"

fixture missing_frame
rm "$BUILD_FIXTURE/Resources/kyome/cat3.png"
run_build --no-restart || fail "A missing frame was not restored"
[[ -f "$BUILD_FIXTURE/assets-fetched" && -s "$BUILD_FIXTURE/build/Cat Menu Bar.app/Contents/Resources/kyome/cat3.png" ]] || fail "The replacement was missing a required animation frame"

fixture timeout
if RUNNING_APP=timeout run_build; then fail "Shutdown timeout was ignored"; fi
check_preserved
[[ "$(cat "$BUILD_FIXTURE/result.log")" == *'did not quit within 10 seconds'* ]] || fail "Shutdown timeout error missing"

echo "Build script checks passed (failures, replacement, registration before launch, assets, restart, timeout)."
