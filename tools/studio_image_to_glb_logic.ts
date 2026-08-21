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
};

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
