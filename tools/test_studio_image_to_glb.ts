/** Deterministic tests for the warm-Chrome chained --image bug. No network/browser. */
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  BARE_GENERATE_URL, STUDIO, UPLOAD_WATCH_LIMIT_MS,
  blankResetArrived, decideHdForm, generateTargetUrl, generateTaskIdFromHref,
  generateWaitReady, isBareGenerateHref, isPriceAgnosticGenerateLabel,
  isTransientEvaluateError, newImageExportGuard, parseStudioArgv,
  pickVisibleGenerate, planStudioRun, planWarmGeneratePage, quotedCreditsFromGenerateLabel,
  refuseNewImageOnTaskUrl, remainingStudioFeatures, resolveStudioRequest,
  shouldClickGenerate, studioExportFormFields, uploadWatchTimedOut,
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

test("smart-mesh defaults stay image→args→glb and do not spend credits on dry-run", () => {
  const raw = parseStudioArgv([
    "--image", "concept.png", "--out", "/tmp/x.glb", "--dry-run",
  ]);
  const req = resolveStudioRequest(raw);
  expect(req.tab).toBe("smart-mesh");
  expect(req.textured).toBe(false);
  expect(req.texture).toBe(false);
  expect(req.pbr).toBe(false);
  expect(req.faces).toBe(800);
  expect(req.topology).toBe("quad");
  expect(req.privacy).toBe("private");
  expect(req.dryRun).toBe(true);
  expect(req.wouldClickGenerate).toBe(false);
  const plan = planStudioRun(req);
  expect(plan.ok).toBe(true);
  expect(plan.dry_run).toBe(true);
  expect(plan.would_spend_credits).toBe(false);
  expect(plan.tab).toBe("smart-mesh");
  expect(plan.workflow).toEqual(["image", "arguments", "3d-model"]);
});

test("--textured selects HD Model defaults for game-content albedo, not Smart Mesh", () => {
  const req = resolveStudioRequest(parseStudioArgv([
    "--image", "assets/art/map-concepts/act1-vigil-hall.png",
    "--out", "/tmp/vigil.glb",
    "--textured",
    "--dry-run",
  ]));
  expect(req.tab).toBe("hd-model");
  expect(req.textured).toBe(true);
  expect(req.texture).toBe(true);
  expect(req.textureQuality).toBe("2k");
  expect(req.pbr).toBe(false);
  expect(req.ultraMesh).toBe(true);
  expect(req.aiComplete).toBe(false);
  expect(req.faces).toBe(6000);
  expect(req.topology).toBe("triangle");
  const plan = planStudioRun(req);
  expect(plan.tab).toBe("hd-model");
  expect(plan.texture).toBe(true);
  expect(plan.texture_quality).toBe("2k");
  expect(plan.pbr).toBe(false);
  expect(plan.would_spend_credits).toBe(false);
  expect(plan.remaining_studio_features).toEqual(remainingStudioFeatures());
  expect(plan.remaining_studio_features).toContain("rig / animation");
  expect(plan.remaining_studio_features).toContain("Generate Multi-Views");
  expect(plan.remaining_studio_features).toContain("PBR metallic/roughness/normal maps");
  expect(plan.remaining_studio_features).toContain("4K texture (over this repo's hero bytes_max)");
});

