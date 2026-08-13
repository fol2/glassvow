# RC mobile performance floor: external evidence

**Scope:** research input for [#158](https://github.com/fol2/glassvow/issues/158), not the device or frame-rate decision.

**Reviewed:** 13 August 2026. **Evidence rule:** cited bullets are source facts; *Inference* bullets are engineering interpretations for the parent’s decision.

## 1. Store and OS constraints

| Area | Source fact | Consequence to keep separate |
|---|---|---|
| App Store submission | Since 28 April 2026, iOS and iPadOS apps uploaded to App Store Connect must be built with the iOS/iPadOS 26 SDK or later ([Apple](https://developer.apple.com/app-store/submitting/)). | This is a **build-SDK** rule, not an audience OS floor. |
| Apple deployment floor | An app’s minimum deployment target defines the OS-version range it supports; App Store Connect exposes the build’s `MinimumOSVersion` ([Apple](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version/), [Apple](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata/)). Xcode 26.6 supports iOS/iPadOS deployment targets from 15 through 26.5 ([Apple](https://developer.apple.com/xcode/system-requirements)). | The product, not the submission-SDK rule, chooses the lowest iOS/iPadOS version. |
| Google Play submission | New mobile apps and updates must target Android 16 / API 36 from **31 August 2026**; this is upcoming at the review date ([Google Play](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB)). Google explicitly says a current target can still run on older Android versions ([Android Developers](https://developer.android.com/google/play/requirements/target-sdk)). | `targetSdkVersion` is not `minSdkVersion`; do not treat the API-36 policy as the performance floor. |
| Android OS floor | `minSdkVersion` determines the minimum OS version with which an app is compatible and is a market/maintenance decision ([Android Developers](https://developer.android.com/ndk/guides/sdk-versions)). | Set it only after matching the renderer and the intended test cohort. |

### Current Apple compatibility edge (not a performance recommendation)

Apple’s current iOS 26 list includes **iPhone 11** and **iPhone SE (2nd generation)** ([Apple Support](https://support.apple.com/en-au/guide/iphone/iphe3fa5df43/26/ios/26)). Its current iPadOS 26 list includes **iPad (8th generation)**, iPad mini (5th generation), and iPad Air (3rd generation) ([Apple Support](https://support.apple.com/en-au/guide/ipad/ipad213a25b2/26/ipados/26)).

*Inference:* these are useful candidates for the lowest *currently supported-OS* Apple classes, but OS eligibility does not prove a satisfactory sustained game experience. The parent must choose whether the RC floor follows this compatibility edge or a newer performance class.

## 2. Godot 4.7 renderer facts

- Godot 4.7 makes **Mobile** its mobile-oriented renderer: it is a traditional single-pass forward renderer, optimised for mobile GPU heat, battery and bandwidth constraints. Its default reduced-precision path limits HDR; enabling `hdr_2d` increases bandwidth and can reduce mobile performance. Sub-passes reduce tile read/write overhead but constrain effects such as glow and depth of field ([Godot 4.7 internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html)).
- The 4.7 Mobile/Forward+ minimum is Android 9 with full Vulkan 1.0, or iOS/iPadOS 16 with Metal 3. Godot characterises these as minima for a simple 2D/3D export and calls for game-specific low-end testing; its *recommended* Mobile example is an A14 / iPhone 12 or Snapdragon 845-class device ([Godot 4.7 system requirements](https://docs.godotengine.org/en/4.7/about/system_requirements.html)).
- Compatibility is the lower-hardware path (OpenGL ES 3.0; Android 7 minimum), whereas Mobile requires a RenderingDevice-capable stack ([Godot 4.7 renderer overview](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)).
- In 4.7, Metal 4 is used where available on iOS 26+ and falls back to Metal 3 on older supported Apple OS releases ([Godot 4.7 internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html)).

*Inference:* if Glassvow ships the Mobile renderer, its technical support floor should be expressed as **Android 9 + Vulkan 1.0** and **iOS/iPadOS 16 + Metal 3** before naming devices. If it ships Compatibility instead, the addressable Android floor changes materially; that is a renderer/product decision, not a store-policy consequence.

## 3. Audience and device-distribution evidence

### Public original data

**Genre-share gap:** no first-party, current public dataset located that breaks the mobile *roguelite/deckbuilder* audience down by named handset or SoC. Accordingly, this note makes no genre-share claim and does not use vendor-market-share reports as a substitute.

Google’s public Distribution Dashboard is the strongest open, device-capability dataset located. Its data covers active Google Play devices on API 23+ in a 28-day period ending **24 November 2025**. For handhelds it reports: no Vulkan 7.37%, Vulkan 1.0.3 3.86%, Vulkan 1.1 62.09%, Vulkan 1.3 26.01%, and Vulkan 1.4 0.67% ([Google](https://developer.android.com/about/dashboards)).

- Therefore **92.63%** of that historical handheld sample had some Vulkan support (100 - 7.37). This calculation says nothing about game genre, frame rate, thermals, RAM headroom, or the current 2026 population.
- The same source says that project-specific *Reach and devices* is the more granular source for decisions, with Android version, RAM, SoC, Vulkan, screen data, historical trends and CSV export.

### Decision-quality data once a Play build exists

Play Console’s Reach and devices page provides app and peer distributions by Android version, RAM, SoC, GPU, Vulkan version, screen characteristics and device model; app active-device data refreshes daily ([Google Play](https://support.google.com/googleplay/android-developer/answer/10770882?hl=en)). Its device catalogue can export actual supported model, SoC, GPU, RAM and Android-version data ([Google Play](https://support.google.com/googleplay/android-developer/answer/9859371?hl=en)). Android vitals also segments quality and estimated session frame rate by device model ([Google Play](https://support.google.com/googleplay/android-developer/answer/9844486?hl=en)).

App Store Connect Analytics exposes device type (for example, iPhone/iPad) and platform version, subject to diagnostic opt-in and privacy thresholds ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-analytics-filters-and-dimensions/), [Apple](https://developer.apple.com/help/app-store-connect-analytics/overview/analytics-dashboard)).

*Inference:* public data supports a **Vulkan-capability** statement, not a defensible named Android game-audience floor. For an RC decision, rank actual Android models from the project’s Play Console/peer data when available; on Apple, use the owned test fleet for exact model testing and App Store data to validate iPhone/iPad and OS segments afterwards.

## 4. Candidate choices and trade-offs — no selection made

| Candidate | What it tests well | Trade-off / missing evidence |
|---|---|---|
| **Apple current-OS edge:** iPhone 11 or SE (2nd generation), plus iPad (8th generation) | The lowest named iPhone/iPad families currently listed for iOS/iPadOS 26. They make a harsh compatibility-edge test set. | They are not proven as the performance or market-share floor. Require real release-build thermal/frame evidence. |
| **Godot recommended class:** iPhone 12 / A14-equivalent | Directly matches Godot’s Mobile renderer recommendation. | Less conservative; may leave an iOS 26-compatible class untested. |
| **Android technical edge:** a real Android 9, Vulkan-1.0 device | Directly exercises the stated Godot Mobile minimum. | Public distribution does not identify a representative model; old devices may be difficult to obtain and lack current profiling support. |
| **Android measurement anchor:** Pixel 6 or later | Android Macrobenchmark `PowerMetric` is limited to Pixel 6/6 Pro and later, so this is a useful reproducible power-measurement anchor ([Android Developers](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-metrics)). | It is a tooling choice, **not** a market or performance-floor claim. |
| **Android market representative:** named model selected from top project/peer SoC × RAM × Vulkan cohort | Aligns the floor test with the actual intended audience and permits model-specific vitals follow-up. | Needs a Play build, country/peer choices, and James’s availability/buy decision. |

## 5. Frame-rate target options

These are candidate targets only. Their budgets are arithmetic: **60 fps = 16.67 ms/frame** and **30 fps = 33.33 ms/frame**.

| Candidate | Benefit | Cost / proof needed |
|---|---|---|
| **Sustained 60 fps floor** | Consistent 16.67 ms budget and headroom for animated map/combat presentation. | Must prove the floor device remains within its frame-time and thermal gate after warm-up; it doubles update/render opportunities versus 30 fps and can increase power use. |
| **Locked 30 fps floor** | 33.33 ms budget permits a more conservative compatibility edge and may improve sustained thermal/power behaviour. | Parent must accept the lower motion target and ensure pacing is deliberately locked rather than fluctuating between 30 and 60. |
| **Tiered 30/60 mode** | Can preserve broad support while exposing a 60-fps option on stronger devices. | Adds settings, test matrix and determinism/presentation validation; it is only justified by measured device cohorts. |

Android’s frame profiler displays a 16.67-ms frame reference; Macrobenchmark `FrameTimingMetric` reports frame-overrun and CPU-frame duration at P50/P90/P95/P99, with positive overrun meaning a missed deadline ([Android Developers](https://developer.android.com/topic/performance/rendering/inspect-gpu-rendering), [Android Developers](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-metrics)). Apple’s Game Performance template exposes frame duration, skipped v-syncs, CPU/GPU work and thermal state ([Apple](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/)).

*Inference:* select a single target only after comparing the two budgets on the prospective floor hardware. Preserve the full percentile distribution and missed-frame count; an average FPS alone can hide intermittent input-visible stutter.

## 6. Falsifiable physical-device measurement gate

This is a proposed protocol, not a measured result.

1. Test a release/profileable build on each candidate, **not an emulator**. Android’s own Macrobenchmark guidance says emulator results are not representative of real devices ([Android Developers](https://developer.android.com/topic/performance/baselineprofiles/measure-baselineprofile)).
2. Define the same scripted RC route: cold launch, worst visible map transition, and the heaviest representative combat/presentation sequence. Record OS version, build SHA, renderer, brightness, network state, battery start level, charger state and room temperature. Repeat cold and heat-soaked runs.
3. **Frame pacing:** record P50/P90/P95/P99 frame timing plus deadline misses for the selected 30- or 60-fps budget. Android: `FrameTimingMetric`/Perfetto; iOS: Instruments Game Performance/Metal HUD. The Metal HUD records average FPS, GPU time and a 120-frame interval history ([Apple](https://developer.apple.com/documentation/xcode/monitoring-your-metal-apps-graphics-performance/)).
4. **Thermals:** retain the complete sustained trace and fail any agreed unacceptable thermal state, rather than inferring thermals from FPS. Android’s Thermal API reports system throttling changes, and Android’s game guidance says CPU/GPU heat can downclock performance and increase battery drain ([Android Developers](https://developer.android.com/reference/android/os/PowerManager.OnThermalStatusChangedListener), [Android Developers](https://developer.android.com/games/optimize/power)). iOS Game Performance traces include a Thermal State track.
5. **Memory:** report peak and post-route memory, then rerun the route to detect retained growth. iOS can measure `XCTMemoryMetric` and `MXMemoryMetric` peak memory ([Apple](https://developer.apple.com/documentation/xctest/performance-tests), [Apple](https://developer.apple.com/documentation/metrickit/mxmemorymetric/peakmemoryusage)); Android Studio’s release-profileable workflow profiles CPU, memory, graphics and battery on a physical API-29+ device ([Android Developers](https://developer.android.com/studio/profile/)).
6. **Energy:** compare like-for-like unplugged runs. iOS 26 Power Profiler reports system power, thermal state and display brightness; it reports system power as zero while charging ([Apple](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler)). Android Performance Analyzer (open beta) can correlate CPU, GPU, memory and power on Android 12+; its predecessor AGI supports multi-frame CPU/GPU/memory/battery system profiles ([Android Developers](https://developer.android.com/blog/posts/introducing-android-performance-analyzer-the-next-evolution-in-profiling-for-android), [Android Developers](https://developer.android.com/agi/sys-trace/system-profiler)).

*Inference:* make the release gate state the exact route duration, percentile/deadline allowance, maximum thermal status, permitted peak/post-route memory behaviour and energy-per-minute comparison. There is no external evidence here from which to invent an absolute MB or battery-drain limit for Glassvow; those numbers must be baselined on the selected devices.

## Parent decision inputs still required

1. Is the shipped Android renderer Mobile or Compatibility, and what `minSdkVersion` is feasible in the export configuration?
2. Which iPhone, iPad and Android handsets does James own or accept buying/borrowing?
3. Is the desired RC promise 30, 60, or tiered 30/60 fps?
4. Which countries and comparable game peer group define the launch audience for Play Console selection?
