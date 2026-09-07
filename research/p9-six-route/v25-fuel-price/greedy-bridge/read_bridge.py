"""Paired cost/competence readout. Not a non-inferiority test or acceptance replacement."""
from pathlib import Path
import importlib.util,sys,json,hashlib
import numpy as np

def read(native_folder,cheap_folder,auditor_path):
 spec=importlib.util.spec_from_file_location('bridge_auditor',auditor_path);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
 nf,cf=Path(native_folder),Path(cheap_folder)
 na,nr=mod.audit(nf);ca,cr=mod.audit(cf)
 nfreeze=json.loads((nf/'freeze.json').read_text());cfreeze=json.loads((cf/'freeze.json').read_text())
 assert nfreeze['observer']['sources']==cfreeze['observer']['sources']
 assert nfreeze['observer']['engine']==cfreeze['observer']['engine']
 ns={x['id']:x for x in nfreeze['specs']};cs={x['id']:x for x in cfreeze['specs']}
 assert ns.keys()==cs.keys();nc={x['id']:x for x in na['cells']};cc={x['id']:x for x in ca['cells']}
 rng=np.random.default_rng(76039);cells=[];groups={False:[],True:[]}
 for key in ns:
  a,b=ns[key],cs[key];allowed=dict(a);allowed['params']=dict(a['params'],native_rollout=False)
  assert allowed==b and a['params']['native_rollout'] is True
  assert [x['seed'] for x in nr[key]]==[x['seed'] for x in cr[key]]
  d=np.array([int(y['result']=='win')-int(x['result']=='win') for x,y in zip(nr[key],cr[key])],float)
  groups[a['random_build']].append(d)
  cells.append({'id':key,'aspect':a['aspect'],'vow':a['vow'],'route':a['route'],'random_build':a['random_build'],'n':len(d),'native_wins':nc[key]['wins'],'greedy_wins':cc[key]['wins'],'improved':int((d==1).sum()),'worsened':int((d==-1).sum()),'change':float(d.mean()),'native_seconds':nc[key]['seconds'],'greedy_seconds':cc[key]['seconds']})
 aggregate={}
 for label,ds in groups.items():
  x=np.mean(ds,axis=0);samp=x[rng.integers(0,len(x),size=(10000,len(x)))].mean(axis=1)
  subset=[x for x in cells if x['random_build']==label]
  aggregate['random_build' if label else 'planned']={'shared_seed_clusters':len(x),'mean_win_change':float(x.mean()),'nominal_cluster_bootstrap95':np.quantile(samp,[.025,.975]).tolist(),'summed_native_seconds':sum(x['native_seconds'] for x in subset),'summed_greedy_seconds':sum(x['greedy_seconds'] for x in subset)}
 report={'status':'PAIRED_EXPLORATORY_CONTROLLER_BRIDGE_NOT_P9','new_greedy_rows':ca['rows'],'reused_native_rows':na['rows'],'counts':{'native':na['counts'],'greedy':ca['counts']},'source_equal':True,'native_freeze':na['freeze_sha256'],'greedy_freeze':ca['freeze_sha256'],'cells':cells,'aggregate':aggregate,'limitations':['The same32 clusters are reused, not4096 independent samples.','Different run lengths and interleaved CPU scheduling affect summed elapsed times.','No non-inferiority or optimality is inferred; signed control arms are not replaced.','No policy/content selection on partial output or P9 certificate.']}
 (cf/'readout.json').write_text(json.dumps(report,indent=2)+'\n')
 print(report['status']);print(json.dumps(aggregate,indent=2));return report
if __name__=='__main__':read(*sys.argv[1:])
