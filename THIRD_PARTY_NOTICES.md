# Third-party notices

Cat Menu Bar (`cat_menubar`) is distributed under the Apache License 2.0. It incorporates or adapts material from the following Apache-2.0 projects.

## Menubar RunCat / RunCat

- Author: Takuto Nakamura (Kyome22)
- Repository: https://github.com/Kyome22/menubar_runcat
- Pinned revision: `82747b139cc32e13a7b713f8521f44c70317f7d4`
- License: Apache License 2.0
- Used for: the original five-frame cat PNG artwork, plus inspiration for sleep/wake handling and lightweight menu-bar behavior.

This project clearly credits RunCat and Takuto Nakamura as the origin of the classic runner artwork.

## RunningCat

- Project owner: `RuslanDemyanov`
- Repository: https://github.com/RuslanDemyanov/RunningCat
- Pinned revision: `e33ca7868092bed8b0f2034815845c52f96aeca2`
- License: Apache License 2.0
- Used for: the `cat walking.json` animation asset and inspiration for `host_processor_info()` CPU sampling and CPU-to-animation-speed mapping.

Cat Menu Bar does not ship Airbnb Lottie. It contains a deliberately small renderer for the subset of Lottie shape features used by this single animation. The renderer currently ignores Lottie's easing curves and the top-level decorative speed-line layers; the underlying cat shapes and keyframes come from the upstream animation.

## RunCat Neo

- Author: Takuto Nakamura (Kyome22)
- Repository: https://github.com/runcat-dev/RunCatNeo
- Pinned revision inspected: `b3b1543049ea0a051ecb78654a45f144724ea737`
- License: Apache License 2.0
- Used for: the low-overhead technique of animating cached frames with `CAKeyframeAnimation` on a layer rather than replacing the menu-bar icon frame-by-frame. RunCat Neo documents a substantial CPU-overhead reduction from this technique in its own profiling; Cat Menu Bar uses the same general architecture.

A copy of the Apache License 2.0 is included as `LICENSE`.
