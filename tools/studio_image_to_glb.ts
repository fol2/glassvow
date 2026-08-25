#!/usr/bin/env bun
/**
 * Studio image → GLB. No LLM. No Tripo API.
 *
 * Workflow: image in → arguments → 3D model out.
 *
 * Two tabs, one driver:
 * - **Smart Mesh** (`tab=low_poly`) — untextured kits. No texture stage.
 *   Default `--faces 800 --topology quad`. 23 map kits want this.
 * - **HD Model** (`tab=high_detail`) — `--textured`. Bakes albedo + unwrap.
 *   Default `--faces 6000 --topology triangle --texture on --texture-quality 2k
 *   --pbr off --ultra-mesh on --ai-complete off`. The Vigil's game-content
 *   path. HD is the DEFAULT on a cold `/workspace/generate`; Smart Mesh used
 *   to click away from it. `--textured` stays.
 *
 * Credit safety: `--dry-run` never opens Chrome. `--smoke-run` (and
 * `--stop-before-generate`) fill the form and refuse to click Generate.
 * Generate matching is price-agnostic (`Generate 40` / `Generate 100 65`);
 * never click **Generate Multi-Views**.
 *
 * `--task-id` re-export does not set the form. JSON `faces`/`topology` are
 * omitted on that path so they cannot be mistaken for the task that ran.
 *
 * Walk, settings, remaining Studio features:
 * `docs/solutions/tooling-decisions/the-textured-studio-path-is-the-hd-tab-not-the-script.md`.
 *
 * Walked 2026-08-19 on Chrome for Testing 145 *new Headless* (Metal M4),
 * cookies decrypted from Chrome Default (`ory_kratos_session` on `.tripo3d.ai`).
 * HD Geometry & Texture walk: 2026-08-24.
 *
 * Measured path (do not skip):
 * 1. After cookie login, `Page.navigate` `/workspace/generate`. New Headless
 *    has WebGL so this cold GET works. Gallery home at 1280px hides
 *    **More Settings**; header **3D Workspace** is a no-op. gstack
 *    chrome-headless-shell still 500s on that URL.
 * 2. Smart Mesh (`tab=low_poly`) or stay on HD Model (`tab=high_detail`).
 *    After upload a **Generate Multi-Views** button appears — do not click it.
 * 3. Privacy: `element.click()` does not open the listbox. Mouse-click the
 *    Sharing/Private/Public combobox, then mouse-click **Private**.
 * 4. Smart Mesh topology: mouse-click **Topology**. Default **Quad New**,
 *    slider 500–25000. HD: **Geometry & Texture** popover (Ultra / AI Complete /
 *    Texture / Texture Quality / PBR / Topology / Polycount). Set faces by
 *    typing in the text box (JS `.value=` does not drive Vue; triple-click,
 *    `Input.insertText`, Tab commits `aria-valuenow`). Escape closes the
 *    popover.
 * 5. Generate is done when a visible **Export** button is in the DOM.
 *    Do not treat Generating/Queuing-absent as done (true before the
 *    label paints). Do not treat leftover Generating text as blocking
 *    once Export is visible. HD may show **View Your Model** then **Guide**.
 * 6. After Export appears, dismiss the walked "Retry for better results"
 *    dialog (14px close) or the dialog Export click is a no-op.
 * 7. Export is the same detect-decide-act loop as the form. Triggers:
 *    Export visible → click it; format combo → open if not GLB; GLB
 *    option → pick; format GLB + second Export → click last Export;
 *    `createObjectURL` magic `glTF` (skip the 1853-byte `//#r` worker
 *    blob) → write `--out`. One-shot clicks; detect until the next
 *    trigger. Viewport 1280×900. HD Format already defaults **GLB**.
 *
 * Speed (2026-08-20): keep Chrome for Testing on port 9335 with a durable
 * profile at `~/Library/Caches/glassvow/studio-cft`. Cookies are cached at
 * `~/Library/Caches/glassvow/studio-cookies.json` (0600) so a cold start
 * does not decrypt Chrome Default. Never reuse `/workspace/generate/<task-id>`
 * for a new `--image`; reset via about:blank and fail closed if that task id
 * remains. `--task-id` re-export is unchanged. Do not kill Chrome to start a
 * new image. JSON `timings.driver_ms` is chrome+login+form (not Studio
 * upload/generate). `timings.generate_ms` starts when a visible Export
 * appears. `--kill-chrome` tears the warm browser down (also valid as a lone
 * flag). Never spawn extra Default Chrome.
 *
 * gstack `Mode: launched` is chrome-headless-shell — Export never mounts there.
 */