test("enriched HD flags and aliases validate, and refuse Smart Mesh + texture", () => {
  const hd = resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--out", "o.glb",
    "--tab", "hd-model",
    "--faces", "5000",
    "--topology", "triangle",
    "--privacy", "private",
    "--texture", "on",
    "--texture-quality", "2k",
    "--pbr", "off",
    "--ultra-mesh", "on",
    "--ai-complete", "off",
    "--smoke-run",
  ]));
  expect(hd.tab).toBe("hd-model");
  expect(hd.faces).toBe(5000);
  expect(hd.smokeRun).toBe(true);
  expect(hd.stopBeforeGenerate).toBe(true);
  expect(hd.wouldClickGenerate).toBe(false);

  const alias = resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--model", "hd-model", "--out", "o.glb",
  ]));
  expect(alias.tab).toBe("hd-model");
  expect(alias.texture).toBe(true);

  expect(() => resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--textured", "--tab", "smart-mesh", "--out", "o.glb",
  ]))).toThrow(/HD Model|hd-model|texture/i);

  expect(() => resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--tab", "smart-mesh", "--texture", "on", "--out", "o.glb",
  ]))).toThrow(/Smart Mesh has no texture/i);

  expect(() => resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--textured", "--pbr", "on", "--texture", "off", "--out", "o.glb",
  ]))).toThrow(/texture/i);

  expect(() => resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--textured", "--faces", "50", "--out", "o.glb",
  ]))).toThrow(/faces/);
  expect(() => resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--pbr", "on", "--out", "o.glb",
  ]))).toThrow(/HD Model only/);
});

test("--task-id export JSON does not invent form state", () => {
  const req = resolveStudioRequest(parseStudioArgv([
    "--task-id", TASK, "--out", "o.glb",
  ]));
  expect(req.wouldClickGenerate).toBe(false);
  expect(studioExportFormFields(req)).toEqual({ form_state: "unset_for_reexport" });
  expect(studioExportFormFields(req)).not.toHaveProperty("texture");
  expect(studioExportFormFields(req)).not.toHaveProperty("faces");
  const live = resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--textured", "--out", "o.glb",
  ]));
  expect(live.wouldClickGenerate).toBe(true);
  expect(studioExportFormFields(live).texture).toBe(true);
  expect(studioExportFormFields(live).faces).toBe(6000);
});

test("Generate still clicks after upload parks a draft task id on the URL", () => {
  const ready = { hasGenerateButton: true, generateClicked: false, taskIdArg: "" };
  expect(shouldClickGenerate({ exportN: 0 }, ready)).toBe(true);
  expect(shouldClickGenerate({ exportN: 1 }, ready)).toBe(false);
  expect(shouldClickGenerate({ exportN: 0 }, { ...ready, generateClicked: true })).toBe(false);
  expect(shouldClickGenerate({ exportN: 0 }, { ...ready, taskIdArg: TASK })).toBe(false);
  expect(shouldClickGenerate({ exportN: 0 }, { ...ready, hasGenerateButton: false })).toBe(false);
  expect(shouldClickGenerate({ exportN: 0 }, { ...ready, stopBeforeGenerate: true })).toBe(false);
});

test("Generate click is price-agnostic and never Multi-Views", () => {
  expect(isPriceAgnosticGenerateLabel("Generate 100 65")).toBe(true);
  expect(isPriceAgnosticGenerateLabel("Generate 40")).toBe(true);
  expect(isPriceAgnosticGenerateLabel("Generate 55")).toBe(true);
  expect(isPriceAgnosticGenerateLabel("Generate")).toBe(false);
  expect(isPriceAgnosticGenerateLabel("Generate Multi-Views")).toBe(false);
  expect(isPriceAgnosticGenerateLabel("Generate Multi Views")).toBe(false);
  expect(isPriceAgnosticGenerateLabel("Export")).toBe(false);
  expect(quotedCreditsFromGenerateLabel("Generate 100 65")).toBe(65);
  expect(quotedCreditsFromGenerateLabel("Generate 40")).toBe(40);
  expect(quotedCreditsFromGenerateLabel("Generate")).toBeNull();
  expect(quotedCreditsFromGenerateLabel("Generate Multi-Views")).toBeNull();
  const picked = pickVisibleGenerate([
    { t: "Generate Multi-Views", vis: true, cx: 10, cy: 10 },
    { t: "Generate 100 65", vis: false, cx: 20, cy: 20 },
    { t: "Generate 40", vis: true, cx: 373, cy: 800 },
  ]);
  expect(picked?.t).toBe("Generate 40");
  expect(quotedCreditsFromGenerateLabel(picked?.t || "")).toBe(40);
});

