#!/usr/bin/env python3
"""Browser control plane for Glassvow's existing visual development surfaces."""

from __future__ import annotations

import argparse
import hmac
import json
import mimetypes
import os
import re
import secrets
import shlex
import shutil
import subprocess
import tempfile
import threading
import webbrowser
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlencode, urlsplit

ROOT = Path(__file__).resolve().parents[1]
LIVE = ROOT / "tools/live.sh"
WEB_BUILD = ROOT / "build/web-dev"
WEB_INDEX = WEB_BUILD / "index.html"
TOP_LEVEL = {"cards", "surfaces", "studio", "enemies", "chips", "hud", "reward", "fight", "layout"}
EXITING = {"shot", "strip"}
ENEMY_STRIPS = {"rite", "hit", "enter", "idle", "crack", "ward"}
SURFACES = [
    {"id": "run", "title": "World & run", "group": "Production", "base": [], "selectors": [], "defaults": "--seed=7", "note": "The shipping world map and run flow."},
    {"id": "combat", "title": "Combat bench", "group": "Production", "base": ["--fight=duskfang"], "selectors": ["fight"], "defaults": "--kind=elite --seed=7", "note": "A real GlassvowGame and CombatScreen; only map selection is skipped."},
    {"id": "cards", "title": "Card catalogue", "group": "Viewers", "base": ["--cards"], "selectors": ["cards", "surfaces"], "defaults": "", "note": "All cards or one material contact sheet, using production CardView."},
    {"id": "studio", "title": "Card studio", "group": "Editors", "base": ["--studio=bastion"], "selectors": ["studio"], "defaults": "", "note": "Interactive card material, pose and lighting bench."},
    {"id": "enemies", "title": "Enemy roster", "group": "Viewers", "base": ["--enemies"], "selectors": ["enemies"], "defaults": "", "note": "Every actor at true relative size; add --states or --fracture --compare."},
    {"id": "layout", "title": "Layout book", "group": "Editors", "base": ["--layout"], "selectors": ["layout"], "defaults": "--shape=pad-landscape", "note": "Author stage shapes over a real fight; saving is available through Native Proof."},
    {"id": "enemy_bench", "title": "Enemy bench", "group": "Editors", "base": ["--enemies", "--bench=duskfang"], "selectors": ["enemies"], "defaults": "", "note": "Interactive actor and fracture tuning. Click or drag the captured viewport."},
    {"id": "chips", "title": "Status & intent chips", "group": "Viewers", "base": ["--chips"], "selectors": ["chips"], "defaults": "", "note": "Production chips on representative grounds."},
    {"id": "hud", "title": "HUD mock", "group": "Mocks", "base": ["--hud"], "selectors": ["hud"], "defaults": "--state=0", "note": "Production HudBar over scripted combat states and a mock stage."},
    {"id": "reward", "title": "Reward mock", "group": "Mocks", "base": ["--reward"], "selectors": ["reward"], "defaults": "", "note": "Production RewardScreen over fixed spoils, without a fight behind it."},
]
BY_ID = {item["id"]: item for item in SURFACES}

