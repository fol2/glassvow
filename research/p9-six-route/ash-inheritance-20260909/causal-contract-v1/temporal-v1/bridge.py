"""Bind the existing whole-run fields to temporal occurrence evidence, without games.
One pre-existing positive provenance row is a diagnostic witness, never a sample.
No census, policy/query replay, model fit, changed primary or certificate follows.
"""
from __future__ import annotations
import ast
import hashlib
import io
import json
import lzma
from pathlib import Path
import subprocess
import tarfile

HEAD = '05d9def6f9105ae8c6b839f355017b6222e60de4'
BASE = 'research/p9-six-route/ash-inheritance-20260909/'
TEMP = BASE + 'causal-contract-v1/temporal-v1/'
OLD = BASE + 'hand-adaptive-v1/'
POP = BASE + 'joint-controller-v1/execution-1/'
LEGACY_BLOB = 'f41337fb6a0ea7fa91a0e2ede26ebf0670cd724b'
POP_MANIFEST = 'cc2081e21e7c603ef0624e399aeaab978a63f9d6'
CONTENT = '4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9'
SOURCES = {'preparation', 'surge'}


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
def integer(x):
    require(type(x) is int, 'INTEGER_REQUIRED')
    return x


def hand(cards):
    result = {}
    for card in cards:
        uid = integer(card['uid'])
        require(uid not in result, 'DUPLICATE_HAND')
        result[uid] = card
    return result


class Tracker:
    """Observed draw occurrences only; no counterfactual or predictive attribution."""
    def __init__(self):
        self.origins = {}
        self.key = None
        self.fight = None
        self.sequence = 0
        self.prior = None

    def take(self, row, coefficient, fields):
        require(integer(coefficient) >= 0, 'NEGATIVE_COEFFICIENT')
        key, seq, fight = row['row_key'], integer(row['sequence']), integer(row['fight'])
        require(self.key is None or key == self.key, 'ONE_COMPLETE_RUN_PER_TRACKER')
        require(seq == self.sequence, 'SEQUENCE')
        self.key = key
        self.sequence += 1
        before, after = hand(row['before']['hand']), hand(row['after']['hand'])
        require(self.prior is None or list(before) == self.prior, 'HAND_CONTINUITY')
        if fight != self.fight:
            self.origins = {}
            self.fight = fight
        self.origins = {u: o for u, o in self.origins.items() if u in before}
        cmd = row['command']
        played = cmd['t'] == 'playCard'
        uid = integer(cmd['uid']) if played else None
        if played:
            require(uid in before and before[uid]['id'] == row['card'], 'PLAY_IDENTITY')
            require(row['ret'] is True, 'REJECTED_ACTION_NOT_ZERO')
        result = None
        if played and row['card'] == 'phantomBlades':
            old = fields(row['before']['hand'], uid, coefficient,
                         {u: o['source_card'] for u, o in self.origins.items()})
            retained = [dict(held_uid=u, **self.origins[u]) for u in before
                        if u != uid and u in self.origins
                        and self.origins[u]['source_card'] in SOURCES]
            result = {'row_key': key, 'sequence': seq, 'fight': fight,
                      'consumer_uid': uid, 'legacy_fields': old,
                      'retained_producer_occurrences': retained,
                      'consumer_draw_occurrence': dict(self.origins[uid]) if uid in self.origins else None,
                      'scope': 'Observed ancestry, not marginal HP or whole-run causal value.'}
        if cmd['t'] in ('endTurn', 'startCombat'):
            self.origins = {}
        exhausted = False
        for index, event in enumerate(row['events']):
            kind = event.get('t')
            if kind in ('play', 'toDiscard', 'exhaust') and 'uid' in event:
                self.origins.pop(integer(event['uid']), None)
            if kind == 'exhaust':
                exhausted = True
            if kind == 'discardHand':
                self.origins = {}
            if kind == 'draw':
                drawn = integer(event['uid'])
                # Exactly the qualified legacy boundary: direct effects precede Exhaust.
                direct = played and row['card'] in SOURCES and not exhausted
                self.origins[drawn] = {
                    'source_card': row['card'] if direct else 'background',
                    'producer_uid': uid if direct else None,
                    'birth_sequence': seq, 'birth_event_index': index, 'birth_fight': fight}
        self.origins = {u: o for u, o in self.origins.items() if u in after}
        self.prior = list(after)
        return result


def functions(data, names, constants=None):
    """Execute only named, hash-bound pure function definitions, not archive tooling."""
    tree = ast.parse(data)
    selected = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    require({n.name for n in selected} == set(names), 'FUNCTION_COVERAGE')
    env = dict(constants or {})
    exec(compile(ast.Module(body=selected, type_ignores=[]), '<bound-pure-functions>', 'exec'), env)
    return env


