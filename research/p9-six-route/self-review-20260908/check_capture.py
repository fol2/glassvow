"""Fail-closed offline reconciliation of the immutable enactment capture.

Adds state/event arithmetic and assignment checks; does not execute Godot, change
raw evidence, invent independent review, or admit packages. Python -O is rejected
because the historical envelope reader uses assert statements.
"""
from pathlib import Path
import copy
import hashlib
import io
import json
import sys
import tarfile

if not __debug__:
    raise RuntimeError('Optimized Python disables the historical verifier; refused')
R = Path(__file__).resolve().parent
sys.path.insert(0, str(R.parent / 'natural-enactment-20260908'))
import read_enactment as old

CONSUMER = dict(facet='resonantLance', fervor='flurry', cycle='momentum',
                smolder='catalyst', hand='phantomBlades')
PRODUCER = dict(facet='chisel', fervor='empower', cycle='momentum',
                smolder='venomStrike', hand='nightSight')

def require(ok, label):
    if not ok:
        raise ValueError(label)

def load():
    files, manifest = old.unpack(old.R, 'RAW-MANIFEST.json', 'raw.parts')
    folder = old.R.parent / 'source-package-audit-20260908'
    meta = json.loads((folder / 'ACQUISITION-WITNESSES.json').read_bytes())
    chunks = []
    for part in meta['parts']:
        data = (folder / 'acquisition.parts' / part['file']).read_bytes()
        require(len(data) == part['bytes'] and old.sha(data) == part['sha256'], 'acquisition part')
        require(hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest() == part['git_blob'], 'acquisition blob')
        chunks.append(data)
    archive = b''.join(chunks)
    require(len(archive) == meta['archive_bytes'] and old.sha(archive) == meta['archive_sha256'], 'acquisition archive')
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:xz') as tf:
        members = tf.getmembers()
        require(all(m.isfile() for m in members), 'acquisition non-file')
        require(len({m.name for m in members}) == len(members), 'duplicate acquisition member')
        audit = {m.name: tf.extractfile(m).read() for m in members}
    require(old.sha(audit['INDEX.json']) == meta['index_sha256'], 'acquisition index')
    require(files['source/PROTOCOL.json'] == (old.R / 'PROTOCOL.json').read_bytes(), 'outer frozen protocol')
    return files, audit

def objects(value):
    out = {}
    def visit(x):
        if isinstance(x, dict):
            if 'object' in x:
                require(x['object'] not in out, 'duplicate projected object')
                out[x['object']] = x
            for v in x.values():
                visit(v)
        elif isinstance(x, list):
            for v in x:
                visit(v)
    visit(value)
    return out

def resolve(x, index):
    if isinstance(x, dict) and set(x) == {'ref'}:
        require(x['ref'] in index, 'dangling projected reference')
        return index[x['ref']]
    return x

def state(projection):
    require(isinstance(projection, list) and len(projection) == 3, 'state shape')
    index = objects(projection)
    run, cb, ret = [resolve(x, index) for x in projection]
    enemies = [resolve(e, index) for e in cb['enemies']]
    require(len({e['idx'] for e in enemies}) == len(enemies), 'duplicate enemy index')
    return run, cb, ret, index, {e['idx']: e for e in enemies}

def accounting(before, arm, route, target):
    _, _, _, _, enemies = state(before)
    _, _, ret, _, after = state(arm['after'])
    require(ret is True and arm['ret'] is True, 'projected return')
    hp = {k: max(0, e['hp']) for k, e in enemies.items()}
    poison_before = sum(e['statuses'].get('poison', 0) for e in enemies.values())
    if route == 'smolder' and arm['m'] == 0:
        poison_before -= enemies[target]['statuses'].get('poison', 0)
    nominal = removed = 0
    for ev in arm['events']:
        if ev['t'] == 'hitEnemy':
            k, n = ev['idx'], ev['amount']
            require(k in hp and isinstance(n, (int, float)) and n >= 0, 'hit domain')
            nominal += n
            removed += min(hp[k], n)
            hp[k] = max(0, hp[k] - n)
            require(hp[k] == ev['hpAfter'], 'event health reconciliation')
        elif ev['t'] == 'heal' and ev.get('who') != 'player':
            k, n = ev['who'], ev['n']
            require(k in hp and n >= 0, 'heal domain')
            hp[k] += n
    require(hp == {k: max(0, e['hp']) for k, e in after.items()}, 'final health reconciliation')
    poison = sum(e['statuses'].get('poison', 0) for e in after.values()) - poison_before
    expected = dict(hp_removed=removed, nominal_damage=nominal, poison_added=poison)
    for key, value in expected.items():
        require(arm[key] == value, 'arithmetic:' + key)
    return expected

