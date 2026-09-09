"""Offline full-capture checker for the frozen native-role contract.

The symbolic identities refer to the declared surviving-target/plain context.
Full native state/queue equality, costs and scopes are checked separately.
No new primitive, full historical quotient, population or P9 claim is emitted.
"""
from __future__ import annotations
from collections import Counter
import hashlib
import itertools
import json
import lzma
from pathlib import Path
import sys


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def trace(row):
    return {k: v for k, v in row.items() if k != 'config'}


def hit_removed(step):
    hp = {e['idx']: max(0, e['hp']) for e in step['before']['view']['targets']}
    removed = poison = nominal = 0
    for event in step['events']:
        if event['t'] == 'hitEnemy':
            i = event['idx']; amount = event['amount']
            require(amount >= 0 and i in hp, 'damage identity')
            clipped = min(hp[i], amount)
            removed += clipped; nominal += amount
            if event.get('poison'):
                poison += clipped
            hp[i] = max(0, hp[i] - amount)
            require(hp[i] == event['hpAfter'], 'hit HP closure')
        elif event['t'] == 'heal' and event['who'] != 'player':
            require(event['who'] in hp, 'heal target')
            hp[event['who']] += event['n']
    require(hp == {e['idx']: max(0, e['hp']) for e in step['after']['view']['targets']}, 'step health accounting')
    return dict(removed=removed, nominal=nominal, poison=poison)


def full_view(snapshot):
    """Check the convenience view against every corresponding reflected field."""
    index = {}
    def visit(v):
        if isinstance(v, dict):
            if 'object' in v:
                require(v['object'] not in index, 'reflected alias collision')
                index[v['object']] = v
            for child in v.values(): visit(child)
        elif isinstance(v, list):
            for child in v: visit(child)
    visit(snapshot['full'])
    def resolve(v):
        return index[v['ref']] if isinstance(v, dict) and set(v) == {'ref'} else v
    run, combat, returned = map(resolve, snapshot['full'])
    player = resolve(combat['player']); v = snapshot['view']
    expect = dict(energy=player['energy'], player_hp=player['hp'], statuses=player['statuses'],
        hand=[{k:resolve(c)[k] for k in ('uid','id','up')} for c in combat['hand']],
        targets=[{k:resolve(e)[k] for k in ('idx','hp','block','statuses','chips','staggered','facet_max')} for e in combat['enemies']],
        turn=combat['turn'], over=combat['over'], embers=combat['embers'],
        attacks=combat['counters_attacks'], played=combat['counters_played'],
        exhaust_uids=[resolve(c)['uid'] for c in combat['exhaust']],
        discard_uids=[resolve(c)['uid'] for c in combat['discard']])
    require(v == expect, 'view disagrees with full reflected state')
    return run, combat, returned


def key(cfg):
    return tuple(cfg[k] for k in ('family','aspect','vow','up','context','mask'))