def run(repo, out):
    repo, out = Path(repo).resolve(), Path(out).resolve()
    require(not out.exists(), 'NO_OUTPUT_OVERWRITE')
    inputs = []
    def get(path, maximum=16 * 1024 * 1024):
        require(not path.startswith('/') and '..' not in Path(path).parts, 'PATH')
        size = int(subprocess.check_output(['git', '-C', str(repo), 'cat-file', '-s', HEAD+':'+path]))
        require(size <= maximum, 'INPUT_RESOURCE_LIMIT')
        b = subprocess.check_output(['git', '-C', str(repo), 'show', HEAD+':'+path])
        require(len(b) == size, 'GIT_OBJECT_SIZE')
        inputs.append({'path': path, 'bytes': len(b), 'sha256': sha(b), 'git_blob': blob(b)})
        return b
    old = get(OLD+'descriptor.py')
    require(blob(old) == LEGACY_BLOB, 'LEGACY_IMPLEMENTATION')
    legacy = functions(old, {'require', 'hand_ids', 'draws', 'fields'}, {'SOURCES': SOURCES})
    check = get(TEMP+'check.py')
    freeze = json.loads(get(TEMP+'FREEZE.json'))
    require(sha(check) == freeze['source_sha256']['check.py'], 'QUALIFIED_TEMPORAL_READER')
    native = functions(check, {'require', 'integer', 'hand', 'useful_hp', 'descriptor'})
    receipt = json.loads(get(TEMP+'REPAIR-READBACK.json'))
    require(receipt['all_bytes_equal'] and receipt['readout_reproduced'], 'TEMPORAL_READBACK')
    packed = get(TEMP+'execution-2/raw.jsonl.xz')
    results = json.loads(get(TEMP+'execution-2/RESULTS.json'))
    require(sha(packed) == results['compressed_sha256'], 'CAPTURE_BYTES')
    raw = lzma.decompress(packed)
    require(len(raw) == results['raw_bytes'] and sha(raw) == results['raw_sha256'], 'RAW_BYTES')
    records = [json.loads(line) for line in raw.splitlines()]
    require(len(records[1:-1]) == 360 and records[-1] == {'kind':'terminal','rows':360}, 'COMPLETE_TEMPORAL_CAPTURE')
    require(records[0]['content_sha256'] == CONTENT, 'TEMPORAL_CONTENT')
    compared = 0
    for index, row in enumerate(records[1:-1]):
        tracker = Tracker(); actual = []
        for seq, step in enumerate(row['steps']):
            cards = hand(step['before']['combat']['hand'])
            uid = step['command'].get('uid')
            compact = dict(row_key=str(index), sequence=seq, fight=0,
                           card=cards[uid]['id'] if step['command']['t']=='playCard' else '',
                           command=step['command'], ret=step['ret'], events=step['events'],
                           before={'hand': list(cards.values())},
                           after={'hand': step['after']['combat']['hand']})
            coefficient = (4 if row['up'] else 3) if row['arm'] == -1 or row['arm'] & 1 else 0
            item = tracker.take(compact, coefficient, legacy['fields'])
            if item: actual.append(item)
        expected = native['descriptor'](row['steps'])
        require(len(actual) == len(expected), 'CONSUMER_COVERAGE')
        for a, e in zip(actual, expected):
            require(sorted(x['held_uid'] for x in a['retained_producer_occurrences']) == e['surviving_source_uids'], 'NATIVE_OCCURRENCE_BRIDGE')
            require(a['legacy_fields']['retained_hand_instances'] == e['hand_units_read'], 'NATIVE_HAND_BRIDGE')
            require(all(x['producer_uid'] == 900 and x['birth_sequence'] == 0 for x in a['retained_producer_occurrences']), 'PRODUCER_INSTANCE_BINDING')
            compared += 1
    require(compared == 440, 'NATIVE_CONSUMER_COUNT')
    # Bind one previously observed source-positive witness, not another census.
    dm = json.loads(get(OLD+'descriptor-1/FILES.json'))
    fields_bytes = get(OLD+'descriptor-1/FIELDS.jsonl', 8*1024*1024)
    entry = next(r for r in dm if r['path'] == 'FIELDS.jsonl')
    require(sha(fields_bytes) == entry['sha256'] and len(fields_bytes) == entry['bytes'], 'FIELD_CAPTURE')
    coverage_bytes = get(OLD+'descriptor-1/RUN-COVERAGE.json')
    entry = next(r for r in dm if r['path'] == 'RUN-COVERAGE.json')
    require(sha(coverage_bytes) == entry['sha256'] and len(coverage_bytes) == entry['bytes'], 'PUBLISHED_RUN_COVERAGE')
    coverage = json.loads(coverage_bytes)
    witness = next(r for r in map(json.loads, fields_bytes.splitlines())
                   if sum(r['retained_direct_source_instances'].values()) > 0)
    vow, policy, seed = map(int, witness['row_key'].split(':'))
    require(vow == 5 and 0 <= policy < 128 and 73414100 <= seed < 73414104, 'WITNESS_ASSIGNMENT')
    pm_bytes = get(POP+'FILES.json'); require(blob(pm_bytes) == POP_MANIFEST, 'POPULATION_MANIFEST')
    pm = {r['path']: r for r in json.loads(pm_bytes)}
    archive = get(POP+'runtime-source.tar.xz')
    require(sha(archive) == pm['runtime-source.tar.xz']['sha256'] and len(archive) == pm['runtime-source.tar.xz']['bytes'], 'WHOLE_RUN_RUNTIME')
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:xz') as tf:
        member = tf.getmember('aware/content/full-content.json')
        require(member.isfile(), 'CONTENT_MEMBER')
        require(sha(tf.extractfile(member).read()) == CONTENT, 'SAME_CONTENT_NOT_ASSUMED')
        combat = tf.getmember('aware/domain/rules/combat.gd')
        require(combat.isfile() and sha(tf.extractfile(combat).read()) == records[0]['combat_sha256'], 'SAME_NATIVE_COMBAT_NOT_ASSUMED')
    rel = f'v5/aware/v5-{policy//2*2:03d}.traces.jsonl.xz'
    capture = get(POP+rel, 64*1024*1024)
    require(sha(capture) == pm[rel]['sha256'] and len(capture) == pm[rel]['bytes'], 'DIAGNOSTIC_CAPTURE')
    tracker = Tracker(); origins = {}; items = []; commands = 0; found = False; fight = None
    with lzma.open(io.BytesIO(capture), 'rt') as lines:
        for line in lines:
            row = json.loads(line)
            if row['row_key'] != witness['row_key']:
                if found: break
                continue
            found = True
            require(row['kind'] == 'command' and row['original_untouched_by_clones'] is True, 'ORIGINAL_CAPTURE')
            if row['fight'] != fight: origins = {}; fight = row['fight']
            before = hand(row['before']['hand']); uid = row['command'].get('uid')
            coefficient = 4 if uid in before and before[uid].get('up', False) else 3
            item = tracker.take(row, coefficient, legacy['fields'])
            if item:
                prior = legacy['fields'](row['before']['hand'], uid, coefficient, origins)
                require(item['legacy_fields'] == prior, 'UNCHANGED_EXISTING_FIELDS')
                items.append(item)
            legacy['draws'](row['events'], row['card'], row['ret'] is True, origins)
            after = hand(row['after']['hand']); origins = {u:s for u,s in origins.items() if u in after}
            commands += 1
    require(commands == coverage[witness['row_key']]['commands'] and len(items) == coverage[witness['row_key']]['phantom_plays'], 'COMPLETE_SELECTED_RUN')
    selected = next(x for x in items if x['sequence'] == witness['sequence'])
    require(selected['retained_producer_occurrences'], 'DECLARED_WITNESS_PRESENT')
    require(selected['legacy_fields']['retained_direct_source_uids'] == witness['retained_direct_source_uids'], 'PUBLISHED_WITNESS_IDENTITY')
    out.mkdir(parents=True)
    result = {'status':'TEMPORAL_TO_EXISTING_WHOLE_RUN_FIELDS_BOUND_NOT_CERTIFICATE',
              'input_head': HEAD, 'content_sha256': CONTENT, 'combat_sha256': records[0]['combat_sha256'],
              'native_trajectories_reused':360,
              'native_consumer_records_compared':compared, 'selected_existing_row':witness['row_key'],
              'selection':'First source-positive row in the immutable existing field publication; exposed diagnostic only.',
              'whole_run_commands_read':commands, 'whole_run_consumers_compared':len(items),
              'new_native_runs':0, 'new_population_runs':0, 'new_independent_samples':0,
              'packages_admitted':0, 'p9_certified':False,
              'review_kind':'SELF_REVIEW_NOT_INDEPENDENT',
              'limits':['No replay of the 512-run census or any controller/query qualification.',
                        'Observed producer ancestry is not marginal HP, predictive validity, reachability frequency or policy value.',
                        'No transport to nonlinear consumer content or revised verdict for a closed nomination.']}
    for name, value in [('RESULTS.json',result), ('SELECTED-WITNESS.json',selected), ('INPUTS.json',inputs), ('RUN-FIELDS.json',items)]:
        (out/name).write_text(json.dumps(value,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return result

if __name__ == '__main__':
    import sys
    run(*sys.argv[1:])
