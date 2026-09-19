#!/usr/bin/env python3
"""Real H role-shape/refusal checks. Synthetic context, NEVER launch authority.

No H replacement, monkeypatch, numerical suite, future outcome receipt, engine,
or account access. The accepted module files must be supplied read-only.
"""
from copy import deepcopy
import hashlib
import importlib
import json
from pathlib import Path
import sys
from types import SimpleNamespace

PINS = {'evidence_boundary.py':'a88db0791572f430ea3e5cde85683c8527cead39',
        'reference_kernel.py':'ee091fb503849117358b3691264fca71803f8bbc'}

def blob(raw):
    return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()

def main():
    root=Path(sys.argv[1]).resolve(strict=True)
    for name,pin in PINS.items():
        p=root/name
        if p.is_symlink() or blob(p.read_bytes())!=pin:
            raise RuntimeError('not exact accepted H: '+name)
    sys.path.insert(0,str(root))
    h=importlib.import_module('evidence_boundary')
    assert Path(h.__file__).resolve()==root/'evidence_boundary.py'
    assert Path(h.kernel.__file__).resolve()==root/'reference_kernel.py'
    # Deliberately NOT a DD1-COMPLETE-UNIT-DEMAND. No argv, reservation or grant.
    raw=h.canonical({'operation':'DD1-B1-COMPAT-1','stage':'INERT_ROLE_SHAPE_ONLY'})
    store={'synthetic:demand':raw,'synthetic:selection':b'SYNTHETIC selection; no owner authority'}
    roles={r:{'locator':l,'sha256':h.digest(store[l])} for r,l in
        [('execution_demand','synthetic:demand'),('owner_selection','synthetic:selection')]}
    inputs,evidence=h.manifest_digests(roles)
    expected=dict(environment='synthetic',epoch=h.kernel.EPOCH,artifact_head='1'*40,
        candidate='synthetic-compat-role-shape',roles=roles,inputs_sha256=inputs,evidence_sha256=evidence)
    context=SimpleNamespace(kind='synthetic',expected_identities={'provenance':expected},resolve=store.get)
    packet={'evidence':{r:v['locator'] for r,v in roles.items()}}
    records=[]
    def refusal(name,p,c,reason):
        try:
            h.verify_bindings(p,c)
        except h.BoundaryError as exc:
            assert str(exc)==reason, (name,str(exc))
            records.append(dict(test=name,exception=type(exc).__name__,reason=str(exc)))
        else:
            raise AssertionError('guard not reached: '+name)
    refusal('absent_manifest',{},SimpleNamespace(expected_identities={}), 'missing_external_manifest')
    assert h.verify_bindings(packet,context)==expected
    records.append(dict(test='synthetic_prospective_role_shape',result='STRUCTURAL_ONLY',authority=False))
    mutated=deepcopy(packet);mutated['evidence'].pop('owner_selection')
    refusal('missing_role',mutated,context,'external_role_set')
    mutated=deepcopy(packet);mutated['evidence']['execution_demand']='synthetic:other'
    refusal('changed_locator',mutated,context,'role_locator:execution_demand')
    store['synthetic:demand']=raw+b'altered'
    refusal('changed_demand_bytes',packet,context,'role_digest:execution_demand')
    store['synthetic:demand']=raw
    context.kind='empirical'
    refusal('no_promotion_of_synthetic_context',packet,context,'manifest_environment')
    assert all(blob((root/name).read_bytes())==pin for name,pin in PINS.items())
    print(json.dumps(dict(scope='REAL_H_CODE_SYNTHETIC_INPUTS_ONLY',accepted_module_blobs=PINS,
        records=records,source_unchanged=True,H_mocked=False,post_output_receipts_required=False,
        native_demand_authenticated=False,engine_launches=0,live_account_writes=0),indent=2))

if __name__=='__main__':
    main()
