"""Read exact inherited Ash dependencies; never execute history or outcomes.

Source-only work: eligibility of an identity is not current numerical admission.
The failed substrate is retained as evidence, not installed into the product.
"""
from __future__ import annotations
import argparse, ast, hashlib, io, json, re, subprocess, tarfile
from pathlib import Path

ARCHIVE='c802be36510273481b6d0f865b92fac43abf6aff'
MAIN='2ed6cdb0302ba3aab5845a18d862841165e8aaf7'
ROOT='research/issue-421/'
HARNESS='raw/post-directive-harness-v2.tar.gz'
HARNESS_BLOB='0e963a6dfadb87912f9b1074b78d8629bbad2a47'
CONTENT='a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
SELECTED='765d9efd639fe3507d92ea2f7515b3ed92afd15166925a6db2f8934e3a777f07'
ADMISSION='summaries/progress-post-directive-hand-size-ash-admission-v1.md'
CARDS=('bloodRite','leechBlade','preparation','surge','phantomBlades')

def require(ok,why):
    if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def dump(obj):return (json.dumps(obj,indent=2,sort_keys=True)+'\n').encode()
def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args],timeout=90)

def gd_functions(text):
    matches=list(re.finditer(r'^(?:static )?func (\w+)\(',text,re.M))
    out={}
    for i,m in enumerate(matches):
        require(m.group(1) not in out,'DUPLICATE_FUNCTION')
        out[m.group(1)]=text[m.start():matches[i+1].start() if i+1<len(matches) else len(text)]
    return out

def relevant_python(data):
    """Source display only: AST locates functions but never evaluates them."""
    text=data.decode();tree=ast.parse(text);lines=text.splitlines(keepends=True);out={}
    for node in tree.body:
        if not isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef,ast.Assign,ast.AnnAssign)):continue
        body=''.join(lines[node.lineno-1:node.end_lineno])
        if any(x in body for x in ('bloodfire','bloodRite','leechBlade','mistboundBonus','fixed-substrate')):
            name=getattr(node,'name',f'line-{node.lineno}')
            out[name]=body
    return out

def status_object(content):
    out={}
    def walk(obj,path=()):
        if isinstance(obj,dict):
            for key,value in obj.items():
                if key=='bloodfire':out['/'.join(path+(key,))]=value
                if path and path[0]=='cards':continue
                walk(value,path+(str(key),))
        elif isinstance(obj,list):
            for i,value in enumerate(obj):
                if isinstance(value,dict) and value.get('id')=='bloodfire':out['/'.join(path+(str(i),))]=value
                walk(value,path+(str(i),))
    walk(content)
    return out

def collect(repo,out):
    require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
    data=git(repo,'show',ARCHIVE+':'+ROOT+HARNESS)
    require(blob(data)==HARNESS_BLOB,'ARCHIVE_IDENTITY')
    (out/'harness.tar.gz').write_bytes(data)
    (out/'ADMISSION.md').write_bytes(git(repo,'show',ARCHIVE+':'+ROOT+ADMISSION))
    (out/'SHA256SUMS').write_bytes(git(repo,'show',ARCHIVE+':'+ROOT+'SHA256SUMS'))
    for path,leaf in [('content/full-content.json','CURRENT-CONTENT.json'),('domain/rules/combat.gd','CURRENT-COMBAT.gd'),('tools/balance_pilot.gd','CURRENT-PILOT.gd')]:
        (out/leaf).write_bytes(git(repo,'show',MAIN+':'+path))
    # Metadata only. No ledger, protected row or empirical endpoint is read.
    names=[]
    for row in git(repo,'ls-tree','-rz',ARCHIVE,'--',ROOT+'artifacts',ROOT+'protocols',ROOT+'summaries').split(b'\0'):
        if not row:continue
        meta,path=row.decode().split('\t');mode,kind,digest=meta.split()
        relative=path[len(ROOT):]
        if re.search(r'bloodfire|hand-size.*(?:admission|inventory)|ash.*(?:pair|admission)|package-order.*heldout|(?:content|candidate).*post-v38|post-v38.*(?:content|candidate)',relative,re.I):
            names.append({'path':path,'git_blob':digest,'kind':kind})
    (out/'RELATED-PATHS.json').write_bytes(dump(names))
    manifest={p.name:{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'git_blob':blob(p.read_bytes())} for p in sorted(out.iterdir())}
    (out/'MANIFEST.json').write_bytes(dump(manifest))