test("HD form decide: stay on HD, drive Geometry & Texture, then done", () => {
  const want = resolveStudioRequest(parseStudioArgv([
    "--image", "a.png", "--textured", "--out", "o.glb",
  ]));
  expect(decideHdForm({ tab: "low_poly", hdPresent: true }, want)).toBe("click_hd");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Sharing Only",
  }, want)).toBe("set_privacy");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: false,
  }, want)).toBe("open_geo_texture");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: false, aiComplete: false, texture: true, textureQuality: "2k",
    pbr: false, topology: "triangle", facesVal: 6000,
  }, want)).toBe("set_ultra");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: true, aiComplete: true, texture: true, textureQuality: "2k",
    pbr: false, topology: "triangle", facesVal: 6000,
  }, want)).toBe("set_ai_complete");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: true, aiComplete: false, texture: false, textureQuality: "2k",
    pbr: false, topology: "triangle", facesVal: 6000,
  }, want)).toBe("set_texture");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: true, aiComplete: false, texture: true, textureQuality: "4k",
    pbr: false, topology: "triangle", facesVal: 6000,
  }, want)).toBe("set_texture_quality");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: true, aiComplete: false, texture: true, textureQuality: "2K",
    pbr: true, topology: "triangle", facesVal: 6000,
  }, want)).toBe("set_pbr");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: true, aiComplete: false, texture: true, textureQuality: "2k",
    pbr: false, topology: "quad", facesVal: 6000,
  }, want)).toBe("set_topology");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: true, aiComplete: false, texture: true, textureQuality: "2k",
    pbr: false, topology: "triangle", facesVal: 2000000, slider: 2000000,
  }, want)).toBe("type_faces");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: true, aiComplete: false, texture: true, textureQuality: "2k",
    pbr: false, topology: "triangle", facesVal: 6000, slider: 6000,
  }, want)).toBe("close_geo");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: false,
    settingsApplied: true, ultra: true, aiComplete: false, texture: true,
    textureQuality: "2k", pbr: false, topology: "triangle", facesVal: 6000,
  }, want)).toBe("done");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: false,
    settingsApplied: false, ultra: true, aiComplete: false, texture: true,
    textureQuality: "2k", pbr: false, topology: "triangle", facesVal: 2000000,
  }, want)).toBe("open_geo_texture");
  expect(decideHdForm({
    tab: "high_detail", hdPresent: true, privacy: "Private", geoOpen: true,
    ultra: undefined, aiComplete: false, texture: true, textureQuality: "2k",
    pbr: false, topology: "triangle", facesVal: 6000,
  }, want)).toBe("watch_geo");
});

test("driver source: HD textured path, dry-run/smoke-run, price-agnostic Generate", () => {
  expect(DRIVER).toContain("parseStudioArgv");
  expect(DRIVER).toContain("resolveStudioRequest");
  expect(DRIVER).toContain("planStudioRun");
  expect(DRIVER).toContain("decideHdForm");
  expect(DRIVER).toContain("shouldClickGenerate");
  expect(DRIVER).toContain("pickVisibleGenerate");
  expect(DRIVER).toContain("studioExportFormFields");
  expect(DRIVER).toContain("--dry-run");
  expect(DRIVER).toContain("--smoke-run");
  expect(DRIVER).toContain("--textured");
  expect(DRIVER).not.toContain("/Generate\\s*100/");
  expect(DRIVER).toContain("HD Model");
  expect(DRIVER).toContain("Geometry & Texture");
  expect(DRIVER.indexOf("if (dryRun)")).toBeLessThan(DRIVER.indexOf("function findChrome"));
  expect(DRIVER.indexOf("if (!taskId && stopBefore)")).toBeLessThan(DRIVER.indexOf('action === "click_generate"'));
});
