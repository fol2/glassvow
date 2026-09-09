"""Retrospective full-rectangle Smolder attribution; never runs the game.
A possible lineage is an upper bound. A clean direct chain is a factual stock
witness, not an intervention, damage outcome, inactivity or package certificate.
"""
from __future__ import annotations
import hashlib, importlib.util, json, lzma
from collections import Counter
from pathlib import Path


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def lines(path):
    with lzma.open(path, 'rt', encoding='utf-8') as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


def enemies(view):
    result = {e['idx']: e for e in view['enemies']}
    require(len(result) == len(view['enemies']), 'DUPLICATE_ENEMY_ID')
    return result


def poison_events(events):
    return [e for e in events if e.get('t') == 'status'
            and e.get('id') == 'poison' and type(e.get('who')) is int]


class Lineage:
    """Overapproximation carried in native target identity, with conservative jumps."""
    def __init__(self):
        self.possible = set()
        self.clean = {}
        self.fight = -1
        self.witnesses = []
        self.possible_consumers = []
        self.reasons = Counter()
        self.consumers = 0

    def command(self, item):
        cmd, events = item['command'], item['events']
        before, after = enemies(item['before']), enemies(item['after'])
        if cmd['t'] == 'startCombat':
            require(item['fight'] == self.fight + 1, 'FIGHT_SEQUENCE')
            self.fight = item['fight']
            self.possible.clear()
            self.clean.clear()
        require(item['fight'] == self.fight, 'FIGHT_BINDING')
        # Zero total stock is the only safe negative provenance reset between fights.
        self.possible = {i for i in self.possible if i in before and before[i]['poison'] > 0}
        self.clean = {i: v for i, v in self.clean.items()
                      if i in before and before[i]['poison'] == v['stock'] and before[i]['hp'] > 0}
        valid_play = cmd['t'] == 'playCard' and item['ret'] is True
        card = item['card'] if valid_play else ''
        target = cmd.get('target')
        ps = poison_events(events)
        transfer = any(e.get('t') in ('die', 'shatter', 'smolderJump', 'finaleHandoff') for e in events)
        end = cmd['t'] == 'endTurn' or any(e.get('t') == 'endTurn' for e in events)
        if card == 'catalyst':
            self.consumers += 1
            require(target in before and before[target]['hp'] > 0, 'CONSUMER_TARGET')
            q = before[target]['poison']
            deltas = [e['n'] for e in ps if e['who'] == target and e['n'] > 0]
            if q > 0:
                require(len(deltas) == 1 and deltas[0] in (q, 2*q), 'AMPLIFIER_EVENT_LAW')
                multiplier = 1 + deltas[0] // q
                copies = [c for c in item['before']['deck'] if c['uid'] == cmd['uid']]
                require(len(copies) <= 1, 'CONSUMER_INSTANCE_AMBIGUOUS')
                if copies:
                    require(copies[0]['id'] == card and multiplier == (3 if copies[0]['up'] else 2),
                            'CONSUMER_UPGRADE_BINDING')
                if target in self.possible:
                    self.possible_consumers.append({'fight': self.fight, 'sequence': item['sequence'],
                                                    'target': target, 'stock': q})
                else:
                    self.reasons['positive_stock_without_possible_venom_lineage'] += 1
                if (target in self.clean and not transfer and not end and len(ps) == 1
                    and target in after and after[target]['poison'] == q + deltas[0]
                    and after[target]['hp'] == before[target]['hp']):
                    source = self.clean[target]
                    self.witnesses.append({'fight': self.fight,
                        'producer_sequence': source['sequence'], 'consumer_sequence': item['sequence'],
                        'producer_uid': source['uid'], 'consumer_uid': cmd['uid'], 'target': target,
                        'source_stock': source['stock'], 'multiplier': multiplier,
                        'amplifier_added_stock': deltas[0], 'consumer_hp_change':
                        after[target]['hp'] - before[target]['hp']})
            else:
                require(not deltas, 'EMPTY_MEDIATOR_AMPLIFIED')
                self.reasons['empty_consumer_stock'] += 1
        # A named source may be generated rather than in the permanent deck.
        # Its positive event is sufficient for a conservative possibility, not an exact role claim.
        additions = [e for e in ps if e['n'] > 0]
        source_additions = [e for e in additions if card == 'venomStrike' and e['who'] == target]
        if source_additions:
            self.possible.add(target)
        had_possible = bool(self.possible)
        if transfer and had_possible:
            self.possible.update(i for i, e in after.items() if e['hp'] > 0 and e['poison'] > 0)
            self.reasons['conservative_transfer_command'] += 1
        # Other additions, decay, jump and death destroy *clean* attribution, not possible attribution.
        if transfer or end:
            self.clean.clear()
        else:
            for e in ps:
                self.clean.pop(e['who'], None)
        if card == 'venomStrike' and not transfer and not end and len(source_additions) == len(ps) == 1:
            e = source_additions[0]
            copies = [c for c in item['before']['deck'] if c['uid'] == cmd['uid'] and c['id'] == card]
            if len(copies) == 1:
                amount = 5 if copies[0]['up'] else 4
                if (target in before and before[target]['poison'] == 0 and target in after
                    and after[target]['hp'] > 0 and e['n'] == amount and after[target]['poison'] == amount):
                    self.clean[target] = {'sequence': item['sequence'], 'uid': cmd['uid'], 'stock': amount}
            else:
                self.reasons['source_instance_not_in_recorded_permanent_deck'] += 1
        self.possible = {i for i in self.possible if i in after and after[i]['hp'] > 0 and after[i]['poison'] > 0}
        self.clean = {i: v for i, v in self.clean.items()
                      if i in after and after[i]['hp'] > 0 and after[i]['poison'] == v['stock']}


