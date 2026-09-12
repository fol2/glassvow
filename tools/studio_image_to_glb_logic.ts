/** Pure helpers for tools/studio_image_to_glb.ts. No Chrome, no network. */

export const STUDIO = "https://studio.tripo3d.ai";
export const BLANK_RESET_URL = "about:blank";
export const BARE_GENERATE_URL = `${STUDIO}/workspace/generate`;
export const UPLOAD_WATCH_LIMIT_MS = 60_000;
export const UPLOAD_WATCH_POLL_MS = 25;

const TASK_PATH = /^\/workspace\/generate\/([0-9a-f-]{20,})\/?$/i;

function studioUrl(href: string): URL | null {
  try {
    const u = new URL(String(href || ""));
    if (u.origin === STUDIO && u.protocol === "https:") return u;
  } catch { /* invalid */ }
  return null;
}

export function generateTargetUrl(taskIdArg: string): string {
  return taskIdArg ? `${BARE_GENERATE_URL}/${taskIdArg}` : BARE_GENERATE_URL;
}

export function generateTaskIdFromHref(href: string): string {
  const u = studioUrl(href);
  if (!u) return "";
  const m = u.pathname.match(TASK_PATH);
  return m ? m[1] : "";
}

export function isBareGenerateHref(href: string): boolean {
  const u = studioUrl(href);
  if (!u) return false;
  const path = u.pathname.replace(/\/+$/, "") || "/";
  return path === "/workspace/generate";
}

export type PageState = { href?: string; login?: boolean; err?: boolean; smart?: boolean };

export function planWarmGeneratePage(state: PageState | null | undefined, taskIdArg: string) {
  const href = String(state?.href || "");
  const leftoverTaskId = taskIdArg ? "" : generateTaskIdFromHref(href);
  const targetUrl = generateTargetUrl(taskIdArg);
  if (taskIdArg) {
    return {
      reuse: !!(state && !state.login && !state.err && href.includes(taskIdArg)),
      targetUrl, resetViaBlank: false, leftoverTaskId: "",
    };
  }
  return {
    reuse: !!(state && !state.login && !state.err && state.smart && isBareGenerateHref(href)),
    targetUrl, resetViaBlank: leftoverTaskId !== "", leftoverTaskId,
  };
}

/** New `--image` waits: login (initial only) or Smart Mesh on exact Studio bare generate. */
export function generateWaitReady(
  s: PageState | null | undefined,
  taskIdArg: string,
  phase: "initial" | "authed",
): boolean {
  if (!s || s.err) return false;
  if (taskIdArg) {
    const onTask = String(s.href || "").includes(taskIdArg);
    if (phase === "initial") return !!(s.login || onTask);
    return !s.login && onTask;
  }
  if (s.login) return phase === "initial";
  return !!s.smart && isBareGenerateHref(String(s.href || ""));
}

export function blankResetArrived(href: string, leftoverTaskId: string): boolean {
  const h = String(href || "");
  if (/^about:blank/i.test(h)) return true;
  if (!leftoverTaskId) return true;
  return generateTaskIdFromHref(h) !== leftoverTaskId;
}

export function isTransientEvaluateError(err: unknown): boolean {
  return /context|navigat|destroyed/i.test(String(err || ""));
}

export function refuseNewImageOnTaskUrl(href: string, taskIdArg: string): void {
  if (taskIdArg) return;
  const leftover = generateTaskIdFromHref(href);
  if (leftover) {
    throw new Error(`prior task still on generate URL (${leftover}); refusing to start a new image`);
  }
}

export function uploadWatchTimedOut(elapsedMs: number, limitMs: number): boolean {
  return elapsedMs > limitMs;
}

export type ExportSnap = {
  gltf?: unknown;
  taskId?: string;
  exportN?: number;
  format?: string;
  glbOption?: boolean;
  retry?: boolean;
  viewOk?: boolean;
  hasTexRes?: boolean;
  texIs1k?: boolean;
  tex1kOption?: boolean;
  hasConvertHref?: boolean;
  generate?: { t: string; vis?: boolean; cx?: number; cy?: number }[];
};

