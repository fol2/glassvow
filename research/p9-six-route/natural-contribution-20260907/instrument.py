from pathlib import Path
import hashlib
R=Path(__file__).resolve().parent
p=R/'study/project/lab_runner.gd';s=p.read_text()
assert 'causal_probe.gd' not in s
s=s.replace('extends SceneTree\n','extends SceneTree\nconst CausalProbe: GDScript=preload("res://causal_probe.gd")\n',1)
s=s.replace('var fight_mechanism: Dictionary={}\n','var fight_mechanism: Dictionary={}\nvar causal_samples: Array=[]\nvar probe_seen: Dictionary={}\nvar probe_failed: bool=false\n',1)
s=s.replace(' var before: Dictionary=HealthAccounting.snapshot(g.cb)\n var events: Array[Dictionary]=g.apply(command)', ''' var captured: Dictionary={}
 if cfg.get("causal_probe",false) and str(command.get("t",""))=="playCard":
  var kind: String=CausalProbe.role(g,command)
  if not kind.is_empty():
   var value: int=CausalProbe.mediator(g,command,kind)
   measure("probe_eligible:"+kind)
   var key: String=kind+(":positive" if value>0 else ":zero")
   if not probe_seen.has(key):
    captured=CausalProbe.sample(g,command)
    if not captured.get("ok",false):
     probe_failed=true;push_error("LAB_CAUSAL_CAPTURE "+str(captured.get("reason")));return []
    captured.record["fight"]=fights.size()
    causal_samples.append(captured.record);probe_seen[key]=true
 var before: Dictionary=HealthAccounting.snapshot(g.cb)
 var events: Array[Dictionary]=g.apply(command)
 if not captured.is_empty() and not CausalProbe.verify_factual(g,events,captured):
  probe_failed=true;push_error("LAB_CAUSAL_FACTUAL_MISMATCH")''',1)
s=s.replace(' played={};offered={};picked={};fights=[];action_diagnostics=[];mechanism={}\n',' played={};offered={};picked={};fights=[];action_diagnostics=[];mechanism={}\n causal_samples=[];probe_failed=false\n',1)
s=s.replace('"mechanism":mechanism}\n','"mechanism":mechanism,"causal_samples":causal_samples}\n',1)
s=s.replace(' fight_mechanism={}\n',' fight_mechanism={};probe_seen={}\n',1)
s=s.replace('   var events: Array[Dictionary]=observed_apply(g,action,cast_id if cast_id!="" else str(action["t"]))\n','   var events: Array[Dictionary]=observed_apply(g,action,cast_id if cast_id!="" else str(action["t"]))\n   if probe_failed:return "error"\n',1)
p.write_text(s)
print('INSTRUMENTED',hashlib.sha256(p.read_bytes()).hexdigest())