PAGE = r"""<!doctype html>
<html lang="en-GB"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Glassvow Dev Tools</title><style>
:root{color-scheme:dark;--ink:#0b0e1a;--panel:#12182b;--line:#30405e;--ember:#efaa68;--text:#edf2ff;--dim:#9eabc5}
*{box-sizing:border-box}body{margin:0;background:var(--ink);color:var(--text);font:15px system-ui,sans-serif}header{height:58px;padding:0 22px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--line)}h1{font:600 20px Georgia,serif;letter-spacing:.04em;margin:0}a{color:var(--ember)}
main{display:grid;grid-template-columns:300px minmax(0,1fr);min-height:calc(100vh - 58px)}main.sidebar-collapsed{grid-template-columns:minmax(0,1fr)}aside{padding:20px;border-right:1px solid var(--line);background:var(--panel)}#sidebar[hidden]{display:none}label{display:block;color:var(--dim);margin:0 0 14px}
select,input{width:100%;margin-top:6px;padding:9px;background:#090d18;color:var(--text);border:1px solid var(--line);border-radius:5px}input[type=checkbox]{width:auto;margin:0}
code{display:block;margin-top:6px;color:var(--ember);white-space:normal}.note{min-height:54px;color:var(--dim);line-height:1.4}.buttons,.toolbar{display:flex;gap:8px;flex-wrap:wrap}button{padding:8px 12px;border:1px solid var(--line);border-radius:5px;background:#1b2740;color:var(--text);cursor:pointer}button.primary{background:#804a2c;border-color:var(--ember)}button:hover{filter:brightness(1.18)}
section{padding:16px;min-width:0}.toolbar{align-items:center;margin-bottom:12px}.toolbar label{margin:0 0 0 auto}#stage{height:calc(100vh - 180px);min-height:320px;background:#05070d;border:1px solid var(--line);border-radius:6px;overflow:hidden;display:grid;place-items:center}#frame{display:block;max-width:100%;max-height:calc(100vh - 182px);height:auto;outline:none;touch-action:none;cursor:crosshair}#frame:not([src]),#frame[hidden],#web[hidden]{display:none}#frame:focus{box-shadow:inset 0 0 0 2px var(--ember)}#web{display:block;width:100%;height:100%;border:0;background:#05070d}pre{white-space:pre-wrap;color:var(--dim);max-height:130px;overflow:auto}details{margin-top:18px;color:var(--dim);line-height:1.4}
@media(max-width:760px){main{grid-template-columns:1fr}aside{border-right:0;border-bottom:1px solid var(--line)}}
</style></head><body>
<header><h1>Glassvow Dev Tools</h1><a id="reference" target="_blank" rel="noreferrer">Web reference ↗</a></header>
<main id="layout"><aside id="sidebar"><label>Mode<select id="mode"><option value="web">Interactive Web</option><option value="native">Native Proof</option></select></label>
<label>Surface<select id="surface"></select></label><label>Fixed route<code id="base"></code></label>
<label>Additional arguments<input id="args" autocomplete="off" spellcheck="false"></label><p class="note" id="note"></p>
<div class="buttons"><button class="primary" id="start">Start / restart</button><button id="stop">Stop</button></div>
<details><summary>Two honest render paths</summary><p>Interactive Web runs the exported Godot canvas directly. Plain HTTP LAN or Tailscale sessions are muted because browser audio worklets require a secure context. Native Proof drives and captures the macOS build for frame-accurate motion, file-writing editors and final approval. Temporal strips and performance probes stay in the CLI.</p></details>
</aside><section><div class="toolbar"><button id="sidebar-toggle" aria-controls="sidebar" aria-expanded="true">Hide controls</button><button id="refresh">Refresh</button><button id="reload">Reload code</button><button id="status">Status</button><label><input id="auto" type="checkbox"> auto-refresh</label></div>
<div id="stage"><span id="empty">Start a surface to see its viewport</span><img id="frame" tabindex="0" alt="Native Godot viewport"><iframe id="web" title="Interactive Godot Web surface" hidden></iframe></div><pre id="log">No host queried yet.</pre></section></main><script>
const surfaces=__SURFACES__, token=new URLSearchParams(location.search).get("token")||"";
const $=id=>document.getElementById(id), headers={"Content-Type":"application/json",...(token?{"X-Glassvow-Token":token}:{})};
let loading=false, objectUrl="", down=null;
function current(){return surfaces.find(x=>x.id===$("surface").value)}
function choose(){const x=current();$("base").textContent=x.base.join(" ")||"(none)";$("args").value=x.defaults;$("note").textContent=x.note}
function write(value){$("log").textContent=typeof value==="string"?value:JSON.stringify(value,null,2)}
async function api(path,body){const r=await fetch(path,{method:body?"POST":"GET",headers,body:body?JSON.stringify(body):undefined});
 const data=await r.json();if(!r.ok)throw Error(data.error||r.statusText);write(data.output||data);return data}
async function refresh(){if(loading)return;loading=true;try{const r=await fetch("/api/frame",{headers});
 if(!r.ok){const e=await r.json();throw Error(e.error)}const blob=await r.blob();if(objectUrl)URL.revokeObjectURL(objectUrl);
 objectUrl=URL.createObjectURL(blob);$("frame").src=objectUrl;$("empty").hidden=true}catch(e){write(e.message)}finally{loading=false}}
async function command(name,data={}){try{await api("/api/command",{name,...data});if(name!=="stop")await refresh()}catch(e){write(e.message)}}
$("surface").innerHTML=surfaces.map(x=>`<option value="${x.id}">${x.group} · ${x.title}</option>`).join("");choose();
$("sidebar-toggle").onclick=()=>{const collapsed=!$("sidebar").hidden;$("sidebar").hidden=collapsed;
 $("layout").classList.toggle("sidebar-collapsed",collapsed);$("sidebar-toggle").setAttribute("aria-expanded",String(!collapsed));
 $("sidebar-toggle").textContent=collapsed?"Show controls":"Hide controls"};
function showWeb(url){$("frame").hidden=true;$("web").hidden=false;$("web").src=url;$("empty").hidden=true}
function showNative(){$("web").src="about:blank";$("web").hidden=true;$("frame").hidden=false}
async function start(){const button=$("start");button.disabled=true;write($("mode").value==="web"?"Exporting Godot Web…":"Starting Native Proof…");
 try{const data=await api("/api/start",{mode:$("mode").value,surface:current().id,args:$("args").value});
  if(data.url)showWeb(data.url);else{showNative();await refresh()}}catch(e){write(e.message)}finally{button.disabled=false}}
$("surface").onchange=choose;$("start").onclick=start;
$("stop").onclick=async()=>{await command("stop");if($("mode").value==="web"){$("web").src="about:blank";$("empty").hidden=false}};
$("refresh").onclick=()=>{$("mode").value==="web"?$("web").contentWindow.location.reload():refresh()};
$("reload").onclick=()=>$("mode").value==="web"?start():command("reload");$("status").onclick=()=>api("/api/status").catch(e=>write(e.message));
$("reference").href=`http://${location.hostname}:5190/`;setInterval(()=>{$("auto").checked&&$("mode").value==="native"&&refresh()},1200);
function point(e){const r=$("frame").getBoundingClientRect(),w=$("frame").naturalWidth,h=$("frame").naturalHeight;
 return {x:Math.round((e.clientX-r.left)*w/r.width),y:Math.round((e.clientY-r.top)*h/r.height),width:w,height:h}}
$("frame").onpointerdown=e=>{down=point(e);$("frame").setPointerCapture(e.pointerId)};
$("frame").onpointerup=e=>{if(!down)return;const to=point(e),d=Math.hypot(to.x-down.x,to.y-down.y);
 command(d<5?"click":"drag",d<5?to:{from:down,to});down=null;$("frame").focus()};
$("frame").onkeydown=e=>{if(e.key==="Tab")return;const names={" ":"space","ArrowUp":"up","ArrowDown":"down","ArrowLeft":"left","ArrowRight":"right","Escape":"escape","Enter":"enter"};
 const key=names[e.key]||(e.key.length===1?e.key:"");if(key){e.preventDefault();command("key",{key})}};
api("/api/status").then(x=>{if(x.surface){$("mode").value=x.mode||"native";$("surface").value=x.surface;choose();$("args").value=x.args}
 if(x.url)showWeb(x.url);else if(x.output.startsWith("running")){showNative();refresh()}}).catch(e=>write(e.message));
</script></body></html>"""