export type HdExportCtx = {
  taskIdArg: string;
  generateClicked: boolean;
  leftoverTaskId: string;
  toolbarExportClicked: boolean;
  formatOpened: boolean;
  texResOpened: boolean;
  dialogExportClicked: boolean;
  cdnFetched: boolean;
  textureQuality: string;
  stopBeforeGenerate?: boolean;
};

/** HD 1K lives on Export Texture Resolution, not the generate form. Never loop on close_tex_list. */
export function decideHdExport(s: ExportSnap, ctx: HdExportCtx): string {
  if (!ctx.taskIdArg) {
    const g = newImageExportGuard(s, {
      generateClicked: ctx.generateClicked, leftoverTaskId: ctx.leftoverTaskId,
    });
    if (g === "refuse_prior_export") return g;
    if (g === "accept_gltf") return "done";
    if (g === "watch_generate") return "watch_generate";
  }
  if (s.gltf) return "done";
  if (s.retry) return "dismiss_retry";
  if (s.viewOk) return "dismiss_ok";
  if ((s.exportN || 0) >= 1 && !s.format) {
    return ctx.toolbarExportClicked ? "watch_dialog" : "click_export";
  }
  if (s.format && s.format !== "GLB" && !s.glbOption) {
    return ctx.formatOpened ? "watch_dialog" : "open_format";
  }
  if (s.glbOption && s.format !== "GLB") return "pick_glb";
  if (s.format === "GLB" && (s.exportN || 0) < 2) return "watch_dialog";
  if (s.format === "GLB" && (s.exportN || 0) >= 2) {
    if (ctx.textureQuality === "1k" && s.hasTexRes && !s.texIs1k) {
      if (s.tex1kOption) return "pick_tex_1k";
      return ctx.texResOpened ? "watch_dialog" : "open_tex_res";
    }
    if (ctx.dialogExportClicked) {
      if (!s.gltf && s.hasConvertHref && !ctx.cdnFetched) return "fetch_cdn";
      return "watch_download";
    }
    return "click_dialog_export";
  }
  if (ctx.dialogExportClicked) {
    if (!s.gltf && s.hasConvertHref && !ctx.cdnFetched) return "fetch_cdn";
    return "watch_download";
  }
  if (ctx.generateClicked) return "watch_generate";
  const genBtn = Array.isArray(s.generate) ? pickVisibleGenerate(s.generate) : null;
  if (shouldClickGenerate(s, {
    taskIdArg: ctx.taskIdArg,
    generateClicked: ctx.generateClicked,
    hasGenerateButton: !!genBtn,
    stopBeforeGenerate: ctx.stopBeforeGenerate,
  })) return "click_generate";
  return "watch_generate";
}

export function hookedGltf<T extends { magic?: string; size?: number }>(
  files: T[] | undefined,
): T | undefined {
  return (files || []).find((f) => f.magic === "glTF" && (f.size || 0) > 100);
}

export function isStudioConvertHref(href: string, download = ""): boolean {
  try {
    const u = new URL(String(href || ""));
    const host = u.hostname.toLowerCase();
    const tripo = host === "tripo3d.ai" || host.endsWith(".tripo3d.ai")
      || host === "tripo3d.com" || host.endsWith(".tripo3d.com")
      || host.includes("tripo-data");
    if (!tripo) return false;
    const n = String(download || "");
    return /\.glb(\?|$)/i.test(n) || /\.glb(\?|$)/i.test(u.pathname + u.search)
      || host.includes("tripo-data");
  } catch {
    return false;
  }
}

