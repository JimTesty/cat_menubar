# Third-party notices

Cat Menu Bar is distributed under the Apache License 2.0. This notice records
the third-party files bundled in the app and the projects that influenced
parts of its implementation. The full license text is in `LICENSE` and is
also copied into the built app bundle.

The upstream revisions below are pinned in `vendor-assets.sh`; that script
also verifies the Git blob IDs of the checked-in assets.

## Bundled assets: Menubar RunCat / RunCat

- Author: Takuto Nakamura (Kyome22)
- Repository: https://github.com/Kyome22/menubar_runcat
- Pinned revision: [`82747b139cc32e13a7b713f8521f44c70317f7d4`](https://github.com/Kyome22/menubar_runcat/tree/82747b139cc32e13a7b713f8521f44c70317f7d4)
- License: Apache License 2.0
- Bundled files: `Resources/classic/cat0.png` through `Resources/classic/cat4.png`
- Upstream source path: `Menubar RunCat/Assets.xcassets/cat_page0.imageset/` through `cat_page4.imageset/`

The five-frame artwork is redistributed under the upstream license.

## Bundled asset: RunningCat

- Author/project owner: RuslanDemyanov
- Repository: https://github.com/RuslanDemyanov/RunningCat
- Pinned revision: [`e33ca7868092bed8b0f2034815845c52f96aeca2`](https://github.com/RuslanDemyanov/RunningCat/tree/e33ca7868092bed8b0f2034815845c52f96aeca2)
- License: Apache License 2.0
- Bundled file: `Resources/ruslan/cat-walking.json`
- Upstream source path: `Sources/RunningCatMenuBar/Resources/cat walking.json`

Cat Menu Bar does not ship Airbnb Lottie. It contains a deliberately small
renderer for the subset of Lottie shape features used by this animation. The
renderer currently simplifies easing and omits the top-level decorative
speed-line layers; the underlying cat shapes and keyframes come from the
upstream animation.

## Implementation inspiration: RunCat Neo

- Author: Takuto Nakamura (Kyome22)
- Repository: https://github.com/runcat-dev/RunCatNeo
- Pinned revision inspected: [`b3b1543049ea0a051ecb78654a45f144724ea737`](https://github.com/runcat-dev/RunCatNeo/tree/b3b1543049ea0a051ecb78654a45f144724ea737)
- License: Apache License 2.0
- Used for: architectural inspiration for animating cached frames with
  `CAKeyframeAnimation` on a layer. No RunCat Neo source files or assets are
  bundled here.

The upstream projects' repository links and licenses are retained here for
attribution. A copy of the Apache License 2.0 is included as `LICENSE`.
