"""Full retained-capture diagnosis, never a new support or statistical study.

Only the completed one-sample assignment is read. No engine, tuning, selection,
protected outcomes, policy intervention, or retrospective threshold change.
"""
from __future__ import annotations
from collections import Counter, defaultdict
from decimal import Decimal
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path('research/p9-six-route')
BASE = ROOT / 'ash-inheritance-20260909'
STUDY = BASE / 'planner-v1/one-sample-v1'
INPUT_HEAD = 'a4b2c318efacc17f2d003a684064dea12f1519f8'
BLOBS = {
    'TERMINAL.json': '95b13f32f886f6300293fce3061103a4ad5e36e3',
    'REMOTE-READBACK.json': 'ff4098353ccbb076d6c9451597a5ffa2f5ed3c30',
    'FILES.json': '62a45de75261e6eba1517438c646aefaa7e63108',
}


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def load(path):
    return json.loads(path.read_bytes())


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def features(row, flag):
    require(row['row_key'] == flag['row_key'], 'FLAG_IDENTITY')
    events = row['row']['packageEvents']
    deck = set(row['row']['deckIds'])
    # Native packageEvents is a sparse bump-counter map. Missing counters are
    # zero events, not absent measurement fields; the enclosing map is required.
    def count(key):
        value = events.get(key, 0)
        require(type(value) is int and value >= 0, 'EVENT_COUNTER:' + key)
        return value
    both = {'bloodRite', 'leechBlade'} <= deck
    return {
        'source_offered': count('bloodRiteOffered') > 0,
        'consumer_offered': count('leechBladeOffered') > 0,
        'both_roles_offered_in_same_run': count('bloodRiteOffered') > 0 and count('leechBladeOffered') > 0,
        'source_in_final_deck': 'bloodRite' in deck,
        'consumer_in_final_deck': 'leechBlade' in deck,
        'both_in_final_deck': both,
        'source_played': count('bloodRitePlayed') > 0,
        'consumer_played': count('leechBladePlayed') > 0,
        'bloodfire_applied': flag['applied'] > 0,
        'bloodfire_consumed': flag['consumed'] > 0,
        'registered_active': flag['bloodfire'],
        'registered_reachable': flag['reachable_bloodfire'],
        'incremental_hp': flag['bloodfire_incremental_hp'],
        'both_owned_but_not_active': both and not flag['bloodfire'],
        'won_and_bloodfire_active': row['row']['outcome'] == 'win' and flag['bloodfire'],
        'won_and_hand_active': row['row']['outcome'] == 'win' and flag['hand'],
    }


def summarize_terminal(terminal):
    require(terminal['status'] == 'FIXED_PLANNER_VALUE_OR_SUPPORT_NOT_ESTABLISHED', 'WRONG_TERMINAL')
    t = terminal['population_terminal']
    require(set(t['stages']) == {'5'} and t['v0_skipped'] is True, 'UNEXPECTED_STAGE')
    stage = t['stages']['5']
    phases = [stage[k] for k in ('value-screen', 'reserved-configuration-check')]
    require(all(x['pass'] is True and x['resource_ceiling_met'] is True for x in phases), 'VALUE_OR_COST_NOT_PASSED')
    costs = {m: str(sum((Decimal(str(x['costs'][m]['process_cpu_seconds'])) for x in phases), Decimal(0))) for m in ('stock', 'planner')}
    require(all(Decimal(x) <= 3600 for x in costs.values()), 'COST_OVER_LIMIT')
    require(stage['support_pass'] is False, 'SUPPORT_NOT_NEGATIVE')
    return {'terminal': terminal['status'], 'cpu_seconds': costs,
            'wins': {m: sum(x[m + '_wins'] for x in phases) for m in ('stock', 'planner')},
            'value_pass': True, 'resource_pass': True, 'support_pass': False,
            'support': {m: stage['support'][m]['packages'] for m in ('stock', 'planner')},
            'v0_opened': False}


