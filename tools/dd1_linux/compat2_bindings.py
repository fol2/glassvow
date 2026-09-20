#!/usr/bin/env python3
"""Real H/module/public-refusal controls. NO empirical context or workload launch.

Structural positives are explicitly SYNTHETIC and cannot enter native entry.
The accepted H module bytes are checked before importing; no monkeypatches.
"""
import argparse
from copy import deepcopy
import importlib
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import dd1_meter_entry as entry
import dd1_compatibility as compat
import dd1_reservations as r


def main():
    p=argparse.ArgumentParser();p.add_argument('--h',type=Path,required=True);p.add_argument('--head',required=True)
    args=p.parse_args();identities=entry.check_h_closure(args.h.resolve())
    sys.path.insert(0,str(args.h.resolve()));h=importlib.import_module('evidence_boundary')
    assert Path(h.__file__).resolve()==args.h.resolve()/'evidence_boundary.py'
    assert Path(h.kernel.__file__).resolve()==args.h.resolve()/'reference_kernel.py'
    store={k: r.encode({'schema':'SYNTHETIC-STRUCTURAL-ONLY','role':k,'head':args.head}) for k in
           ('execution_demand','compatibility_profile','preparation_recipe','preparation_seal')}
    roles={k:dict(locator=k,sha256=r.digest(v)) for k,v in store.items()}
    inputs,evidence=h.manifest_digests(roles)
    expected=dict(environment='synthetic',epoch=h.kernel.EPOCH,artifact_head=args.head,
        candidate='SYNTHETIC-COMPAT2-ROLE-SHAPE',roles=roles,inputs_sha256=inputs,evidence_sha256=evidence)
    packet={'evidence':{k:k for k in store}}
    def context(e=expected,s=store,kind='synthetic'):
        return SimpleNamespace(kind=kind,expected_identities={'provenance':e},resolve=s.get,receipts={})
    records=[]
    def refusal(name,call,reason):
        try:call()
        except (ValueError,r.ReservationError) as exc:
            assert reason in str(exc),(name,str(exc));records.append(dict(name=name,exception=type(exc).__name__,reason=str(exc)))
        else:raise AssertionError(name+' admitted')
    assert h.verify_bindings(packet,context())==expected
    records.append(dict(name='real-H-synthetic-prospective-roles',result='PASS',launchable=False))
    refusal('missing-H-manifest',lambda:h.verify_bindings(packet,SimpleNamespace(expected_identities={})), 'missing_external_manifest')
    altered=deepcopy(packet);altered['evidence'].pop('compatibility_profile')
    refusal('missing-profile-role',lambda:h.verify_bindings(altered,context()),'external_role_set')
    altered=deepcopy(packet);altered['evidence']['execution_demand']='wrong'
    refusal('wrong-demand-locator',lambda:h.verify_bindings(altered,context()),'role_locator:execution_demand')
    for name in store:
        altered_store=dict(store);altered_store[name]=b'altered'
        refusal('altered-'+name,lambda s=altered_store:h.verify_bindings(packet,context(s=s)),'role_digest:'+name)
    refusal('synthetic-not-empirical',lambda:h.verify_bindings(packet,context(kind='empirical')),'manifest_environment')
    absent=Path(tempfile.mkdtemp(prefix='dd1-c2-public-refusals-'))
    kwargs=dict(unit={},account_path=absent/'account',receipt_path=absent/'receipt',output=absent/'out',head=args.head,repo=absent/'repo')
    refusal('public-missing-authority',lambda:entry.run_complete_unit(['/not-an-engine'],**kwargs),'missing H host-authenticated')
    refusal('public-callback',lambda:entry.run_complete_unit(['/not-an-engine'],authority_check=lambda _:True,**kwargs),'callbacks are not native authority')
    refusal('public-synthetic-context',lambda:entry.run_complete_unit(['/not-an-engine'],trusted_context=context(),evidence_packet=packet,**kwargs),'native entry rejects synthetic authority')
    assert not list(absent.iterdir()),'refusal touched account/output'
    # Pure profile-role matching cannot authenticate a host: require a separate
    # authenticated prospective disposition before any native transition.
    raw=r.encode({'synthetic':True});shape=dict(roles={'compatibility_profile':dict(locator='p',sha256=r.digest(raw))})
    ctx=SimpleNamespace(resolve={'p':raw}.get,receipts={})
    refusal('missing-native-disposition',lambda:compat.native_bindings({'compatibility':{'synthetic':True}},shape,ctx),'missing compatibility disposition')
    # Pure contract/diagnostic falsifiers, explicitly NOT a native run or an
    # empirical binding. The public native refusals above remain the entry test.
    refusal('engineering-profile-required',lambda:compat.validate_profile(
        {'mode':'engineering'},{}),'engineering/preparation requires bound profile')
    good={'process_refusals':1,'unexpected_denials':0}
    diagnostic_cases=[
        ('one-source-derived-diagnostic',compat.DESKTOP_ERROR+b'\n',good,False,1),
        ('repeated-diagnostic',compat.DESKTOP_ERROR+b'\n'+compat.DESKTOP_ERROR,good,True,1),
        ('diagnostic-without-class',compat.DESKTOP_ERROR,{},True,0),
        ('diagnostic-with-unexpected-denial',compat.DESKTOP_ERROR,
            {'process_refusals':1,'unexpected_denials':1},True,0),
        ('other-error',b'ERROR: unrelated',good,True,0),
        ('parse-error',b'SCRIPT ERROR: Parse Error',good,True,0),
        ('load-error',b'Failed to load script',good,True,0)]
    for name,stderr,classification,failed,count in diagnostic_cases:
        errors,expected_count=compat.diagnose(stderr,classification)
        assert bool(errors)==failed and expected_count==count,name
        records.append(dict(name=name,result='PASS',scope='pure supplied bytes, not engine output',
            stderr_hex=stderr.hex(),classification=classification,errors=errors,
            expected_diagnostic_count=expected_count,origin_authenticated=False))
    # Source-contract check only: no GDScript parser/interpreter is invoked.
    consumer_path=Path(__file__).resolve().parents[2]/'tests/support/dd1_unit_grant.gd'
    consumer=consumer_path.read_text()
    check_mode=consumer.split('static func _valid_mode(',1)[1].split('static func remaining()',1)[0]
    for obligation in (
        'mode in ["fixed_ordinary", "focused_fixture"]',
        'mode != "engineering" or grant.get("stage") != "fixture"',
        'typeof(profile_v) != TYPE_DICTIONARY',
        'profile.get("id") == "DD1-B1-COMPAT-2-CAPABILITIES-1"',
        'profile.get("operation") == "DD1-LINUX-ENTRY-1"',
        'profile.get("stage") == "fixture"',
        'profile.get("source_head") == grant.get("overlay_head")',
        'profile.get("attribution") == "CAPABILITY_CLASS_ONLY"',
        'grant.get("engine_starts") == 1 and grant.get("contained_starts") == 2'):
        assert obligation in check_mode,obligation
    assert 'or not _valid_mode(_grant):' in consumer
    assert consumer.count('_grant.get("mode") != "fixed_ordinary"')==2
    assert 'if remaining() <= 0:' in consumer and '_used += 1' in consumer
    records.append(dict(name='fixture-consumer-source-contract',result='PASS',
        source_sha256=r.digest(consumer_path.read_bytes()),
        scope='source markers and routing; GDScript parse/runtime UNEXECUTED',
        ordinary_acquisition_enabled=False))
    assert entry.check_h_closure(args.h.resolve())==identities
    print(json.dumps(dict(checks=records,count=len(records),H_blobs=entry.H_BLOBS,H_sha256s=identities,
        accepted_H='5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6',H_mocked=False,
        numerical_tests=False,empirical_context_created=False,native_positive=False,
        future_outcome_receipts=False,engine_runs=0,account_writes=0),indent=2))

if __name__=='__main__':main()
