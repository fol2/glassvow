#!/usr/bin/env bun
/**
 * Studio image → GLB. No LLM. No Tripo API.
 *
 * Walked 2026-08-19 on Chrome for Testing 145 *new Headless* (Metal M4),
 * cookies decrypted from Chrome Default (`ory_kratos_session` on `.tripo3d.ai`).
 *
 * Measured path (do not skip):
 * 1. After cookie login, `Page.navigate` `/workspace/generate`. New Headless
 *    has WebGL so this cold GET works. Gallery home at 1280px hides
 *    **More Settings**; header **3D Workspace** is a no-op. gstack
 *    chrome-headless-shell still 500s on that URL.
 * 2. **Smart Mesh** (`tab=low_poly`). Generate button **Generate 100 65**.
 *    After upload a **Generate Multi-Views** button appears — do not click it.
 * 3. Privacy: `element.click()` does not open the listbox. Mouse-click the
 *    Sharing/Private/Public combobox, then mouse-click **Private**.
 * 4. Topology: mouse-click **Topology**. Default **Quad New**, slider 500–25000.
 *    Set faces by typing in the text box next to the slider (walked:
 *    JS `.value=` does not drive Vue; triple-click, `Input.insertText`,
 *    Tab commits `aria-valuenow`). Escape closes the popover.
 * 5. Generate is done when **Export** is in the DOM. Do not treat
 *    Generating/Queuing-absent as done (true before the label paints).
 * 6. After Export appears, dismiss the walked "Retry for better results"
 *    dialog (14px close) or the dialog Export click is a no-op.
 * 7. Export: viewport 1280×900. Format can be **FBX**. Mouse-click Format,
 *    then **GLB**, then the *last* Export. Hook `createObjectURL` before
 *    that click; keep magic `glTF` (a 1853-byte `//#r` worker blob fires
 *    first).
 *
 * Speed (2026-08-20): keep Chrome for Testing on port 9335 with a durable
 * profile at `~/Library/Caches/glassvow/studio-cft`. Cookies are cached at
 * `~/Library/Caches/glassvow/studio-cookies.json` (0600) so a cold start
 * does not decrypt Chrome Default. Navigate once to `/workspace/generate`.
 * JSON `timings.driver_ms` is chrome+login+form (not Studio upload/generate).
 * `--kill-chrome` tears the warm browser down (also valid as a lone flag).
 * Never spawn extra Default Chrome.
 *
 * gstack `Mode: launched` is chrome-headless-shell — Export never mounts there.
 */

