#!/usr/bin/env python3
"""ARCHIVED 2026-08-20. Superseded by tools/studio_image_to_glb.ts.

gstack chrome-headless-shell 500s on Studio Export (no WebGL). The walked
driver is Chrome for Testing --headless=new. Do not run this file.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, NoReturn

REPO = Path(__file__).resolve().parent.parent
STUDIO = "https://studio.tripo3d.ai"
FORBIDDEN_HOSTS = ("openapi.tripo3d.ai", "platform.tripo3d.ai")
BROWSE_CANDIDATES = (
    Path.home() / ".claude/skills/gstack/browse/dist/browse",
    Path.home() / ".codex/skills/gstack/browse/dist/browse",
)


class Closed(Exception):
    """Fail closed: do not wander, do not retry with a different product."""


def die(reason: str, code: int = 2) -> NoReturn:
    print(json.dumps({"ok": False, "summary": reason}), flush=True)
    raise SystemExit(code)


def browse_bin() -> Path:
    env = os.environ.get("BROWSE")
    if env:
        path = Path(env)
        if path.is_file() and os.access(path, os.X_OK):
            return path
    for path in BROWSE_CANDIDATES:
        if path.is_file() and os.access(path, os.X_OK):
            return path
    raise Closed("gstack browse binary not found")


def run_browse(binary: Path, args: list[str], timeout: int = 90) -> str:
    joined = " ".join(args)
    for host in FORBIDDEN_HOSTS:
        if host in joined:
            raise Closed(f"refusing browse args that mention {host}")
    proc = subprocess.run(
        [str(binary), *args],
        cwd=str(REPO),
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip()[-800:]
        raise Closed(f"browse {' '.join(args[:3])} rc={proc.returncode}: {err}")
    return proc.stdout


def strip_untrusted(text: str) -> str:
    match = re.search(
        r"BEGIN UNTRUSTED EXTERNAL CONTENT ---\n(.*)\n--- END UNTRUSTED",
        text,
        re.S,
    )
    return match.group(1).strip() if match else text.strip()


def js(binary: Path, expr: str, timeout: int = 60) -> str:
    return strip_untrusted(run_browse(binary, ["js", expr], timeout=timeout))


def js_json(binary: Path, expr: str, timeout: int = 60) -> Any:
    raw = js(binary, expr, timeout=timeout)
    if not raw:
        return None
    try:
        value: Any = json.loads(raw)
    except json.JSONDecodeError:
        return raw
    if isinstance(value, str):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value
    return value


def status_text(binary: Path) -> str:
    return run_browse(binary, ["status"])


def is_headed(status: str) -> bool:
    return "Mode: headed" in status


def import_studio_cookies(binary: Path, browser: str) -> str:
    """Scripted import only. Never omit --domain (that opens the Safari picker)."""
    if browser.lower() == "safari":
        raise Closed("refusing Safari cookie import; use Chrome")
    # --domain must match the current page hostname. Navigate first.
    run_browse(binary, ["goto", STUDIO], timeout=60)
    time.sleep(0.8)
    # host_key IN (...) is exact. Auth lives on ".tripo3d.ai", not "tripo3d.ai".
    imported: list[str] = []
    for domain in (".tripo3d.ai", "studio.tripo3d.ai", ".studio.tripo3d.ai"):
        msg = run_browse(
            binary,
            ["cookie-import-browser", browser, "--domain", domain],
            timeout=60,
        )
        imported.append(msg.strip())
    return "; ".join(imported)


def logged_in(binary: Path) -> bool:
    state = js_json(binary, JS_STATE)
    if not isinstance(state, dict) or not state.get("ok"):
        return False
    if state.get("loginWall"):
        return False
    return state.get("credits") not in {None, 0}


def ensure_studio_session(binary: Path, import_cookies: bool, cookie_browser: str) -> str:
    status = status_text(binary)
    if "needs_setup" in status.lower():
        raise Closed("browse binary needs setup")
    url = strip_untrusted(run_browse(binary, ["url"]))
    if "studio.tripo3d.ai" not in url:
        run_browse(binary, ["goto", STUDIO], timeout=60)
        time.sleep(1.0)
    if logged_in(binary):
        return "already-logged-in"
    if not import_cookies:
        raise Closed("Studio login wall and --no-import-cookies")
    imported = import_studio_cookies(binary, cookie_browser)
    run_browse(binary, ["reload"], timeout=30)
    time.sleep(1.0)
    if not logged_in(binary):
        raise Closed("Studio login wall after cookie import: " + imported[:200])
    return "imported:" + imported.replace("\n", " ")[:160]


def is_glb(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size < 20:
        return False
    return path.read_bytes()[:4] == b"glTF"


JS_STATE = r"""(() => {
  const pinia = document.querySelector("#__nuxt")?.__vue_app__?.config?.globalProperties?.$pinia;
  if (!pinia) return JSON.stringify({ok:false, reason:"no-pinia", url: location.href, body: document.body.innerText.slice(0,400)});
  const user = pinia._s.get("user-store");
  const gen = pinia._s.get("workspace-generate-store");
  const btn = [...document.querySelectorAll("button")].find(b => /Generate/.test(b.innerText||"") && /100/.test(b.innerText||""));
  const wallet = user?.$state?.payment?.wallet;
  const member = user?.$state?.payment?.member;
  const s = gen?.$state || {};
  return JSON.stringify({
    ok: true,
    url: location.href,
    credits: wallet && wallet.total_credit,
    member: member && member.type,
    mode: s.mode,
    tab: s.tab,
    uploading: s.imageToModelUploading,
    hasImage: !!(s.imageToModel && (s.imageToModel.image_token || s.imageToModel.url || s.imageToModel.image_url)),
    genDisabled: !btn || btn.disabled,
    multiViewHint: document.body.innerText.includes("Multi-View support is coming soon"),
    loginWall: /sign in|log in|login/i.test(document.body.innerText.slice(0, 800)) && !(wallet && wallet.total_credit)
  });
})()"""

JS_SINGLE_IMAGE = r"""(() => {
  const toolbar = [...document.querySelectorAll("button")].filter(b =>
    String(b.className).includes("rounded-32") && String(b.className).includes("w-1/2"));
  const first = toolbar[0];
  if (first && !String(first.className).includes("c-black")) first.click();
  return JSON.stringify({count: toolbar.length, clicked: !!(first)});
})()"""

JS_MARK_FILE = r"""(() => {
  const inputs = [...document.querySelectorAll('input[type=file]')];
  inputs.forEach((el, i) => { el.id = el.id || ("gv-file-" + i); });
  return JSON.stringify(inputs.map(el => el.id));
})()"""

JS_TOPOLOGY = r"""(() => {
  const el = [...document.querySelectorAll("div")].find(d =>
    d.className && String(d.className).includes("group/advanced") && /^Topology/.test((d.innerText||"").trim()));
  if (el) el.click();
  return el ? "opened" : "missing";
})()"""

JS_TRIANGLE_1500 = r"""(() => {
  const tri = [...document.querySelectorAll("button")].find(b => (b.innerText||"").trim() === "Triangle");
  if (tri) tri.click();
  const box = [...document.querySelectorAll("input[type=text]")].at(-1);
  if (box) {
    const proto = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
    proto && proto.set && proto.set.call(box, "1500");
    box.dispatchEvent(new Event("input", {bubbles:true}));
    box.dispatchEvent(new Event("change", {bubbles:true}));
  }
  const slider = document.querySelector("[role=slider]");
  return JSON.stringify({
    triangle: !!(tri),
    value: box && box.value,
    slider: slider && slider.getAttribute("aria-valuenow")
  });
})()"""

JS_PRIVATE = r"""(() => {
  const combo = [...document.querySelectorAll("[role=combobox]")].find(c => /public|private|unlisted|sharing/i.test(c.innerText||""));
  if (combo && !/private/i.test(combo.innerText||"")) combo.click();
  return JSON.stringify({text: combo && (combo.innerText||"").replace(/\s+/g," ").trim()});
})()"""

JS_CLICK_PRIVATE_ITEM = r"""(() => {
  const item = [...document.querySelectorAll("[role=option], [role=menuitem], div, span")].find(el =>
    (el.innerText||"").trim() === "Private" && el.childElementCount < 4);
  if (item) item.click();
  return item ? "clicked" : "missing";
})()"""

JS_CLICK_GENERATE = r"""(() => {
  const btn = [...document.querySelectorAll("button")].find(b => /Generate/.test(b.innerText||"") && /100/.test(b.innerText||""));
  if (!btn || btn.disabled) return JSON.stringify({clicked:false, disabled: !btn || btn.disabled});
  btn.click();
  return JSON.stringify({clicked:true});
})()"""

JS_POLL = r"""(() => {
  const pinia = document.querySelector("#__nuxt")?.__vue_app__?.config?.globalProperties?.$pinia;
  const user = pinia && pinia._s.get("user-store");
  const ws = pinia && pinia._s.get("workspace-store");
  const t = document.body.innerText;
  const project = ws && ws.$state.assets && ws.$state.assets.projects && ws.$state.assets.projects[0];
  const match = location.href.match(/\/workspace\/generate\/([0-9a-f-]{20,})/i);
  return JSON.stringify({
    url: location.href,
    taskId: match && match[1],
    generating: /Generating/.test(t),
    queuing: /Queuing/.test(t),
    credits: user && user.$state.payment && user.$state.payment.wallet && user.$state.payment.wallet.total_credit,
    projectId: project && project.id,
    exportVisible: [...document.querySelectorAll("button")].some(b => (b.innerText||"").trim() === "Export")
  });
})()"""

JS_OPEN_EXPORT = r"""(() => {
  const btn = [...document.querySelectorAll("button")].find(b => (b.innerText||"").trim() === "Export");
  if (btn) btn.click();
  return btn ? "opened" : "missing";
})()"""

JS_HOOK_AND_EXPORT = r"""(() => {
  const origCreate = URL.createObjectURL.bind(URL);
  URL.createObjectURL = function(obj) {
    const url = origCreate(obj);
    window.__gv_ready = false;
    window.__gv_err = null;
    Promise.resolve(obj.arrayBuffer()).then(buf => {
      const bytes = new Uint8Array(buf);
      let bin = "";
      const chunk = 0x8000;
      for (let i = 0; i < bytes.length; i += chunk) {
        bin += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
      }
      window.__gv_b64 = btoa(bin);
      window.__gv_size = bytes.length;
      window.__gv_ready = true;
    }).catch(err => { window.__gv_err = String(err); window.__gv_ready = true; });
    return url;
  };
  const dialog = [...document.querySelectorAll("button")].find(b =>
    (b.innerText||"").trim() === "Export" && /File Name/.test(
      (b.parentElement && b.parentElement.parentElement && b.parentElement.parentElement.innerText) || ""));
  const all = [...document.querySelectorAll("button")].filter(b => (b.innerText||"").trim() === "Export");
  if (dialog) dialog.click();
  else if (all.length) all[all.length - 1].click();
  else return "no-export";
  return "clicked";
})()"""

JS_EXPORT_READY = r"""JSON.stringify({ready: !!window.__gv_ready, size: window.__gv_size||0, err: window.__gv_err||null, b64len: (window.__gv_b64||"").length})"""


def wait_json(binary: Path, expr: str, ok: Any, timeout: float, interval: float = 1.0) -> Any:
    deadline = time.time() + timeout
    last: Any = None
    while time.time() < deadline:
        last = js_json(binary, expr)
        if ok(last):
            return last
        time.sleep(interval)
    raise Closed(f"timed out waiting; last={last!r}"[:500])


def require_logged_in(binary: Path) -> dict[str, Any]:
    state = js_json(binary, JS_STATE)
    if not isinstance(state, dict) or not state.get("ok"):
        raise Closed(f"Studio page has no pinia/store: {state!r}"[:300])
    if state.get("loginWall"):
        raise Closed("Studio login wall after cookie import")
    member = str(state.get("member") or "")
    if member and member not in {"professional", "pro", "team", "enterprise"}:
        raise Closed(f"Studio member {member!r} is not Pro")
    return state


def generate(
    concept: Path,
    out: Path,
    face_limit: int,
    import_cookies: bool,
    cookie_browser: str,
    setup_only: bool,
    reuse: bool,
    stop_before_generate: bool,
) -> dict[str, Any]:
    binary = browse_bin()
    session = ensure_studio_session(binary, import_cookies, cookie_browser)
    state = require_logged_in(binary)
    # Observed: a cold GET of /workspace/generate returns
    # "500 Error creating WebGL context." SPA-click from Home works.
    url = strip_untrusted(run_browse(binary, ["url"]))
    if "/workspace/generate" not in url:
        run_browse(binary, ["goto", STUDIO], timeout=60)
        time.sleep(1.2)
        clicked = js(binary, r"""(() => {
          const a = [...document.querySelectorAll("a")].find(x => (x.innerText||"").trim() === "3D Workspace");
          if (a) { a.click(); return "clicked"; }
          return "missing";
        })()""")
        if "clicked" not in clicked:
            raise Closed("3D Workspace link missing on Studio home")
        wait_json(
            binary,
            r"""JSON.stringify({n: document.querySelectorAll("button").length, url: location.href})""",
            lambda s: isinstance(s, dict) and int(s.get("n") or 0) > 20
            and "/workspace/generate" in str(s.get("url") or ""),
            timeout=20,
            interval=0.8,
        )
    if setup_only:
        return {
            "ok": True,
            "summary": (
                f"Studio headless session ready; member={state.get('member')}; "
                f"credits={state.get('credits')}; {session}"
            ),
            "credits_after": state.get("credits"),
            "land_method": session,
        }
    # Observed 2026-08-19: arrival tab is high_detail (HD Model). Smart Mesh
    # sets tab=low_poly and changes Generate to "Generate 100 65".
    js(binary, r"""(() => {
      const btn = [...document.querySelectorAll("button")].find(b => {
        const t = (b.innerText || "").replace(/\s+/g, " ").trim();
        return t === "Smart Mesh" || t.replace(/ /g, "") === "SmartMesh";
      });
      if (btn) btn.click();
      return btn ? "smart-mesh" : "missing";
    })()""")
    time.sleep(0.8)
    form = js_json(binary, JS_STATE)
    if not isinstance(form, dict) or form.get("tab") != "low_poly":
        raise Closed(f"Smart Mesh did not select low_poly tab: {form!r}"[:300])
    opened = js(binary, JS_TOPOLOGY)
    if "opened" in opened:
        time.sleep(0.4)
        topo = js_json(binary, JS_TRIANGLE_1500)
        got = ""
        if isinstance(topo, dict):
            got = str(topo.get("value") or topo.get("slider") or "")
        if got not in {str(face_limit), f"{face_limit}.0"}:
            raise Closed(f"Topology face count is {got!r}, want {face_limit}")
        run_browse(binary, ["press", "Escape"], timeout=15)
        time.sleep(0.2)
    # Observed: Privacy combobox options are Public / Private / Sharing Only.
    # Default is Sharing Only. DOM .click() on the combo does not open the
    # listbox; browse click of the combobox @ref does.
    def snapshot_ref(needle: str, kind: str) -> str:
        text = run_browse(binary, ["snapshot", "-i"])
        for line in text.splitlines():
            if kind in line and needle in line:
                token = line.strip().split()[0]
                if token.startswith("@e"):
                    return token
        return ""

    priv_ref = snapshot_ref("Private", "[option]")
    if not priv_ref:
        combo_ref = snapshot_ref("Sharing", "[combobox]") or snapshot_ref("Private", "[combobox]")
        if not combo_ref:
            raise Closed("Privacy combobox not in snapshot")
        run_browse(binary, ["click", combo_ref])
        time.sleep(0.4)
        priv_ref = snapshot_ref("Private", "[option]")
    if not priv_ref:
        raise Closed("Privacy listbox has no Private option")
    run_browse(binary, ["click", priv_ref])
    time.sleep(0.4)
    privacy = js_json(binary, r"""JSON.stringify({combo:[...document.querySelectorAll("[role=combobox]")].map(c=>(c.innerText||"").replace(/\s+/g," ").trim())})""")
    combo_text = " ".join(privacy.get("combo") or []) if isinstance(privacy, dict) else str(privacy)
    if "Private" not in combo_text:
        raise Closed(f"Privacy did not become Private: {privacy!r}")
    if stop_before_generate:
        return {
            "ok": True,
            "summary": f"form ready tab={form.get('tab')} privacy={privacy} session={session}",
            "credits_after": state.get("credits"),
            "land_method": "stop-before-generate",
        }
    if reuse and is_glb(out):
        return {"ok": True, "summary": f"reused existing GLB {out}", "glb_path": str(out),
                "land_method": "reused", "session": session}
    if is_glb(out) and not reuse:
        out.unlink()
    ids = js_json(binary, JS_MARK_FILE)
    if not isinstance(ids, list) or not ids:
        raise Closed("no file inputs on Studio generate form")
    run_browse(binary, ["upload", f"#{ids[0]}", str(concept)])
    wait_json(
        binary, JS_STATE,
        lambda s: isinstance(s, dict) and s.get("hasImage") and s.get("genDisabled") is False
        and s.get("uploading") in {False, None, 0},
        timeout=30,
    )
    clicked = js_json(binary, JS_CLICK_GENERATE)
    if not isinstance(clicked, dict) or not clicked.get("clicked"):
        raise Closed(f"Generate did not click: {clicked!r}")
    poll = wait_json(
        binary, JS_POLL,
        lambda s: isinstance(s, dict) and not s.get("generating") and not s.get("queuing")
        and (s.get("taskId") or s.get("exportVisible")),
        timeout=180,
        interval=4.0,
    )
    task_id = poll.get("taskId") or poll.get("projectId") or ""
    opened = js(binary, JS_OPEN_EXPORT)
    if opened == "missing":
        raise Closed("Export button not visible after generate")
    time.sleep(0.8)
    hook = js(binary, JS_HOOK_AND_EXPORT)
    if hook == "no-export":
        raise Closed("Export dialog had no Export button")
    ready = wait_json(
        binary, JS_EXPORT_READY,
        lambda s: isinstance(s, dict) and s.get("ready") and int(s.get("b64len") or 0) > 100,
        timeout=20,
        interval=0.4,
    )
    if ready.get("err"):
        raise Closed(f"Export blob failed: {ready['err']}")
    out.parent.mkdir(parents=True, exist_ok=True)
    run_browse(
        binary,
        ["js", "'data:model/gltf-binary;base64,' + window.__gv_b64", "--out", str(out)],
        timeout=30,
    )
    if not is_glb(out):
        raise Closed(f"Export did not write a GLB at {out}")
    return {
        "ok": True,
        "summary": (
            f"Studio Smart Mesh image-to-3D Export GLB {out} "
            f"({out.stat().st_size} bytes); task {task_id}; "
            f"credits_after {poll.get('credits')}; session {session}"
        ),
        "glb_path": str(out),
        "task_id": task_id,
        "credits_after": poll.get("credits"),
        "land_method": "studio_download",
        "face_limit": face_limit,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Studio (non-API) image-to-3D → local GLB")
    parser.add_argument("--concept", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--face-limit", type=int, default=1500)
    parser.add_argument(
        "--import-cookies",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Headless path: import Chrome cookies for tripo3d.ai after goto Studio. "
        "Never opens the cookie picker. Skipped automatically when the daemon is already headed.",
    )
    parser.add_argument("--cookie-browser", default="Chrome",
                        help="Chromium family name for cookie-import-browser. Not Safari.")
    parser.add_argument(
        "--setup-only",
        action="store_true",
        help="Disconnect headed if needed, import Chrome cookies, prove Studio login, exit.",
    )
    parser.add_argument(
        "--reuse",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="If --out already exists as a GLB, skip generate after session setup.",
    )
    parser.add_argument(
        "--stop-before-generate",
        action="store_true",
        help="Walk session + Smart Mesh + Topology 1500 + Private, then exit (no Generate click).",
    )
    args = parser.parse_args()
    os.chdir(REPO)
    if args.setup_only or args.stop_before_generate:
        concept = args.concept or Path("/dev/null")
        if args.concept and not args.concept.is_absolute():
            concept = REPO / args.concept
        out = args.out or Path("/tmp/glassvow-studio-setup-only.glb")
        if args.out and not args.out.is_absolute():
            out = Path(args.out)
    else:
        if args.concept is None or args.out is None:
            die("need --concept and --out (or pass --setup-only / --stop-before-generate)")
        concept = args.concept if args.concept.is_absolute() else REPO / args.concept
        out = args.out if args.out.is_absolute() else Path(args.out)
        if not concept.is_file():
            die(f"concept missing: {concept}")
    try:
        result = generate(
            concept, out, args.face_limit,
            import_cookies=args.import_cookies,
            cookie_browser=args.cookie_browser,
            setup_only=args.setup_only,
            reuse=args.reuse,
            stop_before_generate=args.stop_before_generate,
        )
    except Closed as error:
        die(str(error))
    except (OSError, subprocess.TimeoutExpired, subprocess.SubprocessError) as error:
        die(f"{type(error).__name__}: {error}", code=1)
    print(json.dumps(result), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
