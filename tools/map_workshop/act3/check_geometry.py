"""Check actual crossing headroom and terrain against rendered treads, headlessly."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = '''extends SceneTree
const Probe = preload("res://tools/map_workshop/common/mesh_probe.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act3-seed717.json"))
	var routes: Node3D = preload("res://tools/map_workshop/act3/routes.gd").new()
	routes.levels = preload("res://tools/map_workshop/common/terrace_levels.gd").new()
	routes.ruin_plan = preload("res://tools/map_workshop/act3/destination.gd").new()
	routes.bridge_style = preload("res://tools/map_workshop/stone_bridge/presets.gd").drowned_city()
	routes.bridge_style["water_level"] = -10.0
	routes.bridge_style["foundation_level"] = -1.8
	routes.material_factory = func(settings: Dictionary) -> Dictionary: return preload("res://tools/map_workshop/act3/materials.gd").bridge(settings)
	root.add_child(routes)
	routes.build(sample)
	if not routes.failure.is_empty():
		push_error(routes.failure)
		quit(1)
		return
	var ground: Node3D = preload("res://tools/map_workshop/act3/ground.gd").new()
	root.add_child(ground)
	ground.build(routes)
	var floor_probe: Probe = Probe.new()
	for mesh: Mesh in routes.deck_meshes:
		floor_probe.build(mesh)
	var ground_probe: Probe = Probe.new()
	for child: Node in ground.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			ground_probe.build(mesh.mesh)
	var corridors: Dictionary = routes.sampled_routes.duplicate()
	var links: Dictionary = routes.ruin_links
	corridors.merge(links)
	var tested: int = 0
	var hits: int = 0
	var examples: Array[Dictionary] = []
	var worst: float = -INF
	for key: String in corridors:
		var line: PackedVector3Array = corridors[key]
		for i: int in range(line.size()):
			var p: Vector3 = line[i]
			var direction: Vector3 = line[mini(i+1,line.size()-1)]-line[maxi(i-1,0)]
			var side: Vector2 = Vector2(-direction.z,direction.x).normalized()
			for offset: float in [-.6,-.3,0,.3,.6]:
				var at: Vector2 = Vector2(p.x,p.z)+side*offset
				var nearest: float = INF
				var floor_height: float = -INF
				for height: float in floor_probe.heights(at):
					if absf(height-p.y-.022)<nearest:
						nearest = absf(height-p.y-.022)
						floor_height = height
				for height: float in ground_probe.heights(at):
					tested += 1
					worst = maxf(worst,height-floor_height)
					if height>floor_height+.005:
						hits += 1
						if examples.size()<12:
							examples.append({"edge":key,"at":[at.x,at.y],"terrain":height,"deck":floor_height})
	var result: Dictionary = {"court_structure":preload("res://tools/map_workshop/act2/bridge_walkway_audit.gd").measure(routes),"crossings":preload("res://tools/map_workshop/act2/audit.gd")._width(routes),"joints":preload("res://tools/map_workshop/act2/audit.gd")._joints(routes),"terrain_vs_treads":{"samples":tested,"hits":hits,"maximum_terrain_above_deck":worst,"examples":examples}}
	print("ACT_III_SUPPLEMENTAL_GEOMETRY ",JSON.stringify(result))
	quit()
'''


def check(prefix):
    dest = ROOT / 'docs/map/studies/act3-step3'
    with tempfile.TemporaryDirectory(prefix='act3-check-') as folder:
        script = Path(folder) / 'check.gd'
        script.write_text(SCRIPT)
        run = subprocess.run(['godot', '--headless', '--path', str(ROOT), '-s', str(script),
                              '--', '--profile=res://docs/map/studies/act3-step3/profile.json'],
                             cwd=ROOT, capture_output=True, text=True, timeout=240)
    log = run.stdout + run.stderr
    (dest / f'{prefix}-supplemental.log').write_text(log)
    if run.returncode or 'SCRIPT ERROR' in log or '\nERROR:' in log:
        raise RuntimeError('Supplemental geometry execution failed')
    lines = [line.split('ACT_III_SUPPLEMENTAL_GEOMETRY ', 1)[1] for line in log.splitlines()
             if line.startswith('ACT_III_SUPPLEMENTAL_GEOMETRY ')]
    assert len(lines) == 1
    result = json.loads(lines[0])
    (dest / f'{prefix}-supplemental.json').write_text(json.dumps(result, indent=2)+'\n')
    assert result['court_structure']['decoration_hits'] == 0, result['court_structure']
    assert result['crossings']['sample_count'] > 0 and not result['crossings']['failures']
    assert result['joints']['maximum_surface_separation'] < .001
    assert result['terrain_vs_treads']['samples'] > 0 and result['terrain_vs_treads']['hits'] == 0
    print('PASS: crossing width, bridgehead joins and terrain versus actual treads', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', required=True)
    check(parser.parse_args().prefix)