class ToolError(RuntimeError): pass

def live(*arguments: str, timeout: int = 55) -> str:
    try:
        result = subprocess.run(
            [str(LIVE), *arguments], cwd=ROOT, text=True, capture_output=True,
            timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise ToolError(f"live command timed out: {arguments[0]}") from exc
    output = (result.stdout + result.stderr).strip()
    if result.returncode:
        raise ToolError(output or f"live command failed ({result.returncode})")
    return output

def launch_arguments(surface_id: str, extra: str) -> list[str]:
    surface = BY_ID.get(surface_id)
    if surface is None:
        raise ToolError("Unknown development surface.")
    try:
        parts = shlex.split(extra)
    except ValueError as exc:
        raise ToolError(f"Invalid arguments: {exc}") from exc
    if len(parts) > 24:
        raise ToolError("At most 24 additional arguments are allowed.")
    for part in parts:
        if len(part) > 240 or not part.startswith("--") or any(ord(c) < 32 for c in part):
            raise ToolError("Arguments must be short --flag or --flag=value tokens.")
        name = part[2:].split("=", 1)[0]
        if not re.fullmatch(r"[a-z][a-z0-9-]*", name):
            raise ToolError(f"Invalid flag: {part}")
        if name in EXITING or (surface_id.startswith("enemy") and name in ENEMY_STRIPS):
            raise ToolError(f"{part} exits the live host; run that capture through tools/shot.sh.")
        if name in TOP_LEVEL and name not in surface["selectors"]:
            raise ToolError(f"{part} belongs to another surface; select it from the list.")
    return [*surface["base"], *parts]

def web_url(arguments: list[str], token: str) -> str:
    query = ([("token", token)] if token else []) + [("arg", arg) for arg in arguments]
    return "/web/index.html" + (f"?{urlencode(query)}" if query else "")

def build_web() -> str:
    version = subprocess.run(
        ["godot", "--version"], text=True, capture_output=True, timeout=10, check=False)
    if version.returncode or not version.stdout.startswith("4.7.1.stable"):
        raise ToolError("Godot 4.7.1.stable is required for the Web development export.")
    if WEB_BUILD.exists():
        shutil.rmtree(WEB_BUILD)
    WEB_BUILD.mkdir(parents=True)
    try:
        result = subprocess.run(
            ["godot", "--headless", "--path", str(ROOT), "--export-debug",
             "Web Dev", str(WEB_INDEX)],
            text=True, capture_output=True, timeout=180, check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise ToolError("Godot Web export timed out.") from exc
    output = (result.stdout + result.stderr).strip()
    if result.returncode or not WEB_INDEX.exists():
        raise ToolError(output or "Godot Web export failed.")
    return "Godot Web export complete."

class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], token: str):
        super().__init__(address, Handler)
        self.token = token
        self.lock = threading.Lock()
        self.owns_host = False
        self.current: dict[str, str] = {}

