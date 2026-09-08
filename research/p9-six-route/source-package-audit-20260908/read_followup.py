"""Reconstruct finite locality and observer-coverage evidence; no native runs."""
from pathlib import Path
import collections, hashlib, io, itertools, json, re, tarfile
R = Path(__file__).resolve().parent

def sha(data):
    return hashlib.sha256(data).hexdigest()

def blob(data):
    return hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()

def unpack(root, name, directory):
    m = json.loads((root / name).read_bytes())
    parts = []
    for item in m['parts']:
        b = (root / directory / item['file']).read_bytes()
        assert len(b) == item['bytes'] and sha(b) == item['sha256'] and blob(b) == item['git_blob']
        parts.append(b)
    archive = b''.join(parts)
    assert len(archive) == m['archive_bytes'] and sha(archive) == m['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:xz') as tf:
        members = tf.getmembers()
        assert len(members) == len(m['files']) and all(x.isfile() for x in members)
        files = {x.name: tf.extractfile(x).read() for x in members}
    assert set(files) == set(m['files'])
    for name, data in files.items():
        assert len(data) == m['files'][name]['bytes'] and sha(data) == m['files'][name]['sha256']
    return files, m

def rows(data):
    return [json.loads(line) for line in data.splitlines()]

def strip_projection(value):
    if isinstance(value, dict):
        return {k: strip_projection(v) for k, v in value.items()
                if k not in ('state_sha256', 'state_events_sha256')}
    if isinstance(value, list):
        return [strip_projection(x) for x in value]
    return value

