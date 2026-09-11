"""Execute one source-bound two-slope Hand claim; preserve negatives and bytes.
Uses existing native transport, qualified operators and bootstrap. No fitting.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

import readout as R

BASE = Path('research/p9-six-route/ash-inheritance-20260909')
TWO = BASE/'hand-two-slope-v1'
HERE = TWO/'adaptive-value-v1'
OLD = BASE/'hand-value-v1'
QUERY = TWO/'native-v1/query-repair-1/execution-1'
NATIVE = TWO/'native-v1/execution-1'
BRANCH = 'research/p9-six-route-local-20260905'
ENGINE = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
CONTENT = 'ac779e08b0afc5054242ecf5dc1f7421e648e4ee114607708584d1d74ce92cdc'
SOURCE_NAMES = ('CONTRACT.json', 'campaign.py', 'readout.py', 'test_campaign.py')
SHARED = tuple(Path('research/p9-six-route')/p for p in ('SESSION-STATE.json', 'SESSION-HANDOFF.md', 'package-disposition-20260908/ROADMAP.md'))
require = R.require


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p): return json.loads(p.read_bytes())
def save(p, v): p.write_text(json.dumps(v, indent=2)+'\n')
def git(repo, *args): return subprocess.check_output(['git', '-C', str(repo), *args]).decode().strip()


def relative(s):
    require(type(s) is str and bool(s) and '\\' not in s, 'PATH')
    p = Path(s)
    require(not p.is_absolute() and '..' not in p.parts and p.as_posix() == s and s != '.', 'PATH')
    return p


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def publish(repo, expected, paths, message):
    require(git(repo, 'rev-parse', 'HEAD') == expected, 'LOCAL_WRITER_DRIFT')
    require(git(repo, 'ls-remote', 'origin', 'refs/heads/'+BRANCH).split()[0] == expected, 'CONCURRENT_WRITER')
    require(not git(repo, 'diff', '--cached', '--name-only'), 'UNRELATED_INDEX')
    for p in paths:
        rel = p.relative_to(repo)
        require(rel in SHARED or rel.as_posix().startswith(str(HERE)+'/'), 'WRITE_SCOPE')
        git(repo, 'add', '--sparse', '--', str(rel))
    changed = git(repo, 'diff', '--cached', '--name-only').splitlines()
    require(changed and all(Path(x) in SHARED or x.startswith(str(HERE)+'/') for x in changed), 'INDEX_SCOPE')
    git(repo, 'config', 'user.name', 'github-actions[bot]')
    git(repo, 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    git(repo, 'commit', '-m', message)
    git(repo, 'push', 'origin', 'HEAD:refs/heads/'+BRANCH)
    head = git(repo, 'rev-parse', 'HEAD')
    require(git(repo, 'ls-remote', 'origin', 'refs/heads/'+BRANCH).split()[0] == head, 'PUSH_REF')
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a') as f: f.write('PUBLISHED_HEAD='+head+'\n')
    return head


def validate_contract(c):
    expected = {'policy_root': R.ROOT, 'policies':128, 'policies_per_cell':2, 'seeds_per_cell':4,
                'seed_base':R.SEED_BASE, 'seed_vow_stride':1000, 'qualification_seed':R.QUALIFICATION_SEED,
                'vows':[5,0], 'worlds':list(R.WORLDS)}
    require(c['assignment'] == expected, 'FROZEN_ASSIGNMENT')
    require(c['candidate_content_sha256'] == CONTENT, 'CANDIDATE')
    require(c['primary'] == {'outcome':'native_win','contrasts':['11-01','11-10','11-10-01+00'],
        'bootstrap_samples':10000,'bootstrap_seed':421,'lower_quantile':.05/6,'upper_quantile':1-.05/6,
        'positive_lower_bounds_required':3}, 'FROZEN_READOUT')
    require(c['limits'] == {'cpu_seconds_per_world_per_vow':3600,'seconds_per_invocation':240,
        'raw_bytes_per_stream':536870912,'max_workers':4}, 'FROZEN_CONTAINMENT')
    require(c['packages_admitted'] == 0 and c['p9_certified'] is False, 'NO_ADMISSION')


def dependencies(repo):
    pins = {'run_hand.py':'dc27966b3901e31b0949e8dde5b9880c72490f67',
            'read_hand.py':'37337fadd6daaf296b4abb075bc7eb07d4d4a230',
            'entry.gd':'69fff8e67e20f69d2ca5fbbaa6c69b650d53cffc'}
    for n, v in pins.items(): require(blob((repo/OLD/n).read_bytes()) == v, 'DEPENDENCY:'+n)
    sys.path.insert(0, str(repo/OLD))
    import run_hand, read_hand
    require(Path(run_hand.__file__).resolve() == (repo/OLD/'run_hand.py').resolve(), 'IMPORT_LOCATION')
    one, value, base, reader = run_hand.dependencies(repo)
    return run_hand, one, value, base, reader, read_hand.bootstrap_function(repo)


def prereqs(repo, c):
    for rel, expected in c['prerequisite_blobs'].items():
        require(blob((repo/TWO/relative(rel)).read_bytes()) == expected, 'PREREQUISITE:'+rel)
    q = load(repo/QUERY/'REMOTE-READBACK.json')
    guard = load(repo/TWO/'control-v1/closure-1/DECISION.json')
    require(q['all_bytes_equal'] is True and q['readout_reproduced'] is True
        and q['scientific_status'] == 'COHERENT_HAND_QUERY_AND_OFF_MASK_QUALIFIED_NOT_CERTIFICATE', 'QUERY_REQUIRED')
    require(guard['status'] == 'SIGNED_CONTROL_NECESSARY_SCREEN_PASS_NOT_P9'
        and guard['candidate_identity'] == CONTENT
        and guard['signed_control_capture']['all_bytes_equal'] is True, 'CONTROL_REQUIRED')
    root = repo/NATIVE
    entries = {r['path']:r for r in load(root/'FILES.json')}
    identity = load(repo/QUERY/'RUNTIME-IDENTITY.json')
    require(sha((root/'FILES.json').read_bytes()) == identity['parent_capture_manifest_sha256'], 'PARENT_MANIFEST')
    for name in ('SOURCE-MANIFEST.json', 'runtime-source.tar.xz'):
        b = (root/name).read_bytes(); r = entries[name]
        require(len(b) == r['bytes'] and sha(b) == r['sha256'], 'RUNTIME_INPUT:'+name)
    members = load(root/'SOURCE-MANIFEST.json')['legacy-query']
    require(members == identity['runtime_members'], 'COHERENT_MEMBER_IDENTITY')
    return members


def setup(repo, work, out, old, one, c):
    members = prereqs(repo, c)
    reference = work/'reference'; reference.mkdir()
    with tarfile.open(repo/NATIVE/'runtime-source.tar.xz', 'r:xz') as tf:
        selected = {m.name:m for m in tf.getmembers() if m.name.startswith('legacy-query/')}
        require(set(selected) == {'legacy-query/'+p for p in members}, 'ARCHIVE_COVERAGE')
        for rel, r in members.items():
            p = relative(rel); entry = selected['legacy-query/'+rel]
            require(entry.isfile(), 'ARCHIVE_TYPE')
            b = tf.extractfile(entry).read()
            require(len(b) == r['bytes'] and sha(b) == r['sha256'], 'ARCHIVE_BYTES')
            dest = reference/p; dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(b)
    require(sha((reference/'content/full-content.json').read_bytes()) == CONTENT, 'SELECTED_CONTENT')
    combat = (reference/'domain/rules/combat.gd').read_text()
    require('effect["floor_per"] = 0' in combat and '_hand_two_slope_raw' in combat, 'QUALIFIED_PAYOFF_MASK')
    required = sorted({R.QUALIFICATION_SEED} | {s for v in (5,0) for i in range(0,128,2) for s in R.config(i,v)['seeds']})
    tracked = git(repo, 'ls-files', 'research/p9-six-route/**/*.config.json').splitlines()
    require(tracked and all((repo/p).is_file() for p in tracked), 'SEED_METADATA_COVERAGE')
    require(not any(5000 <= s <= 5199 for s in required), 'PROTECTED_SEEDS')
    report = one.seed_check(repo, repo/HERE, required)
    report['tracked_configurations'] = len(tracked); save(out/'SEED-METADATA.json', report)
    previous = repo/BASE/'joint-controller-v1/execution-1/RESOLVED-PROTOCOLS.json'
    require(blob(previous.read_bytes()) == 'd4495e20d026c9a3a4fdafcb388c9367c124e7a2', 'TRANSPORT_PROTOCOL')
    original = (reference/'observed_game.gd').read_bytes()
    projects, protocols = {'reference':reference}, {}
    for world in R.WORLDS:
        project = work/world; shutil.copytree(reference, project)
        (project/'observed_game.gd').write_bytes(old.observer_world(original, world))
        require([n for n in members if (project/n).read_bytes() != (reference/n).read_bytes()] == ['observed_game.gd'], 'WORLD_DELTA')
        p = {'kind':'FIXED_TWO_SLOPE_HAND_VALUE_TRANSPORT','method':'planner','world':world,
             'raw_bytes_per_stream':536870912,'runtime':copy.deepcopy(load(previous)['aware']['runtime']),
             'scientific_contract':'CONTRACT.json'}
        for key, name in (('combat_sha256','domain/rules/combat.gd'),('observer_sha256','observed_game.gd'),
                          ('content_sha256','content/full-content.json')):
            p['runtime'][key] = sha((project/name).read_bytes())
        for name, expected in p['runtime']['sources'].items():
            require(sha((project/'tools'/name).read_bytes()) == expected, 'UNCHANGED_TRANSPORT')
        for key, name in (('probe_sha256','probe.gd'),('bridge_sha256','combat_bridge.gd')):
            require(sha((project/name).read_bytes()) == p['runtime'][key], 'UNCHANGED_POLICY_ENTRY')
        projects[world], protocols[world] = project, p
    entry = (repo/OLD/'entry.gd').read_text()
    # Only the distinct predeclared qualification seed differs from the old entry.
    require(entry.count('73620010') == 1, 'ENTRY_SEED_ANCHOR')
    entry = entry.replace('73620010', str(R.QUALIFICATION_SEED), 1)
    for project in projects.values(): (project/'entry.gd').write_text(entry)
    manifests = {name:{str(p.relative_to(project)):{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())}
        for p in sorted(project.rglob('*')) if p.is_file()} for name, project in projects.items()}
    save(out/'SOURCE-MANIFEST.json', manifests); save(out/'RESOLVED-PROTOCOLS.json', protocols)
    with tarfile.open(out/'runtime-source.tar.xz', 'w:xz') as tf:
        for name, files in manifests.items():
            for rel in files: tf.add(projects[name]/rel, arcname=name+'/'+rel, recursive=False)
    return projects, protocols


def freeze(repo):
    root = repo/HERE
    require(not (root/'FREEZE.json').exists() and not (root/'execution-1').exists(), 'NO_REFREEZE')
    c = load(root/'CONTRACT.json'); validate_contract(c)
    # Bind every inherited input to the inspected checkpoint, not moving branch text.
    git(repo, 'fetch', '--no-tags', '--depth=1', 'origin', c['input_head'])
    delta = git(repo, 'diff', '--name-only', c['input_head'], 'HEAD').splitlines()
    require(all(x.startswith(str(HERE)+'/') or x == '.github/workflows/p9-research-runtime-bundle.yml' for x in delta), 'INPUT_TREE_DRIFT')
    prereqs(repo, c)
    save(root/'FREEZE.json', {'source_head':git(repo,'rev-parse','HEAD'),
        'source_sha256':{n:sha((root/n).read_bytes()) for n in SOURCE_NAMES},
        'new_native_outcomes':0,'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','p9_certified':False})
    publish(repo, git(repo,'rev-parse','HEAD'), [root/'FREEZE.json', root/'source-tests.log'],
            'research(p9): freeze tested two-slope value sources before observations')


def index(out):
    save(out/'FILES.json', [{'path':p.relative_to(out).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())}
        for p in sorted(out.rglob('*')) if p.is_file() and p != out/'FILES.json'])


def run(repo, engine, out, work):
    require(not out.exists() and not work.exists(), 'NO_RERUN')
    out.mkdir(parents=True); work.mkdir(parents=True)
    head = git(repo,'rev-parse','HEAD')
    t = {'status':'INCONCLUSIVE','source_head':head,'stages':{},'packages_admitted':0,'p9_certified':False}
    try:
        for n, v in load(repo/HERE/'FREEZE.json')['source_sha256'].items():
            require(sha((repo/HERE/relative(n)).read_bytes()) == v, 'FROZEN_SOURCE')
        c = load(repo/HERE/'CONTRACT.json'); validate_contract(c)
        require(sha(engine.read_bytes()) == ENGINE, 'ENGINE_IDENTITY')
        old, one, value, base, reader, bootstrap = dependencies(repo)
        projects, protocols = setup(repo, work, out, old, one, c)
        workers = min(4, len(os.sched_getaffinity(0))); require(workers > 0, 'CPU_AFFINITY')
        save(out/'VENUE.json', {'worker_processes':workers,'available_cpu_affinity':len(os.sched_getaffinity(0)),
                                'runner_class':'ubuntu-24.04','engine_sha256':ENGINE})
        head = publish(repo, head, [out], 'research(p9): preserve exact two-slope adaptive worlds before observations')
        base.command([str(engine),'--version'],out,'engine-version')
        t['qualification'] = old.qualify(projects, engine, out/'qualification', base)
        head = publish(repo, head, [out], 'research(p9): preserve two-slope adaptive entry and all-on parity')
        for vow in (5,0):
            folder = out/f'v{vow}'; folder.mkdir()
            for world in R.WORLDS: (folder/world).mkdir()
            specs = [(w,R.config(i,vow)) for i in range(0,128,2) for w in R.WORLDS]
            costs = {w:0. for w in R.WORLDS}
            for offset in range(0,len(specs),8):
                tasks = specs[offset:offset+8]
                with ThreadPoolExecutor(max_workers=workers) as pool:
                    receipts = list(pool.map(lambda x:value.cell(x[1],projects[x[0]],engine,folder/x[0],protocols[x[0]],base,reader),tasks))
                for (world,_), receipt in zip(tasks,receipts):
                    if receipt['status'] == 'COMPLETE': costs[world] += receipt['cpu']['user']+receipt['cpu']['system']
                save(folder/'COST-PROGRESS.json',costs)
                head = publish(repo,head,[out],f'research(p9): preserve two-slope Hand V{vow} matched group {offset//8+1}')
                require(all(r['status']=='COMPLETE' for r in receipts),'INCOMPLETE_ASSIGNED_CELL')
                require(R.resource_ok(costs),'WORLD_RESOURCE_CEILING')
            result = R.stage(folder,protocols,vow,reader,value.read_value.validate_extra,bootstrap)
            save(folder/'RESULTS.json',result); t['stages'][str(vow)] = result
            head = publish(repo,head,[out],f'research(p9): record complete two-slope Hand V{vow} primary decision')
            transition = R.next_stage(result,vow)
            if transition == 'CLOSE_NOT_ESTABLISHED':
                t.update(status=R.NEGATIVE,last_vow=vow,v0_skipped=vow==5); break
        else: t['status'] = R.SUPPORTED
    except Exception as exc: t['failure'] = repr(exc)
    finally:
        save(out/'TERMINAL.json',t); index(out)
        publish(repo,head,[out],'research(p9): preserve two-slope Hand terminal and every captured byte')
        print(json.dumps(t,indent=2))
    return 3 if t['status']=='INCONCLUSIVE' else 0


def verify(repo, original, cold, receipt):
    require(not receipt.exists(),'NO_READBACK_OVERWRITE')
    raw = (original/'FILES.json').read_bytes(); require(raw==(cold/'FILES.json').read_bytes(),'MANIFEST_EQUALITY')
    records = json.loads(raw); names = [r['path'] for r in records]
    require(len(names)==len(set(names)),'DUPLICATE_PATH')
    require({p.relative_to(cold).as_posix() for p in cold.rglob('*') if p.is_file()}==set(names)|{'FILES.json'},'COMPLETE_CAPTURE')
    for r in records:
        p=relative(r['path']); a=(original/p).read_bytes(); b=(cold/p).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'REMOTE_BYTES:'+str(p))
    for n,v in load(repo/HERE/'FREEZE.json')['source_sha256'].items():
        require(sha((repo/HERE/relative(n)).read_bytes())==v,'COLD_FROZEN_SOURCE')
    t=load(cold/'TERMINAL.json')
    old,_,value,_,reader,bootstrap=dependencies(repo)
    if 'qualification' in t:
        require(old.entry_result(cold/'qualification')==t['qualification'],'ENTRY_REPRODUCTION')
    protocols=load(cold/'RESOLVED-PROTOCOLS.json') if t['stages'] else {}
    for vow, expected in t['stages'].items():
        got=R.stage(cold/f'v{vow}',protocols,int(vow),reader,value.read_value.validate_extra,bootstrap)
        require(got==expected==load(cold/f'v{vow}'/'RESULTS.json'),'READOUT_REPRODUCTION')
    if t['status'] != 'INCONCLUSIVE':
        require(list(t['stages']) in (['5'],['5','0']) and 'failure' not in t,'SCIENTIFIC_TERMINAL')
        if '0' in t['stages']: require(t['stages']['5']['pass_all'],'PREMATURE_V0')
        passed = list(t['stages'])==['5','0'] and all(x['pass_all'] for x in t['stages'].values())
        require(t['status']==(R.SUPPORTED if passed else R.NEGATIVE),'TERMINAL_CONJUNCTION')
        if not passed:
            require(t['last_vow']==int(list(t['stages'])[-1]) and t['v0_skipped'] is ('0' not in t['stages']),'STOPPING_RULE')
            require(('0' in t['stages'])==(cold/'v0').exists(),'V0_PRESENCE')
    save(receipt,{'kind':'COMPLETE_TWO_SLOPE_ADAPTIVE_VALUE_COLD_READBACK','published_head':git(repo,'rev-parse','HEAD'),
        'files':len(records)+1,'all_bytes_equal':True,'reproduced_stages':list(t['stages']),
        'scientific_status':t['status'],'new_native_runs':0,'packages_admitted':0,'p9_certified':False})


def close(repo):
    out=repo/HERE/'execution-1'; root=repo/HERE/'closure-1'; require(not root.exists(),'NO_CLOSURE_OVERWRITE')
    t,proof=load(out/'TERMINAL.json'),load(out/'REMOTE-READBACK.json')
    require(proof['all_bytes_equal'] is True and proof['scientific_status']==t['status'],'READBACK_REQUIRED')
    next_action = ('Complete the still-missing descriptor, competent-policy/peer/economy and independent-confirmation evidence before any package admission.' if t['status']==R.SUPPORTED else
        'This exact two-slope/audit-policy value nomination is closed without extension or tuning. Use the complete decision to select only a genuinely unmeasured authorized package obligation; do not reroll seeds or relabel this negative.' if t['status']==R.NEGATIVE else
        'Read the exact recorded delivery/resource failure; preserve complete valid rows. No scientific successor is opened by an inconclusive execution.')
    state=load(repo/SHARED[0]);state.update(status='P9_UNFINISHED_TWO_SLOPE_ADAPTIVE_VALUE_DECIDED',packages_admitted=0,p9_certified=False,
        no_active_research_processes=True,exact_next_action=next_action)
    state['two_slope_hand_adaptive_value']={'terminal':str((HERE/'execution-1/TERMINAL.json').relative_to(Path('research/p9-six-route'))),
        'readback':str((HERE/'execution-1/REMOTE-READBACK.json').relative_to(Path('research/p9-six-route'))),
        'status':t['status'],'stages':t['stages'],'candidate_content_sha256':CONTENT}
    save(repo/SHARED[0],state)
    summary=json.dumps({k:t[k] for k in ('status','stages')},indent=2)
    text='# P9 current handoff — two-slope adaptive-value decision\n\nContinue #421 on `'+BRANCH+'`. Product main is unchanged. Target: three complete strategies per aspect;0/6 certificates. Author self-review is not independent.\n\n'+summary+'\n\nFull exact-source capture and cold-readback: `ash-inheritance-20260909/hand-two-slope-v1/adaptive-value-v1/execution-1/`.\n\nThis is one fixed audit-policy claim, not all Hand policies or P9 impossibility. Sources are one group; outcomes are not selected by realised activation. Earlier linear Hand/Bloodfire, controller and broad-candidate negatives are immutable. Source/query/native and shipping signed-control gates already complete are not rerun. No validation-model refit, protected cohort, new coefficients or controller weights. All older raw gaps remain in SESSION-STATE.\n\nExact next action: '+next_action+'\n\nRemaining: full package causality/descriptor/policy/peer/economy/independent proof; six strategy coverage; seven-direction detector; corrected confirmation and unrestricted retention; all guardrails; minimum lifecycle, exact-head review, one selected product integration and #108 receipt.\n'
    (repo/SHARED[1]).write_text(text)
    (repo/SHARED[2]).write_text('# P9 current outcome roadmap\n\n0/6 full certificates. Latest exact nomination: '+t['status']+'.\n\n1. '+next_action+'\n2. Complete three viable/reachable/distinct strategies per aspect; alternate producers do not create slots.\n3. Detector, corrected independent confirmation, unrestricted retention and all guards.\n4. Minimum lifecycle and one selected exact-product/#108 delivery.\n\nDo not repeat recovery, v25/models, old matrices, old control screens or closed value cohorts.\n')
    root.mkdir();save(root/'DECISION.json',{'status':t['status'],'candidate_content_sha256':CONTENT,'terminal':t,'capture_readback':proof,
        'next_action':next_action,'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_native_runs':0,'packages_admitted':0,'p9_certified':False})
    paths=[repo/HERE/n for n in (*SOURCE_NAMES,'FREEZE.json','source-tests.log')]+[out/'TERMINAL.json',out/'FILES.json',out/'REMOTE-READBACK.json',root/'DECISION.json']+[repo/p for p in SHARED]
    save(root/'FILES.json',[{'path':p.relative_to(repo).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'git_blob':blob(p.read_bytes())} for p in paths])
    publish(repo,git(repo,'rev-parse','HEAD'),[out/'REMOTE-READBACK.json',root]+[repo/p for p in SHARED],
            'research(p9): close verified two-slope value and synchronize current capsule')


def verify_closure(original,cold,receipt):
    require(not receipt.exists(),'NO_RECEIPT_OVERWRITE')
    root=HERE/'closure-1'
    data=(original/root/'FILES.json').read_bytes();require(data==(cold/root/'FILES.json').read_bytes(),'CLOSURE_MANIFEST')
    for r in json.loads(data):
        p=relative(r['path']);a=(original/p).read_bytes();b=(cold/p).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'] and blob(b)==r['git_blob']==git(cold,'rev-parse','HEAD:'+str(p)),'CLOSURE_BYTES')
    save(receipt,{'kind':'TWO_SLOPE_VALUE_CLOSURE_COLD_READBACK','published_head':git(cold,'rev-parse','HEAD'),
        'files':len(json.loads(data)),'all_bytes_equal':True,'new_native_runs':0,'packages_admitted':0,'p9_certified':False})
    publish(original,git(original,'rev-parse','HEAD'),[receipt],'research(p9): record exact cold-readback of two-slope value closure')


if __name__=='__main__':
    action,*args=sys.argv[1:];paths=[Path(x).resolve() for x in args]
    if action=='freeze':freeze(*paths)
    elif action=='run':raise SystemExit(run(*paths))
    elif action=='verify':verify(*paths)
    elif action=='close':close(*paths)
    elif action=='verify-closure':verify_closure(*paths)
    else:raise SystemExit('freeze REPO | run REPO ENGINE OUTPUT WORK | verify COLD_REPO ORIGINAL COLD RECEIPT | close REPO | verify-closure ORIGINAL COLD RECEIPT')
