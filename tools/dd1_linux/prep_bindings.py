#!/usr/bin/env python3
"""PREP-1 pure falsifiers and real H/public-entry refusals. No native authority.

Synthetic structural records stay synthetic; no empirical context, positive
launch disposition, workload, engine or account is created by this checker.
"""
import argparse
from copy import deepcopy
import importlib
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));sys.path.insert(0,str(HERE.parent))
import prep_controls as c
import dd1_prep_view as v
import dd1_import_semantics as s
import dd1_preparation as p
import dd1_meter_entry as entry
r=c.r


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--head',required=True);parser.add_argument('--h',type=Path,required=True)
    args=parser.parse_args();records=[]
    def passed(name, **kw):records.append(dict(name=name,result='PASS',**kw))
    def refused(name, call, text):
        try:call()
        except (ValueError,r.ReservationError) as exc:
            assert text in str(exc),(name,str(exc));passed(name,reason=str(exc))
        else:raise AssertionError(name+' admitted')
    original=(HERE.parents[1]/'project.godot').read_bytes();derived=v.transform(original)
    assert len(original)-len(derived)==len(v.FUNPLAY)
    assert derived.replace(v.PLUGIN_LINE.replace(v.FUNPLAY,b''),v.PLUGIN_LINE)==original
    assert original.count(v.FUNPLAY)==1 and v.FUNPLAY not in derived
    passed('one-exact-config-delta',original_sha256=r.digest(original),derived_sha256=r.digest(derived),original_blob=s.blob(original))
    for name,b in [('already-derived',derived),('extra-setting',original+b'\n'),('duplicate-plugin-line',original+b'\n'+v.PLUGIN_LINE)]:
        refused(name,lambda b=b:v.transform(b),'unexpected/ambiguous')
    refused('plugin-inventory-omission',lambda:v.require_plugin_inputs({v.PROJECT:original}),'missing/altered original plugin inventory')
    # A supplied recipe cannot make .uid or content into an eligible seed.
    source={c.SIDECAR:c.SEED,'res://assets/probe.bin':c.ASSET}
    slot=dict(path='assets/probe.bin.import',kind='file',files={'':{}},seed=dict(git_blob=s.blob(c.SEED),sha256=r.digest(c.SEED),asset='res://assets/probe.bin',asset_sha256=r.digest(c.ASSET)))
    for name,path in [('UID-is-not-seeded-import','assets/probe.bin.uid'),('code-is-not-sidecar','assets/probe.gd')]:
        bad=deepcopy(slot);bad['path']=path
        refused(name,lambda b=bad:s.validate_seed(b,source,set(),True),'seeded sidecar schema')
    refused('no-inert-importer-for-native',lambda:s.validate_seed(slot,source,{'res://.godot/imported/probe.resource'},False),'not an eligible imported asset')
    for name,raw in [('duplicate-key',c.SEED+b'quality=7\n'),('new-default',c.SEED+b'new_option=true\n'),('type-drift',c.SEED.replace(b'quality=7',b'quality=7.0')),('token-joining',c.SEED.replace(b'dest_files=[',b'dest_files=[ tru e, ')),('group-drift',c.SEED.replace(b'[deps]',b'group_file="res://other.glb"\n[deps]'))]:
        data={c.SIDECAR:raw,'res://.godot/imported/probe.resource':c.RESOURCE}
        refused(name,lambda d=data:s.validate_result(slot,source,d),'duplicate' if name=='duplicate-key' else 'drift')
    metadata = c.SEED.replace(b'[deps]', b'metadata={\n"vram_texture": false\n}\n[deps]')
    sample = {c.SIDECAR: metadata, 'res://assets/probe.bin': c.ASSET}
    result = {c.SIDECAR: b'; generated\n'+metadata, 'res://.godot/imported/probe.resource': c.RESOURCE}
    assert s.validate_result(slot, sample, result)['normalizations'] == []
    passed('multiline-metadata-preserved', scope='bounded lexical identity, not an engine import')
    changed = dict(result);changed[c.SIDECAR] = changed[c.SIDECAR].replace(b'false',b'true')
    refused('multiline-metadata-drift',lambda:s.validate_result(slot,sample,changed),'drift')
    refused('unfinished-multiline',lambda:s.document(metadata.replace(b'}\n[deps]',b'[deps]')),'incomplete import value')
    # Existing schema-2 no-overlap rule is still exercised directly, not bypassed.
    old=dict(schema='DD1-PREPARATION-2',source_head=args.head,source_manifest_sha256=r.digest(r.encode({c.SIDECAR:r.digest(c.SEED)})),engine_sha256='e'*64,slots=[dict(path='assets/probe.bin.import',kind='file',files={'':dict(min_bytes=1,max_bytes=4096)})])
    unit=dict(stage='preparation',overlay_head=args.head,source_files={c.SIDECAR:r.digest(c.SEED)},argv=['/workload'],linux={'runtime':{'/workload':{'sha256':'e'*64}}},preparation=old)
    refused('legacy-overlap-still-refused',lambda:p.validate_recipe(unit,{c.SIDECAR:c.SEED}),'slot shadows/aliases')
    identities=entry.check_h_closure(args.h.resolve());sys.path.insert(0,str(args.h.resolve()))
    h=importlib.import_module('evidence_boundary')
    assert Path(h.__file__).resolve()==args.h.resolve()/'evidence_boundary.py'
    assert Path(h.kernel.__file__).resolve()==args.h.resolve()/'reference_kernel.py'
    roleset=('execution_demand','preparation_recipe','preparation_projection','preparation_producer','preparation_writer_closure','preparation_disposition')
    store={name:r.encode(dict(schema='SYNTHETIC-STRUCTURAL-ONLY',role=name)) for name in roleset}
    roles={name:dict(locator=name,sha256=r.digest(raw)) for name,raw in store.items()}
    inputs,evidence=h.manifest_digests(roles)
    expected=dict(environment='synthetic',epoch=h.kernel.EPOCH,artifact_head=args.head,candidate='PREP1-SYNTHETIC-ROLE-SHAPE',roles=roles,inputs_sha256=inputs,evidence_sha256=evidence)
    packet=dict(evidence={name:name for name in roles})
    def ctx(st=store):return SimpleNamespace(kind='synthetic',resolve=st.get,expected_identities={'provenance':expected},receipts={})
    assert h.verify_bindings(packet,ctx())==expected
    passed('real-H-prospective-role-shape',launchable=False)
    for name in roleset:
        st=dict(store);st[name]=b'altered'
        refused('H-altered-'+name,lambda st=st:h.verify_bindings(packet,ctx(st)),'role_digest:'+name)
    missing=deepcopy(packet);missing['evidence'].pop('preparation_writer_closure')
    refused('H-missing-writer-closure',lambda:h.verify_bindings(missing,ctx()),'external_role_set')
    absent=Path(tempfile.mkdtemp(prefix='dd1-prep1-no-authority-'))
    kwargs=dict(unit={},account_path=absent/'account',receipt_path=absent/'receipt',output=absent/'output',head=args.head,repo=absent/'repo')
    refused('native-missing-authority',lambda:entry.run_complete_unit(['/not-an-engine'],**kwargs),'missing H host-authenticated')
    refused('native-callback',lambda:entry.run_complete_unit(['/not-an-engine'],authority_check=lambda _:True,**kwargs),'callbacks are not native authority')
    refused('native-synthetic',lambda:entry.run_complete_unit(['/not-an-engine'],trusted_context=ctx(),evidence_packet=packet,**kwargs),'native entry rejects synthetic authority')
    assert not list(absent.iterdir())
    # Pure PREP-1 role/issuer refusals; do not invent a trusted issuer or fill
    # launch_admitted. These calls cannot launch anything independently.
    recipe=dict(schema=v.SCHEMA,view={'synthetic':True},producer={'synthetic':True})
    u=dict(preparation=recipe)
    rawstore={name:r.encode(recipe[key]) for name,key in [('preparation_projection','view'),('preparation_producer','producer')]}
    e=dict(roles={name:dict(locator=name,sha256=r.digest(raw)) for name,raw in rawstore.items()})
    context=SimpleNamespace(kind='synthetic',resolve=rawstore.get,receipts={})
    refused('PREP-missing-disposition',lambda:v.native_bindings(u,e,context),'missing PREP-1 disposition')
    rawstore['preparation_disposition']=r.encode(dict(authority='synthetic:forbidden'))
    e['roles']['preparation_disposition']=dict(locator='preparation_disposition',sha256=r.digest(rawstore['preparation_disposition']))
    refused('PREP-untrusted-issuer',lambda:v.native_bindings(u,e,context),'unauthenticated PREP-1 issuer')
    # GDScript is not executed or parsed here. Verify the exact adapter source
    # routing and report that narrower claim; actual native parse remains gated.
    consumer_path=HERE.parents[1]/'tests/support/dd1_unit_grant.gd'
    consumer=consumer_path.read_text()
    for marker in ('_grant.has("execution_files")', 'typeof(_grant.get("sealed_input")) != TYPE_DICTIONARY',
                   'not execution.has(original_path)', 'not original_path.ends_with(".import")',
                   'not generated_path.begins_with("res://.godot/")',
                   '_verified_sources = files.duplicate(true)',
                   'return _verified_sources.duplicate(true) if remaining() > 0 else {}'):
        assert marker in consumer,marker
    assert consumer.index('files = execution') < consumer.index('FileAccess.get_sha256(source_path)')
    assert consumer.index('FileAccess.get_sha256(source_path)') < consumer.index('_verified_sources = files.duplicate(true)')
    assert consumer.count('_grant.get("mode") != "fixed_ordinary"')==2
    passed('fixture-execution-view-consumer-source', source_sha256=r.digest(consumer_path.read_bytes()),
           scope='source routing/order only; GDScript parsing/runtime NOT EXECUTED')
    # Projection fact used by that consumer: only explicitly seeded .import
    # files may differ; config/code/UID identities remain original.
    original_map={'res://project.godot':'p','res://x.gd':'g','res://x.gd.uid':'u','res://a.png.import':'i'}
    execution_map=dict(original_map);execution_map['res://a.png.import']='generated'
    execution_map['res://.godot/imported/a.ctex']='resource'
    def shape_ok(o,e):
        return all(n in e and (o[n]==e[n] or n.endswith('.import')) for n in o) and all(
            n in o or n.startswith('res://.godot/') or n.endswith(('.uid','.import')) for n in e)
    assert shape_ok(original_map,execution_map)
    for name in ('res://project.godot','res://x.gd','res://x.gd.uid'):
        altered=dict(execution_map);altered[name]='changed';assert not shape_ok(original_map,altered)
    altered=dict(execution_map);altered['res://unexpected.gd']='new';assert not shape_ok(original_map,altered)
    passed('execution-view-shape-falsifiers',scope='pure supplied maps, not a GDScript interpreter')
    assert entry.check_h_closure(args.h.resolve())==identities
    print(json.dumps(dict(checks=records,count=len(records),head=args.head,H_blobs=entry.H_BLOBS,H_sha256s=identities,H_mocked=False,engine_runs=0,live_account_writes=0,empirical_context_created=False,native_positive=False),indent=2))
    return 0

if __name__=='__main__':sys.exit(main())