def check_rows(rows, contract):
    header = next(rows)
    require(header['kind'] == 'header', 'header')
    require(header['engine'] == '4.7.2-stable (official)', 'engine')
    for field in ('content_sha256', 'combat_sha256'):
        require(header[field] == contract[field], field)
    for name in ('probe','roles'):
        require(header[name+'_sha256'] == contract['source_sha256'][name+'.gd'], name)
    expected = set(itertools.product(contract['families'], (0,1), (0,5), (False,True), contract['contexts'], (-1,0,1,2,3)))
    data = {}; counts = Counter(); failures = []; plain = []
    def claim(ok, label):
        counts['claims'] += 1
        if not ok: failures.append(label)
    for row in rows:
        cfg = row['config']; k = key(cfg)
        require(row['kind'] == 'case' and k in expected and k not in data, 'assignment coverage')
        data[k] = row
        counts['rows'] += 1
        for s in [row['initial'], row['before_reset'], row['after_reset']] + [s for step in row['steps'] for s in (step['before'], step['after'])]:
            full_view(s); counts['checked_snapshots'] += 1
        previous = row['initial']
        for i, step in enumerate(row['steps']):
            require(step['before'] == previous, 'step continuity')
            _, cb, _ = full_view(step['before']); _, acb, ret = full_view(step['after'])
            if not step['permitted']:
                require(i == len(row['steps']) - 1 and not row['complete'], 'blocked prefix is partial')
                require(step['after'] == step['before'] and not step['events'], 'blocked state changed')
                counts['blocked_prefixes'] += 1
            else:
                require(acb['queue'] == cb['queue'] + step['events'], 'complete queue closure')
                hit_removed(step)
                if step['command']['t'] == 'playCard':
                    require(ret is True and step['ret'] is True, 'native legal return')
                    # All declared carrier costs are one; no discount source is installed.
                    require(step['after']['view']['energy'] == step['before']['view']['energy'] - 1, 'cost preservation')
            previous = step['after']
        require(row['before_reset'] == previous, 'final binding')
        for source in ('empower','flurry') if cfg['family']=='fervor' else ('venomStrike','catalyst'):
            require(any(source in cards for cards in row['pools'].values()), 'declared mature pool availability')
        claim(row['after_reset']['view']['statuses'].get('str',0) == 0, str(k)+':new-combat player reset')
    require(set(data) == expected, 'incomplete finite rectangle')
    for family, aspect, vow, up, context in itertools.product(contract['families'], (0,1), (0,5), (False,True), contract['contexts']):
        prefix = (family,aspect,vow,up,context)
        r = {m:data[prefix+(m,)] for m in (-1,0,1,2,3)}
        claim(trace(r[-1]) == trace(r[0]), str(prefix)+':stock/off exact full trace')
        counts['stock_off_pairs'] += 1
        scoped = (family=='fervor' and aspect==0) or (family=='smolder' and aspect==1)
        if not scoped:
            for m in (1,2,3):
                claim(trace(r[-1]) == trace(r[m]), str(prefix)+':other-aspect mask'+str(m))
                counts['other_aspect_pairs'] += 1
        if context=='dormant':
            claim(trace(r[0]) == trace(r[2]), str(prefix)+':zero-mediator exact amplifier null')
            counts['dormant_pairs'] += 1
        if context=='plain' and scoped:
            consumer = {m:r[m]['steps'][1] for m in (0,1,2,3)}
            if family=='fervor':
                y = {m:hit_removed(s)['removed'] for m,s in consumer.items()}
                interaction = y[0]-y[1]-y[2]+y[3]
                expected_i = 2*(3 if up else 2)
                claim(interaction == expected_i, str(prefix)+':per-additional-hit interaction')
                claim(all(len([e for e in s['events'] if e['t']=='hitEnemy'])==3 for s in consumer.values()), str(prefix)+':topology')
                for m in (0,1,2,3):
                    s = consumer[m]
                    claim(s['before']['view']['statuses'].get('str',0) == s['after']['view']['statuses'].get('str',0), str(prefix)+':not-consumed')
            else:
                y = {m:s['after']['view']['targets'][0]['statuses'].get('poison',0) for m,s in consumer.items()}
                interaction = y[0]-y[1]-y[2]+y[3]
                expected_i = (5 if up else 4)*((3 if up else 2)-1)
                claim(interaction == expected_i, str(prefix)+':stock multiplication interaction')
                for m,s in consumer.items():
                    claim(not any(e['t']=='hitEnemy' for e in s['events']), str(prefix)+':not-immediate-damage')
                    claim(901 in s['after']['view']['exhaust_uids'], str(prefix)+':consumer-exhaust')
                    # This fixture has no Ember modification except native exhaustion.
                    claim(s['after']['view']['embers'] == s['before']['view']['embers']+1, str(prefix)+':native-Ember')
                ticks = {m:hit_removed(r[m]['steps'][2])['poison'] for m in (0,1,2,3)}
                claim(ticks == y, str(prefix)+':next-phase-poison')
            plain.append({'family':family,'vow':vow,'up':up,'payoff_unit':'consumer_HP' if family=='fervor' else 'target_stock_then_next_phase_HP','factor_values':y,'interaction':interaction,'expected':expected_i})
    return {'status':'MINIMAL_NATIVE_ROLE_CONTRACT_CHECKED_NOT_ADMITTED' if not failures else 'MINIMAL_NATIVE_ROLE_CONTRACT_CLAIM_FAIL',
        'counts':dict(counts),'failures':failures,'plain_factorial':plain,
        'source_disposition':'Inherited native player-inventory/readout and target-inventory/amplifier compositions. No new primitive or complete closed-family quotient has been proved.',
        'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}


def main(raw, contract_file):
    p = Path(raw); c = Path(contract_file)
    contract = json.loads(c.read_bytes())
    opener = lzma.open if p.suffix=='.xz' else open
    with opener(p, 'rt') as f:
        result = check_rows((json.loads(line) for line in f if line.strip()),contract)
    result['raw_sha256'] = sha(lzma.decompress(p.read_bytes()) if p.suffix=='.xz' else p.read_bytes())
    result['contract_sha256'] = sha(c.read_bytes())
    return result


if __name__ == '__main__':
    print(json.dumps(main(sys.argv[1],sys.argv[2]),indent=2))
