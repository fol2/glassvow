/** Deterministic tests for the warm-Chrome chained --image bug. No network/browser. */
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  BARE_GENERATE_URL, STUDIO, UPLOAD_WATCH_LIMIT_MS,
  blankResetArrived, generateTaskIdFromHref, generateTargetUrl, generateWaitReady,
  isBareGenerateHref, isTransientEvaluateError, newImageExportGuard,
  planWarmGeneratePage, refuseNewImageOnTaskUrl, uploadWatchTimedOut,
} from "./studio_image_to_glb_logic.ts";

const DRIVER = readFileSync(join(dirname(fileURLToPath(import.meta.url)), "studio_image_to_glb.ts"), "utf8");
const TASK = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
const TASK_HREF = `${BARE_GENERATE_URL}/${TASK}`;
const DONE = { href: TASK_HREF, login: false, err: false, smart: true };
const NEW_TASK = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff";

test("URL helpers: exact Studio origin and bare path only", () => {
  const bare = [
    BARE_GENERATE_URL, `${BARE_GENERATE_URL}/`,
    `${BARE_GENERATE_URL}?tab=low_poly`, `${BARE_GENERATE_URL}#x`,
    `${BARE_GENERATE_URL}/?tab=1#h`,
  ];
  for (const h of bare) {
    expect(isBareGenerateHref(h)).toBe(true);
    expect(generateTaskIdFromHref(h)).toBe("");
  }
  expect(isBareGenerateHref(TASK_HREF)).toBe(false);
  expect(generateTaskIdFromHref(TASK_HREF)).toBe(TASK);
  expect(generateTaskIdFromHref(`${TASK_HREF}/?x=1#z`)).toBe(TASK);
  expect(isBareGenerateHref(`${STUDIO}/workspace/history`)).toBe(false);
  expect(generateTaskIdFromHref(`${STUDIO}/workspace/history`)).toBe("");
  expect(isBareGenerateHref("http://studio.tripo3d.ai/workspace/generate")).toBe(false);
  expect(isBareGenerateHref("https://evil.example/workspace/generate")).toBe(false);
  expect(generateTaskIdFromHref(`https://evil.example/workspace/generate/${TASK}`)).toBe("");
});

test("completed task URL: legacy already/wait would accept; new --image must not", () => {
  expect(DONE.smart && /\/workspace\/generate/.test(DONE.href)).toBe(true);
  expect(DONE.smart && !DONE.login && !DONE.err).toBe(true);
  const plan = planWarmGeneratePage(DONE, "");
  expect(plan.reuse).toBe(false);
  expect(plan.resetViaBlank).toBe(true);
  expect(plan.leftoverTaskId).toBe(TASK);
  expect(generateWaitReady(DONE, "", "initial")).toBe(false);
  expect(generateWaitReady(DONE, "", "authed")).toBe(false);
  expect(blankResetArrived(TASK_HREF, TASK)).toBe(false);
  expect(blankResetArrived("about:blank", TASK)).toBe(true);
  expect(blankResetArrived(BARE_GENERATE_URL, TASK)).toBe(true);
});

test("bare generate still reuses; --task-id re-export wait is unchanged", () => {
  const bare = { href: BARE_GENERATE_URL, login: false, err: false, smart: true };
  expect(planWarmGeneratePage(bare, "").reuse).toBe(true);
  expect(generateWaitReady(bare, "", "initial")).toBe(true);
  expect(generateWaitReady(bare, "", "authed")).toBe(true);
  expect(generateWaitReady({ ...bare, href: `${BARE_GENERATE_URL}?tab=low_poly` }, "", "authed")).toBe(true);
  expect(generateWaitReady({ href: TASK_HREF, login: true, err: false, smart: false }, "", "initial")).toBe(true);
  expect(generateWaitReady({ href: TASK_HREF, login: true, err: false, smart: false }, "", "authed")).toBe(false);
  const plan = planWarmGeneratePage(DONE, TASK);
  expect(plan.reuse).toBe(true);
  expect(plan.resetViaBlank).toBe(false);
  expect(generateWaitReady(DONE, TASK, "authed")).toBe(true);
  expect(generateTargetUrl(TASK)).toBe(TASK_HREF);
});

