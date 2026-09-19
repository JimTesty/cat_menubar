# CoreCat

A tiny native macOS menu-bar system monitor whose running cat speed follows total CPU load.

**Target:** macOS 11 Big Sur, including Apple Silicon M1.  
**Stack:** Swift + AppKit + QuartzCore + Mach + IOKit. No third-party runtime dependencies.

## What it does

- Animated menu-bar cat, with speed driven by total CPU usage.
- Two cat styles:
  - **Classic RunCat**: the original five-frame RunCat art by Takuto Nakamura (Kyome22).
  - **Ruslan outline**: the `cat walking.json` animation from RuslanDemyanov/RunningCat, rendered by CoreCat's small built-in subset renderer instead of Lottie.
- Click the cat for a live panel showing:
  - total CPU usage;
  - one live bar per logical CPU core;
  - Apple Silicon GPU utilization when the AGX driver exposes it;
  - RAM used / total, compressed memory, and swap.
- Right-click for cat style and Quit.
- Pauses sampling and animation while the Mac sleeps.

## Low-overhead choices

The status animation is a `CAKeyframeAnimation` over cached `CGImage` frames, so Swift does not run a timer for every animation frame. CPU sampling is normally 1 Hz. While the popover is open it rises to 2 Hz and additionally samples RAM/GPU. GPU access reads the AGX driver's `PerformanceStatistics` dictionary directly through IOKit; it does not launch `ioreg` or `powermetrics`.

The AGX GPU statistic is an undocumented driver property. On an M1 it is normally available without root, but CoreCat treats it as best-effort and displays `N/A` if unavailable.

## Build on Big Sur

You need Apple's Swift toolchain / Xcode Command Line Tools. The package deliberately uses `swift-tools-version: 5.3` and `macOS(.v11)` so it does not require the modern Swift 5.9+ toolchains used by newer RunCat projects.

```bash
./build-app.sh
open build/CoreCat.app
```

`build-app.sh` first downloads the two upstream Apache-2.0 animation assets from GitHub, builds a release executable, and assembles an ad-hoc-signed `.app` bundle.

If you already ran `vendor-assets.sh`, rebuilding does not redownload existing assets.

## Caveats

- Per-core CPU numbers are logical-core utilization from Mach processor tick counters. CoreCat intentionally does not guess which logical core is a P-core vs E-core.
- The Ruslan animation renderer implements only the subset of Lottie needed by the bundled animation. It is not intended as a general Lottie library.
- I cannot compile against the macOS 11 SDK in the environment where this source bundle was generated. The code is written to Big Sur-era APIs and Swift 5.3 syntax, but the first build on an actual Big Sur toolchain is the real compatibility test.

## Licenses / attribution

See `THIRD_PARTY_NOTICES.md` and `LICENSE`.