import {
  existsSync, readdirSync, mkdirSync, writeFileSync, readFileSync, unlinkSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import {
  BLANK_RESET_URL,
  STUDIO_HELP,
  UPLOAD_WATCH_LIMIT_MS,
  UPLOAD_WATCH_POLL_MS,
  blankResetArrived,
  decideHdForm,
  generateTargetUrl,
  generateWaitReady,
  isTransientEvaluateError,
  newImageExportGuard,
  parseStudioArgv,
  pickVisibleGenerate,
  planStudioRun,
  planWarmGeneratePage,
  quotedCreditsFromGenerateLabel,
  refuseNewImageOnTaskUrl,
  remainingStudioFeatures,
  resolveStudioRequest,
  shouldClickGenerate,
  studioExportFormFields,
  uploadWatchTimedOut,
} from "./studio_image_to_glb_logic.ts";

const FORBIDDEN = ["openapi.tripo3d.ai", "platform.tripo3d.ai"];
const WARM_PORT = 9335;
const WARM_PROFILE = join(homedir(), "Library/Caches/glassvow/studio-cft");
const COOKIE_CACHE = join(homedir(), "Library/Caches/glassvow/studio-cookies.json");
const COOKIE_DOMAINS = [
  ".tripo3d.ai", "studio.tripo3d.ai", ".studio.tripo3d.ai", "api.tripo3d.ai",
];

function die(summary: string): never {
  throw new Error(summary);
}

const rawArgs = parseStudioArgv(process.argv.slice(2));
let req: ReturnType<typeof resolveStudioRequest>;
try {
  req = resolveStudioRequest(rawArgs);
} catch (e) {
  console.log(JSON.stringify({ ok: false, summary: String(e) }));
  process.exit(2);
}
if (req.help) {
  console.log(STUDIO_HELP);
  process.exit(0);
}
const image = req.image;
const out = req.out;
const faces = req.faces;
const topology = req.topology;
const privacy = req.privacy;
const taskIdArg = req.taskId;
const stopBefore = req.stopBeforeGenerate;
const cookieBrowser = req.cookieBrowser;
const killChrome = req.killChrome;
const dryRun = req.dryRun;
const smokeRun = req.smokeRun;

if (image && !existsSync(image)) die(`image missing: ${image}`);
for (const h of FORBIDDEN) {
  if (process.argv.join(" ").includes(h)) die(`refusing ${h}`);
}

if (dryRun) {
  console.log(JSON.stringify({
    ...planStudioRun(req),
    remaining_studio_features: remainingStudioFeatures(),
  }));
  process.exit(0);
}

function findChrome(): string {
  const env = process.env.STUDIO_CHROME;
  if (env && existsSync(env)) return env;
  const root = join(homedir(), "Library/Caches/ms-playwright");
  const dirs = readdirSync(root).filter((d) => /^chromium-\d+$/.test(d)).sort().reverse();
  for (const d of dirs) {
    const p = join(
      root, d, "chrome-mac-arm64",
      "Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
    );
    if (existsSync(p)) return p;
  }
  die("Chrome for Testing not found under ~/Library/Caches/ms-playwright/chromium-*");
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

type Cdp = (method: string, params?: Record<string, unknown>) => Promise<any>;

type StudioCookie = {
  name: string;
  value: string;
  domain: string;
  path?: string;
  expires?: number;
  httpOnly?: boolean;
  secure?: boolean;
  sameSite?: string;
};

const t0 = Date.now();
let lastLap = t0;
const timings: Record<string, number> = {};
function lap(name: string) {
  const now = Date.now();
  timings[name] = now - lastLap;
  lastLap = now;
}

async function attach(wsUrl: string): Promise<{ cdp: Cdp; close: () => void }> {
  const ws = new WebSocket(wsUrl);
  await new Promise<void>((resolve, reject) => {
    ws.addEventListener("open", () => resolve());
    ws.addEventListener("error", (e) => reject(e));
  });
  let seq = 0;
  const pending = new Map<number, { resolve: (v: any) => void; reject: (e: Error) => void }>();
  ws.addEventListener("message", (ev) => {
    const msg = JSON.parse(String(ev.data));
    if (typeof msg.id === "number" && pending.has(msg.id)) {
      const p = pending.get(msg.id)!;
      pending.delete(msg.id);
      if (msg.error) p.reject(new Error(`${msg.error.message || JSON.stringify(msg.error)}`));
      else p.resolve(msg.result);
    }
  });
  const cdp: Cdp = (method, params) => {
    const id = ++seq;
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      ws.send(JSON.stringify({ id, method, params: params || {} }));
      setTimeout(() => {
        if (pending.has(id)) {
          pending.delete(id);
          reject(new Error(`cdp timeout ${method}`));
        }
      }, 30000);
    });
  };
  return { cdp, close: () => ws.close() };
}

async function portUp(port: number): Promise<boolean> {
  try {
    const r = await fetch(`http://127.0.0.1:${port}/json/version`);
    return r.ok;
  } catch {
    return false;
  }
}

async function waitPort(port: number) {
  for (let i = 0; i < 80; i++) {
    if (await portUp(port)) return;
    await sleep(50);
  }
  die("Chrome DevTools port never came up");
}

async function reapChrome() {
  const proc = Bun.spawn(["pkill", "-f", `user-data-dir=${WARM_PROFILE}`], {
    stdout: "ignore", stderr: "ignore",
  });
  await proc.exited;
  await sleep(150);
  for (const name of ["SingletonLock", "SingletonCookie", "SingletonSocket"]) {
    const p = join(WARM_PROFILE, name);
    if (existsSync(p)) {
      try { unlinkSync(p); } catch { /* ignore */ }
    }
  }
}

function loadCookieCache(): StudioCookie[] | null {
  if (!existsSync(COOKIE_CACHE)) return null;
  try {
    const data = JSON.parse(readFileSync(COOKIE_CACHE, "utf8")) as { cookies?: StudioCookie[] };
    if (!Array.isArray(data.cookies) || !data.cookies.length) return null;
    const session = data.cookies.find((c) => c.name === "ory_kratos_session");
    if (!session) return null;
    if (typeof session.expires === "number" && session.expires > 0
      && session.expires * 1000 < Date.now() + 60_000) return null;
    return data.cookies;
  } catch {
    return null;
  }
}

function saveCookieCache(cookies: StudioCookie[]) {
  mkdirSync(dirname(COOKIE_CACHE), { recursive: true });
  writeFileSync(COOKIE_CACHE, JSON.stringify({ saved_at: Date.now(), cookies }), { mode: 0o600 });
}

async function importFreshCookies(): Promise<StudioCookie[]> {
  const { importCookies } = await import(
    join(homedir(), ".claude/skills/gstack/browse/src/cookie-import-browser.ts")
  );
  const imported = await importCookies(cookieBrowser, COOKIE_DOMAINS, "Default");
  if (!imported.cookies?.length) die("no cookies imported from Chrome Default");
  const cookies = imported.cookies as StudioCookie[];
  saveCookieCache(cookies);
  return cookies;
}

async function applyCookies(cdp: Cdp, cookies: StudioCookie[]) {
  for (const c of cookies) {
    const sameSite = String(c.sameSite || "Lax");
    await cdp("Network.setCookie", {
      name: c.name,
      value: c.value,
      url: "https://studio.tripo3d.ai/",
      domain: c.domain,
      path: c.path || "/",
      httpOnly: !!c.httpOnly,
      secure: !!c.secure,
      expires: typeof c.expires === "number" && c.expires > 0 ? c.expires : undefined,
      sameSite: sameSite === "None" ? "None" : sameSite === "Strict" ? "Strict" : "Lax",
    });
  }
}

async function ev(cdp: Cdp, expr: string): Promise<any> {
  const r = await cdp("Runtime.evaluate", { expression: expr, returnByValue: true, awaitPromise: true });
  return r?.result?.value;
}

