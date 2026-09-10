"""Offline audit of already-emitted native evidence, not a new admission gate.

Keep the locally frozen source and original RESULTS immutable.  No engine call,
new cohort, model fitting or synthesis of missing native observations occurs.
Usage: python audit_capture.py STUDY_ROOT NEW_OUTPUT_DIRECTORY
"""
from __future__ import annotations
import hashlib
import json
import lzma
from pathlib import Path
import tarfile
import read


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n')


def verify_files(root, entries):
    seen = set()
    for entry in entries:
        path = Path(entry['path'])
        require(not path.is_absolute() and '..' not in path.parts, 'UNSAFE_MANIFEST_PATH')
        require(str(path) not in seen, 'DUPLICATE_MANIFEST_PATH')
        seen.add(str(path))
        data = (root/path).read_bytes()
        require(len(data) == entry['bytes'] and sha(data) == entry['sha256'], 'BYTE_IDENTITY:'+str(path))
    return len(seen)


def groups(root):
    for source in read.SOURCES:
        lines = [json.loads(line) for line in lzma.decompress((root/(source+'.jsonl.xz')).read_bytes()).splitlines()]
        indexed = {}
        for row in lines[1:-1]:
            require(type(row['arm']) is int, 'ARM_TYPE')
            require(type(row['aspect']) is int and type(row['vow']) is int, 'CONTEXT_TYPE')
            require(type(row['up']) is bool, 'UPGRADE_TYPE')
            key = tuple(row[k] for k in read.KEYS)
            arms = indexed.setdefault(key, {})
            require(row['arm'] not in arms, 'DUPLICATE_ARM')
            arms[row['arm']] = row
        for key in sorted(indexed):
            yield source, key, indexed[key]


def stock(state):
    return state['combat']['player']['statuses'].get('bloodfire', 0)


def describe(source, key, arms):
    """Explicit source identity and causal features; not a fitted descriptor."""
    summary = read.check_group(source, key, arms)
    row, no_source = arms[7], arms[5]
    a, c = row['steps']
    require(type(a['ret']) is bool, 'SOURCE_RETURN_TYPE')
    s0, s1 = a['before']['combat'], a['after']['combat']
    before_ids = {x['uid']: x for x in s0['hand']}
    after_ids = {x['uid']: x for x in s1['hand']}
    require(before_ids[900]['id'] == source, 'WRONG_PRODUCER_INSTANCE')
    expected_consumer = 'leechBlade' if source == 'bloodRite' else 'phantomBlades'
    require(before_ids[901]['id'] == expected_consumer, 'WRONG_CONSUMER_INSTANCE')
    drawn = [e['uid'] for e in a['events'] if e.get('t') == 'draw']
    require(len(drawn) == len(set(drawn)), 'DUPLICATE_DRAW_EVENT')
    require(all(uid not in before_ids and uid in after_ids for uid in drawn), 'DRAW_UID_IDENTITY')
    disabled_ids = {x['uid'] for x in no_source['steps'][0]['after']['combat']['hand']}
    if source != 'bloodRite':
        require(set(after_ids)-disabled_ids == set(drawn), 'PRODUCER_DRAW_ATTRIBUTION')
    else:
        require(not drawn, 'ENERGY_SOURCE_IS_NOT_DRAW')
    source_hp = s1['player']['hp']-s0['player']['hp']
    source_energy = s1['player']['energy']-s0['player']['energy']
    source_charge = stock(a['after'])-stock(a['before'])
    if source == 'bloodRite' and a['ret']:
        require(source_hp == -min(3, s0['player']['hp']), 'ORIGINAL_HP_COST_NOT_RETAINED')
        require(sum(e['amount'] for e in a['events'] if e.get('t')=='hitPlayer' and e.get('source')=='self') == 3, 'DECLARED_SELF_HIT_NOT_RETAINED')
        require(source_energy == (0 if s1['over'] else 3 if key[2] else 2), 'ORIGINAL_ENERGY_NOT_RETAINED')
    else:
        require(source_hp == 0, 'HAND_SOURCE_HP_CONFOUND')
    utility_effect = {}
    for m in (0, 2):
        for c_bit in (0, 1):
            low, high = arms[m+c_bit]['steps'][1], arms[4+m+c_bit]['steps'][1]
            utility_effect[f'm{bool(m)}-c{bool(c_bit)}'] = {
                'disabled_consumer_eligible': low['ret'], 'enabled_consumer_eligible': high['ret'],
                'cross_energy_payoff_identified': low['ret'] is True and high['ret'] is True}
    e_on = read.interaction(arms, True)
    all_on, no_m = read.payoff(c), read.payoff(no_source['steps'][1])
    example = {'source':source, 'aspect':key[0], 'vow':key[1], 'upgraded':key[2], 'context':key[3],
        'producer_uid':900, 'consumer_uid':901, 'consumer_id':expected_consumer, 'target_idx':0,
        'source_eligible':a['ret'], 'source_net_hp_delta':source_hp,
        'source_net_energy_delta':source_energy, 'source_bloodfire_created':source_charge,
        'source_drawn_uids':drawn, 'source_exhausted':any(e.get('t')=='exhaust' and e.get('uid')==900 for e in a['events']),
        'post_source_embers':s1['embers'],
        'consumer_eligible':c['ret'], 'consumer_entry_bloodfire':stock(c['before']),
        'consumer_entry_hand_uids':list(after_ids),
        'source_drawn_uids_present_at_consumer_entry':[uid for uid in drawn if uid in after_ids],
        'controlled_commands_between_source_and_consumer':0,
        'bloodfire_consumed_in_consumer':sum(-e['n'] for e in c['events'] if e.get('t')=='status' and e.get('id')=='bloodfire' and e['n']<0),
        'all_on_payoff':all_on, 'source_mediator_disabled_payoff':no_m,
        'interaction_with_energy_on':e_on, 'interaction_with_energy_off':read.interaction(arms,False),
        'energy_eligibility_effects':utility_effect,
        'necessary_proxy_without_source_causality':summary['necessary_activation_is_not_causal_witness'],
        'descriptor_status':'CONSTRUCTED_CAUSAL_FIELDS_ONLY_NOT_CLASSIFICATION_VALIDATION'}
    if all_on['eligible'] and no_m['eligible']:
        example['incremental_player_hp_at_consumer'] = all_on['player_hp_delta']-no_m['player_hp_delta']
        example['healing_without_additional_actual_hp_removal'] = (all_on['actual_hp_removed'] == no_m['actual_hp_removed'] and all_on['healing_events'] > no_m['healing_events'])
    else:
        example['incremental_player_hp_at_consumer'] = None
        example['healing_without_additional_actual_hp_removal'] = False
    return example


