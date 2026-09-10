"""Bind actual inherited forecast calls and close scoped checked Hand evidence.
No game execution, new controller, descriptor admission or population sample.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile

ROOT=Path('research/p9-six-route')
HERE=ROOT/'ash-inheritance-20260909/hand-adaptive-v1'
OUT=HERE/'closure-1'
FLAGS=('hand_preparation_enabled','hand_surge_enabled','hand_phantom_enabled')


def require(ok,why):
    if not ok:raise ValueError(why)


def load(p):return json.loads(p.read_bytes())
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args]).decode().strip()


def source_binding(capture):
    manifest=load(capture/'SOURCE-MANIFEST.json')['qualified'];sources={}
    with tarfile.open(capture/'runtime-source.tar.xz','r:xz') as tf:
        def source(name):
            require(name in manifest and not Path(name).is_absolute() and '..' not in Path(name).parts,'SOURCE_PATH')
            b=tf.extractfile('qualified/'+name).read();record=manifest[name]
            require(len(b)==record['bytes'] and sha(b)==record['sha256'],'SOURCE_IDENTITY:'+name)
            sources[name]={'bytes':len(b),'sha256':sha(b),'git_blob':blob(b),'text':b.decode()}
            return b.decode()
        chain=[];name='lab_policy.gd'
        while name:
            require(name not in chain and len(chain)<8,'INHERITANCE_CYCLE_OR_LIMIT')
            chain.append(name);text=source(name)
            parent=re.search(r'^extends\s+"res://([^\"]+)"',text,re.M)
            name=parent.group(1) if parent else None
        require('rollout_policy.gd' in chain,'ACTUAL_ROLLOUT_PARENT')
        policy='\n'.join(sources[n]['text'] for n in chain)
        imports=re.findall(r'^const\s+(\w+)[^\n]*preload\("res://([^\"]+)"\)',policy,re.M)
        aliases={}
        for alias,path in imports:aliases.setdefault(alias,set()).add(path)
        calls=re.findall(r'(\w+)\.clone_public\(',policy)
        require(calls and all(aliases.get(c)=={'public_rollout.gd'} for c in calls),'ACTUAL_CLONER_BINDING')
        bindings=[path for alias,path in imports if alias in calls]
        require('GlassvowGame.new(' not in policy,'UNREVIEWED_MODEL_ALLOCATION')
        wrapper=source('public_rollout.gd')
        require(all('"'+f+'"' in wrapper for f in FLAGS),'MISSING_HAND_FLAG')
        require(re.search(r'for\s+prop\s*:\s*Dictionary\s+in\s+g\.rules\.get_property_list\(\)',wrapper)
                and re.search(r'if\s+key\s+in\s+SWITCHES\s*:',wrapper),'FLAG_PROPAGATION_BODY')
        base=re.search(r'const Base[^\n]*preload\("res://([^\"]+)"\)',wrapper).group(1)
        source(base)
        require(all(base not in sources[n]['text'] for n in chain),'DIRECT_BASE_BYPASS')
    return {'kind':'ACTUAL_INHERITED_FORECAST_CALL_PATH_BOUND','inheritance_chain':chain,
            'cloner_bindings':bindings,'clone_call_sites':len(calls),
            'all_named_public_clone_call_sites_use_tested_wrapper':True,'sources':sources,
            'scope':'Pinned source composition and already-captured direct clone/mutation proof. Not an independent runtime/source oracle or optimal planner claim.'}


def run(repo,out):
    require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
    root=repo/HERE
    receipt=load(root/'offline-publication-1/REMOTE-READBACK.json')
    require(receipt['all_bytes_equal'] and receipt['full_512_run_fields_reproduced'] and receipt['actual_dispatch_source_reproduced'],'OFFLINE_READBACK')
    for r in receipt['files']:
        p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'INPUT_PATH')
        b=(root/p).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'INPUT_BYTES:'+str(p))
    binding=source_binding(root/'execution-1');save(out/'PLANNER-CALL-PATH.json',binding)
    qualifier=load(root/'reader-repair-1/execution-1/REMOTE-READBACK.json')
    require(qualifier['readout_reproduced'] and qualifier['original_capture_unchanged'],'QUALIFICATION_READBACK')
    fields=load(root/'descriptor-1/RESULTS.json')
    spec=importlib.util.spec_from_file_location('current_hand_closure',root/'close.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.sync(repo)
    state=load(repo/ROOT/'SESSION-STATE.json')
    state['hand_realized_descriptor_fields']['readback']=str((HERE/'offline-publication-1/REMOTE-READBACK.json').relative_to(ROOT))
    state['hand_adaptive_interface']['actual_inherited_call_path']=str((OUT/'PLANNER-CALL-PATH.json').relative_to(ROOT))
    state['hand_adaptive_interface']['all_named_policy_clone_sites_bound']=True
    state['no_active_research_processes']=True
    save(repo/ROOT/'SESSION-STATE.json',state)
    note='\n## Actual planner dispatch\n\nThe complete inherited policy chain has been read from the archived qualified\nruntime. All named public-clone bindings resolve to the tested wrapper; no\nliteral native-model allocation or direct base-cloner reference is present in\nthat chain. See `ash-inheritance-20260909/hand-adaptive-v1/closure-1/PLANNER-CALL-PATH.json`.\nThe full field readback is `hand-adaptive-v1/offline-publication-1/REMOTE-READBACK.json`.\nThis source binding does not add a new native test or independent oracle claim.\n'
    handoff=repo/ROOT/'SESSION-HANDOFF.md';handoff.write_text(handoff.read_text()+note)
    decision={'kind':'HAND_ADAPTIVE_INTERFACE_AND_FACTUAL_FIELDS_CLOSED','qualification':qualifier['qualification'],
              'factual_fields':fields,'actual_policy_inheritance':binding['inheritance_chain'],
              'actual_clone_call_sites':binding['clone_call_sites'],
              'source_utility_packet_remotely_preserved':True,
              'future_population_authorized_by_this_closure':False,
              'remaining':'Complete prospective Hand adaptive-value and held-out descriptor/policy/peer/economy/independent-confirmation proof. No controller retuning, Bloodfire extension or model refit.',
              'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_native_runs':0,
              'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    save(out/'DECISION.json',decision)
    paths=[root/'finalize.py',root/'close.py',root/'descriptor.py',root/'descriptor-1/SYNC-MANIFEST.json']
    paths += list(out.iterdir())
    paths += [repo/ROOT/n for n in ('SESSION-HANDOFF.md','SESSION-STATE.json','package-disposition-20260908/ROADMAP.md')]
    save(out/'FILES.json',[{'path':str(p.relative_to(repo)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'git_blob':blob(p.read_bytes())} for p in sorted(paths) if p.is_file()])
    print(json.dumps({k:v for k,v in decision.items() if k not in ('qualification','factual_fields')},indent=2))


def verify(original,cold,receipt):
    require(not receipt.exists(),'RECEIPT_EXISTS')
    manifest=(original/OUT/'FILES.json').read_bytes();require(manifest==(cold/OUT/'FILES.json').read_bytes(),'MANIFEST_EQUALITY')
    records=json.loads(manifest)
    for r in records:
        p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
        a=(original/p).read_bytes();b=(cold/p).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'REMOTE_BYTES:'+str(p))
        require(blob(b)==r['git_blob']==git(cold,'rev-parse','HEAD:'+str(p)),'REMOTE_GIT_IDENTITY:'+str(p))
    binding=source_binding(cold/HERE/'execution-1')
    require(binding==load(cold/OUT/'PLANNER-CALL-PATH.json'),'CALL_PATH_REPRODUCTION')
    save(receipt,{'kind':'HAND_INTERFACE_FIELDS_AND_CAPSULE_COMPLETE_COLD_READBACK',
                  'published_head':git(cold,'rev-parse','HEAD'),'files':records,
                  'all_bytes_equal':True,'call_path_reproduced':True,'previous_raw_and_field_receipts_retained':True,
                  'new_native_runs':0,'packages_admitted':0,'p9_certified':False})


if __name__=='__main__':
    if sys.argv[1]=='run':run(*(Path(x).resolve() for x in sys.argv[2:]))
    elif sys.argv[1]=='verify':verify(*(Path(x).resolve() for x in sys.argv[2:]))
    else:raise SystemExit('run REPO OUTPUT | verify ORIGINAL COLD RECEIPT')