test("fail closed if a prior task id remains when preparing a new image", () => {
  expect(() => refuseNewImageOnTaskUrl(TASK_HREF, "")).toThrow(/prior task still on generate URL/);
  expect(() => refuseNewImageOnTaskUrl(BARE_GENERATE_URL, "")).not.toThrow();
  expect(() => refuseNewImageOnTaskUrl(TASK_HREF, TASK)).not.toThrow();
});

test("upload deadline is overall elapsed time, not reset by action oscillation", () => {
  expect(uploadWatchTimedOut(1170, UPLOAD_WATCH_LIMIT_MS)).toBe(false);
  expect(uploadWatchTimedOut(UPLOAD_WATCH_LIMIT_MS + 1, UPLOAD_WATCH_LIMIT_MS)).toBe(true);
  let t = 0;
  let actionAt = 0;
  let action = "watch_upload";
  let overall = false;
  let perActionFired = false;
  while (t <= 250) {
    if (t - actionAt >= 50) {
      action = action === "watch_upload" ? "set_file" : "watch_upload";
      actionAt = t;
    }
    if (uploadWatchTimedOut(t - actionAt, 200)) perActionFired = true;
    if (uploadWatchTimedOut(t, 200)) { overall = true; break; }
    t += 25;
  }
  expect(action === "watch_upload" || action === "set_file").toBe(true);
  expect(perActionFired).toBe(false);
  expect(overall).toBe(true);
});

test("export guard: leftover GLB/Export without a new Generate is refused", () => {
  const prior = { gltf: { size: 200 }, taskId: TASK, exportN: 1, format: "", glbOption: false };
  expect(prior.gltf && prior.exportN >= 1 ? "done" : "").toBe("done");
  expect(newImageExportGuard(prior, { generateClicked: false, leftoverTaskId: TASK }))
    .toBe("refuse_prior_export");
  expect(newImageExportGuard(
    { gltf: null, taskId: TASK, exportN: 1 },
    { generateClicked: false, leftoverTaskId: TASK },
  )).toBe("refuse_prior_export");
  expect(newImageExportGuard(
    { gltf: { size: 200 }, taskId: TASK },
    { generateClicked: true, leftoverTaskId: TASK },
  )).toBe("refuse_prior_export");
  expect(newImageExportGuard(
    { gltf: { size: 200 }, taskId: NEW_TASK, exportN: 2 },
    { generateClicked: true, leftoverTaskId: TASK },
  )).toBe("accept_gltf");
  expect(newImageExportGuard(
    { gltf: null, taskId: "", exportN: 0, format: "", glbOption: false },
    { generateClicked: false, leftoverTaskId: TASK },
  )).toBe("allow");
  expect(newImageExportGuard(
    { gltf: null, taskId: TASK, exportN: 1 },
    { generateClicked: true, leftoverTaskId: TASK },
  )).toBe("watch_generate");
});

test("driver source: poll blank reset, overall upload deadline, export guard, OpenAPI ban", () => {
  expect(DRIVER).toContain("generateWaitReady");
  expect(DRIVER).toContain("blankResetArrived");
  expect(DRIVER).toContain("newImageExportGuard");
  expect(DRIVER).toContain("isTransientEvaluateError");
  expect(DRIVER).toContain("await sleep(UPLOAD_WATCH_POLL_MS)");
  expect(DRIVER).toContain("uploadStarted");
  expect(DRIVER).not.toContain("usame > 3000");
  expect(DRIVER).not.toContain("Page.loadEventFired");
  const reset = DRIVER.slice(
    DRIVER.indexOf("const plan = planWarmGeneratePage"),
    DRIVER.indexOf('lap("login_ms")'),
  );
  expect(reset).toContain("BLANK_RESET_URL");
  expect(reset).toContain("blankResetArrived");
  expect(reset).not.toContain("reapChrome");
  expect(reset).not.toContain("killChrome");
  expect(DRIVER).toContain("openapi.tripo3d.ai");
  expect(isTransientEvaluateError("Cannot find context with specified id")).toBe(true);
  expect(isTransientEvaluateError(new Error("Execution context was destroyed."))).toBe(true);
  expect(isTransientEvaluateError("cdp timeout DOM.getDocument")).toBe(false);
});
