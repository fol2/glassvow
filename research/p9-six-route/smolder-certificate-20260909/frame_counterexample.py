"""A source-level counterexample to an unqualified common-background bridge.
No game, historical executable, outcome sample or model fitting is run.
"""
from __future__ import annotations
import hashlib, json, re
from pathlib import Path
from source_relation import PINS, require, sha


def function(text, name):
    starts = list(re.finditer(r'^(?:static )?func (\w+)\(', text, re.M))
    matches = [i for i, m in enumerate(starts) if m.group(1) == name]
    require(len(matches) == 1, 'FUNCTION_BINDING:'+name)
    i = matches[0]
    return text[starts[i].start():starts[i+1].start() if i+1 < len(starts) else len(text)]


def check_preview(native, historical):
    require('sid == "leech"' not in native, 'NATIVE_LEECH_PREVIEW_ADDED')
    require('if sid == "leech":' in historical, 'HISTORICAL_LEECH_BRANCH_MISSING')
    branch = historical.split('if sid == "leech":', 1)[1].split('elif sid == "execute":', 1)[0]
    require('if bloodfire else 0' in branch and 'hits.append(' in branch
            and '"times": 1' in branch and '_ji(fx["n"]) + bonus' in branch,
            'HISTORICAL_LEECH_WITNESS_CHANGED')
    guard = 'if hits.is_empty() and block == 0 and fx_chips == 0:\n\t\treturn null'
    require(guard in native and guard in historical, 'NULL_PREVIEW_GUARD_CHANGED')
    require('var hits: Array[Dictionary] = []' in native and 'var block: int = 0' in native
            and 'var fx_chips: int = 0' in native, 'NATIVE_INITIAL_ACCUMULATORS')
    require('"hits": hits' in historical and '"total": total' in historical,
            'HISTORICAL_NON_NULL_RETURN_CHANGED')
    return {
        'witness': 'One ordinary unupgraded leechBlade, legal living target, no Bloodfire/Scoreline/Afterimage/Mistbound, native card definition.',
        'native_preview_shape': 'null: its sole special leech has no matching native preview branch, and all three accumulators remain empty/zero.',
        'historical_preview_shape': 'non-null dictionary with one hit: the leech branch appends an ordinary hit even when bloodfire is false.',
        'historical_nominal_damage': 'Not independently evaluated here; the return-shape distinction does not require assuming an unextracted historical helper.',
        'conclusion': 'The claim that removing or omitting the historical tags yields an identical complete public observation/background interface is false.',
        'scope': 'Exact source-level return-shape counterexample. No measured policy outcome, native trace or full-family equivalence is asserted.'
    }


def main(repo, output):
    repo, output = Path(repo), Path(output)
    require(not output.exists(), 'OUTPUT_EXISTS')
    root = repo/'research/p9-six-route/smolder-certificate-20260909'
    source = root/'source-1'
    for name, digest in PINS.items():
        require(sha((source/name).read_bytes()) == digest, 'SOURCE_INPUT:'+name)
    index = json.loads((source/'SOURCE-INDEX.json').read_bytes())
    hist = json.loads((source/'HISTORICAL-FUNCTIONS.json').read_bytes())
    data = (repo/'domain/rules/combat.gd').read_bytes()
    require(sha(data) == index['native_combat_sha256'], 'NATIVE_COMBAT')
    content_bytes = (repo/'content/full-content.json').read_bytes()
    require(sha(content_bytes) == index['native_content_sha256'], 'NATIVE_CONTENT')
    content = json.loads(content_bytes)
    card = content['cards']['leechBlade']
    require(card['effects'] == [{'kind':'special','id':'leech','n':9}]
            and card.get('chip', 0) == 0, 'WITNESS_CARD_CHANGED')
    n = function(data.decode(), 'preview_play')
    h = hist['source/domain/rules/combat.gd::preview_play']
    require(sha(h['body'].encode()) == h['sha256'], 'HISTORICAL_PREVIEW_BODY')
    result = {'status':'UNQUALIFIED_COMMON_BACKGROUND_EQUIVALENCE_REFUTED',
        'native_preview_sha256':sha(n.encode()), 'historical_preview_sha256':h['sha256'],
        'counterexample':check_preview(n, h['body']),
        'core_background':{
            'ashen_core_definition':content['relics']['ashenCore'],
            'source_body':function(data.decode(), '_apply_start_relics'),
            'scope':'Initial native poison is shared background. Zero clean-direct witnesses do not mean zero source benefit; the already frozen pure-source criterion is not relaxed.'},
        'do_not_infer':['No claim that the game combat outcomes necessarily differ on every run.',
            'No reuse of old aggregate outcomes or old policy support from shared consumer code alone.',
            'No universal rejection of native Smolder; no new primitive is introduced by this background mismatch.'],
        'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
        'review':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(result['status'])

if __name__ == '__main__':
    import sys
    main(*sys.argv[1:])