def analyze(files, original, root=R):
    for name, data in files.items():
        if name.endswith(('.log', '.stdout', '.stderr')):
            assert not any(s in data for s in (b'SCRIPT ERROR', b'Parse Error', b'ERROR:'))
    for name in ('locality/receipt.json', 'locality/full-receipt.json'):
        receipt = json.loads(files[name])
        assert receipt['returncode'] == 0 and 0 <= receipt['elapsed_seconds'] < 120
        for n, item in receipt['files'].items():
            assert len(files['locality/' + n]) == item['bytes']
            assert sha(files['locality/' + n]) == item['sha256']
    for x in json.loads(files['state-coverage/receipts.json']):
        assert x['returncode'] == 0 and 0 <= x['elapsed_seconds'] < 120
        assert x['protocol_sha256'] == sha(files['state-coverage/COVERAGE-PROTOCOL.json'])
        assert sha(files['state-coverage/' + x['name'] + '.ndjson']) == x['output_sha256']
        for suffix in ('stdout', 'stderr'):
            assert sha(files['state-coverage/' + x['name'] + '.' + suffix]) == x[suffix + '_sha256']
    protocol = json.loads(files['locality/LOCALITY-PROTOCOL.json'])
    repair = json.loads(files['locality/OBSERVATION-REPAIR.json'])
    coverage_protocol = json.loads(files['state-coverage/COVERAGE-PROTOCOL.json'])
    receipt = json.loads(files['locality/receipt.json'])
    assert receipt['protocol_sha256'] == sha(files['locality/LOCALITY-PROTOCOL.json'])
    assert receipt['engine_sha256'] == protocol['engine_sha256']
    receipt = json.loads(files['locality/full-receipt.json'])
    assert receipt['observation_repair_sha256'] == sha(files['locality/OBSERVATION-REPAIR.json'])
    assert repair['original_protocol_sha256'] == sha(files['locality/LOCALITY-PROTOCOL.json'])
    assert repair['unchanged_content_sha256'] == protocol['content_sha256']
    assert repair['cases'] == protocol['cases'] == 60
    assert repair['changed_inputs_or_expected_payoffs'] is False and repair['new_independent_samples'] == 0
    assert sha(files['locality/test_locality.gd']) == protocol['source_sha256']['test_locality.gd']
    for relative in ('locality/LOCALITY-PROTOCOL.json', 'locality/OBSERVATION-REPAIR.json',
                     'state-coverage/COVERAGE-PROTOCOL.json'):
        assert (root / relative).read_bytes() == files[relative]
    old = rows(files['locality/native.ndjson'])
    new = rows(files['locality/full-native.ndjson'])
    assert len(old) == len(new) == 62
    assert new[-1] == {'kind': 'summary', 'checks': 60, 'failures': 0}
    for header in (old[0], new[0]):
        assert header['kind'] == 'manifest' and header['engine'] == '4.7.2-stable (official)'
        assert header['content_sha256'] == protocol['content_sha256']
        assert header['combat_sha256'] == protocol['source_sha256']['domain/rules/combat.gd']
    assert old[0]['script_sha256'] == protocol['source_sha256']['test_locality.gd']
    assert old[0]['fixture_sha256'] == protocol['source_sha256']['test_package_nulls.gd']
    assert new[0]['script_sha256'] == repair['updated_test_sha256']
    assert new[0]['fixture_sha256'] == repair['updated_fixture_sha256']
    assert new[0]['projection_sha256'] == repair['existing_projection_sha256']
    assert old[1:] == [{k: v for k, v in x.items() if k not in ('before_fields', 'after_fields')} for x in new[1:]]
    expected = {(a, route, up, op) for a, routes in [(0, ('facet', 'fervor', 'cycle')),
                (1, ('smolder', 'hand', 'cycle'))] for route in routes for up in (False, True)
                for op in protocol['operations']}
    cells = new[1:-1]
    keys = [(x['aspect'], x['route'], x['up'], x['op']) for x in cells]
    assert len(set(keys)) == 60 and set(keys) == expected
    grouped = collections.defaultdict(dict)
    for x in cells:
        assert x['ret'] is True
        before, after = x['before_fields'][1], x['after_fields'][1]
        enemy0, enemy1 = before['enemies'][0], after['enemies'][0]
        assert enemy0['staggered'] == (x['op'] != 'target_reset')
        assert enemy0['statuses']['poison'] == (0 if x['op'] == 'target_reset' else 4)
        assert before['player']['statuses']['str'] == (0 if x['op'] == 'strength_reset' else 3)
        assert len(before['hand']) == (5 if x['op'] == 'hand_trim' else 7)
        consumer = next(card for card in before['hand'] if card.get('uid') == 900)
        assert consumer['bonus'] == (0 if x['op'] == 'copy_reset' else (17 if x['up'] else 14))
        assert x['hp_removed'] == enemy0['hp'] - enemy1['hp']
        assert x['poison_added'] == enemy1['statuses']['poison'] - enemy0['statuses']['poison']
        payoff = x['poison_added'] if x['route'] == 'smolder' else x['hp_removed']
        target = protocol['expected_payoff_order_by_base_and_upgrade'][x['route']][int(x['up'])]
        assert payoff == target[protocol['operations'].index(x['op'])]
        grouped[(x['aspect'], x['route'], x['up'])][x['op']] = payoff
    signatures, pairs = [], []
    for (a, route, up), outcomes in sorted(grouped.items()):
        values = [outcomes[k] for k in protocol['operations']]
        delta = [values[0] - v for v in values[1:]]
        signatures.append({'aspect': a, 'route': route, 'up': up, 'payoffs': values,
                           'deltas': delta, 'dependency_mask': [int(v != 0) for v in delta]})
    for a, up in itertools.product((0, 1), (False, True)):
        subset = [s for s in signatures if s['aspect'] == a and s['up'] == up]
        for left, right in itertools.combinations(subset, 2):
            assert left['dependency_mask'] != right['dependency_mask']
            pairs.append([a, up, left['route'], right['route']])
    coverage = rows(files['state-coverage/coverage.ndjson'])
    mutations = [x for x in coverage if x['kind'] == 'coverage']
    expected_fields = {'ember_cap', 'art_used_turn', 'kindled_turn', 'kindles_this_turn',
        'pending_chips_active', 'counters_played', 'counters_attacks', 'first_card_played',
        'hp_lost', 'prism_procd', 'finale_handoff', 'enemy.staggered', 'enemy.elite',
        'enemy.boss', 'enemy.flags', 'enemy.last_moves', 'pending_chips'}
    assert len(mutations) == 17 and {x['field'] for x in mutations} == expected_fields
    assert coverage[0]['content_sha256'] == protocol['content_sha256']
    assert coverage[0]['test_sha256'] == coverage_protocol['source_sha256']['test_coverage.gd']
    assert sha(files['state-coverage/test_coverage.gd']) == coverage[0]['test_sha256']
    assert coverage[0]['projection_sha256'] == repair['existing_projection_sha256']
    assert all(x['fixture_omits_change'] and x['full_observes_change'] and
               x['before_sha256'] != x['after_sha256'] for x in mutations)
    assert coverage[-1] == {'kind': 'summary', 'checks': 17, 'failures': 0}
    inventory = next(x['script_fields'] for x in coverage if x['kind'] == 'inventory')
    assert len(inventory) == 6
    source = root.parents[2]
    for name, observed in inventory.items():
        text = (source / (name.removeprefix('res://') if name else 'domain/state/run_state.gd')).read_text()
        if name:
            declared = set(re.findall(r'^var\s+(\w+)\s*:', text, re.M)) - {'queue'}
        else:
            text = text.split('class Player:\n', 1)[1].split('\n\n\nvar seed:', 1)[0]
            declared = set(re.findall(r'^\tvar\s+(\w+)\s*:', text, re.M))
        assert set(observed) == declared
    reexam = rows(files['state-coverage/reexam.ndjson'])
    initial = rows(original['native.ndjson'])
    assert len(reexam) == len(initial) == 174
    assert reexam[0]['test_sha256'] == coverage_protocol['source_sha256']['test_package_nulls.gd']
    assert reexam[0]['engine'] == '4.7.2-stable (official)'
    assert reexam[0]['content_sha256'] == protocol['content_sha256']
    for key, name in [('legacy_sha256', 'diagnostic_rules.gd'),
                      ('selective_sha256', 'selective_fervor.gd'),
                      ('combat_sha256', 'domain/rules/combat.gd')]:
        assert reexam[0][key] == coverage_protocol['source_sha256'][name]
    assert reexam[-1] == {'kind': 'summary', 'checks': 677, 'failures': 0,
                          'legacy_dormant_mismatches': 24, 'selective_dormant_mismatches': 0}
    assert strip_projection(reexam[1:]) == strip_projection(initial[1:])
    return {'status': 'FINITE_LOCALITY_AND_OBSERVER_REPAIR_COMPLETE_NOT_P9',
            'content_sha256': protocol['content_sha256'], 'locality_cases': 60,
            'new_population_or_protected_samples': 0, 'locality_replay_equal_rows': 60,
            'operations': protocol['operations'][1:], 'signatures': signatures,
            'within_aspect_distinct_mask_pairs': pairs,
            'omitted_field_mutations_detected': 17, 'declared_fields_matched': sum(map(len, inventory.values())),
            'reexam_assertions': 677, 'non_projection_rows_unchanged': 173,
            'limits': ['Finite constructed interventions are not legal acquisition histories or population support.',
                       'State-dependency masks are not a new fingerprint model or the seven-direction P9 detector.',
                       'No complete canonical quotient, proper-subset, whole-run selectivity or endpoint-retention admission.',
                       'Reflected script fields exclude append-only queue; emitted events are compared separately.',
                       'Observer repair retains prior raw and does not create fresh independent samples.',
                       'No refit, product change, protected cohort or P9 certificate.']}

def read(root=R):
    root = Path(root)
    files, _ = unpack(root, 'FOLLOWUP-MANIFEST.json', 'followup.parts')
    original, _ = unpack(root, 'NATIVE-MANIFEST.json', 'native.parts')
    return analyze(files, original, root)

if __name__ == '__main__':
    result = read()
    data = json.dumps(result, indent=2) + '\n'
    p = R / 'FOLLOWUP-RESULTS.json'
    if p.exists():
        assert p.read_text() == data, 'Existing publication differs; do not overwrite'
    else:
        p.write_text(data)
    print(result['status'], result['locality_cases'], result['omitted_field_mutations_detected'], result['reexam_assertions'])