def check(files, audit):
    original = old.analyze(files, audit)
    protocol = json.loads(files['source/PROTOCOL.json'])
    require(old.sha(audit['INDEX.json']) == protocol['original_acquisition_index_sha256'], 'protocol acquisition identity')
    receipt = json.loads(files['evidence/receipt.json'])
    evidence = {n.removeprefix('evidence/') for n in files if n.startswith('evidence/')}
    require(set(receipt['files']) == evidence - {'receipt.json', 'ASSEMBLY-NOTE.txt'}, 'receipt file coverage')
    for name, data in files.items():
        if name.endswith('.log'):
            require(not any(s in data for s in (b'SCRIPT ERROR', b'Parse Error', b'ERROR:')), 'log diagnostic')
    rows = [json.loads(line) for line in files['evidence/native.ndjson'].splitlines()]
    temporal = []
    for w in (x for x in rows if x['kind'] == 'witness'):
        run, cb, _, ix, enemies = state(w['before'])
        route, cmd, producer = w['route'], w['cmd'], w['producer']
        require(run['aspect'] == {'duskblade': 0, 'ashwarden': 1}[w['aspect']], 'aspect context')
        require(run['vow'] == w['vow'] and run['seed'] == w['seed'], 'run context')
        require(cb['turn'] == w['turn'], 'turn context')
        require(cmd['t'] == 'playCard', 'consumer command')
        hand = [resolve(c, ix) for c in cb['hand']]
        matches = [c for c in hand if c['uid'] == cmd['uid']]
        require(len(matches) == 1 and matches[0]['id'] == CONSUMER[route], 'consumer identity')
        card = matches[0]
        player = resolve(cb['player'], ix)
        target = cmd['target']
        require(target in enemies, 'consumer target')
        if route == 'cycle': mediator = card['bonus']
        elif route == 'fervor': mediator = player['statuses'].get('str', 0)
        elif route == 'hand': mediator = max(0, len(hand) - 1 - 4)  # exact frozen candidate reserve
        elif route == 'smolder': mediator = enemies[target]['statuses'].get('poison', 0)
        else: mediator = int(enemies[target]['staggered'] or enemies[target]['statuses'].get('vulnerable', 0) > 0)
        require(mediator > 0, 'positive mediator')
        index = producer['command_index']
        require(type(index) is int and 0 <= index < len(w['commands']), 'producer prefix index')
        require(producer['card'] == PRODUCER[route], 'producer identity')
        require(producer['uid'] == producer['cmd']['uid'], 'producer uid')
        require(producer['cmd']['t'] == 'playCard', 'producer command')
        require(1 <= producer['turn'] <= w['turn'], 'producer turn')
        require(sum(c['cmd']['t'] == 'startCombat' for c in w['commands']) == 1, 'single battle prefix')
        for arm in w['arms']:
            accounting(w['before'], arm, route, target)
        # Do not silently promote a historical producer event to causal persistence.
        temporal.append(dict(aspect=w['aspect'], vow=w['vow'], seed=w['seed'], route=route,
                             producer_turn=producer['turn'], consumer_turn=w['turn'],
                             intervening_turns=w['turn'] - producer['turn'],
                             full_chain_necessity_proved=False))
    return dict(status='CAPTURE_RECONCILED_NOT_PACKAGE_ADMISSION', review_kind='SELF_REVIEW_NOT_INDEPENDENT',
                source_measurement_head='46401783b39ada692ce9b990f9deda342b79e7dd',
                native_sha256=original['native_sha256'], checked_witnesses=len(temporal),
                arithmetic_recomputed_arms=4 * len(temporal), requested_contexts=12,
                new_native_runs=0, new_independent_samples=0, temporal_scope=temporal,
                limitations=['Factual live parity is a source-bound native assertion; raw contains no second live post-state.',
                             'Cross-turn producer registration is temporal, not proof that its mediator survived to the consumer.',
                             'Selected runs, arithmetic and self-review do not establish canonical novelty, subset necessity, population support or P9.'])

if __name__ == '__main__':
    result = check(*load())
    print(json.dumps(result, indent=2))