/** New `--image` must not click or write a leftover task's GLB. */
export function newImageExportGuard(
  s: ExportSnap,
  ctx: { generateClicked: boolean; leftoverTaskId: string },
): "refuse_prior_export" | "accept_gltf" | "watch_generate" | "allow" {
  const tid = String(s.taskId || "");
  const isNewTask = tid !== "" && tid !== ctx.leftoverTaskId;
  if (s.gltf) {
    if (!ctx.generateClicked || !isNewTask) return "refuse_prior_export";
    return "accept_gltf";
  }
  if (!ctx.generateClicked && (s.exportN || s.format || s.glbOption)) return "refuse_prior_export";
  if (ctx.generateClicked && !isNewTask) return "watch_generate";
  return "allow";
}

export const STUDIO_TABS = ["smart-mesh", "hd-model"] as const;
export type StudioTab = (typeof STUDIO_TABS)[number];
export const TEXTURE_QUALITIES = ["1k", "2k", "4k"] as const;
export type TextureQuality = (typeof TEXTURE_QUALITIES)[number];
export const TOPOLOGIES = ["quad", "triangle"] as const;
export type StudioTopology = (typeof TOPOLOGIES)[number];
export const PRIVACIES = ["private", "public", "sharing"] as const;
export type StudioPrivacy = (typeof PRIVACIES)[number];

export const SMART_MESH_FACES_DEFAULT = 800;
export const HD_FACES_DEFAULT = 6000;
export const SMART_MESH_FACES_MAX = 25000;
export const HD_FACES_MAX = 2_000_000;
export const FACES_MIN = 500;

export const STUDIO_HELP = `Studio image → GLB. No Tripo API.

Workflow: image in → arguments → 3D model out.

Usage:
  bun tools/studio_image_to_glb.ts --image <path> --out <path> [options]
  bun tools/studio_image_to_glb.ts --dry-run --textured --image <path> --out <path>
  bun tools/studio_image_to_glb.ts --smoke-run --textured --image <path> --out <path>
  bun tools/studio_image_to_glb.ts --task-id <id> --out <path>
  bun tools/studio_image_to_glb.ts --kill-chrome

Options:
  --image PATH
  --out PATH                  default /tmp/glassvow-studio.glb
  --tab smart-mesh|hd-model   --model is an alias
  --textured                  HD Model + albedo, 2K, PBR off, faces 6000, triangle
  --faces N                   Smart Mesh 500-25000 (default 800); HD 500-2000000 (default 6000)
  --topology quad|triangle    Smart Mesh default quad; HD default triangle
  --privacy private|public|sharing   default private
  --texture on|off            HD only; Smart Mesh has no texture stage
  --texture-quality 1k|2k|4k  HD only; default 2k (4K blows the hero bytes_max)
  --pbr on|off                HD only; default off (map shaders sample one map)
  --ultra-mesh on|off         HD only; default on
  --ai-complete on|off        HD only; default off (invents unseen backsides)
  --dry-run                   print the planned arguments; no Chrome; no credits
  --smoke-run                 fill the form; do not click Generate
  --stop-before-generate      same Generate-not-clicked stop as --smoke-run
  --task-id ID                re-export an existing task (no Generate)
  --cookie-browser NAME       default Chrome
  --kill-chrome
  --help

Smart Mesh (tab=low_poly) has no texture stage. Textured game content uses
--textured, which stays on the HD Model tab (tab=high_detail).

--dry-run JSON remaining_studio_features lists Studio controls this driver
does not spend credits on (rig, Multi-Views, 8K trial, OpenAPI, …).
`;

export function remainingStudioFeatures(): string[] {
  return [
    "rig / animation",
    "Generate Multi-Views",
    "PBR metallic/roughness/normal maps",
    "4K texture (over this repo's hero bytes_max)",
    "8K Texture trial",
    "AI Complete (invents unseen backsides)",
    "FBX/OBJ/STL/USD/3MF export formats",
    "Public or Sharing Only privacy",
    "Godot DCC Bridge auto-import",
    "Tripo OpenAPI / platform generation (forbidden: Studio is the paid product)",
  ];
}

