---
title: "Headless WebGL for Studio Export is a Chromium launch problem, not a Studio URL problem"
date: 2026-08-19
last_updated: 2026-08-19
category: tooling-decisions
module: assets/art/map
problem_type: tooling_decision
component: tooling
severity: high
applies_when:
  - "Driving Studio image-to-3D from gstack browse without a visible window"
  - "Export on /workspace/generate or /3d-model never mounts"
  - "THREE.WebGLRenderer fails with BindToCurrentSequence or Error creating WebGL context"
  - "Choosing Playwright headless true versus new Headless versus headed-offscreen"
root_cause: missing_tooling
resolution_type: documented_workaround
related_components:
  - "development_workflow"
  - "documentation"
tags: [tripo, studio, webgl, headless, browse, chromium, swiftshader, angle, playwright]
---

# Headless WebGL for Studio Export is a Chromium launch problem, not a Studio URL problem

## Context

Tripo Studio's model page
(`https://studio.tripo3d.ai/3d-model/<id>`) gates Export on a successful
`THREE.WebGLRenderer` construct. That is a measured fact of this port's
Studio session, not a Studio API claim.

gstack browse `Mode: launched` is Playwright Chromium-1208 / Chrome for
Testing 145 on this macOS ARM box. The live process is:

```
…/chromium_headless_shell-1208/chrome-headless-shell-mac-arm64/chrome-headless-shell --headless
```

`document.createElement("canvas").getContext("webgl"|"webgl2")` returns
`null`. The console is the Blink + THREE string:

```
THREE.WebGLRenderer: A WebGL context could not be created. Reason: Could not create a WebGL context, VENDOR = 0xffff, DEVICE = 0xffff, GL_VENDOR = Google Inc. (Google), GL_RENDERER = ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (LLVM 10.0.0) (0x0000C0DE)), SwiftShader driver-5.0.0), GL_VERSION = 5.0.0, Sandboxed = yes, Optimus = no, AMD switchable = no, Reset notification strategy = 0x8252, ErrorMessage = BindToCurrentSequence failed: .
THREE.WebGLRenderer: Error creating WebGL context.
```

A cold GET of `/3d-model/<id>` is HTTP 500 `Error creating WebGL context`.
The SPA from `/assets` loads chrome; Export never mounts. Headed gstack
Chromium (the full `chromium-1208` binary, not the shell) mounts Export.

This note records what first-party Playwright, Chrome, Chromium, ANGLE,
and THREE documents actually say, plus what gstack browse on disk will
and will not pass. It does not invent that a flag works.

## 1. Playwright `headless: true` vs `"shell"` vs headed-offscreen

Three different products share the word "headless."

### Chrome's two Headless modes