async function clickxy(cdp: Cdp, x: number, y: number) {
  await cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  await cdp("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
  await cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
}

/** Detect until `ok`. Yields on this process so Chrome/Vue can run.
 *  `timeoutMs` is abort only. */
async function waitEv(cdp: Cdp, expr: string, ok: (v: any) => boolean, timeoutMs: number) {
  const deadline = Date.now() + timeoutMs;
  let last: any = null;
  while (Date.now() < deadline) {
    try {
      last = await ev(cdp, expr);
      if (ok(last)) return last;
    } catch (e) {
      if (!isTransientEvaluateError(e)) throw e;
    }
    await sleep(UPLOAD_WATCH_POLL_MS);
  }
  throw new Error(`timeout: ${JSON.stringify(last)}`.slice(0, 400));
}

const HOOK_EXPORT = `(() => {
  if (window.__gv_hooked) return "already";
  const orig = URL.createObjectURL.bind(URL);
  window.__gv_files = [];
  window.__gv_hooked = true;
  URL.createObjectURL = function(obj) {
    const url = orig(obj);
    Promise.resolve(obj.arrayBuffer()).then(buf => {
      const bytes = new Uint8Array(buf);
      let bin = "";
      const chunk = 0x8000;
      for (let i = 0; i < bytes.length; i += chunk)
        bin += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
      window.__gv_files.push({
        magic: String.fromCharCode(bytes[0], bytes[1], bytes[2], bytes[3]),
        size: bytes.length,
        b64: btoa(bin),
      });
    });
    return url;
  };
  return "hooked";
})()`;

const privacyLabel: Record<string, string> = {
  private: "Private",
  public: "Public",
  sharing: "Sharing Only",
};

const pageStateExpr = `({
  href: location.href,
  login: /Sign up\\/Log in/.test(document.body.innerText||""),
  smart: [...document.querySelectorAll("button")].some(b => {
    const t = (b.innerText||"").replace(/\\s+/g," ").trim();
    return t === "Smart Mesh" || t.replace(/ /g,"") === "SmartMesh";
  }),
  exp: [...document.querySelectorAll("button")].some(b => (b.innerText||"").trim() === "Export"),
  err: /WebGL|Internal Server Error/.test(document.body.innerText||"")
})`;

if (killChrome && !image && !taskIdArg) {
  await reapChrome();
  console.log(JSON.stringify({
    ok: true,
    summary: "killed warm Chrome for Testing",
    profile: WARM_PROFILE,
    port: WARM_PORT,
  }));
  process.exit(0);
}

mkdirSync(WARM_PROFILE, { recursive: true });

let close = () => {};
let attachedWarm = false;
try {
  if (await portUp(WARM_PORT)) {
    attachedWarm = true;
  } else {
    await reapChrome();
    const chromePath = findChrome();
    const spawned = Bun.spawn([
      chromePath,
      `--remote-debugging-port=${WARM_PORT}`,
      `--user-data-dir=${WARM_PROFILE}`,
      "--headless=new",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-blink-features=AutomationControlled",
      "about:blank",
    ], { stdout: "ignore", stderr: "ignore" });
    spawned.unref();
    await waitPort(WARM_PORT);
  }

  const pages = await (await fetch(`http://127.0.0.1:${WARM_PORT}/json/list`)).json() as Array<{
    type?: string; webSocketDebuggerUrl?: string;
  }>;
  const page = pages.find((p) => p.webSocketDebuggerUrl && p.type !== "service_worker");
  if (!page?.webSocketDebuggerUrl) die("no Chrome page target on warm port");
  const session = await attach(page.webSocketDebuggerUrl);
  const cdp = session.cdp;
  close = session.close;

  await cdp("Runtime.enable");
  await cdp("Page.enable");
  await cdp("Network.enable");
  await cdp("DOM.enable");
  await cdp("Emulation.setDeviceMetricsOverride", {
    width: 1280, height: 900, deviceScaleFactor: 1, mobile: false,
  });
  lap("chrome_ms");

  let cookieSource = "profile";
  const targetUrl = generateTargetUrl(taskIdArg);

  let state = await ev(cdp, pageStateExpr);
  const plan = planWarmGeneratePage(state, taskIdArg);
  if (!plan.reuse) {
    if (plan.resetViaBlank) {
      await cdp("Page.navigate", { url: BLANK_RESET_URL });
      await waitEv(cdp, "({ href: location.href })", (s) => s && blankResetArrived(String(s.href || ""), plan.leftoverTaskId), 10000);
    }
    await cdp("Page.navigate", { url: targetUrl });
    state = await waitEv(cdp, pageStateExpr, (s) => generateWaitReady(s, taskIdArg, "initial"), 20000);
  }

  async function injectCookies(source: string, cookies: StudioCookie[]) {
    await applyCookies(cdp, cookies);
    cookieSource = source;
    await cdp("Page.navigate", { url: targetUrl });
    state = await waitEv(cdp, pageStateExpr, (s) => generateWaitReady(s, taskIdArg, "authed"), 20000);
  }

  if (state.login) {
    const cached = loadCookieCache();
    if (cached) {
      try {
        await injectCookies("cache", cached);
      } catch {
        await injectCookies("chrome-default", await importFreshCookies());
      }
    } else {
      await injectCookies("chrome-default", await importFreshCookies());
    }
  }
  refuseNewImageOnTaskUrl(String(state.href || ""), taskIdArg);
  lap("login_ms");
  await ev(cdp, HOOK_EXPORT);

  async function typeFacesAt(cx: number, cy: number) {
    await clickxy(cdp, cx, cy);
    await cdp("Input.dispatchMouseEvent", { type: "mousePressed", x: cx, y: cy, button: "left", clickCount: 3 });
    await cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x: cx, y: cy, button: "left", clickCount: 3 });
    await cdp("Input.insertText", { text: String(faces) });
    await cdp("Input.dispatchKeyEvent", { type: "keyDown", key: "Tab", code: "Tab", windowsVirtualKeyCode: 9 });
    await cdp("Input.dispatchKeyEvent", { type: "keyUp", key: "Tab", code: "Tab", windowsVirtualKeyCode: 9 });
  }

  async function pressEscape() {
    await cdp("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
    await cdp("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
  }

  let taskId = taskIdArg;
  let sliderNow = faces;
  let formSnapshot: Record<string, unknown> = {};
  if (!taskIdArg && req.tab === "hd-model") {
    const hdFormFn = `() => {
      const txt = (el) => (el.innerText || "").replace(/\\s+/g, " ").trim();
      const vis = (el) => {
        if (!el) return false;
        const r = el.getBoundingClientRect();
        return r.width > 8 && r.height > 8;
      };
      const box = (el) => {
        if (!el) return { cx: 0, cy: 0 };
        const r = el.getBoundingClientRect();
        return { cx: r.x + r.width / 2, cy: r.y + r.height / 2 };
      };
      const pressed = (el) => {
        if (!el) return undefined;
        const aria = el.getAttribute("aria-checked") || el.getAttribute("aria-pressed");
        if (aria === "true") return true;
        if (aria === "false") return false;
        if (el.checked === true) return true;
        if (el.checked === false) return false;
        return undefined;
      };
      const switchByRow = (label) => [...document.querySelectorAll("[role=switch]")].find(el => {
        if (!vis(el)) return false;
        let node = el;
        for (let i = 0; i < 8 && node; i++) {
          if (txt(node) === label) return true;
          node = node.parentElement;
        }
        return false;
      });
      const qualityBtn = (name) => [...document.querySelectorAll("button")].find(b =>
        vis(b) && txt(b) === name);
      let tab = "";
      try {
        tab = document.querySelector("#__nuxt").__vue_app__.config.globalProperties.$pinia._s.get("workspace-generate-store").$state.tab;
      } catch (e) {}
      const hdBtn = [...document.querySelectorAll("button")].find(b => txt(b) === "HD Model" && vis(b));
      const combo = [...document.querySelectorAll("[role=combobox]")].find(c =>
        vis(c) && /Private|Public|Sharing/.test(c.innerText || ""));
      const geoHit = [...document.querySelectorAll("button, span, div, p")].find(n =>
        vis(n) && /^Geometry\\s*&\\s*Texture$/.test(txt(n)));
      const body = document.body.innerText || "";
      const geoOpen = /Ultra Mesh Quality/.test(body) && /PBR|Texture Quality/.test(body);
      const ultraSw = switchByRow("Ultra Mesh Quality");
      const aiSw = switchByRow("AI Complete");
      const texSw = switchByRow("Texture");
      const pbrSw = switchByRow("PBR");
      const q2 = qualityBtn("2K");
      const q4 = qualityBtn("4K");
      const q1 = qualityBtn("1K");
      let textureQuality = "";
      if (pressed(q1) === true) textureQuality = "1k";
      else if (pressed(q2) === true) textureQuality = "2k";
      else if (pressed(q4) === true) textureQuality = "4k";
      const tri = [...document.querySelectorAll("button, [role=button]")].find(b =>
        vis(b) && /^Triangle$/.test(txt(b)));
      const quad = [...document.querySelectorAll("button, [role=button]")].find(b =>
        vis(b) && /^(Quad|Quad New)$/.test(txt(b)));
      const input = [...document.querySelectorAll("input[type=text], input[type=number]")].find(x => {
        const r = x.getBoundingClientRect();
        return r.width > 20 && r.height > 10 && /^\\d+$/.test(x.value);
      });
      const slider = document.querySelector("[role=slider]");
      const gens = [...document.querySelectorAll("button")].map(b => txt(b)).filter(t => /^Generate/.test(t));
      let topology = "";
      if (tri && tri.getAttribute("aria-pressed") === "true") topology = "triangle";
      else if (quad && quad.getAttribute("aria-pressed") === "true") topology = "quad";
      else if (tri) topology = "triangle";
      else if (quad) topology = "quad";
      return {
        tab,
        hdPresent: !!hdBtn,
        hdAt: box(hdBtn),
        privacy: combo ? txt(combo) : "",
        privCx: combo ? box(combo).cx : 0,
        privCy: combo ? box(combo).cy : 0,
        geoOpen,
        geoAt: box(geoHit),
        ultra: pressed(ultraSw),
        ultraAt: box(ultraSw),
        aiComplete: pressed(aiSw),
        aiAt: box(aiSw),
        texture: pressed(texSw),
        texAt: box(texSw),
        textureQuality,
        q1At: box(q1),
        q2At: box(q2),
        q4At: box(q4),
        pbr: pressed(pbrSw),
        pbrAt: box(pbrSw),
        topology,
        topoTriAt: box(tri),
        topoQuadAt: box(quad),
        facesVal: input ? Number(input.value) : (slider ? Number(slider.getAttribute("aria-valuenow")) : null),
        slider: slider ? Number(slider.getAttribute("aria-valuenow")) : null,
        facesCx: input ? box(input).cx : 0,
        facesCy: input ? box(input).cy : 0,
        generateLabels: gens,
      };
    }`;
    const detectHd = () => ev(cdp, `(${hdFormFn})()`);
    let settingsApplied = false;
    let observed: Record<string, unknown> | null = null;
    let f = await detectHd();
    f.settingsApplied = settingsApplied;
    const steps: string[] = [];
    let same = 0;
    let prev = "";
    for (let i = 0; i < 50; i++) {
      const action = decideHdForm(f, req);
      if (action === prev) same++;
      else same = 0;
      prev = action;
      if (action !== "watch_geo" && same > 12) die("HD form stuck on " + action + ": " + JSON.stringify(f));
      if (action === "watch_geo" && same > 40) die("HD form stuck on " + action + ": " + JSON.stringify(f));
      steps.push(action);
      if (action === "done") break;
      if (action === "click_hd") {
        if (!f.hdAt || f.hdAt.cx === 0) die("HD Model button missing: " + JSON.stringify(f));
        await clickxy(cdp, f.hdAt.cx, f.hdAt.cy);
      } else if (action === "set_privacy") {
        await clickxy(cdp, f.privCx, f.privCy);
        const opts = await waitEv(cdp, `[...document.querySelectorAll("[role=option]")].map(o => {
          const r = o.getBoundingClientRect();
          return { t: (o.innerText||"").trim(), cx: r.x+r.width/2, cy: r.y+r.height/2 };
        })`, (o) => Array.isArray(o) && o.length >= 2, 15000);
        const wantPriv = privacy === "private" ? "Private" : privacy === "public" ? "Public" : "Sharing Only";
        const hit = opts.find((o: any) => o.t === wantPriv);
        if (!hit) die(`Privacy option ${wantPriv} missing`);
        await clickxy(cdp, hit.cx, hit.cy);
      } else if (action === "open_geo_texture") {
        if (!f.geoAt || f.geoAt.cx === 0) {
          const opened = await ev(cdp, `(() => {
            const el = [...document.querySelectorAll("button, span, div, p")].find(n =>
              /^Geometry\\s*&\\s*Texture$/.test((n.innerText || "").replace(/\\s+/g, " ").trim()));
            if (!el) return "missing";
            el.click();
            return "ok";
          })()`);
          if (opened !== "ok") die("Geometry & Texture control missing: " + JSON.stringify(f));
        } else {
          await clickxy(cdp, f.geoAt.cx, f.geoAt.cy);
        }
      } else if (action === "set_ultra") {
        if (!f.ultraAt || f.ultraAt.cx === 0) die("Ultra Mesh Quality switch missing: " + JSON.stringify(f));
        await clickxy(cdp, f.ultraAt.cx, f.ultraAt.cy);
      } else if (action === "set_ai_complete") {
        if (!f.aiAt || f.aiAt.cx === 0) die("AI Complete switch missing: " + JSON.stringify(f));
        await clickxy(cdp, f.aiAt.cx, f.aiAt.cy);
      } else if (action === "set_texture") {
        if (!f.texAt || f.texAt.cx === 0) die("Texture switch missing: " + JSON.stringify(f));
        await clickxy(cdp, f.texAt.cx, f.texAt.cy);
      } else if (action === "set_texture_quality") {
        const at = req.textureQuality === "1k" ? f.q1At
          : req.textureQuality === "4k" ? f.q4At : f.q2At;
        if (!at || at.cx === 0) die("Texture Quality " + req.textureQuality + " missing: " + JSON.stringify(f));
        await clickxy(cdp, at.cx, at.cy);
      } else if (action === "set_pbr") {
        if (!f.pbrAt || f.pbrAt.cx === 0) die("PBR switch missing: " + JSON.stringify(f));
        await clickxy(cdp, f.pbrAt.cx, f.pbrAt.cy);
      } else if (action === "set_topology") {
        const at = req.topology === "triangle" ? f.topoTriAt : f.topoQuadAt;
        if (!at || at.cx === 0) die("HD topology control missing: " + JSON.stringify(f));
        await clickxy(cdp, at.cx, at.cy);
      } else if (action === "type_faces") {
        if (!f.facesCx) die("HD faces input missing: " + JSON.stringify(f));
        await typeFacesAt(f.facesCx, f.facesCy);
      } else if (action === "watch_geo") {
        await sleep(UPLOAD_WATCH_POLL_MS);
      } else if (action === "close_geo") {
        observed = { ...f };
        await pressEscape();
        settingsApplied = true;
      }
      for (let d = 0; d < 30; d++) {
        f = await detectHd();
        f.settingsApplied = settingsApplied;
        if (decideHdForm(f, req) !== action) break;
      }
    }
    if (!settingsApplied || !observed) {
      die("HD form ended without applying Geometry & Texture: " + steps.join(">") + " " + JSON.stringify(f));
    }
    const observedFaces = Number(observed.slider ?? observed.facesVal);
    if (observedFaces !== faces) {
      die("HD form ended without faces=" + faces + " observed=" + observedFaces + " steps=" + steps.join(">"));
    }
    if (observed.texture !== req.texture) {
      die("HD form ended without texture=" + req.texture + " " + JSON.stringify(observed));
    }
    sliderNow = observedFaces;
    for (let i = 0; i < 4; i++) {
      f = await detectHd();
      if (!f.geoOpen) break;
      await pressEscape();
    }
    formSnapshot = observed;
    timings.form_steps = steps;
    lap("form_ms");
  } else if (!taskIdArg) {
    const formFn = `() => {
      const txt = (el) => (el.innerText || "").replace(/\\s+/g, " ").trim();
      let tab = "";
      try {
        tab = document.querySelector("#__nuxt").__vue_app__.config.globalProperties.$pinia._s.get("workspace-generate-store").$state.tab;
      } catch (e) {}
      const combo = [...document.querySelectorAll("[role=combobox]")].find(c =>
        /Private|Public|Sharing/.test(c.innerText || ""));
      const cr = combo && combo.getBoundingClientRect();
      const input = [...document.querySelectorAll("input[type=text]")].find(x => {
        const r = x.getBoundingClientRect();
        return r.width > 20 && r.height > 10 && /^\\d+$/.test(x.value);
      });
      const ir = input && input.getBoundingClientRect();
      const slider = document.querySelector("[role=slider]");
      const smart = [...document.querySelectorAll("button")].find(b => {
        const t = txt(b);
        return t === "Smart Mesh" || t.replace(/ /g, "") === "SmartMesh";
      });
      return {
        smart: !!smart,
        tab,
        privacy: combo ? txt(combo) : "",
        privCx: cr ? cr.x + cr.width / 2 : 0,
        privCy: cr ? cr.y + cr.height / 2 : 0,
        facesOpen: !!input,
        facesVal: input ? Number(input.value) : null,
        facesCx: ir ? ir.x + ir.width / 2 : 0,
        facesCy: ir ? ir.y + ir.height / 2 : 0,
        slider: slider ? Number(slider.getAttribute("aria-valuenow")) : null,
        hasTopo: [...document.querySelectorAll("*")].some(el =>
          [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim() === "Topology")),
        p2Banner: [...document.querySelectorAll("button")].some(b =>
          /P2\\.0 Preview Try Now/.test((b.innerText || "").replace(/\\s+/g, " "))),
        p2Form: [...document.querySelectorAll("button")].some(b =>
          /^Generate\\s+\\d+/.test(txt(b))),
        model: (() => {
          const c = [...document.querySelectorAll("[role=combobox]")].find(x =>
            /P2|v3|Preview|Best Quality/.test(x.innerText || ""));
          if (!c) return "";
          return txt(c);
        })(),
        modelCx: (() => {
          const c = [...document.querySelectorAll("[role=combobox]")].find(x =>
            /P2|v3|Preview|Best Quality/.test(x.innerText || ""));
          if (!c) return 0;
          const r = c.getBoundingClientRect();
          return r.x + r.width / 2;
        })(),
        modelCy: (() => {
          const c = [...document.querySelectorAll("[role=combobox]")].find(x =>
            /P2|v3|Preview|Best Quality/.test(x.innerText || ""));
          if (!c) return 0;
          const r = c.getBoundingClientRect();
          return r.y + r.height / 2;
        })(),
      };
    }`;
    const detect = () => ev(cdp, `(${formFn})()`);
    const wantPriv = privacyLabel[privacy];
    const decide = (s: any): string => {
      if (!s.smart) return "click_smart";
      if (!s.hasTopo && s.p2Banner) return "click_p2_banner";
      if (!s.hasTopo && (/v3/i.test(s.model || "") || s.p2Form === false)) return "reset_via_hd";
      if (s.privacy && s.privacy !== wantPriv) return "set_privacy";
      if (s.hasTopo && !s.facesOpen) return "open_topology";
      const now = s.slider ?? s.facesVal;
      if (s.facesOpen && now !== faces) return "type_faces";
      if (s.hasTopo && (now === faces || (s.facesVal === faces))) return "done";
      if (s.privacy && !s.hasTopo) return "need_p2";
      return "done";
    };

    let f = await detect();
    const steps: string[] = [];
    let same = 0;
    let prev = "";
    for (let i = 0; i < 40; i++) {
      const action = decide(f);
      if (action === prev) same++;
      else same = 0;
      prev = action;
      if (same > 12) die("stuck on " + action + ": " + JSON.stringify(f));
      steps.push(action);
      if (action === "done") break;
      if (action === "need_p2") die("on v3.1 form, no P2.0 control to click: " + JSON.stringify({
        model: f.model, p2Banner: f.p2Banner, hasTopo: f.hasTopo, p2Form: f.p2Form,
      }));
      if (action === "click_smart") {
        await ev(cdp, `(() => {
          const btn = [...document.querySelectorAll("button")].find(b => {
            const t = (b.innerText || "").replace(/\\s+/g, " ").trim();
            return t === "Smart Mesh" || t.replace(/ /g, "") === "SmartMesh";
          });
          if (btn) btn.click();
          return true;
        })()`);
      } else if (action === "click_p2_banner") {
        await ev(cdp, `(() => {
          const b = [...document.querySelectorAll("button")].find(x =>
            /P2\\.0 Preview Try Now/.test((x.innerText || "").replace(/\\s+/g, " ")));
          if (b) b.click();
          return true;
        })()`);
      } else if (action === "reset_via_hd") {
        // Walked: v3.1 has no Topology. HD Model then Smart Mesh restores P2.0.
        await ev(cdp, `(() => {
          const b = [...document.querySelectorAll("button")].find(x =>
            (x.innerText || "").replace(/\\s+/g, " ").trim() === "HD Model");
          if (b) b.click();
          return true;
        })()`);
        f = await detect();
        await ev(cdp, `(() => {
          const b = [...document.querySelectorAll("button")].find(x => {
            const t = (x.innerText || "").replace(/\\s+/g, " ").trim();
            return t === "Smart Mesh" || t.replace(/ /g, "") === "SmartMesh";
          });
          if (b) b.click();
          return true;
        })()`);
      } else if (action === "set_privacy") {
        await clickxy(cdp, f.privCx, f.privCy);
        const opts = await waitEv(cdp, `[...document.querySelectorAll("[role=option]")].map(o => {
          const r = o.getBoundingClientRect();
          return { t: (o.innerText||"").trim(), cx: r.x+r.width/2, cy: r.y+r.height/2 };
        })`, (o) => Array.isArray(o) && o.length >= 2, 15000);
        const hit = opts.find((o: any) => o.t === wantPriv);
        if (!hit) die(`Privacy option ${wantPriv} missing`);
        await clickxy(cdp, hit.cx, hit.cy);
      } else if (action === "open_topology") {
        const topoClicked = await ev(cdp, `(() => {
          const el = [...document.querySelectorAll("*")].find(n =>
            [...n.childNodes].some(c => c.nodeType === 3 && c.textContent.trim() === "Topology"));
          if (!el) return "missing";
          el.click();
          return "ok";
        })()`);
        if (topoClicked !== "ok") die("Topology control missing");
      } else if (action === "type_faces") {
        await typeFacesAt(f.facesCx, f.facesCy);
      }
      // Continuous detect until this action is no longer what decide() wants.
      for (let d = 0; d < 30; d++) {
        f = await detect();
        if (decide(f) !== action) break;
      }
    }
    sliderNow = f.slider ?? f.facesVal;
    formSnapshot = f;
    if (f.facesOpen) {
      await pressEscape();
    }
    timings.form_steps = steps;
    if (sliderNow !== faces) die("form ended without faces=" + faces + " slider=" + sliderNow + " steps=" + steps.join(">"));
    lap("form_ms");
  } else {
    timings.form_ms = 0;
  }

  if (!taskId && stopBefore) {
    const gen = await ev(cdp, `[...document.querySelectorAll("button")].map(b => {
      const t = (b.innerText||"").replace(/\\s+/g," ").trim();
      const r = b.getBoundingClientRect();
      return { t, vis: r.width > 8 && r.height > 8, cx: r.x + r.width / 2, cy: r.y + r.height / 2 };
    }).filter(g => /^Generate/.test(g.t))`);
    const genList = Array.isArray(gen) ? gen : [];
    const picked = pickVisibleGenerate(genList);
    const quoted = picked ? quotedCreditsFromGenerateLabel(picked.t) : null;
    if (quoted == null) {
      die("smoke/stop: no visible priced Generate button: " + JSON.stringify(genList));
    }
    const driver_ms = (timings.chrome_ms || 0) + (timings.login_ms || 0) + (timings.form_ms || 0);
    const stopKind = smokeRun ? "smoke-run" : "stop-before-generate";
    console.log(JSON.stringify({
      ok: true,
      summary: `${stopKind}: ${req.tab} form ready, Generate not clicked`,
      stopped: true,
      smoke_run: smokeRun,
      would_spend_credits: false,
      workflow: ["image", "arguments", "3d-model"],
      tab: req.tab,
      textured: req.textured,
      texture: req.texture,
      texture_quality: req.textureQuality,
      pbr: req.pbr,
      ultra_mesh: req.ultraMesh,
      ai_complete: req.aiComplete,
      faces: sliderNow,
      topology,
      privacy,
      generate_buttons: genList.map((g: { t: string }) => g.t),
      quoted_credits: quoted,
      form_snapshot: formSnapshot,
      remaining_studio_features: remainingStudioFeatures(),
      timings: { ...timings, driver_ms, total_ms: Date.now() - t0 },
      warm: attachedWarm,
      cookie_source: cookieSource,
      kept_chrome: !killChrome,
    }));
  } else {
    await ev(cdp, HOOK_EXPORT);

    if (!taskId) {
      refuseNewImageOnTaskUrl(String(await ev(cdp, "location.href") || state.href || ""), taskIdArg);
      const detectU = () => ev(cdp, `(() => {
        const imgIn = [...document.querySelectorAll("input[type=file]")].find(i =>
          /image|jpg|jpeg|png|webp|gif/.test((i.accept || "").toLowerCase()));
        if (imgIn) imgIn.setAttribute("data-gv-image", "1");
        const del = [...document.querySelectorAll("button")].find(b =>
          [...b.querySelectorAll("div")].some(d => /i-tripo:delete/.test(d.className || "")));
        const dr = del && del.getBoundingClientRect();
        let key = "", audit = "", uploading = false;
        try {
          const pinia = document.querySelector("#__nuxt").__vue_app__.config.globalProperties.$pinia;
          const s = pinia._s.get("workspace-generate-store").$state;
          const img = s.imageToModel || {};
          key = img.key || "";
          audit = img.image_audit_result || "";
          uploading = !!s.imageToModelUploading;
        } catch (e) {}
        return {
          hasImageInput: !!imgIn,
          delete: !!del,
          delCx: dr ? dr.x + dr.width / 2 : 0,
          delCy: dr ? dr.y + dr.height / 2 : 0,
          key, audit, uploading,
        };
      })()`);
      const u0 = await detectU();
      const prevKey = u0.key || "";
      let fileSet = false;
      let clearClicked = false;
      let sawUploading = false;
      const decideU = (s: any): string => {
        if (fileSet && s.uploading) sawUploading = true;
        if (fileSet && s.key && s.audit === "pass" && !s.uploading &&
            (s.key !== prevKey || sawUploading)) return "done";
        if (s.hasImageInput && !fileSet) return "set_file";
        if (s.delete && !fileSet && !clearClicked) return "click_clear";
        return "watch_upload";
      };
      const usteps: string[] = [];
      let u = await detectU();
      let usame = 0;
      let uprev = "";
      const uploadStarted = Date.now();
      while (true) {
        const action = decideU(u);
        if (action === uprev) usame++;
        else usame = 0;
        uprev = action;
        if (uploadWatchTimedOut(Date.now() - uploadStarted, UPLOAD_WATCH_LIMIT_MS)) {
          die("upload never ready: " + JSON.stringify(u) + " steps=" + usteps.join(">"));
        }
        if (action !== "watch_upload" && usame > 20) {
          die("upload stuck on " + action + ": " + JSON.stringify(u));
        }
        if (action !== "watch_upload" || usteps[usteps.length - 1] !== action) {
          usteps.push(action);
        }
        if (action === "done") break;
        if (action === "watch_upload") {
          await sleep(UPLOAD_WATCH_POLL_MS);
          u = await detectU();
          continue;
        }
        if (action === "click_clear") {
          // Walked: mouse events miss this overlay; element.click() clears the preview.
          const cleared = await ev(cdp, `(() => {
            const del = [...document.querySelectorAll("button")].find(b =>
              [...b.querySelectorAll("div")].some(d => /i-tripo:delete/.test(d.className || "")));
            if (!del) return "missing";
            del.click();
            return "clicked";
          })()`);
          if (cleared !== "clicked") die("image delete click: " + cleared);
          clearClicked = true;
        } else if (action === "set_file") {
          const doc = await cdp("DOM.getDocument", { depth: 1 });
          const q = await cdp("DOM.querySelector", {
            nodeId: doc.root.nodeId,
            selector: "input[data-gv-image='1']",
          });
          if (!q.nodeId) die("image file input marked but missing from DOM");
          await cdp("DOM.setFileInputFiles", { nodeId: q.nodeId, files: [resolve(image)] });
          fileSet = true;
        }
        for (let d = 0; d < 40; d++) {
          u = await detectU();
          if (decideU(u) !== action) break;
        }
      }
      if (decideU(u) !== "done") die("upload loop ended without audit pass: " + usteps.join(">"));
      timings.upload_steps = usteps;
      lap("upload_ms");
    }

    const exportFn = `() => {
      const txt = (el) => (el.innerText || "").replace(/\\s+/g, " ").trim();
      const vis = (el) => {
        if (!el) return false;
        const r = el.getBoundingClientRect();
        return r.width > 8 && r.height > 8;
      };
      const box = (el) => {
        if (!el) return { cx: 0, cy: 0 };
        const r = el.getBoundingClientRect();
        return { cx: r.x + r.width / 2, cy: r.y + r.height / 2 };
      };
      const exports = [...document.querySelectorAll("button")].filter(b =>
        txt(b) === "Export" && vis(b));
      const retry = [...document.querySelectorAll("[role=dialog]")].find(d =>
        /Retry for better/.test(d.innerText || ""));
      const fmt = [...document.querySelectorAll("[role=combobox]")].find(c =>
        vis(c) && /USD|FBX|OBJ|STL|GLB|3MF/.test(c.innerText || ""));
      const glbOpt = [...document.querySelectorAll("[role=option]")].find(o =>
        txt(o) === "GLB" && vis(o));
      const ok = /View Your Model|Retry for better/.test(document.body.innerText || "")
        ? [...document.querySelectorAll("button")].find(b => txt(b) === "OK" && vis(b))
        : null;
      const href = location.href;
      const m = href.match(/\\/workspace\\/generate\\/([0-9a-f-]{20,})/);
      const gltf = (window.__gv_files || []).find(f => f.magic === "glTF" && f.size > 100);
      return {
        href,
        taskId: m ? m[1] : "",
        generating: /Generating|Queuing/.test(document.body.innerText || ""),
        generate: [...document.querySelectorAll("button")].map(b => {
          const t = txt(b);
          const r = b.getBoundingClientRect();
          return { t, vis: r.width > 8 && r.height > 8, cx: r.x + r.width / 2, cy: r.y + r.height / 2 };
        }).filter(g => /^Generate/.test(g.t)),
        exportN: exports.length,
        export0: box(exports[0]),
        exportLast: box(exports[exports.length - 1]),
        retry: !!retry,
        retryClose: box(retry && retry.querySelector("button")),
        viewOk: !!ok,
        okAt: box(ok),
        format: fmt ? txt(fmt) : "",
        formatAt: box(fmt),
        glbOption: !!glbOpt,
        glbAt: box(glbOpt),
        gltf: gltf ? { size: gltf.size, hasB64: !!gltf.b64 } : null,
      };
    }`;
    const detectX = () => ev(cdp, `(${exportFn})()`);
    let generateClicked = false;
    let toolbarExportClicked = false;
    let formatOpened = false;
    let dialogExportClicked = false;
    if (!taskIdArg) await ev(cdp, "window.__gv_files = []");
    const decideX = (s: any): string => {
      if (!taskIdArg) {
        const g = newImageExportGuard(s, {
          generateClicked, leftoverTaskId: plan.leftoverTaskId,
        });
        if (g === "refuse_prior_export") return g;
        if (g === "accept_gltf") return "done";
        if (g === "watch_generate") return "watch_generate";
      }
      if (s.gltf) return "done";
      if (s.retry) return "dismiss_retry";
      if (s.viewOk) return "dismiss_ok";
      // Export visible is generate-complete. Leftover Generating text does not block.
      if (s.exportN >= 1 && !s.format) {
        return toolbarExportClicked ? "watch_dialog" : "click_export";
      }
      if (s.format && s.format !== "GLB" && !s.glbOption) {
        return formatOpened ? "watch_dialog" : "open_format";
      }
      if (s.glbOption && s.format !== "GLB") return "pick_glb";
      if (s.format === "GLB" && s.exportN < 2) return "watch_dialog";
      if (s.format === "GLB" && s.exportN >= 2) {
        return dialogExportClicked ? "watch_download" : "click_dialog_export";
      }
      if (dialogExportClicked) return "watch_download";
      if (generateClicked) return "watch_generate";
      const genBtn = Array.isArray(s.generate) ? pickVisibleGenerate(s.generate) : null;
      if (shouldClickGenerate(s, {
        taskIdArg, generateClicked, hasGenerateButton: !!genBtn,
        stopBeforeGenerate: stopBefore,
      })) return "click_generate";
      return "watch_generate";
    };
    const watching = (a: string) =>
      a === "watch_generate" || a === "watch_dialog" || a === "watch_download";

    let x = await detectX();
    const xsteps: string[] = [];
    let same = 0;
    let prev = "";
    let watchStarted = Date.now();
    const generateWaitMs = req.tab === "hd-model" ? 600000 : 180000;
    for (let i = 0; i < 20000; i++) {
      if (!taskIdArg && timings.generate_ms == null && x.exportN >= 1) {
        lap("generate_ms");
      }
      const action = decideX(x);
      if (action === prev) same++;
      else {
        same = 0;
        if (watching(action)) watchStarted = Date.now();
      }
      prev = action;
      if (!watching(action) && same > 20) {
        die("export stuck on " + action + ": " + JSON.stringify(x));
      }
      // Abort only. Control is Export/dialog/blob appearing.
      if (action === "watch_generate" && Date.now() - watchStarted > generateWaitMs) {
        die("generate never offered Export: " + JSON.stringify(x));
      }
      if (action === "watch_dialog" && Date.now() - watchStarted > 30000) {
        die("export dialog never advanced: " + JSON.stringify(x));
      }
      if (action === "watch_download" && Date.now() - watchStarted > 180000) {
        die("GLB blob never arrived: " + JSON.stringify(x));
      }
      if (!watching(action) || xsteps[xsteps.length - 1] !== action) {
        xsteps.push(action);
      }
      if (action === "done") break;
      if (action === "refuse_prior_export") {
        die("refusing prior GLB: Generate must have been clicked with a new task id, leftover=" + (plan.leftoverTaskId || "") + " now=" + (x.taskId || ""));
      }
      if (watching(action)) {
        await sleep(UPLOAD_WATCH_POLL_MS);
        x = await detectX();
        continue;
      }
      if (action === "click_generate") {
        const genBtn = pickVisibleGenerate(Array.isArray(x.generate) ? x.generate : []);
        if (!genBtn) die("Generate click: no visible priced Generate");
        await clickxy(cdp, genBtn.cx, genBtn.cy);
        generateClicked = true;
      } else if (action === "dismiss_retry") {
        await clickxy(cdp, x.retryClose.cx, x.retryClose.cy);
      } else if (action === "dismiss_ok") {
        await clickxy(cdp, x.okAt.cx, x.okAt.cy);
      } else if (action === "click_export") {
        await ev(cdp, `(() => {
          const b = [...document.querySelectorAll("button")].find(btn => {
            const t = (btn.innerText || "").trim();
            const r = btn.getBoundingClientRect();
            return t === "Export" && r.width > 8 && r.height > 8;
          });
          if (b) b.click();
          return true;
        })()`);
        toolbarExportClicked = true;
      } else if (action === "open_format") {
        await clickxy(cdp, x.formatAt.cx, x.formatAt.cy);
        formatOpened = true;
      } else if (action === "pick_glb") {
        await clickxy(cdp, x.glbAt.cx, x.glbAt.cy);
      } else if (action === "click_dialog_export") {
        await clickxy(cdp, x.exportLast.cx, x.exportLast.cy);
        dialogExportClicked = true;
      }
      for (let d = 0; d < 40; d++) {
        x = await detectX();
        if (decideX(x) !== action) break;
      }
    }
    if (!taskIdArg) {
      const g = newImageExportGuard(x, {
        generateClicked, leftoverTaskId: plan.leftoverTaskId,
      });
      if (g !== "accept_gltf") {
        die("refusing to write GLB without Generate click and a new task id, leftover=" +
          (plan.leftoverTaskId || "") + " now=" + (x.taskId || "") + " guard=" + g);
      }
    }
    if (x.taskId) taskId = x.taskId;
    if (!x.gltf) die("export loop ended without glTF: " + xsteps.join(">"));
    const b64 = await ev(cdp, `(window.__gv_files||[]).find(f => f.magic === "glTF" && f.size > 100).b64`);
    const bytes = Buffer.from(b64, "base64");
    if (bytes.subarray(0, 4).toString() !== "glTF") die(`export magic ${bytes.subarray(0, 4)}`);
    await Bun.write(out, bytes);
    timings.export_steps = xsteps;
    lap("export_ms");

    const driver_ms = (timings.chrome_ms || 0) + (timings.login_ms || 0) + (timings.form_ms || 0);
    const tabName = req.tab === "hd-model" ? "HD Model" : "Smart Mesh";
    const payload: Record<string, unknown> = {
      ok: true,
      summary: `Studio ${tabName} Export GLB ${out} (${bytes.length} bytes)`,
      glb_path: out,
      task_id: taskId,
      driver: "chrome-for-testing-new-headless",
      timings: { ...timings, driver_ms, total_ms: Date.now() - t0 },
      warm: attachedWarm,
      cookie_source: cookieSource,
      kept_chrome: !killChrome,
      remaining_studio_features: remainingStudioFeatures(),
      ...studioExportFormFields(req),
    };
    if (!taskIdArg) payload.slider_faces = sliderNow;
    console.log(JSON.stringify(payload));
  }
} catch (e) {
  console.log(JSON.stringify({
    ok: false,
    summary: String(e),
    timings: { ...timings, total_ms: Date.now() - t0 },
    warm: attachedWarm,
  }));
  process.exitCode = 2;
} finally {
  try { close(); } catch { /* ignore */ }
  if (killChrome) await reapChrome();
  process.exit(process.exitCode ?? 0);
}