export function argValue(argv: string[], name: string, fallback = ""): string {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] && !String(argv[i + 1]).startsWith("--")
    ? String(argv[i + 1]) : fallback;
}

export function hasFlag(argv: string[], name: string): boolean {
  return argv.includes(name);
}

function parseOnOff(raw: string): boolean {
  const t = String(raw || "").toLowerCase();
  if (["on", "true", "1", "yes"].includes(t)) return true;
  if (["off", "false", "0", "no"].includes(t)) return false;
  throw new Error(`bad on/off value ${raw}`);
}

/** Bare `--name` is on. `--name off` is off. Missing is undefined. */
export function optionalOnOff(argv: string[], name: string): boolean | undefined {
  const i = argv.indexOf(name);
  if (i < 0) return undefined;
  const next = argv[i + 1];
  if (next && !String(next).startsWith("--") && /^(on|off|true|false|1|0|yes|no)$/i.test(next)) {
    return parseOnOff(next);
  }
  return true;
}

export type StudioRawArgs = {
  image: string;
  out: string;
  facesRaw: string;
  topologyRaw: string;
  privacyRaw: string;
  tabRaw: string;
  modelRaw: string;
  textured: boolean;
  texture: boolean | undefined;
  textureQualityRaw: string;
  pbr: boolean | undefined;
  ultraMesh: boolean | undefined;
  aiComplete: boolean | undefined;
  dryRun: boolean;
  smokeRun: boolean;
  stopBeforeGenerate: boolean;
  taskId: string;
  killChrome: boolean;
  cookieBrowser: string;
  help: boolean;
};

export type StudioRequest = {
  image: string;
  out: string;
  faces: number;
  topology: StudioTopology;
  privacy: StudioPrivacy;
  tab: StudioTab;
  textured: boolean;
  texture: boolean;
  textureQuality: TextureQuality;
  pbr: boolean;
  ultraMesh: boolean;
  aiComplete: boolean;
  dryRun: boolean;
  smokeRun: boolean;
  stopBeforeGenerate: boolean;
  wouldClickGenerate: boolean;
  taskId: string;
  killChrome: boolean;
  cookieBrowser: string;
  help: boolean;
};

export function parseStudioArgv(argv: string[]): StudioRawArgs {
  return {
    image: argValue(argv, "--image"),
    out: argValue(argv, "--out", "/tmp/glassvow-studio.glb"),
    facesRaw: argValue(argv, "--faces"),
    topologyRaw: argValue(argv, "--topology"),
    privacyRaw: argValue(argv, "--privacy", "private"),
    tabRaw: argValue(argv, "--tab"),
    modelRaw: argValue(argv, "--model"),
    textured: hasFlag(argv, "--textured"),
    texture: optionalOnOff(argv, "--texture"),
    textureQualityRaw: argValue(argv, "--texture-quality"),
    pbr: optionalOnOff(argv, "--pbr"),
    ultraMesh: optionalOnOff(argv, "--ultra-mesh"),
    aiComplete: optionalOnOff(argv, "--ai-complete"),
    dryRun: hasFlag(argv, "--dry-run"),
    smokeRun: hasFlag(argv, "--smoke-run"),
    stopBeforeGenerate: hasFlag(argv, "--stop-before-generate") || hasFlag(argv, "--smoke-run"),
    taskId: argValue(argv, "--task-id"),
    killChrome: hasFlag(argv, "--kill-chrome"),
    cookieBrowser: argValue(argv, "--cookie-browser", "Chrome"),
    help: hasFlag(argv, "--help") || hasFlag(argv, "-h"),
  };
}

function asTab(raw: string): StudioTab | "" {
  if (!raw) return "";
  if (raw === "smart-mesh" || raw === "low_poly") return "smart-mesh";
  if (raw === "hd-model" || raw === "high_detail" || raw === "hd") return "hd-model";
  throw new Error(`bad --tab/--model ${raw}`);
}

