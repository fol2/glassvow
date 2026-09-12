let meta = #{
    name: "first-paid-map-glb",
    description: "Land the first paid Studio (non-API) ordinary map GLB and the production-camera silhouette raster gate for #292",
    when_to_use: "When generating the first shipping map kit module from Studio credits, never the Tripo API",
    phases: [
        #{ title: "Preflight", detail: "paid Studio, no API, concept on disk" },
        #{ title: "Studio", detail: "image-to-3D on studio.tripo3d.ai using monthly credits" },
        #{ title: "Land", detail: "GLB, provenance, GPU silhouette gate, 20-placement" },
        #{ title: "Verify", detail: "import, scripts, suite, map-asset gates" },
    ],
};

let status_schema = #{
    "type": "object",
    "required": ["ok", "summary"],
    "properties": #{
        "ok": #{ "type": "boolean" },
        "summary": #{ "type": "string" },
        "glb_path": #{ "type": "string" },
        "credits_after": #{ "type": "integer" },
        "task_id": #{ "type": "string" },
        "report_path": #{ "type": "string" },
    },
};

fn trimmed(s) {
    if type_of(s) != "string" { return ""; }
    s.trim();
    s
}

fn as_bool(x) {
    if x == () { return false; }
    if type_of(x) == "bool" { return x; }
    false
}

let asset_id = "shared-road-slab-a";
if args != () && args.asset_id != () {
    asset_id = trimmed(args.asset_id);
    if asset_id == "" { asset_id = "shared-road-slab-a"; }
}

let concept_path = "assets/art/map-concepts/shared-road-slab-a.jpg";
if args != () && args.concept_path != () {
    let requested = trimmed(args.concept_path);
    if requested != "" { concept_path = requested; }
}

phase("Preflight");
let pre_prompt = "";
pre_prompt += "Repo: /Users/jamesto/Coding/glassvow. Ticket: GitHub fol2/glassvow #292 ";
pre_prompt += "(First paid map GLB and production-camera silhouette raster gate). ";
pre_prompt += "HARD RULE: do not call the Tripo API. Forbidden hosts: openapi.tripo3d.ai, ";
pre_prompt += "platform.tripo3d.ai generation endpoints, any curl/http to /v2/openapi or /v3/generation. ";
pre_prompt += "Generation surface is Tripo Studio only (studio.tripo3d.ai), using the paid Pro 3000 monthly credits. ";
pre_prompt += "Read assets/art/map/provenance.json paid_product. Confirm api_forbidden is true, product is Studio, tier is Pro. ";
pre_prompt += "Confirm this concept file exists and hash it: " + concept_path + ". ";
pre_prompt += "Confirm godot --version prints 4.7.2.stable. ";
pre_prompt += "Do not generate a mesh. Do not edit shipping GLBs. ";
pre_prompt += "Return ok=true only if paid Studio evidence, concept file, and Godot pin are all present. ";
pre_prompt += "summary must name the concept sha256 and the paid_product.plan_expires value.";

let pre = agent(pre_prompt, #{
    label: "preflight",
    capability_mode: "read-only",
    output_schema: status_schema,
});
if pre == () || !pre.success {
    pause("verification", "Preflight agent failed. Fix paid Studio evidence, concept path, or Godot pin, then resume.");
}
if pre.output != () && pre.output.ok == false {
    pause("verification", "Preflight returned ok=false. Fix paid Studio evidence, concept path, or Godot pin, then resume.");
}

phase("Studio");
let studio_prompt = "";
studio_prompt += "HARD RULE: do not use the Tripo API. No requests to openapi.tripo3d.ai or ";
studio_prompt += "platform.tripo3d.ai generation. If you are about to write an Authorization Bearer ";
studio_prompt += "call to those hosts, stop and set ok=false. ";
studio_prompt += "Generate ONE ordinary kit module in the headed GStack browser already running. ";
studio_prompt += "Browse binary: /Users/jamesto/.codex/skills/gstack/browse/dist/browse (also try ";
studio_prompt += "$HOME/.claude/skills/gstack/browse/dist/browse). Run status first. Do not kill ";
studio_prompt += "the daemon, do not disconnect, do not browse connect (it is already headed). ";
studio_prompt += "Asset id: " + asset_id + ". Concept: " + concept_path + " (absolute under repo root). ";
studio_prompt += "Go to https://studio.tripo3d.ai . Confirm header credits are 3000+ (Pro). ";
studio_prompt += "Open image-to-3D / Smart Mesh (P1 / P2 preview is OK if it is the Studio Smart Mesh control). ";
studio_prompt += "Upload the concept. Settings: face/poly target 1500, texture OFF, PBR OFF, no quad/FBX, no rig, no animation. ";
studio_prompt += "Generate. When done, download the GLB to /tmp/glassvow-studio-" + asset_id + ".glb ";
studio_prompt += "and copy it to /tmp/glassvow-studio-" + asset_id + "-source.glb. ";
studio_prompt += "Record credits remaining after the charge, and any Studio task/model id shown in the UI. ";
studio_prompt += "Do not publish to the community. Do not enable texture. Do not use Free leftover as the justification. ";
studio_prompt += "Return ok=true only if a GLB file exists on disk, credits dropped, and you never hit the API. ";
studio_prompt += "Put the GLB path in glb_path, credits remaining in credits_after, Studio id in task_id.";

