# Validation status

Validated by static checks in this checkout:

- every Swift source file passes `swiftc -frontend -parse`;
- `Package.swift` is syntactically valid;
- `build-app.sh`, `vendor-assets.sh`, `make-app-icon.sh`, and `Tests/BuildScriptChecks.sh` pass `bash -n`;
- the build script contains no `xctest`/XCTest dependency and compiles with `swiftc` directly;
- the Ruslan animation was inspected programmatically: its inner cat composition has 9 vector shape layers, only `sh`, `st`, `fl`, and `tr` shape operators, no images/text/masks/effects, two animated shape paths, and a 14-frame inner cycle at 25 fps; the subset renderer covers those features;
- borrowed assets are pinned to exact upstream revisions and `vendor-assets.sh` verifies Git blob IDs when `git` is available.

Build and launch checks:

- the app compiles and links for the current Mac with a macOS 11 deployment target;
- the ad-hoc signed bundle passes `codesign --verify --strict`;
- isolated build-script checks preserve the previous bundle on compile/resource/sign/install failures and shutdown timeout, verify replacement registration before launch, and cover restoring a missing animation frame;
- the entrypoint routes SIGTERM through normal AppKit termination instead of bypassing controller cleanup.

Not covered by these checks:

- rendered animation/panel layout, live SIGTERM handling, and sleep/wake behavior;
- runtime CPU/RAM measurements on supported Apple Silicon hardware;
- whether every supported AGX driver exposes `Device Utilization %`; GPU reporting therefore degrades to `N/A` when unavailable.