def read_trace(path, expected):
    result, state, current, sequence = {}, None, None, 0
    for item in lines(path):
        key = item['row_key']
        require(key in expected, 'UNASSIGNED_TRACE')
        if key != current:
            require(current is None or current in result, 'UNFINISHED_ROW')
            require(key not in result, 'REOPENED_ROW')
            current, sequence, state = key, 0, Lineage()
        if item['kind'] == 'row_end':
            require(key not in result and item['commands'] == sequence, 'TRACE_CLOSURE')
            old = expected[key]
            result[key] = dict(old, clean_direct_stock_witness=bool(state.witnesses),
                source_attributed_possible=bool(state.possible_consumers), witnesses=state.witnesses,
                possible_consumers=state.possible_consumers, consumer_commands=state.consumers,
                reasons=dict(sorted(state.reasons.items())))
            require(not result[key]['source_attributed_possible'] or old['potential_chain'],
                    'NEW_UPPER_BOUND_EXCEEDS_OLD_BOUND')
        else:
            require(item['kind'] == 'command' and key not in result and item['sequence'] == sequence,
                    'COMMAND_SEQUENCE')
            state.command(item)
            sequence += 1
    require(set(result) == set(expected), 'MISSING_TRACE_ROW')
    return result


def summarize(rows, vow):
    require(len(rows) == 512, 'COMPLETE_RECTANGLE')
    by_policy = {i: [r for r in rows if r['policy_index'] == i] for i in range(128)}
    for rs in by_policy.values():
        require(sorted(r['seed'] for r in rs) == list(range(73209100, 73209104)), 'POLICY_SEEDS')
    selected = lambda field: [i for i, rs in by_policy.items() if any(r[field] for r in rs)]
    possible = selected('source_attributed_possible')
    winning = [i for i, rs in by_policy.items() if any(r['source_attributed_possible'] and r['outcome'] == 'win' for r in rs)]
    surviving = len(possible) >= 32 and len(winning) >= 16
    return {'vow': vow, 'rows': 512, 'policies': 128,
        'old_potential_policies': selected('potential_chain'),
        'source_attributed_possible_policies': possible,
        'winning_possible_policies': winning,
        'clean_direct_stock_witness_policies': selected('clean_direct_stock_witness'),
        'direct_witnesses': sum(len(r['witnesses']) for r in rows),
        'status': 'SOURCE_ATTRIBUTED_CAPACITY_NOT_FALSIFIED_NOT_ADMISSION' if surviving
                  else 'FIXED_NATIVE_SUPPLIER_SOURCE_ATTRIBUTED_UPPER_BOUND_INSUFFICIENT',
        'clean_absence_is_not_inactivity': True, 'hp_causal_effect_identified': False,
        'new_native_runs': 0, 'new_independent_samples': 0, 'packages_admitted': 0, 'p9_certified': False}


def main(repo, out):
    repo, out = Path(repo), Path(out)
    require(not out.exists(), 'OUTPUT_EXISTS')
    cap = repo/'research/p9-six-route/minimal-native-20260909/capacity'
    protocol = json.loads((cap/'PROTOCOL.json').read_bytes())
    for name, digest in protocol['source_sha256'].items():
        require(sha((cap/name).read_bytes()) == digest, 'CAPACITY_SOURCE:'+name)
    spec = importlib.util.spec_from_file_location('retained_capacity_reader', cap/'read.py')
    reader = importlib.util.module_from_spec(spec); spec.loader.exec_module(reader)
    terminal = json.loads((cap/'native-1/TERMINAL.json').read_bytes())
    require(terminal['status'] == 'FIXED_NATIVE_POLICY_CAPACITY_COMPLETE_NOT_ADMISSION', 'UPSTREAM_TERMINAL')
    out.mkdir(parents=True)
    receipts, summaries = {}, []
    for vow in (5, 0):
        rows = []
        for first in range(0, 128, 32):
            folder = cap/f'native-1/ashwarden-v{vow}/p{first:03}'
            for name in ('CONFIG.json', 'endpoints.ndjson.xz', 'trace.ndjson.xz', 'EXECUTION.json'):
                path = folder/name; b = path.read_bytes()
                rel = str(path.relative_to(cap/'native-1')); wanted = terminal['files'][rel]
                require(len(b) == wanted['bytes'] and sha(b) == wanted['sha256'], 'RAW_BYTES:'+rel)
                receipts[str(path.relative_to(repo))] = wanted
            cfg = reader.config('ashwarden', vow, first, 32)
            cell = reader.cell(folder, cfg, protocol)
            expected = {f"{r['policy_index']}:{r['seed']}": r for r in cell['rows']}
            derived = read_trace(folder/'trace.ndjson.xz', expected)
            rows.extend(derived.values())
        summary = summarize(rows, vow); summaries.append(summary)
        (out/f'v{vow}-ROWS.json').write_text(json.dumps(rows, indent=2)+'\n')
    result = {'kind': 'RETAINED_TRACE_SOURCE_ATTRIBUTION_NOT_CERTIFICATION', 'grids': summaries,
              'inputs': receipts, 'review': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
              'full_closed_family_quotient_established': False, 'new_native_runs': 0,
              'new_independent_samples': 0, 'packages_admitted': 0, 'p9_certified': False}
    (out/'RESULTS.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'source_attribution': summaries}, sort_keys=True))

if __name__ == '__main__':
    import sys
    main(*sys.argv[1:])
