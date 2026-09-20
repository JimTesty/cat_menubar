#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

KYOME_REV="82747b139cc32e13a7b713f8521f44c70317f7d4"
RUSLAN_REV="e33ca7868092bed8b0f2034815845c52f96aeca2"
KYOME_BLOBS=(
  "215665a15044180c95d4032d137bbd5c8a22eaec"
  "a9671cfcaef814cf8184595902337ae95ccc0a2d"
  "d0ecaeb8fc94fc9c87858523af43a92b34e2e5a9"
  "97bd00ced653d2525505857e70720c049c56fc5f"
  "55f4d0894095bd191a6eb2c2b1fe4b4416570099"
)
RUSLAN_BLOB="6abb23795d08801f72375ed30d732a118c9d473a"

verify_blob() {
  local file="$1"
  local expected="$2"
  if command -v git >/dev/null 2>&1; then
    local actual
    actual="$(git hash-object "$file")"
    if [[ "$actual" != "$expected" ]]; then
      echo "Asset verification failed: $file" >&2
      echo "expected Git blob $expected" >&2
      echo "actual   Git blob $actual" >&2
      rm -f "$file"
      exit 1
    fi
  fi
}

mkdir -p Resources/kyome Resources/ruslan

for n in 0 1 2 3 4; do
  dst="Resources/kyome/cat${n}.png"
  if [[ ! -s "$dst" ]]; then
    echo "Fetching Kyome22 RunCat frame ${n}..."
    url="https://raw.githubusercontent.com/Kyome22/menubar_runcat/${KYOME_REV}/Menubar%20RunCat/Assets.xcassets/cat_page${n}.imageset/cat${n}.png"
    curl -fL --retry 3 --connect-timeout 15 "$url" -o "$dst"
  fi
  verify_blob "$dst" "${KYOME_BLOBS[$n]}"
done

ruslan_url="https://raw.githubusercontent.com/RuslanDemyanov/RunningCat/${RUSLAN_REV}/Sources/RunningCatMenuBar/Resources/cat%20walking.json"
ruslan_dst="Resources/ruslan/cat-walking.json"
if [[ ! -s "$ruslan_dst" ]]; then
  echo "Fetching RuslanDemyanov/RunningCat animation..."
  curl -fL --retry 3 --connect-timeout 15 "$ruslan_url" -o "$ruslan_dst"
fi
verify_blob "$ruslan_dst" "$RUSLAN_BLOB"

echo "Assets ready and verified."