export function resolveStudioRequest(raw: StudioRawArgs): StudioRequest {
  if (raw.help) {
    return {
      image: raw.image, out: raw.out, faces: SMART_MESH_FACES_DEFAULT,
      topology: "quad", privacy: "private", tab: "smart-mesh", textured: false,
      texture: false, textureQuality: "2k", pbr: false, ultraMesh: true,
      aiComplete: false, dryRun: raw.dryRun, smokeRun: raw.smokeRun,
      stopBeforeGenerate: raw.stopBeforeGenerate, wouldClickGenerate: false,
      taskId: raw.taskId, killChrome: raw.killChrome, cookieBrowser: raw.cookieBrowser,
      help: true,
    };
  }
  if (!raw.image && !raw.taskId && !raw.killChrome) {
    throw new Error("need --image, --task-id, or --kill-chrome");
  }

  const fromTab = asTab(raw.tabRaw);
  const fromModel = asTab(raw.modelRaw);
  if (fromTab && fromModel && fromTab !== fromModel) {
    throw new Error(`--tab ${fromTab} conflicts with --model ${fromModel}`);
  }
  let tab: StudioTab = fromTab || fromModel || "smart-mesh";
  if (raw.textured) {
    if (tab === "smart-mesh" && (fromTab || fromModel)) {
      throw new Error("--textured needs --tab hd-model; Smart Mesh has no texture stage");
    }
    tab = "hd-model";
  }

  const hd = tab === "hd-model";
  const textured = raw.textured || (hd && raw.texture !== false);
  let texture = hd ? (raw.texture === undefined ? true : raw.texture) : false;
  if (!hd && raw.texture === true) {
    throw new Error("Smart Mesh has no texture stage; use --textured / --tab hd-model");
  }
  if (raw.textured && !texture) {
    throw new Error("--textured requires texture on");
  }
  const pbr = hd ? (raw.pbr === undefined ? false : raw.pbr) : false;
  if (pbr && !texture) {
    throw new Error("PBR needs texture on");
  }
  const ultraMesh = hd ? (raw.ultraMesh === undefined ? true : raw.ultraMesh) : true;
  const aiComplete = hd ? (raw.aiComplete === undefined ? false : raw.aiComplete) : false;

  const topologyRaw = (raw.topologyRaw || (hd ? "triangle" : "quad")).toLowerCase();
  if (!TOPOLOGIES.includes(topologyRaw as StudioTopology)) {
    throw new Error(`bad --topology ${raw.topologyRaw}`);
  }
  const topology = topologyRaw as StudioTopology;

  const privacyRaw = raw.privacyRaw || "private";
  if (!PRIVACIES.includes(privacyRaw as StudioPrivacy)) {
    throw new Error(`bad --privacy ${privacyRaw}`);
  }
  const privacy = privacyRaw as StudioPrivacy;

  const qualityRaw = (raw.textureQualityRaw || "2k").toLowerCase();
  if (!TEXTURE_QUALITIES.includes(qualityRaw as TextureQuality)) {
    throw new Error(`bad --texture-quality ${raw.textureQualityRaw}`);
  }
  const textureQuality = qualityRaw as TextureQuality;
  if (!hd) {
    if (raw.textureQualityRaw) throw new Error("--texture-quality is HD Model only");
    if (raw.pbr !== undefined) throw new Error("--pbr is HD Model only");
    if (raw.ultraMesh !== undefined) throw new Error("--ultra-mesh is HD Model only");
    if (raw.aiComplete !== undefined) throw new Error("--ai-complete is HD Model only");
  }

  const defaultFaces = hd ? HD_FACES_DEFAULT : SMART_MESH_FACES_DEFAULT;
  const faces = raw.facesRaw ? Number(raw.facesRaw) : defaultFaces;
  const facesMax = hd ? HD_FACES_MAX : SMART_MESH_FACES_MAX;
  if (!Number.isFinite(faces) || faces < FACES_MIN || faces > facesMax) {
    throw new Error(`--faces ${faces} outside ${FACES_MIN}-${facesMax}`);
  }

  const stopBeforeGenerate = raw.stopBeforeGenerate || raw.smokeRun || raw.dryRun;
  const wouldClickGenerate = !!(
    raw.image && !raw.taskId && !stopBeforeGenerate && !raw.help
    && !(raw.killChrome && !raw.image)
  );

  return {
    image: raw.image,
    out: raw.out,
    faces,
    topology,
    privacy,
    tab,
    textured,
    texture,
    textureQuality,
    pbr,
    ultraMesh,
    aiComplete,
    dryRun: raw.dryRun,
    smokeRun: raw.smokeRun,
    stopBeforeGenerate,
    wouldClickGenerate,
    taskId: raw.taskId,
    killChrome: raw.killChrome,
    cookieBrowser: raw.cookieBrowser,
    help: false,
  };
}

