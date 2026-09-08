"""Derive exhaustive proper-subword consequences from an existing BFS certificate.

No native execution or new samples. This is post-observation proof checking of
four fixed states, not population support, complete package admission, or a new
interpretation of the old 672-row negative. Run with the facet-language directory.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import sys

RAW_SHA = 'c86b7bfffdc748400eed5436005feef36d990640f64d7505c131eb85a8dd289a'
VERIFY_SHA = 'ecfea2cc6bf01307cda74738ce44b13081eed77357d234c749f5828740ef8a8f'
SEARCH_SHA = '00e5444acc72d00d73457f1a209d5136be6ea9322063a768c30049768773fa22'
INITIALS_SHA = '97b886ab9bb417d799b07c14c260fdd2166af9ae9cb9f867c538022d074297cb'
RESULT_SHA = 'e0714cb6943486eba9d70a63c41f9e4a88d300301ac356d1bdaaea14660cb5c5'

def need(ok: bool, why: str) -> None:
    if not ok:
        raise ValueError(why)

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def derive(nodes: dict[str, dict], initial: str, full_word: list[dict]) -> dict:
    """Check every proper positional subset of the prefix, retaining consumer.

    A missing legal edge is a rejected command word, not an unobserved payoff.
    A missing expanded node is an evidence failure, never a negative finding.
    """
    need(len(full_word) >= 2, 'WORD_LENGTH')
    prefix, consumer = full_word[:-1], full_word[-1]
    need(len(prefix) <= 9, 'OUTSIDE_FROZEN_LANGUAGE')
    rows, distinct = [], set()
    # The omitted-consumer case is a separate structural absence, not a run.
    for mask in range((1 << len(prefix)) - 1):
        kept = [i for i in range(len(prefix)) if mask & (1 << i)]
        word = [prefix[i] for i in kept]
        distinct.add(json.dumps(word, sort_keys=True, separators=(',', ':')))
        current = initial
        outcome, illegal_position = None, None
        for position, command in zip(kept, word):
            need(current in nodes, 'MISSING_EXPANDED_FRONTIER')
            node = nodes[current]
            edges = [e for e in node['edges'] if e['cmd'] == command]
            need(len(edges) <= 1, 'DUPLICATE_COMMAND_EDGE')
            if not edges:
                # The parent reader verified the complete legal alphabet here.
                outcome, illegal_position = 'ILLEGAL_PREFIX', position
                break
            current = edges[0]['state']
        if outcome is None:
            need(current in nodes, 'MISSING_EXPANDED_FRONTIER')
            terminal = nodes[current]['terminal']
            if not terminal:
                outcome = 'NO_ENABLED_PREFIX_SHATTER_ECHO_CHAIN'
            else:
                need(terminal['cmd'] == consumer, 'DIFFERENT_CONSUMER')
                need(terminal['extra_hp'] <= 0, 'POSITIVE_PROPER_SUBWORD_COUNTEREXAMPLE')
                outcome = 'NO_POSITIVE_SAME_STATE_ECHO_CONTRIBUTION'
        # Mask bit i retains full_word[i]; the final consumer is always retained.
        # This lossless indexing avoids copying commands into every derived row.
        rows.append({'mask': mask, 'outcome': outcome,
                     'invalid_original_position': illegal_position,
                     'last_reached_state': current})
    counts = {k: sum(r['outcome'] == k for r in rows) for k in sorted({r['outcome'] for r in rows})}
    return {'full_word': full_word, 'positional_proper_subsets': len(rows),
            'distinct_retained_prefix_words': len(distinct), 'outcomes': counts,
            'omitted_consumer': 'SPECIFIED_CONSUMER_NOT_ENACTED_BY_DEFINITION_NOT_A_NATIVE_RUN',
            'all_retained_consumer_proper_subwords_fail_specified_goal': True,
            'rows': rows}

def analyze(directory: Path) -> dict:
    directory = directory.resolve()
    pinned = {
        'verify.py': VERIFY_SHA, 'search.gd': SEARCH_SHA,
        'native-1/OLD-INITIALS.json': INITIALS_SHA,
        'native-1/RESULTS.json': RESULT_SHA}
    for name, expected in pinned.items():
        need(sha((directory / name).read_bytes()) == expected, 'INPUT_IDENTITY:' + name)
    packed = (directory / 'native-1/native.ndjson.xz').read_bytes()
    decompressor = lzma.LZMADecompressor()
    raw = decompressor.decompress(packed, max_length=28_412_381)
    need(decompressor.eof and not decompressor.unused_data, 'ARCHIVE_FRAMING')
    need(len(raw) == 28_412_380 and sha(raw) == RAW_SHA, 'RAW_IDENTITY')
    records = [json.loads(line) for line in raw.splitlines()]
    specification = importlib.util.spec_from_file_location('frozen_facet_verifier', directory / 'verify.py')
    need(specification is not None and specification.loader is not None, 'VERIFIER_IMPORT')
    verifier = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(verifier)
    initials = {(x['vow'], x['up']): x['initial'] for x in json.loads((directory / 'native-1/OLD-INITIALS.json').read_bytes())}
    checked = verifier.verify(records, initials, SEARCH_SHA)
    need(sha((json.dumps(checked, indent=2) + '\n').encode()) == RESULT_SHA, 'PARENT_CERTIFICATE')
    results = []
    for case in checked['cases']:
        need(case['status'] == 'BOUNDED_MINIMUM_WORD_FOUND', 'UNPROVED_PARENT_WORD')
        key = (case['vow'], case['up'])
        selected = [r for r in records if r['kind'] == 'node' and (r['case']['vow'], r['case']['up']) == key]
        nodes = {r['state']: r for r in selected}
        need(len(nodes) == len(selected), 'DUPLICATE_EXPANDED_STATE')
        derived = derive(nodes, initials[key], case['path'])
        results.append({'vow': key[0], 'up': key[1], 'parent_minimum_commands': case['minimum_commands'], **derived})
    count = sum(x['positional_proper_subsets'] for x in results)
    need(count == 156 and len(results) == 4, 'DERIVED_ASSIGNMENT')
    return {
        'status': 'BOUNDED_PROPER_SUBWORD_CERTIFICATE_NOT_PACKAGE_ADMISSION',
        'evidence_parent': 'f36d1428e595711aa997fd3ff8cea633c4df319a',
        'raw_sha256': RAW_SHA, 'parent_result_sha256': RESULT_SHA,
        'cases': results, 'positional_proper_subsets': count,
        'new_native_runs': 0, 'new_independent_samples': 0,
        'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
        'packages_admitted': 0, 'p9_certified': False,
        'limits': [
            'Post-observation deductive reuse of a complete shorter-word frontier, not fresh confirmation or an extra experimental cohort.',
            'The goal includes an already produced Shatter, an enabled Echo before the consumer hit, and positive same-state extra HP.',
            'Only command omission from the four certified words and four fixed controlled initial states is covered; not every component-removal intervention or all natural states.',
            'Illegal prefixes cannot enact the specified word; this is not a measurement of their hypothetical payoff.',
            'Identical retained command words from different positional masks are not independent evidence.',
            'Costs, target/instance IDs, Block and coupled Stun remain in the original native graph; no artificial compensator or graph repair.',
            'This does not construct the full canonical closed-family quotient or prove real-economy support, policy viability, detector admission or P9.']}

if __name__ == '__main__':
    need(len(sys.argv) == 2, 'Usage: python read_subsequences.py FACET_LANGUAGE_DIRECTORY')
    print(json.dumps(analyze(Path(sys.argv[1])), indent=2))