let studio = agent(studio_prompt, #{
    label: "studio-generate",
    capability_mode: "all",
    output_schema: status_schema,
});
if studio == () || !studio.success {
    await_user("user", "Studio generate agent failed. Finish image-to-3D in the headed browser (NOT the API), save /tmp/glassvow-studio-" + asset_id + ".glb, then resume.");
}
if studio.output != () && studio.output.ok == false {
    await_user("user", "Studio generate did not land a GLB. Finish image-to-3D in the headed browser (NOT the API), save /tmp/glassvow-studio-" + asset_id + ".glb, then resume.");
}

phase("Land");
let land_prompt = "";
land_prompt += "Repo: /Users/jamesto/Coding/glassvow. Load .claude/skills/glassvow-godot/SKILL.md and follow it. ";
land_prompt += "HARD RULE: do not call the Tripo API. Do not regenerate. Use the Studio GLB already on disk. ";
land_prompt += "Asset: " + asset_id + " -> assets/art/map/geometry/shared/road-slab-a.glb. ";
land_prompt += "Source GLB is /tmp/glassvow-studio-" + asset_id + ".glb or the glb_path from the previous agent. ";
land_prompt += "Ordinary contract (docs/map-scene-asset-bill.md): 600-2500 triangles, target 1500 faces, ";
land_prompt += "GLB <=192 KiB, one mesh, one surface, normals, no animation/skeleton/texture/required UV/tangent, ";
land_prompt += "pivot on ground contact, Y-up, metres, no hidden islands. ";
land_prompt += "If Blender is on PATH, clean: join to one mesh, remove internals, origin to ground contact, ";
land_prompt += "apply scale, export untextured triangulated GLB. If Blender is missing, document the skip and ";
land_prompt += "keep the Studio download only if it already meets the contract. ";
land_prompt += "Write an accepted provenance record in assets/art/map/provenance.json for this asset_id. ";
land_prompt += "source must say Studio (not API). Include task id, model shown in UI, face limit 1500, ";
land_prompt += "texture=false, pbr=false, concept path, concept sha256, source_sha256, final_sha256, edits, ";
land_prompt += "reviewer fol2, verdict accepted only if gates pass. Keep paid_product.api_forbidden true. ";
land_prompt += "Implement the missing GPU silhouette raster gate required by #292: ";
land_prompt += "Godot 4.7.2 harness imports the GLB, renders alpha masks at MapCameraRig.TILT_DEGREES, ";
land_prompt += "widest zoom stop 28, eight Y rotations at 45 degrees, intended world scale, transparent target. ";
land_prompt += "Feed each mask through the existing silhouette-noise definition; fail above 0.04. ";
land_prompt += "Replace the SKIP in tools/map_asset_checks.py / tools/check_map_assets.py. ";
land_prompt += "Add the deterministic 20-placement capture required by docs/map-scene-asset-bill.md. ";
land_prompt += "Wire the module through the #291 active-act lazy binding if that path already exists; ";
land_prompt += "do not invent a second loader. Do not touch domain/. ";
land_prompt += "Stage new .gd files before running tools/check_scripts.sh. ";
land_prompt += "Return ok=true only if the GLB is in the declared path, provenance accepted, and the ";
land_prompt += "silhouette gate is implemented (not a SKIP). summary must list files changed.";

let land = agent(land_prompt, #{
    label: "land-gate",
    capability_mode: "all",
    output_schema: status_schema,
});
if land == () || !land.success {
    pause("verification", "Land/gate agent failed. Inspect the GLB and silhouette harness, then resume or rerun.");
}
if land.output != () && land.output.ok == false {
    pause("verification", "Land/gate returned ok=false. Inspect the GLB and silhouette harness, then resume or rerun.");
}

phase("Verify");
let verify_prompt = "";
verify_prompt += "Repo: /Users/jamesto/Coding/glassvow. HARD RULE: no Tripo API. ";
verify_prompt += "Run from repo root, in order: godot --version (must be 4.7.2.stable); ";
verify_prompt += "tools/check_imports.sh; tools/check_scripts.sh; ";
verify_prompt += "godot --headless -s res://tests/run_all.gd (grade by exit 0 and PASS line); ";
verify_prompt += "python3 tools/check_map_assets.py ; python3 tools/check_map_assets.py --self-test. ";
verify_prompt += "gpu-silhouette must no longer print SKIP for " + asset_id + ". ";
verify_prompt += "Also python3 tools/check_anchors.py and python3 tools/check_benchmark_freeze.py. ";
verify_prompt += "Return ok=true only if every command exits 0. summary must quote the PASS line and map-assets OK line.";

let verify = agent(verify_prompt, #{
    label: "verify-gates",
    capability_mode: "execute",
    output_schema: status_schema,
});
if verify == () || !verify.success {
    pause("verification", "Verification agent failed. Do not claim #292 done. Fix and resume.");
}
if verify.output != () && verify.output.ok == false {
    pause("verification", "Verification returned ok=false. Do not claim #292 done. Fix and resume.");
}

let report = "";
report += "# first-paid-map-glb\n\n";
report += "asset_id: " + asset_id + "\n";
report += "concept: " + concept_path + "\n";
report += "surface: Studio (API forbidden)\n";
if verify != () && verify.output != () {
    report += "verify: " + trimmed(verify.output.summary) + "\n";
}
let report_path = write_scratch_file("report.md", report);
complete(#{
    summary: "First Studio (non-API) map GLB landed and verified",
    asset_id: asset_id,
    path: report_path,
});
