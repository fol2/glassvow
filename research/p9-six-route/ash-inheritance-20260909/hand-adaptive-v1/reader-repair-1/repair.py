"""Repair reader-only native draw-order defect; never rerun or edit captures.
The frozen protocol requires native instance order. Native draw_cards pops the
back of the six-card fixture stack, not its front. All other claims are retained.
"""
from pathlib import Path
import hashlib
import importlib.util
import io
import json
import sys
import tarfile
import types
import unittest

OLD = '[10002,10003]+list(range(10100,10100+drawn))'
NEW = '[10002,10003]+list(range(10105,10105-drawn,-1))'
READER = '711eeede46216092e5db81ae534710764de22412cd644f5f1f500953c22ad291'
COMBAT = '3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0'
BASE = Path('research/p9-six-route/ash-inheritance-20260909/hand-adaptive-v1')


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()
def save(p,v): p.write_text(json.dumps(v,indent=2)+'\n')
def load(p): return json.loads(p.read_bytes())


def fixed_module(source):
    require(sha(source)==READER,'READER_IDENTITY')
    text=source.decode();require(text.count(OLD)==1,'EXACT_REPAIR_SITE')
    corrected=text.replace(OLD,NEW,1)
    m=types.ModuleType('read_gate')
    exec(compile(corrected,'read_gate_draw_order_repair.py','exec'),m.__dict__)
    return m,corrected.encode()


def module(name,p):
    s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m


def tests(root,reader,out):
    previous=sys.modules.get('read_gate');sys.modules['read_gate']=reader
    fixture=module('corrected_reader_regressions',root/'test_read_gate.py')
    original=fixture.synthetic
    def tail_source(*args):
        row=original(*args)
        cards=row['source_after']['combat']['hand'];n=len(cards)-2
        row['source_after']['combat']['hand']=cards[:2]+[{'uid':i} for i in range(10105,10105-n,-1)]
        return row
    fixture.synthetic=tail_source
    log=io.StringIO();suite=unittest.defaultTestLoader.loadTestsFromModule(fixture)
    result=unittest.TextTestRunner(stream=log,verbosity=2).run(suite)
    (out/'TESTS.log').write_text(log.getvalue())
    if previous is None:sys.modules.pop('read_gate',None)
    else:sys.modules['read_gate']=previous
    require(result.wasSuccessful() and result.testsRun==9,'READER_REGRESSIONS')
    return result.testsRun


def run(repo,out):
    root=repo/BASE;capture=root/'execution-1'
    require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
    old=load(capture/'TERMINAL.json')
    require(old['status']=='INCONCLUSIVE' and old['failure']=="ValueError('DRAW_INSTANCE_PROVENANCE')",'ORIGINAL_FAILURE_IDENTITY')
    readback=load(capture/'REMOTE-READBACK.json');require(readback['all_bytes_equal'] is True,'CAPTURE_NOT_READ_BACK')
    files=load(capture/'FILES.json')
    require(len({r['path'] for r in files})==len(files),'UNIQUE_CAPTURE_FILES')
    for r in files:
        rel=Path(r['path']);require(not rel.is_absolute() and '..' not in rel.parts,'PATH')
        b=(capture/rel).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'RAW_IDENTITY:'+str(rel))
    with tarfile.open(capture/'runtime-source.tar.xz','r:xz') as tf:
        combat=tf.extractfile('reference/domain/rules/combat.gd').read()
    require(sha(combat)==COMBAT,'NATIVE_COMBAT_IDENTITY')
    text=combat.decode();start=text.index('func draw_cards(');end=text.index('\nfunc ',start+1)
    draw=text[start:end]
    require('var c: CardInst = cb.draw.pop_back()' in draw and 'cb.hand.append(c)' in draw,'NATIVE_STACK_LAW')
    reader,corrected=fixed_module((root/'read_gate.py').read_bytes())
    (out/'read_gate.py').write_bytes(corrected)
    n=tests(root,reader,out)
    result=reader.check(capture)
    save(out/'RESULTS.json',result)
    decision={'kind':'HAND_ADAPTIVE_READER_DELIVERY_REPAIR','status':result['status'],
              'original_terminal':old,'original_capture_sha256':sha((capture/'FILES.json').read_bytes()),
              'original_reader_sha256':READER,'corrected_reader_sha256':sha(corrected),
              'native_draw_function':draw,'change':{'before':OLD,'after':NEW},
              'reason':'Native card identity/order was always the contract; the decoder expected front-pop instead of native back-pop. No intervention, fixture, engine, policy, raw outcome or acceptance rule is changed.',
              'regression_tests':n,'original_source_checks_reused':7,
              'qualification':result,'new_native_runs':0,'new_independent_samples':0,
              'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','packages_admitted':0,'p9_certified':False}
    save(out/'DECISION.json',decision)
    save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.iterdir()) if p.is_file() and p.name!='FILES.json'])
    print(json.dumps(decision,indent=2))


def verify(repo,original,cold,receipt):
    require(not receipt.exists(),'RECEIPT_EXISTS')
    require((original/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(),'MANIFEST_EQUALITY')
    for r in load(original/'FILES.json'):
        a=(original/r['path']).read_bytes();b=(cold/r['path']).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTES:'+r['path'])
    m=module('cold_corrected_hand_reader',cold/'read_gate.py')
    result=m.check(repo/BASE/'execution-1')
    require(result==load(cold/'RESULTS.json')==load(cold/'DECISION.json')['qualification'],'DECISION_REPRODUCTION')
    save(receipt,{'kind':'HAND_ADAPTIVE_REPAIR_COLD_READBACK','all_bytes_equal':True,
                  'readout_reproduced':True,'original_capture_unchanged':True,
                  'qualification':result,'new_native_runs':0,'packages_admitted':0,'p9_certified':False})


if __name__=='__main__':
    if sys.argv[1]=='run':run(*(Path(p).resolve() for p in sys.argv[2:]))
    elif sys.argv[1]=='verify':verify(*(Path(p).resolve() for p in sys.argv[2:]))
    else:raise SystemExit('run REPO OUTPUT | verify COLD_REPO ORIGINAL COLD RECEIPT')
