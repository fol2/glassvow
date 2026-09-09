"""Conditional delivery correction, before any controller outcome was observed.
Old qualification and terminal remain immutable. Only expected weight conversion
is made consistent with the already-bound pilot _w implementation; no tolerance
is used by the repaired equality test or the scientific decision.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parent


def require(ok,why):
    if not ok:raise ValueError(why)

def sha(b):return hashlib.sha256(b).hexdigest()

def dump(p,x):p.write_text(json.dumps(x,indent=2)+'\n')


def corrected(old):
    replacements={
      'float(policies[pi].status.venomousAsh)':'float(str(policies[pi].status.venomousAsh))',
      'float(policies[pi].card.aspectBonus)':'float(str(policies[pi].card.aspectBonus))'}
    require(old.count(next(iter(replacements)))==1,'SOURCE_WEIGHT_SITE')
    require(old.count('float(policies[pi].card.aspectBonus)')==2,'PARTNER_WEIGHT_SITES')
    result=old
    for a,b in replacements.items():result=result.replace(a,b)
    return result


def run(repo,engine):
    repo,engine=map(lambda p:Path(p).resolve(),(repo,engine))
    p=json.loads((ROOT/'PROTOCOL.json').read_bytes())
    old=ROOT/'execution-1';t=json.loads((old/'TERMINAL.json').read_bytes())
    require(t['status']=='INCONCLUSIVE' and not t['stages'],'NO_NEW_OLD_POPULATION')
    require(not (old/'v5').exists(),'POPULATION_ALREADY_OPENED')
    files={r['path']:r for r in json.loads((old/'FILES.json').read_bytes())}
    raw=(old/'qualification/capability.jsonl').read_bytes();r=files['qualification/capability.jsonl']
    require(len(raw)==r['bytes'] and sha(raw)==r['sha256'],'ORIGINAL_CAPTURE_IDENTITY')
    rows=[json.loads(x) for x in raw.splitlines()];last=rows.pop()
    require(last['kind']=='terminal' and last['checks']==len(rows),'OLD_QUALIFICATION_COVERAGE')
    failed=[r for r in rows if r['okay'] is not True]
    require(failed and len(failed)==last['failures'],'OLD_FAILURE_COUNT')
    require(all(r['kind']=='score' and r['aspect']==1 and r['random_build'] is False and r['card'] in ('bloodRite','leechBlade') for r in failed),'UNEXPLAINED_FAILURE_CLASS')
    # Diagnostic only. The repaired native checks still demand exact equality.
    require(all(abs(r['actual']-r['expected'])<1e-9 for r in failed),'MATERIAL_UNEXPLAINED_DIFFERENCE')
    source=(repo/'tools/balance_pilot.gd').read_bytes()
    require(sha(source)=='4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47','BOUND_PILOT')
    require(b'return float(str(d[key]))' in source,'WEIGHT_CONVERSION_LAW')
    prior_source=(ROOT/'capability.gd').read_bytes()
    require(sha(prior_source)==p['own_sha256']['capability.gd'],'ORIGINAL_QUERY_SOURCE')
    new_source=corrected(prior_source.decode()).encode()
    target=ROOT/'repaired-source-1';repair=ROOT/'repair-1'
    require(not target.exists() and not repair.exists(),'REPAIR_ALREADY_EXISTS')
    target.mkdir();repair.mkdir()
    for name,want in p['own_sha256'].items():
        b=(ROOT/name).read_bytes();require(sha(b)==want,'FROZEN_IMPLEMENTATION:'+name)
        (target/name).write_bytes(new_source if name=='capability.gd' else b)
    amended=json.loads(json.dumps(p));amended['own_sha256']['capability.gd']=sha(new_source)
    same=json.loads(json.dumps(amended));same['own_sha256']['capability.gd']=p['own_sha256']['capability.gd']
    require(same==p,'NON_DELIVERY_CONTRACT_CHANGE')
    dump(target/'PROTOCOL.json',amended)
    diagnosis={'kind':'PREPOPULATION_EXPECTED_WEIGHT_CONVERSION_REPAIR',
      'old_capture_sha256':sha(raw),'old_query_checks':len(rows),'old_failed_checks':len(failed),
      'failure_roles':sorted({r['card'] for r in failed}),
      'maximum_serialized_score_difference':max(abs(r['actual']-r['expected']) for r in failed),
      'old_query_sha256':sha(prior_source),'repaired_query_sha256':sha(new_source),
      'old_protocol_sha256':sha((ROOT/'PROTOCOL.json').read_bytes()),
      'only_contract_identity_change':'own_sha256/capability.gd',
      'controller_source_identical':True,'policy_cohort_seeds_thresholds_identical':True,
      'old_populations_run':0,'old_raw_and_terminal_preserved':True,
      'equality_tolerance_added':False,
      'explanation':'The frozen scorer resolves weights using float(str(value)); the oracle used direct float(value). Only its three expected-weight reads are corrected. Full qualification must pass again before any controller comparison; no outcome or expected sign is overwritten.'}
    dump(repair/'DIAGNOSIS.json',diagnosis)
    # Preserve the executed repaired files and identity delta before all new data.
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo).decode().strip()
    branch='research/p9-six-route-local-20260905'
    remote=subprocess.check_output(['git','ls-remote','origin','refs/heads/'+branch],cwd=repo,timeout=60).decode().split()[0]
    require(remote==head,'CONCURRENT_WRITER')
    subprocess.run(['git','add','-f',str(target.relative_to(repo)),str(repair.relative_to(repo))],cwd=repo,check=True)
    subprocess.run(['git','commit','-m','research(p9): preserve conditional numeric-oracle repair before any population'],cwd=repo,check=True)
    subprocess.run(['git','push','origin','HEAD:refs/heads/'+branch],cwd=repo,check=True,timeout=90)
    newhead=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo).decode().strip()
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+newhead+'\n')
    sys.path.insert(0,str(target))
    spec=importlib.util.spec_from_file_location('repaired_experiment',target/'experiment.py')
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    print(json.dumps(diagnosis,sort_keys=True),flush=True)
    return m.execute(repo,engine,ROOT/'execution-2',Path(os.environ['RUNNER_TEMP'])/'acquisition-repaired',True)

if __name__=='__main__':raise SystemExit(run(*sys.argv[1:]))
