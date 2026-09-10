"""One fixed composition trial. No old cohort replay, new weights, or content.
Reuses the one-sample runtime, existing acquisition law and existing readers.
"""
from concurrent.futures import ThreadPoolExecutor
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import unittest

BASE = Path('research/p9-six-route/ash-inheritance-20260909')
ONE = BASE / 'planner-v1/one-sample-v1'
HERE = Path(__file__).resolve().parent
ENGINE = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
SIGNED = '''extends SceneTree
const Sim: GDScript = preload("res://tools/balance_sim.gd")
func _initialize() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var db: ContentDB = BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
 var out: FileAccess = FileAccess.open(args[0],FileAccess.WRITE)
 if db==null or out==null:quit(2);return
 for aspect: String in ["duskblade","ashwarden"]:
  var modes: Array = [[true,false],[false,true],[true,true]]
  if aspect=="duskblade":modes.append([false,false])
  for vow: int in [0,5]:
   for mode: Array in modes:
    var row: Dictionary = Sim.simulate(db,aspect,73414010,vow,PackedStringArray(),{},mode[0],mode[1])
    out.store_line(JSON.stringify({"aspect":aspect,"vow":vow,"modes":mode,"row":row}))
 out.close();quit(0)
'''


def require(ok, why):
    if not ok:raise ValueError(why)