class Handler(BaseHTTPRequestHandler):
    server: Server

    def log_message(self, _format: str, *_args: object) -> None:
        pass

    def authorised(self) -> bool:
        return not self.server.token or hmac.compare_digest(
            self.headers.get("X-Glassvow-Token", ""), self.server.token)

    def web_authorised(self) -> tuple[bool, bool]:
        if not self.server.token:
            return True, False
        query_token = parse_qs(urlsplit(self.path).query).get("token", [""])[0]
        if hmac.compare_digest(query_token, self.server.token):
            return True, True
        cookie = SimpleCookie(self.headers.get("Cookie", ""))
        value = cookie.get("glassvow_web")
        return bool(value and hmac.compare_digest(value.value, self.server.token)), False

    def send_json(self, status: int, value: dict[str, object]) -> None:
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def read_json(self) -> dict[str, object]:
        length = int(self.headers.get("Content-Length", "0"))
        if length < 0 or length > 16_384:
            raise ToolError("Request body is too large.")
        value = json.loads(self.rfile.read(length) or b"{}")
        if not isinstance(value, dict):
            raise ToolError("Request body must be a JSON object.")
        return value

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path == "/":
            body = PAGE.replace("__SURFACES__", json.dumps(SURFACES)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        if path.startswith("/web/"):
            authorised, set_cookie = self.web_authorised()
            if not authorised:
                self.send_json(401, {"error": "Unauthorised."})
            else:
                self.send_web_file(path, set_cookie)
            return
        if path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return
        if not path.startswith("/api/") or not self.authorised():
            self.send_json(401 if path.startswith("/api/") else 404, {"error": "Unauthorised."})
            return
        try:
            if path == "/api/status":
                with self.server.lock:
                    output = ("web build ready" if self.server.current.get("mode") == "web"
                              and WEB_INDEX.exists() else live("status").splitlines()[0])
                    self.send_json(200, {"output": output, **self.server.current})
            elif path == "/api/frame":
                self.send_frame()
            else:
                self.send_json(404, {"error": "Unknown endpoint."})
        except ToolError as exc:
            self.send_json(409, {"error": str(exc)})

    def send_web_file(self, request_path: str, set_cookie: bool) -> None:
        relative = unquote(request_path.removeprefix("/web/")) or "index.html"
        candidate = (WEB_BUILD / relative).resolve()
        try:
            candidate.relative_to(WEB_BUILD.resolve())
        except ValueError:
            self.send_json(404, {"error": "Unknown Web export file."})
            return
        if not candidate.is_file():
            self.send_json(404, {"error": "Build Interactive Web before opening it."})
            return
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(candidate.name)[0]
                         or "application/octet-stream")
        self.send_header("Content-Length", str(candidate.stat().st_size))
        self.send_header("Cache-Control", "no-store")
        if set_cookie:
            self.send_header(
                "Set-Cookie",
                f"glassvow_web={self.server.token}; HttpOnly; SameSite=Strict; Path=/web/",
            )
        self.end_headers()
        with candidate.open("rb") as source:
            shutil.copyfileobj(source, self.wfile)

    def send_frame(self) -> None:
        fd, name = tempfile.mkstemp(prefix="glassvow-dev-", suffix=".png")
        os.close(fd)
        path = Path(name)
        path.unlink()
        try:
            with self.server.lock:
                live("shot", str(path))
                body = path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
        finally:
            path.unlink(missing_ok=True)

    def do_POST(self) -> None:
        if not self.path.startswith("/api/") or not self.authorised():
            self.send_json(401, {"error": "Unauthorised."})
            return
        try:
            request = self.read_json()
            if self.path == "/api/start":
                mode = str(request.get("mode", "native"))
                if mode not in {"native", "web"}:
                    raise ToolError("Unknown development mode.")
                surface_id = str(request.get("surface", ""))
                extra = str(request.get("args", ""))
                arguments = launch_arguments(surface_id, extra)
                with self.server.lock:
                    if live("status").startswith("running"):
                        live("stop")
                        self.server.owns_host = False; self.server.current = {}
                    if mode == "web":
                        output = build_web()
                        url = web_url(arguments, self.server.token)
                        self.server.current = {
                            "mode": mode, "surface": surface_id, "args": extra, "url": url}
                    else:
                        output = live("start", *arguments)
                        url = ""
                        self.server.owns_host = True
                        self.server.current = {
                            "mode": mode, "surface": surface_id, "args": extra}
                self.send_json(200, {"output": output, **({"url": url} if url else {})})
            elif self.path == "/api/command":
                self.send_json(200, {"output": self.run_command(request)})
            else:
                self.send_json(404, {"error": "Unknown endpoint."})
        except (ToolError, ValueError, OverflowError, UnicodeError, json.JSONDecodeError) as exc:
            self.send_json(400, {"error": str(exc)})

    def run_command(self, request: dict[str, object]) -> str:
        name = str(request.get("name", ""))
        with self.server.lock:
            if name == "stop" and self.server.current.get("mode") == "web":
                self.server.current = {}
                return "Web canvas stopped."
            if name in {"reload", "stop"}:
                output = live(name)
                if name == "stop":
                    self.server.owns_host = False; self.server.current = {}
                return output
            if name == "key":
                key = str(request.get("key", ""))
                if not re.fullmatch(r"[A-Za-z0-9]|enter|escape|space|up|down|left|right", key):
                    raise ToolError("Unsupported key.")
                return live("key", key)
            if name == "click":
                x, y = self.point(request)
                return live("click", str(x), str(y))
            if name == "drag":
                start = request.get("from", {})
                end = request.get("to", {})
                if not isinstance(start, dict) or not isinstance(end, dict):
                    raise ToolError("Drag requires from and to points.")
                x1, y1 = self.point(start)
                x2, y2 = self.point(end)
                return live("drag", str(x1), str(y1), str(x2), str(y2))
        raise ToolError("Unsupported browser command.")

    @staticmethod
    def point(value: dict[str, object]) -> tuple[int, int]:
        """Browser click -> the injected event's coordinate space.

        The rescale is a backing-store conversion, not a layout one: a live-host
        capture of the 1180x820 window comes back at 3620x2516 on this Mac (the
        3.068x Retina backing store), while the runtime bridge feeds positions
        to Input.parse_input_event, which reads WINDOW pixels. Hence capture px
        -> logical window px.

        The 1180x820 written here is therefore the WINDOW's logical size, which
        stage shapes do not change -- a shape changes content_scale_size, not
        the window. Two known gaps, both pre-existing and neither reachable from
        this side: --vp resizes the window and this constant does not follow it,
        and past the flex cap the stage is letterboxed, so the capture is inset
        within the window and a click needs that offset added as well. Every
        interactive surface today runs at the identity shape in a default
        window, where both corrections are zero. The layout editor is the first
        surface that will be clicked at another shape, and is where the game
        should start reporting its stage rect back instead of it being assumed.
        """
        width, height = int(value.get("width", 1180)), int(value.get("height", 820))
        if not 0 < width <= 32_768 or not 0 < height <= 32_768:
            raise ToolError("Capture dimensions are invalid.")
        return (
            max(0, min(1180, round(int(value.get("x", 0)) * 1180 / width))),
            max(0, min(820, round(int(value.get("y", 0)) * 820 / height))),
        )