/** `--task-id` never set the form. Do not report argv as if it did. */
export function studioExportFormFields(req: StudioRequest): Record<string, unknown> {
  if (req.taskId) {
    return { form_state: "unset_for_reexport" };
  }
  return {
    tab: req.tab,
    textured: req.textured,
    texture: req.texture,
    texture_quality: req.textureQuality,
    pbr: req.pbr,
    ultra_mesh: req.ultraMesh,
    ai_complete: req.aiComplete,
    privacy: req.privacy,
    faces: req.faces,
    topology: req.topology,
  };
}

export function planStudioRun(req: StudioRequest): Record<string, unknown> {
  const kind = req.texture ? "textured" : "untextured";
  const stop = req.dryRun ? "dry-run" : req.smokeRun ? "smoke-run" : req.stopBeforeGenerate
    ? "stop-before-generate" : "generate";
  return {
    ok: true,
    summary: `${stop}: ${req.tab} ${kind} GLB; Generate ${req.wouldClickGenerate ? "will be clicked" : "not clicked"}`,
    dry_run: req.dryRun,
    smoke_run: req.smokeRun,
    would_spend_credits: req.wouldClickGenerate,
    workflow: ["image", "arguments", "3d-model"],
    image: req.image,
    out: req.out,
    tab: req.tab,
    textured: req.textured,
    texture: req.texture,
    texture_quality: req.textureQuality,
    pbr: req.pbr,
    ultra_mesh: req.ultraMesh,
    ai_complete: req.aiComplete,
    faces: req.faces,
    topology: req.topology,
    privacy: req.privacy,
    generate_match: "price-agnostic Generate (not Multi-Views)",
    remaining_studio_features: remainingStudioFeatures(),
  };
}

export function isPriceAgnosticGenerateLabel(text: string): boolean {
  const t = String(text || "").replace(/\s+/g, " ").trim();
  if (/multi-?views/i.test(t)) return false;
  // Walked labels always include a price: "Generate 40", "Generate 100 65".
  // Bare "Generate" is not a credit button we should click.
  return /^Generate\s+\d+(\s+\d+)?$/.test(t);
}

export type GenerateButton = { t: string; vis: boolean; cx: number; cy: number };

export function pickVisibleGenerate(buttons: GenerateButton[]): GenerateButton | null {
  return buttons.find((b) => b.vis && isPriceAgnosticGenerateLabel(b.t)) ?? null;
}

export function quotedCreditsFromGenerateLabel(text: string): number | null {
  if (!isPriceAgnosticGenerateLabel(text)) return null;
  const t = String(text || "").replace(/\s+/g, " ").trim();
  const m = t.match(/^Generate(?:\s+(\d+))?(?:\s+(\d+))?$/);
  if (!m) return null;
  if (m[2]) return Number(m[2]);
  if (m[1]) return Number(m[1]);
  return null;
}

export function normalizeTextureQuality(v: string): string {
  const m = String(v || "").toLowerCase().match(/([124])k/);
  return m ? `${m[1]}k` : String(v || "").toLowerCase().replace(/\s+/g, "");
}

