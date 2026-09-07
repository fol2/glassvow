"""Reassemble published layers; verify exact bytes instead of inventing recovered state."""
from pathlib import Path
from zipfile import ZipFile
import hashlib, shutil, subprocess, importlib.util, json
R=Path(__file__).resolve().parent; S=R/'snapshot'; H=S/'research/p9-six-route'; W=R/'study'; P=W/'project'
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def copy(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
def patch(src):
 cp=subprocess.run(['patch','--batch','--forward','--fuzz=0','-p1','-i',str(src)],cwd=P,text=True,capture_output=True)
 if cp.returncode:raise RuntimeError(str(src)+'\n'+cp.stdout+cp.stderr)
 print(cp.stdout.strip())
def load(path,name):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
if (W/'studies').exists() and any((W/'studies').glob('*/freeze.json')):
 raise RuntimeError('Refusing to reassemble a project with frozen studies; use a new output directory.')
W.mkdir(exist_ok=True);(W/'content').mkdir(exist_ok=True)
# Always restore the immutable v5 basis before layering; no scientific output is overwritten.
archive=Path('/mnt/data/glassvow-p9-native-continuation-20260905.zip')
assert digest(archive)=='76041bfc907164e0c5b5252d48c4bb0aac7b29223a011eee9f03fef17f180e65'
with ZipFile(archive) as z:
 prefix='p9_continue_20260905/project_v5/'
 for name in z.namelist():
  if name.startswith(prefix) and not name.endswith('/'):
   dest=P/name[len(prefix):];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(name))
# Domain/content bytes are refreshed from exact product snapshot.
for n in ['domain','content']:
 shutil.copytree(S/n,P/n,dirs_exist_ok=True)
legacy=P/'lab_policy.gd'
copy(legacy,P/'legacy_policy.gd')
for src,dst in [
 ('v8/project/lab_policy.gd','policy_v8.gd'),('v9/project/lab_policy.gd','policy_buggy_v9.gd'),
 ('v18/project/greedy_policy.gd','additive_policy.gd'),('v19/recovery/greedy_stock.gd','greedy_stock.gd'),
 ('v19/fuel/recovery/greedy_policy.gd','greedy_policy.gd'),('v13/project/lab_policy.gd','rollout_policy.gd'),
 ('v15/public_rollout.gd','public_rollout.gd'),('v17/tactical/terminal_extension.gd','lab_policy.gd'),
 ('v16/recovery/health_accounting.gd','health_accounting.gd'),
 ('v14/test_public_rollout.gd','test_public_rollout.gd'),('v19/recovery/test_stock_ramp.gd','test_stock_ramp.gd'),
 ('v19/fuel/recovery/test_fuel.gd','test_fuel.gd')]: copy(H/src,P/dst)
for n in ['v7/resource-reserve-experiment.patch','v17/banklight/native.patch','v19/native-ramp.patch','v19/fuel/native-fuel.patch','v16/recovery/runner-health.patch']:
 patch(H/n)
# Published terminal-health patch has absent trailing-context blank in the file.
# Apply the two exact substitutions, asserting uniqueness.
p=P/'lab_policy.gd';t=p.read_text()
for old,new in [
 ('"value":1000000.0+10.0*model.cb.player.hp','"value":1000000.0+10.0*model.run.player.hp'),
 (' if g.cb.over or not params.get("leaf_terminal",false):return super.future_value(g)',
  ' if g.cb.over:\n  return 1000000.0+10.0*g.run.player.hp if g.cb.result=="win" and g.run.player.hp>0 else -1000000.0\n if not params.get("leaf_terminal",false):return super.future_value(g)')]:
 assert t.count(old)==1,old;t=t.replace(old,new)
p.write_text(t)
# Memo reuse targets rollout_policy rather than top wrapper in assembled chain.
t=(P/'rollout_policy.gd').read_text();old=' for action: Dictionary in candidates:\n';assert t.count(old)==1
new=' var driver: RefCounted=Greedy.new();driver.route=route;driver.params=params.duplicate()\n'+old
t=t.replace(old,new).replace('   var driver: RefCounted=Greedy.new();driver.route=route;driver.params=params.duplicate()','   driver._turn_key="";driver._draw_seen.clear();driver.repeat_draw_avoided=0')
(P/'rollout_policy.gd').write_text(t)
# Optional affine catalyst handler defaults to zero; no supplied recipe here uses nonzero bonus.
p=P/'domain/rules/combat.gd';t=p.read_text();old='_sget(target.statuses, "poison") * (_ji(fx["n"]) - 1)'
if old in t:t=t.replace(old,old+' + _ji(fx.get("bonus", 0))');p.write_text(t)
# Generate exact known intermediate content, then published additive/ramp/fuel recipes.
v8=load(H/'v8/recipes.py','v8');v8.BASE=W
cs=v8.make();x=json.loads(cs['reserve4_access'].read_text());x['cards']['novaflare']['cost']=1
p=W/'content/fixed.json';p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
expected='de41f69c9cd28cbd09e16880450957b80675f21b53125cd68a42594e41fbf747'
assert digest(p)==expected,('fixed',digest(p))
v18=load(H/'v18/recipes_current.py','v18');v18.R=W;v18.build()
v19=load(H/'v19/recipes.py','v19');v19.R=W/'ramp';v19.R.mkdir(exist_ok=True);v19.build()
copy(H/'v19/fuel/recovery/fuel_recipes.py',W/'fuel_recipes.py');copy(H/'v19/fuel/recovery/capped_recipes.py',W/'capped_recipes.py')
copy(H/'v16/recovery/study_bound.py',W/'study.py')
p=W/'study.py';t=p.read_text().replace("Path('/mnt/data/p9_engine/Godot_v4.7.2-stable_linux.x86_64')", "ROOT.parent/'engine/Godot_v4.7.2-stable_linux.x86_64'");p.write_text(t)
copy(H/'v17/audit_study.py',W/'audit_study.py')
report={'snapshot':'d1d3367ed863728c991b158f07be65d7a66f88f5','files':{str(p.relative_to(W)):digest(p) for p in W.rglob('*') if p.is_file() and '.godot' not in p.parts},'engine_sha256':digest(R/'engine/Godot_v4.7.2-stable_linux.x86_64')}
(W/'ASSEMBLY.json').write_text(json.dumps(report,indent=2)+'\n')
print('ASSEMBLY_OK',len(report['files']))