def audit(root, out):
    root, out = Path(root), Path(out)
    require(not out.exists(), 'OUTPUT_EXISTS')
    execution = root/'execution-1'
    frozen = json.loads((root/'FREEZE.json').read_bytes())
    for name, expected in frozen['source_sha256'].items():
        require(sha((root/name).read_bytes()) == expected, 'FROZEN_SOURCE:'+name)
    manifest = json.loads((execution/'FILES.json').read_bytes())
    count = verify_files(execution, manifest)
    runtime = json.loads((execution/'RUNTIME-MANIFEST.json').read_bytes())
    with tarfile.open(execution/'runtime-source.tar.xz', 'r:xz') as tf:
        members = tf.getmembers()
        require(len(members) == len(runtime) and {m.name for m in members} == set(runtime), 'RUNTIME_COVERAGE')
        for member in members:
            p = Path(member.name)
            require(member.isfile() and not p.is_absolute() and '..' not in p.parts, 'UNSAFE_ARCHIVE_MEMBER')
            b = tf.extractfile(member).read()
            require(sha(b) == runtime[member.name]['sha256'] and len(b) == runtime[member.name]['bytes'], 'RUNTIME_BYTES:'+member.name)
    result = read.read(execution, frozen['source_sha256'])
    rendered = (json.dumps(result, indent=2)+'\n').encode()
    require(rendered == (execution/'RESULTS.json').read_bytes(), 'ORIGINAL_READOUT_NOT_REPRODUCED')
    descriptions = [describe(*g) for g in groups(execution)]
    examples = [r for r in descriptions if r['aspect']==1 and r['vow']==0 and not r['upgraded'] and r['context'] in ('available','no_energy','empty_draw','already_lethal')]
    undefined = sum(not r[k]['identified_for_fixed_commands'] for r in descriptions for k in ('interaction_with_energy_on','interaction_with_energy_off'))
    findings = {
        'kind':'OFFLINE_AUTHOR_AUDIT_NOT_PACKAGE_ADMISSION',
        'scope':'Same captured 192 constructed fixtures. No new native invocation or independence claim.',
        'status':'FROZEN_CAPTURE_AND_SOURCE_UTILITY_FINDINGS_REPRODUCED',
        'frozen_source_files':len(frozen['source_sha256']), 'manifest_entries_verified':count,
        'runtime_members_verified':len(runtime), 'original_result_sha256':sha(rendered),
        'constructed_descriptor_records':len(descriptions),
        'undefined_fixed_command_contrasts_retained':undefined,
        'necessary_hand_pattern_without_source_draw_causality':sum(r['necessary_proxy_without_source_causality'] for r in descriptions),
        'healing_without_additional_actual_hp_removal':sum(r['healing_without_additional_actual_hp_removal'] for r in descriptions),
        'examples':examples,
        'limits':['The public planning preview of switched effects is NOT qualified; the probe uses externally fixed commands only.',
                  'No adaptive policy, source substitution, trained descriptor, held-out prediction or population effect was evaluated.',
                  'The immutable historical support rule remains necessary-only; these findings neither retroactively change its gate nor admit a package.',
                  'Local source freeze and local readback are not remote publication or trusted external timing/provenance.',
                  'Only the enumerated contexts were executed; universal modifiers, relic and lifecycle coverage are not claimed.'],
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
        'new_native_runs':0, 'new_independent_samples':0, 'packages_admitted':0,
        'p9_certified':False, 'remote_preserved':False}
    out.mkdir(parents=True)
    dump(out/'CAUSAL-FIELDS.json',descriptions)
    dump(out/'REVIEW.json',findings)
    return findings


if __name__ == '__main__':
    import sys
    print(json.dumps(audit(*sys.argv[1:]),indent=2))
