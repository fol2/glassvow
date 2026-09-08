"""Assemble the already-preregistered original-arm diagnostic in isolation."""
from pathlib import Path
import json,hashlib,shutil,subprocess,os
R=Path(__file__).resolve().parent;S=Path('/mnt/data/p9-source');W=R/'original-arms'
assert not W.exists();W.mkdir()
protocol=S/'research/p9-six-route/natural-contribution-20260907/original-arms/PROTOCOL.json'
shutil.copyfile(protocol,W/'PROTOCOL.json');cfg=json.loads(protocol.read_text())
for label,source in [('candidate-project',R/'study/project'),('reference-project',S)]:
    p=W/label;p.mkdir()
    for part in ('domain','content'):shutil.copytree(source/part,p/part)
    shutil.copyfile(R/'study/project/project.godot',p/'project.godot')
    (p/'tools').mkdir()
    for name,h in cfg['sources'].items():
        b=(S/'tools'/name).read_bytes();assert hashlib.sha256(b).hexdigest()==h
        (p/'tools'/name).write_bytes(b)
    shutil.copyfile(S/'tools/balance_sweep.gd',p/'tools/balance_sweep.gd')
    (p/'arms_runner.gd').write_text('''extends SceneTree
const Sim: GDScript=preload("res://tools/balance_sim.gd")
const Policy: GDScript=preload("res://tools/balance_policy.gd")
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=2:
  push_error("ARM_CFG: expected config and output");quit(2);return
 var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if typeof(parsed)!=TYPE_DICTIONARY:
  push_error("ARM_CFG: invalid JSON");quit(2);return
 var cfg: Dictionary=parsed
 var content: ContentDB=BalanceCatalogue.load_prepared({"path":cfg["content_path"]})
 if content==null:
  push_error("ARM_CFG: content load");quit(2);return
 var output: FileAccess=FileAccess.open(args[1],FileAccess.WRITE)
 if output==null:
  push_error("ARM_CFG: output unavailable");quit(2);return
 var hashes: Dictionary={}
 for name: String in ["balance_catalogue.gd","balance_metrics.gd","balance_pilot.gd","balance_policy.gd","balance_sim.gd","vow_incentives.gd"]:
  hashes[name]=FileAccess.get_sha256("res://tools/"+name)
 output.store_line(JSON.stringify({"config":cfg,"engine":Engine.get_version_info()["string"],"content_sha256":FileAccess.get_sha256(str(cfg["content_path"])),"sources":hashes,"policy":Policy.resolve({}),"driver_sha256":FileAccess.get_sha256("res://arms_runner.gd")}))
 output.flush()
 var arm: int=int(cfg["arm"])
 for offset: int in range(int(cfg["runs"])):
  var row: Dictionary=Sim.simulate(content,str(cfg["aspect"]),int(cfg["seed0"])+offset,int(cfg["vow"]),PackedStringArray(),{},arm==2 or arm==4,arm==3 or arm==4)
  row["arm"]=arm
  output.store_line(JSON.stringify(row));output.flush()
 output.close();quit(0)
''')
    engine=R/'engine/Godot_v4.7.2-stable_linux.x86_64'
    with (W/(label+'-import.log')).open('wb') as f:
        q=subprocess.run([str(engine),'--headless','--path',str(p),'--editor','--import'],stdout=f,stderr=subprocess.STDOUT,timeout=60,env={**os.environ,'GODOT_SILENCE_ROOT_WARNING':'1'})
    text=(W/(label+'-import.log')).read_text();assert q.returncode==0 and 'SCRIPT ERROR' not in text and 'Parse Error' not in text,text[-3000:]
print('ORIGINAL_ARM_PROJECTS_READY')
