"""One exact safe-integer refinement of the measured continuation computation.
No new heuristic, samples, scalar or changed CPU acceptance. Base benchmark reused.
"""
from __future__ import annotations
import hashlib,importlib.util,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
BASE=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1/continuation-cache-v1')
EXPECTED={'benchmark.py':'15004a488edcbfd774d15ab6ecb0e26db597dcb9a0e9560be0118f5578d71919',
          'continuation_cache.gd':'df6f1753217b905d1fcc9ec85a078c964b9ea18389fa07d9960208e094955e69',
          'cache_gate.gd':'699d003c82af7382507bfbb6a8a5c7aa175a26c2f50d05fc45748fca37c25eb9'}
FAST='''
## int -> decimal string -> binary64 -> int is identity in this exact range.
## All other Variant cases retain the original conversion, including rounding.
func ji(v: Variant) -> int:
 if typeof(v)==TYPE_INT:
  var integer: int=v
  if integer>=-9007199254740991 and integer<=9007199254740991:
   return integer
 return super.ji(v)
'''
INPUTS=[0,1,-1,42,-42,1000000,-1000000,2147483647,-2147483648,
        9007199254740990,9007199254740991,9007199254740992,9007199254740993,
        -9007199254740991,-9007199254740992,-9007199254740993,
        9223372036854775807,-9223372036854775807,
        0.0,1.0,1.75,-1.75,1e-8,1e8,'42','-1.75','9007199254740993']
GATE=''' var numeric_inputs: Array=INPUT_VALUES
 var unsafe_witnesses: int=0
 for v: Variant in numeric_inputs:
  var expected: int=reference.ji(v)
  var actual: int=memo.ji(v)
  var unbounded: int=int(v) if typeof(v)==TYPE_INT else expected
  if actual!=expected:failures+=1
  if unbounded!=expected:unsafe_witnesses+=1
  out.store_line(JSON.stringify({"kind":"integer_conversion","input":str(v),"type":typeof(v),"expected":expected,"actual":actual,"unbounded":unbounded}))
 if unsafe_witnesses==0:failures+=1
'''

def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def dump(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def base_module(repo):
 for name,digest in EXPECTED.items():require(sha((repo/BASE/name).read_bytes())==digest,'BASE_SOURCE:'+name)
 path=repo/BASE/'benchmark.py';spec=importlib.util.spec_from_file_location('base_benchmark',path)
 m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def build(repo,out):
 repo,out=map(Path,(repo,out));require(not out.exists(),'BOUND_SOURCE_EXISTS');out.mkdir(parents=True)
 base_module(repo)
 memo=(repo/BASE/'continuation_cache.gd').read_text()+FAST
 gate=(repo/BASE/'cache_gate.gd').read_text();anchor=' for i: int in range(24):\n'
 require(gate.count(anchor)==1,'GATE_ANCHOR')
 gate=gate.replace(anchor,GATE.replace('INPUT_VALUES',json.dumps(INPUTS))+anchor,1)
 files={'benchmark.py':(repo/BASE/'benchmark.py').read_bytes(),'continuation_cache.gd':memo.encode(),'cache_gate.gd':gate.encode()}
 for n,b in files.items():(out/n).write_bytes(b)
 p={'kind':'EXACT_SAFE_INTEGER_REFINEMENT_BOUND_SOURCE','source_sha256':{n:sha(b) for n,b in files.items()},
    'benchmark_cpu_ratio_limit':0.85,'old_compute_and_cache_terminals_unchanged':True,'new_independent_samples':0,'p9_certified':False}
 dump(out/'PROTOCOL.json',p);return p

def read(repo,out):
 repo,out=map(Path,(repo,out));m=base_module(repo);result=m.read(repo,out)
 numeric=[json.loads(line) for line in (out/'qualification/cache-lifecycle.jsonl').read_text().splitlines() if json.loads(line).get('kind')=='integer_conversion']
 require(len(numeric)==len(INPUTS),'NUMERIC_COVERAGE')
 require(all(r['expected']==r['actual'] for r in numeric),'EXACT_NUMERIC_IDENTITY')
 witnesses=sum(r['expected']!=r['unbounded'] for r in numeric)
 require(witnesses>0,'UNBOUNDED_CAST_NEGATIVE_MISSING')
 result.update(kind='EXACT_CONTINUATION_SAFE_INTEGER_REFINEMENT',numeric_cases=len(numeric),unguarded_integer_cast_counterexamples=witnesses,
               previous_memo_target_miss_preserved=True,source_reason='Safe TYPE_INT fast path only. Other types and magnitudes call the unchanged conversion.')
 return result

def run(repo,engine,out):
 repo,out=Path(repo).resolve(),Path(out).resolve();m=base_module(repo);m.HERE=HERE/'bound-source'
 p=json.loads((HERE/'PROTOCOL.json').read_bytes())
 require(sha(Path(__file__).read_bytes())==p['source_sha256']['refinement.py'],'OWN_SOURCE')
 require(sha((m.HERE/'PROTOCOL.json').read_bytes())==p['bound_protocol_sha256'],'BOUND_PROTOCOL')
 code=m.run(repo,engine,out)
 if (out/'RESULTS.json').exists():dump(out/'RESULTS.json',read(repo,out))
 return code

if __name__=='__main__':
 if sys.argv[1]=='build':print(json.dumps(build(*sys.argv[2:]),indent=2))
 elif sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:]))
 elif sys.argv[1]=='read':print(json.dumps(read(*sys.argv[2:]),indent=2))
 else:raise SystemExit('build REPO OUTPUT | run REPO ENGINE OUTPUT | read REPO OUTPUT')