def sha(data):return hashlib.sha256(data).hexdigest()
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def load(path):return json.loads(Path(path).read_bytes())
def save(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n')


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m


def replace_once(text,old,new):
    require(text.count(old)==1,'UNIQUE_SOURCE_ANCHOR:'+old[:70])
    return text.replace(old,new,1)


def random_guard(text):
    return replace_once(text,'if random_build or aspect != 1:',
                        'if random_build or random_play or aspect != 1:')


def costs_valid(costs):
    import math
    return all(math.isfinite(c) and 0<=c<=3600 for c in costs.values())


def dependencies(repo):
    expected={ONE/'study.py':'b7561642e19fc409c423b8b66710c68a482d3a47',
              BASE/'acquisition-v1/bridge.py':'f76b705b7b986bac5c5823d9c25158b1fcfc92e2',
              BASE/'acquisition-v1/compare_value.py':'22f1ba8575d91ff461e523370a139ccb3258ccc3',
              BASE/'acquisition-v1/repaired-source-1/capability.gd':'99f5cfdee9319e93145f607a30f7bb38d89d78da'}
    for rel,want in expected.items():require(blob((repo/rel).read_bytes())==want,'DEPENDENCY:'+str(rel))
    one=module('joint_one',repo/ONE/'study.py')
    value,base,reader,bench=one.dependencies(repo)
    bridge=module('joint_bridge',repo/BASE/'acquisition-v1/bridge.py')
    comparison=module('joint_comparison',repo/BASE/'acquisition-v1/compare_value.py')
    return one,value,base,reader,bench,bridge,comparison


def setup(repo,work,out,p,one,bench,bridge):
    old=repo/ONE/'execution-2';pop=old/'population'
    require(blob((old/'TERMINAL.json').read_bytes())==p['evidence']['one_sample_terminal_blob'],'TERMINAL_INPUT')
    require(blob((old/'REMOTE-READBACK.json').read_bytes())==p['evidence']['one_sample_readback_blob'],'READBACK_INPUT')
    require(load(old/'REMOTE-READBACK.json')['population_reproduced'] is True,'UNVERIFIED_INPUT')
    audit=repo/ONE/'closure-1/capture-audit/RESULTS.json'
    require(sha(audit.read_bytes())==p['evidence']['complete_bottleneck_result_sha256'],'BASIS_IDENTITY')
    require(load(repo/ONE/'closure-1/REMOTE-READBACK.json')['readout_reproduced'] is True,'BASIS_READBACK')
    assignment=p['assignment']
    seed_report=one.seed_check(repo,HERE,assignment['seeds']+[assignment['qualification_seed']])
    entries={r['path']:r for r in load(old/'FILES.json')}
    source=pop/'planner-source'
    def previous_file(path):
        rel=str(path.relative_to(old));entry=entries[rel];data=path.read_bytes()
        require(sha(data)==entry['sha256'] and len(data)==entry['bytes'],'SOURCE_BYTES:'+rel)
        return entry
    previous_file(source/'FINAL-SOURCE-MANIFEST.json')
    manifest=load(source/'FINAL-SOURCE-MANIFEST.json')
    archive=source/'bound-runtime.tar.xz';archive_record=previous_file(archive)
    projects={}
    for name in ('stock','aware'):
        target=work/name
        bench.unpack(archive,target,[dict(path=k,**r) for k,r in manifest.items()],archive_record['sha256'])
        projects[name]=target
    aware=projects['aware'];pilot=aware/'tools/balance_pilot.gd'
    (aware/'tools/stock_pilot.gd').write_text(replace_once(pilot.read_text(),'class_name BalancePilot\n',''))
    delta=bridge.install(aware)
    pilot.write_text(random_guard(pilot.read_text()))
    observed=aware/'tools/observed_sim.gd'
    observed.write_text(replace_once(observed.read_text(),'\t\tPilot.play_turn(game)',
                                    '\t\tpreload("res://combat_bridge.gd").play_turn(game)'))
    permitted={'tools/balance_pilot.gd','tools/balance_sim.gd','tools/observed_sim.gd'}
    for rel in manifest:
        if rel not in permitted:
            require((projects['stock']/rel).read_bytes()==(aware/rel).read_bytes(),'UNRELATED_DELTA:'+rel)
    before=bridge.funcs((projects['stock']/'tools/observed_sim.gd').read_text())
    after=bridge.funcs(observed.read_text())
    require({n for n in before if before[n]!=after.get(n)}=={'_claim_rewards','_resolve_event'},'COMBAT_DISPATCH_DELTA')
    require('"rollout_samples":1' in (aware/'combat_bridge.gd').read_text(),'ONE_SAMPLE_BINDING')
    require('"rollout_samples":2' not in (aware/'combat_bridge.gd').read_text(),'TWO_SAMPLE_LEAK')
    for project in projects.values():
        (project/'signed_composition.gd').write_text(SIGNED)
        shutil.copyfile(repo/ONE/'bound-source/decision_gate.gd',project/'decision_gate.gd')
    shutil.copyfile(repo/BASE/'acquisition-v1/repaired-source-1/capability.gd',aware/'capability.gd')
    previous_file(pop/'RESOLVED-PROTOCOLS.json')
    original=load(pop/'RESOLVED-PROTOCOLS.json')['planner'];protocols={}
    for name,project in projects.items():
        q=copy.deepcopy(original)
        q.update(policy_root=assignment['policy_root'],policies=128,policies_per_cell=2,
                 seeds=assignment['seeds'],qualification_seed=assignment['qualification_seed'],composition_arm=name)
        require(q['support_bounds']==p['support_bounds'],'SUPPORT_BAR_CHANGE')
        for n in q['runtime']['sources']:q['runtime']['sources'][n]=sha((project/'tools'/n).read_bytes())
        protocols[name]=q
    save(out/'SEED-METADATA.json',seed_report)
    save(out/'SOURCE-DELTA.json',dict(delta,random_play_guard_added=True,experimental_arm_scores_unchanged_by_guard=True))
    save(out/'RESOLVED-PROTOCOLS.json',protocols)
    all_sources={m:{str(f.relative_to(project)):{'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())}
                       for f in sorted(project.rglob('*')) if f.is_file()} for m,project in projects.items()}
    save(out/'SOURCE-MANIFEST.json',all_sources)
    with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
        for name,project in projects.items():
            for rel in all_sources[name]:tf.add(project/rel,arcname=name+'/'+rel,recursive=False)
    return projects,protocols


def qualify(repo,engine,projects,out,base,reader):
    q=out/'qualification';q.mkdir()
    for name,project in projects.items():
        base.command([str(engine),'--headless','--path',str(project),'--import'],q,name+'-import')
        paths=['tools/balance_pilot.gd','tools/balance_sim.gd','tools/observed_sim.gd','combat_bridge.gd','decision_gate.gd','signed_composition.gd']
        if name=='aware':paths+=['tools/stock_pilot.gd','capability.gd']
        base.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*paths],q,name+'-parse',cwd=project)
    base.command([str(engine),'--headless','--path',str(projects['aware']),'-s','res://capability.gd','--',str(q/'capability.jsonl')],q,'capability')
    records=list(reader.stream(q/'capability.jsonl'));last=records.pop()
    require(last=={'kind':'terminal','checks':len(records),'failures':0} and all(r['okay'] is True for r in records),'ACQUISITION_QUALIFICATION')
    require(len(records)==9851,'ACQUISITION_COVERAGE')
    for mode in ('active','off','producer_off','consumer_off'):
        target=q/(mode+'.jsonl')
        base.command([str(engine),'--headless','--path',str(projects['aware']),'-s','res://decision_gate.gd','--',mode,str(target)],q,'query-'+mode)
        reference=repo/ONE/'execution-2/preflight/raw'/(mode+'.jsonl')
        require(target.read_bytes()==reference.read_bytes(),'UNCHANGED_COMBAT_QUERY:'+mode)
    for name,project in projects.items():
        base.command([str(engine),'--headless','--path',str(project),'-s','res://signed_composition.gd','--',str(q/(name+'-signed.jsonl'))],q,name+'-signed')
    require((q/'stock-signed.jsonl').read_bytes()==(q/'aware-signed.jsonl').read_bytes(),'SIGNED_OR_DUSK_CHANGED')
    signed=list(reader.stream(q/'stock-signed.jsonl'))
    require(len(signed)==14,'SIGNED_COVERAGE')
    require(all(r['row']['outcome'] in ('win','loss') and not r['row']['error'] for r in signed),'SIGNED_FAULT')
    result={'status':'JOINT_SOURCE_QUERY_AND_SIGNED_NULL_PASS','combat_queries_byte_equal':384,
            'acquisition_queries':len(records),'signed_and_other_aspect_endpoint_pairs':14,
            'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    save(q/'RESULTS.json',result)
    return result


def run(repo,engine,out,work,publish=False):
    repo,engine,out,work=map(lambda x:Path(x).resolve(),(repo,engine,out,work))
    require(not out.exists() and not work.exists(),'OUTPUT_EXISTS_NO_RERUN')
    out.mkdir(parents=True);work.mkdir(parents=True)
    terminal={'status':'INCONCLUSIVE','stages':{},'packages_admitted':0,'p9_certified':False}
    base=None;head=None
    try:
        one,value,base,reader,bench,bridge,comparison=dependencies(repo)
        head=base.git(repo,'rev-parse','HEAD');terminal['source_head']=head
        p=load(HERE/'PROTOCOL.json');freeze=load(HERE/'FREEZE.json')
        for n,h in freeze['source_sha256'].items():require(sha((HERE/n).read_bytes())==h,'FROZEN_OWN_SOURCE:'+n)
        require(sha(engine.read_bytes())==ENGINE,'PINNED_ENGINE')
        projects,protocols=setup(repo,work,out,p,one,bench,bridge)
        if publish:head=base.publish(repo,out,head,'research(p9): bind joint acquisition/combat runtimes before observations')
        terminal['qualification']=qualify(repo,engine,projects,out,base,reader)
        if publish:head=base.publish(repo,out,head,'research(p9): preserve exact joint query and signed-null qualification')
        for vow in (5,0):
            stage=out/f'v{vow}';stage.mkdir()
            for name in projects:(stage/name).mkdir()
            specs=[(name,{'root':p['assignment']['policy_root'],'first':i,'count':2,'seeds':p['assignment']['seeds'],'vow':vow,'integration':False}) for i in range(0,128,2) for name in projects]
            cumulative={m:0.0 for m in projects}
            for offset in range(0,len(specs),8):
                tasks=specs[offset:offset+8]
                with ThreadPoolExecutor(max_workers=2) as pool:
                    receipts=list(pool.map(lambda x:value.cell(x[1],projects[x[0]],engine,stage/x[0],protocols[x[0]],base,reader),tasks))
                for (name,cfg),r in zip(tasks,receipts):
                    if r['status']=='COMPLETE':cumulative[name]+=r['cpu']['user']+r['cpu']['system']
                save(stage/'COST-PROGRESS.json',cumulative)
                if publish:head=base.publish(repo,out,head,f'research(p9): preserve joint v{vow} assigned group {offset//8+1}')
                require(all(r['status']=='COMPLETE' for r in receipts),'INCOMPLETE_ASSIGNED_CELL')
                if not costs_valid(cumulative):
                    terminal.update(status='JOINT_RESOURCE_FAIL',last_vow=vow,v0_skipped=vow==5,actual_partial_costs=cumulative)
                    break
                for i in range(0,len(tasks),2):
                    a,b=tasks[i:i+2];require(a[1]==b[1],'PAIRED_CONFIG')
                    stem=f"v{vow}-{a[1]['first']:03d}.outcomes.jsonl.xz"
                    headers=[next(reader.stream(stage/m/stem)) for m in projects]
                    require(headers[0]['policies']==headers[1]['policies'],'PAIRED_POLICY_VECTORS')
            else:
                results={m:reader.analyze(stage/m,protocols[m],vow) for m in projects}
                costs={m:value.read_value.read_stage(stage/m,protocols[m],vow,0,128,reader)[1] for m in projects}
                result=comparison.compare(results['stock'],results['aware'],p)
                result['comparison_scope']='Same one-sample combat in BOTH arms; stock and aware denote acquisition only.'
                result['costs']=costs
                result['resource_pass']=costs_valid({m:r['process_cpu_seconds'] for m,r in costs.items()})
                result['pass']=result['pass'] and result['resource_pass']
                for m,r in results.items():save(stage/(m+'-support.json'),r)
                save(stage/'COMPARISON.json',result);terminal['stages'][str(vow)]=result
                if publish:head=base.publish(repo,out,head,f'research(p9): preserve full joint v{vow} decision')
                if not result['pass']:
                    terminal.update(status='JOINT_CONTROLLER_VALUE_OR_SUPPORT_NOT_ESTABLISHED',last_vow=vow,v0_skipped=vow==5)
                    break
                continue
            break
        else:terminal['status']='JOINT_CONTROLLER_AND_PAIR_SUPPORT_PASS_NOT_CERTIFICATE'
    except Exception as exc:terminal['failure']=repr(exc)
    finally:
        save(out/'TERMINAL.json',terminal)
        save(out/'FILES.json',[{'path':str(f.relative_to(out)),'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(out.rglob('*')) if f.is_file() and f!=out/'FILES.json'])
        if publish and base is not None and head is not None:
            head=base.publish(repo,out,head,'research(p9): preserve actual joint controller terminal and every emitted byte')
        if head and os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
        print(json.dumps(terminal,indent=2))
    return 3 if terminal['status']=='INCONCLUSIVE' else 0


def verify(repo,original,cold,receipt):
    repo,original,cold,receipt=map(Path,(repo,original,cold,receipt))
    require(not receipt.exists(),'READBACK_EXISTS')
    one,value,base,reader,bench,bridge,comparison=dependencies(repo)
    manifest=(original/'FILES.json').read_bytes();require((cold/'FILES.json').read_bytes()==manifest,'MANIFEST')
    entries=json.loads(manifest);require(len({r['path'] for r in entries})==len(entries),'DUPLICATE_MANIFEST_PATH')
    for r in entries:
        rel=Path(r['path']);require(not rel.is_absolute() and '..' not in rel.parts,'PATH')
        b=(cold/rel).read_bytes();require(b==(original/rel).read_bytes() and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTES:'+str(rel))
    p=load(HERE/'PROTOCOL.json');t=load(cold/'TERMINAL.json');protocols=load(cold/'RESOLVED-PROTOCOLS.json')
    if 'qualification' in t:
        q=cold/'qualification';require(load(q/'RESULTS.json')==t['qualification'],'QUALIFICATION_BINDING')
        for mode in ('active','off','producer_off','consumer_off'):
            require((q/(mode+'.jsonl')).read_bytes()==(repo/ONE/'execution-2/preflight/raw'/(mode+'.jsonl')).read_bytes(),'QUERY_READBACK')
        require((q/'stock-signed.jsonl').read_bytes()==(q/'aware-signed.jsonl').read_bytes(),'SIGNED_READBACK')
    for vow,expected in t['stages'].items():
        stage=cold/f'v{vow}'
        results={m:reader.analyze(stage/m,protocols[m],int(vow)) for m in ('stock','aware')}
        costs={m:value.read_value.read_stage(stage/m,protocols[m],int(vow),0,128,reader)[1] for m in results}
        actual=comparison.compare(results['stock'],results['aware'],p)
        actual['comparison_scope']='Same one-sample combat in BOTH arms; stock and aware denote acquisition only.'
        actual['costs']=costs;actual['resource_pass']=costs_valid({m:r['process_cpu_seconds'] for m,r in costs.items()})
        actual['pass']=actual['pass'] and actual['resource_pass']
        require(actual==expected==load(stage/'COMPARISON.json'),'EXACT_DECISION_REPRODUCTION')
        if vow=='0':require(t['stages']['5']['pass'] is True,'V0_WITHOUT_PASS')
    save(receipt,{'kind':'COMPLETE_JOINT_COMPOSITION_COLD_READBACK','files':len(entries)+1,'all_bytes_equal':True,
         'reproduced_stages':list(t['stages']),'scientific_status':t['status'],'new_native_runs':0,'packages_admitted':0,'p9_certified':False})


class Tests(unittest.TestCase):
    def test_guard_does_not_change_active_arm(self):
        text='if random_build or aspect != 1:\n return score\nscore += 2.0\n'
        self.assertEqual(random_guard(text),text.replace('random_build or','random_build or random_play or',1))
    def test_duplicate_guard_site_rejected(self):
        with self.assertRaises(ValueError):random_guard('if random_build or aspect != 1:'*2)
    def test_missing_guard_rejected(self):
        with self.assertRaises(ValueError):random_guard('return score')
    def test_cost_boundary(self):
        self.assertTrue(costs_valid({'a':3600.0,'b':0}))
        self.assertFalse(costs_valid({'a':3600.01,'b':0}))
    def test_nonfinite_cost(self):
        self.assertFalse(costs_valid({'a':float('nan')}))
        self.assertFalse(costs_valid({'a':-1}))
    def test_signed_random_modes_present(self):
        self.assertIn('[[true,false],[false,true],[true,true]]',SIGNED)
        self.assertIn('if aspect=="duskblade"',SIGNED)


if __name__=='__main__':
    if sys.argv[1:] == ['--self-test']:unittest.main(argv=[sys.argv[0]],verbosity=2)
    elif sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:6],publish='--publish' in sys.argv))
    elif sys.argv[1]=='verify':verify(*sys.argv[2:])
    else:raise SystemExit('run REPO ENGINE OUTPUT WORK [--publish] | verify REPO ORIGINAL COLD RECEIPT')
