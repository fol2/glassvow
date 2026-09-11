"""Add factual Phantom snapshots without changing any existing observation field.
The legacy observer and native rules stay authoritative; this is not a detector.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

LEGACY_BLOB = 'f1a60da814b2eff8b5c10bc7d2ce29e00d12268f'
EXTRA = ('phantom_factual_before', 'phantom_factual_after')


def need(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()


def patch(data):
    need(blob(data) == LEGACY_BLOB, 'EXACT_LEGACY_OBSERVER')
    text = data.decode('utf-8')
    anchors = (
        ('\tvar before: Dictionary = compact()\n',
         '\tvar before: Dictionary = compact()\n\tvar phantom_before: Dictionary = snapshot(self) if card == "phantomBlades" else {}\n'),
        ('\t\t"original_untouched_by_clones":untouched, "factual_clone_match":factual_match}))',
         '\t\t"original_untouched_by_clones":untouched, "factual_clone_match":factual_match,\n'
         '\t\t"phantom_factual_before":phantom_before,\n'
         '\t\t"phantom_factual_after":snapshot(self) if not phantom_before.is_empty() else {}}))'))
    for old, new in anchors:
        need(text.count(old) == 1, 'UNIQUE_PATCH_ANCHOR')
        text = text.replace(old, new, 1)
    # The inverse establishes that the ONLY edits are two new field expressions.
    reverse = text
    for old, new in reversed(anchors):
        need(reverse.count(new) == 1, 'INVERSE_ANCHOR')
        reverse = reverse.replace(new, old, 1)
    need(reverse.encode() == data, 'EXACT_INVERSE')
    return text.encode('utf-8')


def projection(row):
    need(all(k in row for k in EXTRA), 'MISSING_SNAPSHOT_FIELD')
    return {k:v for k,v in row.items() if k not in EXTRA}


def validate_extension(old, new, truth=None):
    need(set(new) == set(old) | set(EXTRA), 'ONLY_DECLARED_ADDITIONS')
    need(projection(new) == old, 'LEGACY_TRACE_DRIFT')
    before, after = (new[k] for k in EXTRA)
    if old['card'] != 'phantomBlades':
        need(before == after == {}, 'NON_PHANTOM_CAPTURE')
        return False
    need(isinstance(before, dict) and isinstance(after, dict) and before and after,
         'PHANTOM_FULL_STATE_REQUIRED')
    for snapshot in (before, after):
        need(set(snapshot) == {'run', 'combat', 'return'}, 'SNAPSHOT_SCHEMA')
        need(isinstance(snapshot['run'], dict) and isinstance(snapshot['combat'], dict), 'NATIVE_STATE')
    need(after['return'] is old['ret'], 'FACTUAL_RETURN')
    need(old['clones'] == {}, 'NO_BLOODFIRE_CLONES_FOR_PHANTOM')
    if truth is not None:
        need(before == truth['before'] and after == truth['after'], 'ORACLE_SNAPSHOT_MISMATCH')
    else:
        # Queue growth can be interrupted by terminal handoff; exact plain-state
        # equality is checked upstream, never replaced by a fabricated suffix.
        need(old['command']['t'] == 'playCard', 'PHANTOM_COMMAND')
    for label, snapshot in (('before', before), ('after', after)):
        compact = old[label]; cb = snapshot['combat']
        held = [{'uid':c['uid'], 'id':c['id'], 'up':c['up']} for c in cb['hand']]
        need(held == compact['hand'], 'SNAPSHOT_HAND')
        for field in ('hp', 'energy'):
            need(cb['player'][field] == compact[field], 'SNAPSHOT_'+field.upper())
        need(cb['turn'] == compact['turn'] and cb['over'] is compact['over'], 'SNAPSHOT_PHASE')
    return True


def jsonl(path):
    import lzma
    path = Path(path)
    op = lzma.open if path.suffix == '.xz' else open
    with op(path, 'rt', encoding='utf-8') as handle:
        for line in handle:
            need(bool(line.strip()), 'EMPTY_RAW_RECORD')
            yield json.loads(line)


def equivalent_outcome(old, new):
    # These are measured timers, not game semantics; their raw values are retained.
    timing = {'query_usec', 'run_usec'}
    need(set(new) == set(old), 'OUTCOME_SCHEMA')
    need({k:v for k,v in old.items() if k not in timing} ==
         {k:v for k,v in new.items() if k not in timing}, 'OUTCOME_OR_DECISION_DRIFT')