/**
 * Quality the HD generate form can actually click.
 * Walked 2026-08-25: Geometry & Texture offers 2K / 4K / 8K Trial; 1K is gone.
 * Ordinary kits still want 1K (192 KiB), applied at Export Texture Resolution
 * when that combobox exists.
 */
export function hdGenerateTextureQuality(
  want: string,
  available: readonly string[] | undefined,
): string {
  const wantN = normalizeTextureQuality(want);
  const avail = (available || []).map((q) => normalizeTextureQuality(q)).filter(Boolean);
  if (!avail.length || avail.includes(wantN)) return wantN;
  if (wantN === "1k" && avail.includes("2k")) return "2k";
  if (avail.includes("2k")) return "2k";
  return avail[0];
}

export function normalizeTopology(v: string): string {
  const t = String(v || "").toLowerCase();
  if (t.includes("quad")) return "quad";
  if (t.includes("triangle")) return "triangle";
  return t;
}

export function isHdStoreTab(tab: string): boolean {
  const t = String(tab || "").toLowerCase();
  return t === "high_detail" || t === "hd-model" || t === "hd";
}

export type HdFormState = {
  tab?: string;
  hdPresent?: boolean;
  privacy?: string;
  geoOpen?: boolean;
  settingsApplied?: boolean;
  ultra?: boolean;
  aiComplete?: boolean;
  texture?: boolean;
  textureQuality?: string;
  availableTextureQualities?: string[];
  pbr?: boolean;
  topology?: string;
  facesVal?: number | null;
  slider?: number | null;
};

export type HdFormAction =
  | "click_hd"
  | "set_privacy"
  | "open_geo_texture"
  | "watch_geo"
  | "set_ultra"
  | "set_ai_complete"
  | "set_texture"
  | "set_texture_quality"
  | "set_pbr"
  | "set_topology"
  | "type_faces"
  | "close_geo"
  | "done";

const privacyLabel: Record<string, string> = {
  private: "Private",
  public: "Public",
  sharing: "Sharing Only",
};

/** After upload Studio often parks a draft task on the URL. That is not a reason to skip Generate. Re-export (`--task-id`) never clicks Generate. */
export function shouldClickGenerate(
  snap: { exportN?: number },
  ctx: { taskIdArg: string; generateClicked: boolean; hasGenerateButton: boolean; stopBeforeGenerate?: boolean },
): boolean {
  if (ctx.taskIdArg) return false;
  if (ctx.stopBeforeGenerate) return false;
  if (ctx.generateClicked) return false;
  if (snap.exportN) return false;
  return ctx.hasGenerateButton;
}

export function decideHdForm(state: HdFormState, want: StudioRequest): HdFormAction {
  const wantPriv = privacyLabel[want.privacy] || want.privacy;
  const tabIsHd = isHdStoreTab(String(state.tab || ""));
  if (!tabIsHd) return "click_hd";
  if (state.privacy && state.privacy !== wantPriv) return "set_privacy";
  if (state.settingsApplied) return "done";
  if (!state.geoOpen) return "open_geo_texture";
  if ([state.ultra, state.aiComplete, state.texture, state.pbr].some((v) => v === undefined)) {
    return "watch_geo";
  }
  if (state.ultra !== want.ultraMesh) return "set_ultra";
  if (state.aiComplete !== want.aiComplete) return "set_ai_complete";
  if (state.texture !== want.texture) return "set_texture";
  if (want.texture && normalizeTextureQuality(String(state.textureQuality || "")) !==
      hdGenerateTextureQuality(want.textureQuality, state.availableTextureQualities)) {
    return "set_texture_quality";
  }
  if (state.pbr !== want.pbr) return "set_pbr";
  if (normalizeTopology(String(state.topology || "")) !== want.topology) return "set_topology";
  const now = state.slider ?? state.facesVal;
  if (now !== want.faces) return "type_faces";
  if (state.geoOpen) return "close_geo";
  return "done";
}