def analyse(inputs,out):
    require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
    for name,r in json.loads((inputs/'MANIFEST.json').read_bytes()).items():
        require(Path(name).name==name,'INPUT_PATH')
        b=(inputs/name).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'] and blob(b)==r['git_blob'],'INPUT_IDENTITY:'+name)
    raw=(inputs/'harness.tar.gz').read_bytes();require(blob(raw)==HARNESS_BLOB,'ARCHIVE_IDENTITY')
    sources={}
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz') as tf:
        for m in tf.getmembers():
            if m.isdir():continue
            require(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts and m.name not in sources,'ARCHIVE_PATH')
            sources[m.name]=tf.extractfile(m).read()
    cb=(inputs/'CURRENT-CONTENT.json').read_bytes();require(sha(cb)==CONTENT,'CURRENT_IDENTITY')
    current=json.loads(cb);history=json.loads(sources['source/content/full-content.json'])
    current_gd=gd_functions((inputs/'CURRENT-COMBAT.gd').read_text())
    history_gd=gd_functions(sources['source/domain/rules/combat.gd'].decode())
    law_names=[n for n in history_gd if 'bloodfire' in history_gd[n]]
    historical_laws={n:history_gd[n] for n in law_names}
    current_laws={n:current_gd[n] for n in law_names if n in current_gd}
    recipes={name:relevant_python(b) for name,b in sources.items() if name.endswith('.py')}
    recipes={k:v for k,v in recipes.items() if v}
    for name,value in [('HISTORICAL-LAWS.json',historical_laws),('CURRENT-LAWS.json',current_laws),('CONSTRUCTION-SOURCE.json',recipes)]:
        (out/name).write_bytes(dump(value))
    lines=(inputs/'SHA256SUMS').read_text().splitlines()
    exact=[line for line in lines if line.split()[0]==SELECTED]
    admission=(inputs/'ADMISSION.md').read_text()
    require('Admit Ashwarden' in admission and 'does not revive the rejected scalar substrate' in admission,'ADMISSION_SCOPE')
    hand=('preparation','surge','phantomBlades')
    cards={k:{'current':current['cards'][k],'harness':history['cards'][k],'equal':current['cards'][k]==history['cards'][k]} for k in CARDS}
    result={'kind':'INHERITED_DIRECTION_DEPENDENCY_BINDING_NOT_NEW_ADMISSION',
      'admission_source':ARCHIVE+':'+ROOT+ADMISSION,'current_source':MAIN,
      'harness_source':ARCHIVE+':'+ROOT+HARNESS,'harness_content_sha256':sha(sources['source/content/full-content.json']),
      'selected_historical_content_sha256':SELECTED,'selected_content_exact_file_matches':exact,
      'harness_is_selected_historical_content':sha(sources['source/content/full-content.json'])==SELECTED,
      'cards':cards,'historical_status_definitions':status_object(history),'current_status_definitions':status_object(current),
      'bloodfire_changed_combat_functions':law_names,
      'hand_card_packet_equal_in_this_harness':all(cards[k]['equal'] for k in hand),
      'construction_source_files':sorted(recipes),'related_metadata':json.loads((inputs/'RELATED-PATHS.json').read_bytes()),
      'claims':{
        'historical_hand_and_bloodfire_directions_admitted':True,
        'historical_whole_run_support_carries_to_current_main':False,
        'current_bloodfire_mediator_implemented':bool(status_object(current)),
        'minimal_product_delta_selected':False,
        'restore_failed_scalar_substrate_authorised':False,
        'new_population_execution_authorised':False},
      'limits':['Same card bytes alone do not carry whole-run policy, joint activation or peer separation across a changed content/rule/controller frame.',
                'The harness content is distinguished from the selected content identity; recipe source is preserved for exact binding, never silently assumed identical.',
                'This work reads immutable source/metadata/admission text only, not native or empirical rows. It does not rerun or reopen the old campaign.'],
      'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    (out/'RESULTS.json').write_bytes(dump(result))
    print(json.dumps({'harness_is_selected':result['harness_is_selected_historical_content'],'law_names':law_names,'selected_content_files':exact,'metadata':result['related_metadata'],'recipes':sorted(recipes)},sort_keys=True))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('mode',choices=('collect','analyse'));p.add_argument('input',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    (collect if a.mode=='collect' else analyse)(a.input,a.output)