def check() -> None:
    assert len(BY_ID) == len(SURFACES)
    assert not hasattr(BaseHTTPRequestHandler, "run_command")
    assert Handler.point({"x": 3130, "y": 310, "width": 3620, "height": 2516}) == (1020, 101)
    assert web_url(["--enemies", "--bench=duskfang"], "secret") == (
        "/web/index.html?token=secret&arg=--enemies&arg=--bench%3Dduskfang")
    assert all(marker in PAGE for marker in (
        'id="sidebar-toggle" aria-controls="sidebar" aria-expanded="true"',
        'id="layout"', 'id="sidebar"', 'main.sidebar-collapsed',
        '$("sidebar").hidden=collapsed',
    ))
    for surface in SURFACES:
        launch_arguments(surface["id"], surface["defaults"])
    try:
        launch_arguments("enemy_bench", "--idle=gloomslime")
    except ToolError:
        pass
    else:
        raise AssertionError("an exiting strip reached the live host")
    print(f"dev tools: PASS ({len(SURFACES)} browser surfaces)")

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--token", default="")
    parser.add_argument("--open", action="store_true", help="open the local browser")
    parser.add_argument("--check", action="store_true", help="validate the registry and exit")
    parser.add_argument("--build-web", action="store_true", help="export Interactive Web and exit")
    options = parser.parse_args()
    if options.check:
        check()
        return
    if options.build_web:
        print(build_web())
        return
    remote = options.host not in {"127.0.0.1", "::1", "localhost"}
    token = options.token or (secrets.token_urlsafe(18) if remote else "")
    server = Server((options.host, options.port), token)
    local_url = f"http://127.0.0.1:{options.port}/" + (f"?token={token}" if token else "")
    print(f"Glassvow Dev Tools: {local_url}")
    if remote:
        print("Remote access is enabled; use this Mac's trusted LAN or Tailscale hostname with the same token.")
    if options.open:
        webbrowser.open(local_url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        if server.owns_host:
            try:
                live("stop", timeout=10)
            except ToolError:
                pass

if __name__ == "__main__": main()
