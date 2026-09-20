# Validation status

Validated by static checks in this checkout:

- every Swift source file passes `swiftc -frontend -parse`;
- `Package.swift` is syntactically valid;
- `build-app.sh` and `vendor-assets.sh` pass `bash -n`;
- the build script contains no `xctest`/XCTest dependency and compiles with `swiftc` directly;
- the Ruslan animation was inspected programmatically: its inner cat composition has 9 vector shape layers, only `sh`, `st`, `fl`, and `tr` shape operators, no images/text/masks/effects, two animated shape paths, and a 14-frame inner cycle at 25 fps; the subset renderer covers those features;
- borrowed assets are pinned to exact upstream revisions and `vendor-assets.sh` verifies Git blob IDs when `git` is available.

Not covered by these static checks:

- full compile/link against the macOS 11 SDK;
- runtime CPU/RAM measurements on supported Apple Silicon hardware;
- whether every supported AGX driver exposes `Device Utilization %`; GPU reporting therefore degrades to `N/A` when unavailable.