import {
  existsSync, readdirSync, mkdirSync, writeFileSync, readFileSync, unlinkSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

const STUDIO = "https://studio.tripo3d.ai";
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

function arg(name: string, fallback = ""): string {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
function flag(name: string): boolean {
  return process.argv.includes(name);
}

const image = arg("--image");
const out = arg("--out", "/tmp/glassvow-studio.glb");
// Quad@1344 → 2701 tris. Default under 1000 so a coarse slider still
// lands inside the ordinary 2500-tri cap.
const faces = Number(arg("--faces", "800"));
const topology = arg("--topology", "quad");
const privacy = arg("--privacy", "private");
const taskIdArg = arg("--task-id");
const stopBefore = flag("--stop-before-generate");
const cookieBrowser = arg("--cookie-browser", "Chrome");
const killChrome = flag("--kill-chrome");

if (!image && !taskIdArg && !killChrome) die("need --image, --task-id, or --kill-chrome");
if (image && !existsSync(image)) die(`image missing: ${image}`);
if (image || taskIdArg) {
  if (faces < 500 || faces > 25000) die(`--faces ${faces} outside Studio slider 500-25000`);
  if (!["quad", "triangle"].includes(topology)) die(`bad --topology ${topology}`);
  if (!["private", "public", "sharing"].includes(privacy)) die(`bad --privacy ${privacy}`);
}
for (const h of FORBIDDEN) {
  if (process.argv.join(" ").includes(h)) die(`refusing ${h}`);
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
    last = await ev(cdp, expr);
    if (ok(last)) return last;
    await new Promise((r) => setTimeout(r, 0));
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

async function dismissPostGenerateOverlays(cdp: Cdp) {
  const retry = await ev(cdp, `(() => {
    const dlg = [...document.querySelectorAll("[role=dialog]")].find(d =>
      /Retry for better/.test(d.innerText || ""));
    if (!dlg) return null;
    const b = dlg.querySelector("button");
    if (!b) return null;
    const r = b.getBoundingClientRect();
    return { cx: r.x + r.width / 2, cy: r.y + r.height / 2 };
  })()`);
  if (retry) {
    await clickxy(cdp, retry.cx, retry.cy);
    await waitEv(cdp, `[...document.querySelectorAll("[role=dialog]")].some(d => /Retry for better/.test(d.innerText||""))`,
      (open) => open === false, 4000).catch(() => null);
  }
  const ok = await ev(cdp, `(() => {
    if (!/View Your Model|Retry for better/.test(document.body.innerText || "")) return null;
    const b = [...document.querySelectorAll("button")].find(x => (x.innerText || "").trim() === "OK");
    if (!b) return null;
    const r = b.getBoundingClientRect();
    if (r.width < 8) return null;
    return { cx: r.x + r.width / 2, cy: r.y + r.height / 2 };
  })()`);
  if (ok) {
    await clickxy(cdp, ok.cx, ok.cy);
  }
}

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
  const targetUrl = taskIdArg
    ? `${STUDIO}/workspace/generate/${taskIdArg}`
    : `${STUDIO}/workspace/generate`;

  let state = await ev(cdp, pageStateExpr);
  const already = state && !state.login && !state.err && (
    taskIdArg ? state.exp && String(state.href).includes(taskIdArg)
      : state.smart && /\/workspace\/generate\/?$/.test(String(state.href).split("?")[0])
  );
  if (!already) {
    await cdp("Page.navigate", { url: targetUrl });
    await cdp("Page.loadEventFired").catch(() => null);
    state = await waitEv(cdp, pageStateExpr, (s) => s && (s.login || (taskIdArg ? s.exp : s.smart)) && !s.err, 20000);
  }

  async function injectCookies(source: string, cookies: StudioCookie[]) {
    await applyCookies(cdp, cookies);
    cookieSource = source;
    await cdp("Page.navigate", { url: targetUrl });
    await cdp("Page.loadEventFired").catch(() => null);
    state = await waitEv(cdp, pageStateExpr, (s) => s && !s.login && !s.err && (taskIdArg ? s.exp : s.smart), 20000);
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
  lap("login_ms");
  await ev(cdp, HOOK_EXPORT);

  let taskId = taskIdArg;
  let sliderNow = faces;
  if (!taskIdArg) {
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
        gen100: [...document.querySelectorAll("button")].some(b =>
          /Generate\\s*100/.test(txt(b))),
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
      if (!s.hasTopo && (/v3/i.test(s.model || "") || s.gen100 === false)) return "reset_via_hd";
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
        model: f.model, p2Banner: f.p2Banner, hasTopo: f.hasTopo, gen100: f.gen100,
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
        await clickxy(cdp, f.facesCx, f.facesCy);
        await cdp("Input.dispatchMouseEvent", { type: "mousePressed", x: f.facesCx, y: f.facesCy, button: "left", clickCount: 3 });
        await cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x: f.facesCx, y: f.facesCy, button: "left", clickCount: 3 });
        await cdp("Input.insertText", { text: String(faces) });
        await cdp("Input.dispatchKeyEvent", { type: "keyDown", key: "Tab", code: "Tab", windowsVirtualKeyCode: 9 });
        await cdp("Input.dispatchKeyEvent", { type: "keyUp", key: "Tab", code: "Tab", windowsVirtualKeyCode: 9 });
      }
      // Continuous detect until this action is no longer what decide() wants.
      for (let d = 0; d < 30; d++) {
        f = await detect();
        if (decide(f) !== action) break;
      }
    }
    sliderNow = f.slider ?? f.facesVal;
    if (f.facesOpen) {
      await cdp("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
      await cdp("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
    }
    timings.form_steps = steps;
    if (sliderNow !== faces) die("form ended without faces=" + faces + " slider=" + sliderNow + " steps=" + steps.join(">"));
    lap("form_ms");
  } else {
    timings.form_ms = 0;
  }

  if (!taskId && stopBefore) {
    const gen = await ev(cdp, `[...document.querySelectorAll("button")].map(b => (b.innerText||"").replace(/\\s+/g," ").trim()).filter(t => /Generate/.test(t))`);
    const driver_ms = (timings.chrome_ms || 0) + (timings.login_ms || 0) + (timings.form_ms || 0);
    console.log(JSON.stringify({
      ok: true,
      summary: "stop-before-generate: form ready, Generate not clicked",
      stopped: true,
      faces: sliderNow,
      topology,
      privacy,
      generate_buttons: gen,
      timings: { ...timings, driver_ms, total_ms: Date.now() - t0 },
      warm: attachedWarm,
      cookie_source: cookieSource,
      kept_chrome: !killChrome,
    }));
  } else if (!taskId) {
    const doc = await cdp("DOM.getDocument", { depth: 1 });
    const q = await cdp("DOM.querySelector", {
      nodeId: doc.root.nodeId,
      selector: 'input[type=file][accept*="image"]',
    });
    if (!q.nodeId) die("no image file input");
    await cdp("DOM.setFileInputFiles", { nodeId: q.nodeId, files: [resolve(image)] });
    await waitEv(cdp, `(() => {
      const pinia = document.querySelector("#__nuxt").__vue_app__.config.globalProperties.$pinia;
      const s = pinia._s.get("workspace-generate-store").$state;
      const img = s.imageToModel || {};
      return { key: img.key || "", audit: img.image_audit_result || "", uploading: s.imageToModelUploading };
    })()`, (s) => s && s.key && s.audit === "pass" && !s.uploading, 40000, 250);
    lap("upload_ms");

    const timingPayload = () => {
      const driver_ms = (timings.chrome_ms || 0) + (timings.login_ms || 0) + (timings.form_ms || 0);
      return {
        timings: { ...timings, driver_ms, total_ms: Date.now() - t0 },
        warm: attachedWarm,
        cookie_source: cookieSource,
        kept_chrome: !killChrome,
      };
    };

    {
      const clicked = await ev(cdp, `(() => {
        const btn = [...document.querySelectorAll("button")].find(b =>
          /Generate\\s*100/.test((b.innerText || "").replace(/\\s+/g, " ")));
        if (!btn) return "missing";
        if (/Multi-Views/.test(btn.innerText || "")) return "refusing-multiview";
        btn.click();
        return "clicked";
      })()`);
      if (clicked !== "clicked") die(`Generate 100 click: ${clicked}`);
      const nav = await waitEv(cdp, `location.href`, (h) => /\/workspace\/generate\/[0-9a-f-]{20,}/.test(String(h)), 20000, 200);
      taskId = String(nav).match(/\/workspace\/generate\/([0-9a-f-]{20,})/)![1];
      await waitEv(cdp, `[...document.querySelectorAll("button")].some(b => (b.innerText||"").trim() === "Export")`,
        (v) => v === true, 180000, 250);
      lap("generate_ms");
    }
  }

  if (!stopBefore) {
    await waitEv(cdp, `[...document.querySelectorAll("button")].some(b => (b.innerText||"").trim() === "Export")`,
      (v) => v === true, 25000);
    await dismissPostGenerateOverlays(cdp);
  }

  if (stopBefore) {
    // JSON already printed. Skip Export.
  } else {
    await ev(cdp, HOOK_EXPORT);

    const opened = await ev(cdp, `(() => {
      const b = [...document.querySelectorAll("button")].find(x => (x.innerText||"").trim() === "Export");
      if (!b) return "missing";
      b.click();
      return "opened";
    })()`);
    if (opened !== "opened") die("Export button missing");
    await waitEv(cdp, `[...document.querySelectorAll("button")].filter(b => (b.innerText||"").trim() === "Export").length`,
      (n) => n >= 2, 5000);

    const fmt = await waitEv(cdp, `(() => {
      const combo = [...document.querySelectorAll("[role=combobox]")].find(c =>
        /USD|FBX|OBJ|STL|GLB|3MF/.test(c.innerText||""));
      if (!combo) return null;
      const r = combo.getBoundingClientRect();
      const hit = document.elementFromPoint(r.x + r.width/2, r.y + r.height/2);
      return { t: (combo.innerText||"").trim(), cx: r.x+r.width/2, cy: r.y+r.height/2, hit: hit && hit.tagName };
    })()`, (s) => s && s.cx, 5000);
    if (fmt.t !== "GLB") {
      await clickxy(cdp, fmt.cx, fmt.cy);
      const opts = await waitEv(cdp, `[...document.querySelectorAll("[role=option]")].map(o => {
        const r = o.getBoundingClientRect();
        return { t: (o.innerText||"").trim(), cx: r.x+r.width/2, cy: r.y+r.height/2 };
      })`, (o) => Array.isArray(o) && o.some((x: any) => x.t === "GLB"), 4000);
      const glb = opts.find((o: any) => o.t === "GLB");
      await clickxy(cdp, glb.cx, glb.cy);
      await waitEv(cdp, `[...document.querySelectorAll("[role=combobox]")].map(c => (c.innerText||"").trim())`,
        (now) => Array.isArray(now) && now.includes("GLB"), 3000);
    }

    const dialog = await ev(cdp, `(() => {
      const btns = [...document.querySelectorAll("button")].filter(b => (b.innerText||"").trim() === "Export");
      const last = btns[btns.length - 1];
      if (!last) return null;
      const r = last.getBoundingClientRect();
      return { n: btns.length, cx: r.x+r.width/2, cy: r.y+r.height/2 };
    })()`);
    if (!dialog || dialog.n < 2) die("Export dialog button missing");
    await clickxy(cdp, dialog.cx, dialog.cy);

    const blob = await waitEv(cdp, `({
      files: (window.__gv_files||[]).map(f => ({magic:f.magic, size:f.size})),
      gltf: (window.__gv_files||[]).find(f => f.magic === "glTF") || null
    })`, (s) => s && s.gltf && s.gltf.size > 100, 20000, 200);
    const b64 = await ev(cdp, `(window.__gv_files||[]).find(f => f.magic === "glTF").b64`);
    const bytes = Buffer.from(b64, "base64");
    if (bytes.subarray(0, 4).toString() !== "glTF") die(`export magic ${bytes.subarray(0, 4)}`);
    await Bun.write(out, bytes);
    lap("export_ms");

    const driver_ms = (timings.chrome_ms || 0) + (timings.login_ms || 0) + (timings.form_ms || 0);
    console.log(JSON.stringify({
      ok: true,
      summary: `Studio Smart Mesh Export GLB ${out} (${bytes.length} bytes)`,
      glb_path: out,
      task_id: taskId,
      faces,
      slider_faces: sliderNow,
      topology,
      privacy,
      driver: "chrome-for-testing-new-headless",
      timings: { ...timings, driver_ms, total_ms: Date.now() - t0 },
      warm: attachedWarm,
      cookie_source: cookieSource,
      kept_chrome: !killChrome,
    }));
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
