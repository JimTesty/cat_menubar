# Validation status

Validated in the generation environment:

- every Swift source file passes `swiftc -frontend -parse`;
- `Package.swift` parses successfully as a Swift package;
- `build-app.sh` and `vendor-assets.sh` pass `bash -n`;
- the Ruslan animation was inspected programmatically: its inner cat composition has 9 vector shape layers, only `sh`, `st`, `fl`, and `tr` shape operators, no images/text/masks/effects, two animated shape paths, and a 14-frame inner cycle at 25 fps. CoreCat's subset renderer covers those features;
- borrowed assets are pinned to exact upstream revisions and verified by Git blob IDs during vendoring.

Not validated here:

- a full compile/link against the macOS 11 SDK, because this environment is Linux and has no AppKit/macOS SDK;
- runtime CPU/RAM measurements on an M1 Big Sur machine;
- whether the Big Sur M1 AGX driver exposes `Device Utilization %` on every OS point release. GPU reporting therefore degrades to `N/A`.
