let meta = #{
    name: "studio-dcc-map-glb",
    description: "Land one Studio (non-API) ordinary map GLB. Observed flow: .grok/workflows/studio-dcc-map-glb-flow.md. Drivers: tools/studio_image_to_glb.ts then tools/land_map_glb.py",
    when_to_use: "When generating the next shipping map kit module from Studio credits. Scripts drive Chrome for Testing new Headless. Never the Tripo API.",
    phases: [
        #{ title: "Generate", detail: "python3 tools/studio_image_to_glb.py" },
        #{ title: "Land", detail: "python3 tools/land_map_glb.py --gates" },
    ],
};

let status_schema = #{
    "type": "object",
    "required": ["ok", "summary"],
    "properties": #{
        "ok": #{ "type": "boolean" },
        "summary": #{ "type": "string" },
        "glb_path": #{ "type": "string" },
        "dest_path": #{ "type": "string" },
        "credits_after": #{ "type": "integer" },
        "task_id": #{ "type": "string" },
        "land_method": #{ "type": "string" },
    },
};

fn trimmed(s) {
    if type_of(s) != "string" { return ""; }
    s.trim();
    s
}

fn glb_from(r) {
    if r == () { return ""; }
    if r.output == () { return ""; }
    if r.output.glb_path == () { return ""; }
    trimmed(r.output.glb_path)
}

fn is_ok(r) {
    if r == () { return false; }
    if !r.success { return false; }
    if r.output == () { return false; }
    r.output.ok == true
}

let asset_id = "shared-road-slab-b";
if args != () && args.asset_id != () {
    let requested = trimmed(args.asset_id);
    if requested != "" { asset_id = requested; }
}

let dest_path = "assets/art/map/geometry/shared/road-slab-b.glb";
if args != () && args.dest_path != () {
    let requested_dest = trimmed(args.dest_path);
    if requested_dest != "" { dest_path = requested_dest; }
}

let concept_path = "assets/art/map-concepts/" + asset_id + ".jpg";
if args != () && args.concept_path != () {
    let requested_concept = trimmed(args.concept_path);
    if requested_concept != "" { concept_path = requested_concept; }
}

let tmp_glb = "/tmp/glassvow-studio-" + asset_id + ".glb";
let found_glb = "";
if args != () && args.glb_path != () {
    found_glb = trimmed(args.glb_path);
}

phase("Generate");
if found_glb != "" {
    log("skip generate: " + found_glb);
} else {
    let gen_prompt = "";
    gen_prompt += "Repo /Users/jamesto/Coding/glassvow. HARD RULE: no Tripo API. ";
    gen_prompt += "Your only job is to run this exact command with run_terminal_command, cwd the repo root, then return its JSON: ";
    gen_prompt += "python3 tools/studio_image_to_glb.py --image " + concept_path + " --out " + tmp_glb + " --faces 1500 --topology quad --privacy private --model smart-mesh ";
    gen_prompt += "Do not browse yourself. Do not run cookie-import-browser (the script does Chrome --domain if needed). ";
    gen_prompt += "Do not read SKILL.md. Do not grep the repo. Do not install DCC. Do not open Godot. Do not open Safari. ";
    gen_prompt += "If the command prints JSON, copy ok/summary/glb_path/task_id/land_method/credits_after from it. ";
    gen_prompt += "ok=true only if " + tmp_glb + " exists after the command.";

    let gen = agent(gen_prompt, #{
        label: "studio-script",
        capability_mode: "execute",
        output_schema: status_schema,
    });
    if is_ok(gen) {
        found_glb = glb_from(gen);
        if found_glb == "" { found_glb = tmp_glb; }
    }
    if found_glb == "" {
        await_user("user", "studio_smart_mesh.py did not write " + tmp_glb + ". Put a Studio (NOT API) Export GLB there and resume. Do not install DCC.");
        found_glb = tmp_glb;
    }
}

phase("Land");
let land_prompt = "";
land_prompt += "Repo /Users/jamesto/Coding/glassvow. HARD RULE: no Tripo API. Do not generate. ";
land_prompt += "Run this exact command with run_terminal_command, cwd the repo root, then return its JSON: ";
land_prompt += "python3 tools/land_map_glb.py --asset " + asset_id + " --src " + found_glb + " --concept " + concept_path + " --gates ";
if args != () && args.task_id != () {
    let tid = trimmed(args.task_id);
    if tid != "" {
        land_prompt += "--task-id " + tid + " ";
    }
}
land_prompt += "Do not browse. Do not read SKILL.md. Do not rewrite other provenance records by hand. ";
land_prompt += "ok=true only if the command's JSON has ok true.";

let land = agent(land_prompt, #{
    label: "land-script",
    capability_mode: "execute",
    output_schema: status_schema,
});

let report = "";
report += "# studio-dcc-map-glb\n\n";
report += "asset_id: " + asset_id + "\n";
report += "concept: " + concept_path + "\n";
report += "dest: " + dest_path + "\n";
report += "source: " + found_glb + "\n";
report += "driver: tools/studio_smart_mesh.py + tools/land_map_glb.py\n";
if land != () && land.output != () {
    report += "land: " + trimmed(land.output.summary) + "\n";
}
let report_path = write_scratch_file("report.md", report);
if !is_ok(land) {
    complete(#{
        ok: false,
        summary: "land_map_glb.py failed. Not pausing.",
        asset_id: asset_id,
        dest_path: dest_path,
        path: report_path,
    });
}
complete(#{
    ok: true,
    summary: "Studio (non-API) map GLB landed via scripts",
    asset_id: asset_id,
    dest_path: dest_path,
    path: report_path,
});