def audit(repo, out):
    repo, out = Path(repo).resolve(), Path(out).resolve()
    require(not out.exists(), 'OUTPUT_EXISTS_NO_REWRITE')
    capture = repo / STUDY / 'execution-2'
    for name, expected in BLOBS.items():
        require(blob((capture / name).read_bytes()) == expected, 'INPUT_BLOB:' + name)
    rb = load(capture / 'REMOTE-READBACK.json')
    require(rb['all_bytes_equal'] and rb['qualification_reproduced'] and rb['population_reproduced'], 'INPUT_NOT_VERIFIED')
    manifest = load(capture / 'FILES.json')
    require(len({x['path'] for x in manifest}) == len(manifest), 'DUPLICATE_INPUT_PATH')
    for entry in manifest:
        rel = Path(entry['path'])
        require(not rel.is_absolute() and '..' not in rel.parts, 'INPUT_PATH')
        data = (capture / rel).read_bytes()
        require(len(data) == entry['bytes'] and sha(data) == entry['sha256'], 'INPUT_BYTES:' + str(rel))
    path = repo / BASE / 'pair-v1/read_pair.py'
    require(blob(path.read_bytes()) == '51f606a1f9370b14bc6b28f236ae78a7ed2806fb', 'READER_IDENTITY')
    spec = importlib.util.spec_from_file_location('frozen_pair', path)
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    population = capture / 'population'
    protocols = load(population / 'RESOLVED-PROTOCOLS.json')
    terminal = load(capture / 'TERMINAL.json')
    decision = summarize_terminal(terminal)
    out.mkdir(parents=True)
    reports = {}
    for method in ('stock', 'planner'):
        p = protocols[method]
        require(p['policies'] == 128 and p['policies_per_cell'] == 2 and p['seeds'] == [73412100,73412101,73412102,73412103], 'ASSIGNMENT')
        folder = population / 'v5' / method
        support = reader.analyze(folder, p, 5)
        require(support == load(population / 'v5' / (method + '-support.json')), 'SUPPORT_RECONSTRUCTION')
        require(support['packages'] == decision['support'][method], 'TERMINAL_SUPPORT_BINDING')
        flags = {r['row_key']: r for r in support['row_results']}
        rows = []
        counts = Counter()
        policy_sets = defaultdict(set)
        for first in range(0, 128, 2):
            cfg = {'root':p['policy_root'], 'first':first, 'count':2, 'seeds':p['seeds'], 'vow':5, 'integration':False}
            for row in reader.outcome_records(folder / (f'v5-{first:03d}.outcomes.jsonl.xz'), cfg, p):
                f = features(row, flags[row['row_key']])
                require(all(type(v) is bool for v in f.values()), 'FEATURE_TYPES')
                for key, value in f.items():
                    counts[key] += int(value)
                    if value:
                        policy_sets[key].add(row['index'])
                rows.append({'row_key':row['row_key'], 'index':row['index'], 'seed':row['seed'], **f})
        require(len(rows) == len({r['row_key'] for r in rows}) == 512, 'FULL_RECTANGLE')
        require(len(policy_sets['registered_active']) == support['packages']['bloodfire']['active'], 'ACTIVE_RECONCILIATION')
        save(out / (method + '-rows.json'), rows)
        reports[method] = {'row_counts':dict(counts), 'policy_counts':{k:len(policy_sets[k]) for k in counts},
                           'policy_sets':{k:sorted(policy_sets[k]) for k in counts},
                           'row_file_sha256':sha((out / (method + '-rows.json')).read_bytes())}
    result = {'kind':'COMPLETE_ONE_SAMPLE_BOTTLENECK_DIAGNOSIS', 'input_head':INPUT_HEAD,
              'input_manifest_sha256':sha((capture / 'FILES.json').read_bytes()), 'input_files_verified':len(manifest),
              'decision':decision, 'methods':reports,
              'limits':['Offers do not prove affordability or optimal selection.',
                        'Final co-ownership, anytime co-ownership and enacted consumption are distinct observations.',
                        'Policy counts OR together four runs; they are not independent seed replications.',
                        'This descriptive audit does not identify the causal effect of an acquisition change.',
                        'The closed one-sample nomination is not rescued by this readout.'],
              'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT', 'new_native_runs':0,
              'new_independent_samples':0, 'packages_admitted':0, 'p9_certified':False}
    save(out / 'RESULTS.json', result)
    print(json.dumps({'decision':decision, 'policy_counts':{m:r['policy_counts'] for m,r in reports.items()}}, indent=2))


class Tests(unittest.TestCase):
    def sample(self):
        return ({'row_key':'5:0:1','row':{'packageEvents':{},'deckIds':[], 'outcome':'loss'}},
                {'row_key':'5:0:1','applied':0,'consumed':0,'bloodfire':False,'hand':False,
                 'reachable_bloodfire':False,'bloodfire_incremental_hp':False})

    def test_sparse_counters_are_not_ownership(self):
        r,f=self.sample();r['row']['packageEvents']={'bloodRiteOffered':1,'leechBladeOffered':2}
        x=features(r,f);self.assertTrue(x['both_roles_offered_in_same_run']);self.assertFalse(x['both_in_final_deck'])

    def test_ownership_is_not_activation(self):
        r,f=self.sample();r['row']['deckIds']=['bloodRite','leechBlade']
        self.assertTrue(features(r,f)['both_owned_but_not_active'])

    def test_flag_identity(self):
        r,f=self.sample();f['row_key']='other'
        with self.assertRaisesRegex(ValueError,'IDENTITY'):features(r,f)

    def test_missing_measurement_map_rejected(self):
        r,f=self.sample();del r['row']['packageEvents']
        with self.assertRaises(KeyError):features(r,f)

    def test_bad_counter_rejected(self):
        r,f=self.sample();r['row']['packageEvents']['bloodRiteOffered']=-1
        with self.assertRaisesRegex(ValueError,'COUNTER'):features(r,f)

    def test_boolean_counter_rejected(self):
        r,f=self.sample();r['row']['packageEvents']['bloodRiteOffered']=True
        with self.assertRaisesRegex(ValueError,'COUNTER'):features(r,f)


if __name__ == '__main__':
    if sys.argv[1:] == ['--self-test']:
        unittest.main(argv=[sys.argv[0]], verbosity=2)
    else:
        audit(*sys.argv[1:])