Chrome documents the split at
[Chrome Headless mode](https://developer.chrome.com/docs/chromium/headless)
and
[chrome-headless-shell](https://developer.chrome.com/blog/chrome-headless-shell):

- **New Headless** (`chrome --headless`, Chrome 112+). Unified with headed
  Chrome. Since Chrome 112, "Chrome creates, but doesn't display, any
  platform windows. All other functions, existing and future, are
  available with no limitations."
- **Headless Shell** (old implementation). Since Chrome 132.0.6793.0 it
  ships only as a standalone `chrome-headless-shell` binary from Chrome
  for Testing. Chrome: it is "a lightweight wrapper around Chromium's
  `//content` module" and "does not require X11/Wayland, D-Bus"; new
  Headless is "the real Chrome browser" and "more authentic."

Puppeteer (Chrome's own automation API) maps that split as
([pptr.dev/guides/headless-modes](https://pptr.dev/guides/headless-modes);
same text on the Chrome Headless page):

| Puppeteer `headless` | Binary |
|---|---|
| `true` (default since Puppeteer 22) | New Headless (real Chrome, no UI) |
| `'shell'` | `chrome-headless-shell` |
| `false` | Headed |

### Playwright's mapping is the other way around

Playwright's public launch type is a boolean, not `"shell"`:

```ts
headless?: boolean;  // defaults to true
```

([playwright.dev BrowserType.launch](https://playwright.dev/docs/api/class-browsertype#browser-type-launch);
confirmed in Playwright `packages/playwright-core/types/types.d.ts`).
Passing `headless: "shell"` is a **Puppeteer** option. Playwright's
published type does not accept it.

What Playwright actually launches
([playwright.dev/docs/browsers](https://playwright.dev/docs/browsers#chromium-headless-shell);
Playwright source `chromium.ts` `getExecutableName`):

```ts
return options.headless ? 'chromium-headless-shell' : 'chromium';
```

| Playwright launch | Binary | Chrome product |
|---|---|---|
| `chromium.launch({ headless: true })` (default; no `channel`) | `chrome-headless-shell` | Old Headless Shell |
| `chromium.launch({ headless: true, channel: 'chromium' })` | full Chrome for Testing + `--headless` | New Headless |
| `chromium.launch({ headless: false })` | full Chrome for Testing | Headed |
| `launchPersistentContext(..., { headless: false })` | full Chrome for Testing, persistent profile | Headed |

Playwright 1.57 switched headed to Chrome for Testing `chrome` and
default headless to `chrome-headless-shell`
([release notes](https://playwright.dev/docs/release-notes)).
Playwright #33566 is explicit that GPU/WebGL "availability, features and
performance will vary" between old shell and new Headless.

Chrome's first-party GPU note for the **shell** is
[Puppeteer troubleshooting](https://pptr.dev/troubleshooting#chrome-headless-shell-disables-gpu-compositing):

> chrome-headless-shell requires `--enable-gpu` to
> [enable GPU acceleration in headless mode](https://crbug.com/1416283).

The Chrome Web-AI blog
([Supercharge Web AI model testing](https://developer.chrome.com/blog/supercharge-web-ai-testing))
states the same starting point for Headless Chrome: "By default, Headless
Chrome disables GPU" (citing crbug 1416283). That post's working recipe
is **new** Headless (`headless: 'new'` / `--headless=new`) plus Linux
Vulkan flags against a real NVIDIA GPU. It is not a macOS ARM recipe,
and it does not claim the shell plus SwiftShader is enough.

### Headed-offscreen

Chrome's documented "no visible UI, real Chrome" path is new Headless:
the browser still creates platform windows, it just does not show them.

gstack browse has a different off-screen trick. When
`BROWSE_EXTENSIONS_DIR` is set, `launch()` forces `useHeadless = false`
and adds `--window-position=-9999,-9999 --window-size=1,1`
(`~/.claude/skills/gstack/browse/src/browser-manager.ts:357-369`). That
is headed Chromium parked off-screen so extensions can load. It is not
new Headless and it is not the default `Mode: launched` path.

## 2. SwiftShader WebGL deprecation and `--enable-unsafe-swiftshader`

Chromium's own GPU doc
([docs/gpu/swiftshader.md](https://chromium.googlesource.com/chromium/src/+/main/docs/gpu/swiftshader.md)):

> Allowing automatic fallback to WebGL backed by SwiftShader has been
> deprecated and WebGL context creation will soon fail instead of
> falling back to SwiftShader.

Reasons given there (and repeated in the
[Chrome 138 beta notes](https://developer.chrome.com/blog/chrome-138-beta)
and the
[blink-dev Intent to Remove](https://groups.google.com/a/chromium.org/g/blink-dev/c/yhFguWS_3pM)):

1. SwiftShader JITs in the GPU process (security).
2. Users get a silent drop from GPU WebGL to CPU WebGL.

The documented opt-in is **`--enable-unsafe-swiftshader`**. The same
Chromium doc lists the only SwiftShader switches it endorses:

| Role | Switches Chromium documents |
|---|---|
| GLES driver (SwANGLE = ANGLE + SwiftShader Vulkan) | `--use-gl=angle --use-angle=swiftshader` |
| Unsafe WebGL fallback | `--use-gl=angle --use-angle=swiftshader-webgl --enable-unsafe-swiftshader` |
| Vulkan driver | `--use-vulkan=swiftshader` (needs `enable_swiftshader_vulkan`) |

`--enable-unsafe-swiftshader` is a real Chromium switch
(`ui/gl/gl_switches.cc`: `kEnableUnsafeSwiftShader = "enable-unsafe-swiftshader"`).
Chrome's deprecation guide cites it as the local-dev flag that
"re-enable[s] usage of SwiftShader as a fallback for software WebGL"
([Feature deprecation and removal in Chrome](https://developer.chrome.com/docs/web-platform/chrome-deprecation)).

Timeline from first-party posts, not inference:

- Chrome 130: DevTools warning when a WebGL context is SwiftShader-backed.
  Passing `--enable-unsafe-swiftshader` removes the warning
  (Intent; Chrome 138 beta).
- Chrome 137: Intent's estimated desktop ship milestone.
- Chrome 139: Finch experiments to **remove SwiftShader on macOS and
  Linux**, replace it with WARP on Windows, and stop the OOM fallback
  (David Adrian, 2025-07-09, same Intent thread).
- Chrome 145 (this box): well after that Finch start.

The Intent also records a Chrome GPU-team fact that matters on this
machine (David Adrian, 2025-03-10):

> SwiftShader is already unused on many Mac clients, **since it does
> not support ARM**. We will run an experiment where we fully remove it
> on Mac.

Geoff Lang (2025-09-02, same thread): SwiftShader "will remain available
by command line flag." That is the opt-in, not a promise that the
opt-in produces a working WebGL2 context on Apple silicon.

Chromium is also explicit that WebGL is fallible:

> Chromium and other browsers do not guarantee WebGL availability.
> Please test and handle WebGL context creation failure and fall back
> to other web APIs such as Canvas2D
> ([swiftshader.md](https://chromium.googlesource.com/chromium/src/+/main/docs/gpu/swiftshader.md)).

## 3. `BindToCurrentSequence failed`, `Sandboxed = yes`, `VENDOR = 0xffff`

The console line is assembled in Blink, not in THREE.

`third_party/blink/renderer/modules/webgl/webgl_rendering_context_base.cc`
(`CreateContextProviderInternal` / `ExtractWebGLContextCreationError`):

1. Blink asks the browser for a `WebGraphicsContext3DProvider`.
2. If the provider exists but `BindToCurrentSequence()` returns false,
   Blink prepends `BindToCurrentSequence failed: ` to whatever
   `context_info->error_message` already held and drops the provider.
3. The user-visible reason string is then:

   `Could not create a WebGL context, VENDOR = …, DEVICE = …, GL_VENDOR = …, GL_RENDERER = …, GL_VERSION = …, Sandboxed = yes|no, … ErrorMessage = ….`

4. `VENDOR` / `DEVICE` print `0xffff` when `vendor_id` / `device_id`
   are zero (`info.vendor_id ? Format("0x{:04x}", …) : "0xffff"`).
   Zero PCI IDs are the software / unknown-GPU case, not a real Apple
   GPU.
5. `Sandboxed = yes` is `info.sandboxed` — the GPU process is running
   sandboxed.
6. The empty suffix after `BindToCurrentSequence failed: ` means
   `context_info->error_message` was empty. Blink has no extra GPU
   error to attach.

So the measured failure is: a SwiftShader-via-ANGLE Vulkan adapter was
**selected** (`GL_RENDERER` names it), then the renderer thread failed
to bind that GPU channel to the current sequence. It is not "Studio hid
Export," and it is not the deprecation's clean "refuse to create a
SwiftShader context" path (that path would not still print a SwiftShader
`GL_RENDERER`).

### What Chromium actually documents for the related flags

These switches exist. Chromium's comments say what they *do*. They do
**not** say they fix `BindToCurrentSequence failed`.

| Switch | Where Chromium defines it | What the comment says |
|---|---|---|
| `--disable-gpu-sandbox` | `sandbox/policy/switches.cc` `kDisableGpuSandbox` | "Disables the GPU process sandbox." |
| `--in-process-gpu` | `content/public/common/content_switches.cc` `kInProcessGPU` | "Run the GPU process as a thread in the browser process." |
| `--use-angle=` | `ui/gl/gl_switches.cc` `kUseANGLE` | Select ANGLE backend. Documented values include `swiftshader`, `swiftshader-webgl`, `vulkan`, `metal`, `gl`, `default`. |
| `--use-gl=` | `ui/gl/gl_switches.cc` `kUseGL` | Select the GPU process GL implementation (`angle`, `egl`, …). |
| `--ignore-gpu-blocklist` | `gpu/config/gpu_switches.cc` `kIgnoreGpuBlocklist` | "Ignores GPU blocklist." |
| `--enable-unsafe-swiftshader` | `ui/gl/gl_switches.cc` | "Allow usage of SwiftShader for WebGL." |
| `--no-sandbox` | `sandbox/policy/switches.cc` `kNoSandbox` | "Disables the sandbox for all process types that are normally sandboxed." Browser-level; **not** the GPU-process sandbox bit. |
| `--disable-gpu` | `content_switches.cc` `kDisableGpu` | "Disables GPU hardware acceleration. If software renderer is not in place, then the GPU process won't launch." Wrong lever for creating WebGL. |
| `--disable-software-rasterizer` | `content_switches.cc` | "Disables the use of a 3D software rasterizer." |

On macOS, ANGLE's Metal backend is the documented hardware path
([ANGLE README](https://chromium.googlesource.com/angle/angle/+/HEAD/README.md):
Metal "complete" on macOS 10.14+). Chromium even defaults ANGLE-on-Mac
to Metal (`ui/gl/gl_switches.cc` `kDefaultANGLEMetal` is
`FEATURE_ENABLED_BY_DEFAULT`). The shell session on this box did **not**
take that path; it took SwANGLE / SwiftShader Vulkan.

Playwright's current `chromium.ts` (main) injects
`--enable-unsafe-swiftshader` for every Chromium launch, citing
[crbug 40277080](https://issues.chromium.org/issues/40277080). That is
Playwright main, not a promise that gstack's bundled Playwright 1.58 /
Chromium-1208 does the same. The live `Mode: launched` GPU child on
this box was measured **without** `--enable-unsafe-swiftshader`. Even
if that flag is added, the error we already have is a **bind** failure
after SwiftShader was selected, so the flag is not, by itself, a
documented fix.

## 4. WebGL2 vs WebGL1 for THREE r1xx+

THREE's current `WebGLRenderer` is WebGL **2 only**.

From `src/renderers/WebGLRenderer.js` (dev / current docs):

> This renderer uses WebGL 2 to display scenes.
> WebGL 1 is not supported since `r163`.

Constructor behaviour:

- If a `context` is passed and it is a `WebGLRenderingContext`
  (WebGL 1), THREE **throws**:
  `THREE.WebGLRenderer: WebGL 1 is not supported since r163.`
- Otherwise it calls only `canvas.getContext('webgl2', attrs)`.
- It never tries `'webgl'` / `'experimental-webgl'`.
- On `webglcontextcreationerror` it logs exactly
  `THREE.WebGLRenderer: A WebGL context could not be created. Reason: `
  plus `event.statusMessage` — the line we captured.
- `getContext()` on the renderer is typed and documented as returning
  `WebGL2RenderingContext`
  ([threejs.org WebGLRenderer](https://threejs.org/docs/pages/WebGLRenderer.html)).

`failIfMajorPerformanceCaveat` defaults to `false`. Studio is not
failing because THREE asked for a high-performance GPU and refused
SwiftShader. It is failing because `getContext('webgl2')` returned
`null`.

WebGL1 succeeding would not help a current THREE `WebGLRenderer`.
Probing `getContext("webgl")` on this box is useful as a GPU-process
smoke test; the Export gate needs **WebGL2**.

## 5. What gstack browse will and will not pass on this box

gstack browse launch is
`~/.claude/skills/gstack/browse/src/browser-manager.ts`.

### `Mode: launched` (default)

```ts
this.browser = await chromium.launch({
  headless: useHeadless,          // true unless BROWSE_EXTENSIONS_DIR
  chromiumSandbox: shouldEnableChromiumSandbox(),
  args: [...STEALTH_LAUNCH_ARGS, ...buildGStackLaunchArgs()],
});
```

- `STEALTH_LAUNCH_ARGS` is only
  `--disable-blink-features=AutomationControlled`
  (`stealth.ts:477-479`).
- `buildGStackLaunchArgs()` emits `--gstack-*` spoofs only when
  `GSTACK_GPU_*` / `GSTACK_PLATFORM` / … are set. Those flags are
  no-ops on stock Playwright Chromium (they need gbrowser C++ patches).
  They do not create a GL context.
- On this Mac (not Windows, not `CI`, not `CONTAINER`, not root,
  `GSTACK_CHROMIUM_NO_SANDBOX` unset) `shouldEnableChromiumSandbox()`
  returns **true**. Playwright then does **not** add `--no-sandbox`
  (`chromium.ts`: `if (options.chromiumSandbox !== true) args.push('--no-sandbox')`).
  Playwright's own default is `chromiumSandbox: false`. gstack flips
  it on for desktop Mac.
- There is no `--enable-unsafe-swiftshader`, no `--enable-gpu`, no
  `--disable-gpu-sandbox`, no `--in-process-gpu`, no
  `--use-angle=metal`, no `--ignore-gpu-blocklist`, no
  `channel: 'chromium'`.
- `GSTACK_CHROMIUM_PATH` is honoured only on the **headed** persistent
  path, not on `launch()`.

### `Mode: headed` (`browse --headed` / `browse connect` / `handoff`)

`launchPersistentContext(userDataDir, { headless: false, … })`
(`browser-manager.ts:579-591`). Full Chrome for Testing, visible
window, real Metal GPU on this Mac. Export mounts (measured).

### Off-screen headed without forking

Set `BROWSE_EXTENSIONS_DIR` to an unpacked extension directory. `launch()`
then sets `useHeadless = false` and parks the window at `-9999,-9999`.
That is the only in-tree way to get the full Chromium binary from the
`launch()` path. It still does not add GPU flags.

### What we would pass (a one-off Playwright probe, not gstack)

If we spawn Playwright ourselves against the **full** Chromium-1208
binary (new Headless), the flags Chromium documents for "real Chrome,
no window, allow software WebGL if hardware is missing" are:

```js
await chromium.launch({
  headless: true,
  channel: 'chromium',   // new Headless; not the shell
  chromiumSandbox: true, // match gstack's Mac default, or false to add --no-sandbox
  args: [
    // Chromium documents these. This list is not a measured-working recipe.
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=metal',          // ANGLE's documented macOS hardware backend
    // software fallback only if Metal is unavailable:
    // '--use-angle=swiftshader-webgl',
  ],
});
```

A **shell** probe, if we insist on staying on `chrome-headless-shell`,
would add the one flag Puppeteer documents for GPU on that binary:

```js
await chromium.launch({
  headless: true,                 // Playwright: this *is* the shell
  args: [
    '--enable-gpu',               // pptr.dev: required for shell GPU compositing
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader-webgl',
  ],
});
```

`--disable-gpu-sandbox` and `--in-process-gpu` are the Chromium switches
that change `Sandboxed = yes` / the GPU process topology. No first-party
page says they make `BindToCurrentSequence` succeed. Treat them as a
second probe, not as a documented fix.

### What we cannot do without forking browse

gstack browse has no env var and no CLI flag that appends extra Chromium
args. `STEALTH_LAUNCH_ARGS` is a one-line constant. `channel` is never
set. `GSTACK_CHROMIUM_PATH` does not apply to `Mode: launched`.

So without editing `browser-manager.ts` (or wrapping `launch()`):

- We cannot pass `--enable-unsafe-swiftshader`, `--enable-gpu`,
  `--use-angle=metal`, `--disable-gpu-sandbox`, or `--in-process-gpu`.
- We cannot set `channel: 'chromium'` to opt the launched daemon into
  new Headless.
- We cannot flip `headless` to `false` except via `--headed` / `connect`
  / `handoff` / `BROWSE_EXTENSIONS_DIR`.

What we **can** do without a fork:

1. `browse --headed` / `browse connect` / `browse handoff` — full
   Chromium, Metal, Export mounts (measured).
2. `BROWSE_EXTENSIONS_DIR=…` — off-screen headed, same binary.
3. A one-off Playwright script against the cached
   `chromium-1208` / `chromium_headless_shell-1208` binaries, separate
   from the browse daemon.
4. `browse disconnect` first if the daemon is already up with the
   wrong mode (browse refuses a silent restart).

Do not spawn a second Default Chrome against the user's daily profile.
`GSTACK_CHROMIUM_PATH` / the Playwright cache are the binaries to use.

`GSTACK_STEALTH=extended` spoofs `WebGLRenderingContext.getParameter`
vendor/renderer strings (`stealth.ts:268-277`). It does not create a
context. It cannot unstick Export.

## 6. Cheaper than a full 3D context?

No first-party source says Studio, or THREE's `WebGLRenderer`, will
accept a substitute.

- **OffscreenCanvas.** THREE documents `canvas` as
  `HTMLCanvasElement | OffscreenCanvas`. The constructor still calls
  `canvas.getContext('webgl2', …)`. Offscreen is the same GPU
  requirement on a different surface.
- **THREE addons.** `SVGRenderer` and `CSS3DRenderer` exist under
  Addons → Renderers. They are not `WebGLRenderer`. Nothing in THREE
  or Studio says the Export chrome will construct those instead.
- **Stub `getContext`.** THREE immediately runs `initGLContext()`
  (`createFramebuffer`, extensions, caps). A fake non-null return is
  not a documented contract and would throw on the first real GL call.
  We already measured that Studio treats a failed `WebGLRenderer`
  construct as "no Export" / HTTP 500.
- **Canvas2D.** Chromium tells *sites* to fall back to Canvas2D when
  WebGL creation fails. That is advice to the page author, not a
  switch we can flip so Studio mounts Export.

"Load the WebGL UI" on this product means a real WebGL2 context.

## Verdict

`Mode: launched` is Playwright's **headless shell**. Chrome documents
that binary as the old, lighter Headless, and Puppeteer documents that
it disables GPU compositing unless `--enable-gpu` is passed. gstack
does not pass that flag, does not pass `--enable-unsafe-swiftshader`,
and does not opt into new Headless (`channel: 'chromium'`).

The console is Blink reporting: software/unknown PCI IDs (`0xffff`),
SwiftShader-via-ANGLE selected, GPU process sandboxed, then
`BindToCurrentSequence()` failed. Chrome's GPU team has said SwiftShader
does not support ARM on many Macs. Headed full Chromium on this box
uses ANGLE Metal and Export mounts.

The path that first-party docs support on this machine is **real
Chrome** (new Headless or headed / off-screen headed), not a SwiftShader
shell and not a stubbed `getContext`.

## What to try next on this box

1. **New Headless probe, no gstack fork.** One-off Playwright against
   the full `chromium-1208` binary:
   `chromium.launch({ headless: true, channel: 'chromium' })`.
   Evaluate `!!document.createElement('canvas').getContext('webgl2')`
   and dump `chrome://gpu` (WebGL / WebGL2 / GL_RENDERER). If WebGL2
   is hardware Metal, cookie-import and `goto` `/3d-model/<id>` and
   see whether Export mounts.
2. **Same probe with `--use-angle=metal` only.** ANGLE documents Metal
   as the macOS backend. Do not add SwiftShader flags on this step.
3. **Shell + documented GPU flags, as a negative control.**
   `headless: true` (no channel) plus `--enable-gpu
   --enable-unsafe-swiftshader --use-gl=angle
   --use-angle=swiftshader-webgl`. If `getContext('webgl2')` is still
   null, software WebGL on this ARM Mac + shell is a dead end; stop
   spending time on it.
4. **Optional bind-failure probe, last.** Repeat (1) or (3) with
   `--disable-gpu-sandbox` and, separately, `--in-process-gpu`. Record
   `Sandboxed =` and whether `BindToCurrentSequence` remains. Do not
   treat a green result as a gstack default; those flags weaken the
   GPU process isolation Chromium documents.
5. **Keep generate in the shell; Export in headed / new Headless.**
   Generate does not need WebGL. `browse --headed` / `connect` /
   `BROWSE_EXTENSIONS_DIR` already give the full binary without a
   browse fork.
6. **Do not** cold-GET `/3d-model/<id>` or `/workspace/generate` in
   the shell. Do not stub `getContext`. Do not call
   `openapi.tripo3d.ai` / `platform.tripo3d.ai`. Do not download
   `*_meshopt.glb` as a kit mesh.

## Sources

- [Playwright Browsers — headless shell and new Headless](https://playwright.dev/docs/browsers)
- [Playwright BrowserType.launch (`headless` boolean, `channel`)](https://playwright.dev/docs/api/class-browsertype#browser-type-launch)
- [Playwright 1.57 / 1.49 notes and issue #33566](https://github.com/microsoft/playwright/issues/33566)
- [Playwright `chromium.ts` `getExecutableName` / default args](https://github.com/microsoft/playwright/blob/main/packages/playwright-core/src/server/chromium/chromium.ts)
- [Chrome Headless mode (new vs shell)](https://developer.chrome.com/docs/chromium/headless)
- [chrome-headless-shell](https://developer.chrome.com/blog/chrome-headless-shell)
- [Puppeteer headless modes](https://pptr.dev/guides/headless-modes)
- [Puppeteer: chrome-headless-shell disables GPU compositing](https://pptr.dev/troubleshooting#chrome-headless-shell-disables-gpu-compositing)
- [Supercharge Web AI model testing (Headless Chrome disables GPU)](https://developer.chrome.com/blog/supercharge-web-ai-testing)
- [Chromium `docs/gpu/swiftshader.md`](https://chromium.googlesource.com/chromium/src/+/main/docs/gpu/swiftshader.md)
- [Chrome 138 beta — Remove SwiftShader fallback](https://developer.chrome.com/blog/chrome-138-beta)
- [Chrome deprecation guide — `enable-unsafe-swiftshader`](https://developer.chrome.com/docs/web-platform/chrome-deprecation)
- [blink-dev Intent to Remove: SwiftShader Fallback](https://groups.google.com/a/chromium.org/g/blink-dev/c/yhFguWS_3pM)
- [Chrome Status 5166674414927872](https://chromestatus.com/feature/5166674414927872)
- [Chromium `sandbox/policy/switches.cc`](https://chromium.googlesource.com/chromium/src/+/main/sandbox/policy/switches.cc)
- [Chromium `content/public/common/content_switches.cc`](https://chromium.googlesource.com/chromium/src/+/main/content/public/common/content_switches.cc)
- [Chromium `ui/gl/gl_switches.cc`](https://chromium.googlesource.com/chromium/src/+/main/ui/gl/gl_switches.cc)
- [Chromium `gpu/config/gpu_switches.cc`](https://chromium.googlesource.com/chromium/src/+/main/gpu/config/gpu_switches.cc)
- [Blink `webgl_rendering_context_base.cc` (`BindToCurrentSequence failed`, `0xffff`)](https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/modules/webgl/webgl_rendering_context_base.cc)
- [ANGLE README (Metal on macOS)](https://chromium.googlesource.com/angle/angle/+/HEAD/README.md)
- [THREE WebGLRenderer (WebGL2, OffscreenCanvas, failIfMajorPerformanceCaveat)](https://threejs.org/docs/pages/WebGLRenderer.html)
- [THREE `WebGLRenderer.js` — WebGL 1 unsupported since r163](https://github.com/mrdoob/three.js/blob/dev/src/renderers/WebGLRenderer.js)
- gstack `browse/src/browser-manager.ts` `launch()` / `launchHeaded()` / `shouldEnableChromiumSandbox()`
- gstack `browse/src/stealth.ts` `STEALTH_LAUNCH_ARGS`
- This session: console dump + `ps` of `chrome-headless-shell` on macOS ARM
