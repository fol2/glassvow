"""Check exact inherited Catalyst kernel and scope of the historical extension.
No archived executable is imported or run. This is not a whole-family quotient.
"""
from __future__ import annotations
import hashlib, json, re
from pathlib import Path

PINS = {'SOURCE-INDEX.json': '93d94268da77ab53385046f83ddc461f3d0501dfa50b018145adf5383457743f',
        'HISTORICAL-FUNCTIONS.json': '7158a8e070f583f5c5fd959183364f75c17009139adc27324bcfa504034177b0',
        'NATIVE-FUNCTIONS.json': '3998de0cb74fca7ad702c2d95799b37562589403f5abf15552393d7d1257c145'}
SHARED = ('_apply_start_relics', '_start_player_turn', 'gain_embers', 'damage_player',
          '_on_enemy_death', '_shatter_enemy', '_jump_smolder', 'play_card', 'end_turn', 'use_potion')

def require(ok, reason):
    if not ok: raise ValueError(reason)

def sha(data): return hashlib.sha256(data).hexdigest()

def case(text, sid):
    lines = text.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip() == '\t\t"'+sid+'":']
    require(len(starts) == 1, 'CASE_IDENTITY:'+sid)
    start = starts[0]
    end = next((i for i in range(start+1, len(lines)) if re.match(r'^\t\t(?:"|_:)', lines[i])), len(lines))
    return ''.join(lines[start:end]).rstrip()

def catalyst_relation(native, historical):
    current = case(native, 'catalyst')
    old = case(historical, 'catalyst')
    lines = old.splitlines()
    guard = '\t\t\t\tif run.aspect == 1 and _sget(target.statuses, "mistbound") > 0:'
    require(lines.count(guard) == 1, 'MISTBOUND_GUARD')
    pos = lines.index(guard)
    expected = [guard, '\t\t\t\t\tmultiplier += _ji(fx.get("mistboundBonus", 0))',
                '\t\t\t\t\tadd_status_enemy(cb, target, "mistbound", -1, run)']
    require(lines[pos:pos+3] == expected, 'MISTBOUND_EXTENSION_BODY')
    residual = lines[:pos]+lines[pos+3:]
    var = '\t\t\t\tvar multiplier: int = _ji(fx["n"])'
    require(residual.count(var) == 1, 'MULTIPLIER_BINDING')
    residual.remove(var)
    residual = '\n'.join(residual).replace('poison * (multiplier - 1)', 'poison * (_ji(fx["n"]) - 1)')
    require(residual == current, 'RESIDUAL_NOT_NATIVE_KERNEL')
    return {'native_case': current, 'historical_case': old, 'residual_after_explicit_extension_removal': residual,
            'same_residual_kernel': True,
            'transformation_scope': 'Read-only decomposition of the archived source case, not an authorised edit to old evidence or current product.',
            'semantic_relation': 'For positive target poison q and zero mistbound, the historical consumer body and native consumer body have the same native call. With positive mistbound the historical body also emits its consumption event, and uses m+bonus instead of m. At q<=0 neither body consumes mistbound or amplifies poison.',
            'not_full_package_equivalence': True}

def main(repo, out):
    repo, out = Path(repo), Path(out)
    study = repo/'research/p9-six-route/smolder-certificate-20260909'
    require(not out.exists(), 'OUTPUT_EXISTS')
    inputs = {}
    for name, digest in PINS.items():
        data = (study/'source-1'/name).read_bytes()
        require(sha(data) == digest, 'PINNED_INPUT:'+name); inputs[name] = json.loads(data)
    index, native, historical = (inputs[x] for x in ('SOURCE-INDEX.json', 'NATIVE-FUNCTIONS.json', 'HISTORICAL-FUNCTIONS.json'))
    require(sha((repo/'domain/rules/combat.gd').read_bytes()) == index['native_combat_sha256'], 'PRODUCT_COMBAT')
    require(sha((repo/'content/full-content.json').read_bytes()) == index['native_content_sha256'], 'PRODUCT_CONTENT')
    for name, body in native.items(): require(sha(body.encode()) == index['native_function_hashes'][name], 'NATIVE_BODY:'+name)
    for name, record in historical.items(): require(sha(record['body'].encode()) == record['sha256'] == index['historical_function_hashes'][name], 'HISTORICAL_BODY:'+name)
    common = {}
    for name in SHARED:
        require(native[name] == historical['source/domain/rules/combat.gd::'+name]['body'], 'SHARED_FUNCTION:'+name)
        common[name] = sha(native[name].encode())
    relation = catalyst_relation(native['_apply_special'], historical['source/domain/rules/combat.gd::_apply_special']['body'])
    cards = index['cards']; source = cards['venomStrike']; mist = cards['toxicMist']; consumer = cards['catalyst']
    require(source['type']=='attack' and source['target']=='enemy' and source['cost']==1, 'SOURCE_CARD')
    require(source['effects']==[{'kind':'dmg','n':4},{'kind':'status','who':'target','id':'poison','n':4}], 'SOURCE_EFFECT_ORDER')
    require(mist['type']=='skill' and mist['target']=='allEnemies' and mist['cost']==1, 'MIST_CARD')
    require(mist['effects']==[{'kind':'status','who':'allEnemies','id':'poison','n':3}], 'MIST_MULTIPLICITY')
    require(consumer['exhaust'] is True and consumer['effects']==[{'kind':'special','id':'catalyst','n':2}], 'CONSUMER_ENVELOPE')
    result = {'status': 'EXACT_MISTBOUND_EXTENSION_AND_SHARED_NATIVE_KERNEL_SEPARATED',
        'input_sha256': PINS, 'shared_complete_function_hashes':common, 'consumer_relation':relation,
        'producer_relation': {'same_complete_native_source_command':False,
          'native_venomStrike':'Single-target Attack: ordinary hit first; poison only if the target survives. The one play envelope, chip settlement and hooks remain.',
          'native_toxicMist':'All-living-target Skill: poison without a source hit; different target cardinality and damage/death dependence.',
          'historical_registered_mediator':'mistbound, not just the native poison stock',
          'distinguishing_contexts':['Two living targets retain non-selected target identity: native ToxicMist touches both, native VenomStrike does not.',
            'A source hit lethally removes its target: native VenomStrike cannot then add its poison to that target.',
            'Positive mistbound is visibly consumed by the old Catalyst extension; native Catalyst has no such operation.'],
          'scope':'Source-level counterexamples for the declared command/extension aliases. No claim that ordinary damage creates a new strategy family.'},
        'disposition': {'historical_mistbound_support_failure_is_native_poison_failure':False,
          'native_amplifier_is_new_primitive':False,
          'native_chain_novelty_relative_to_all_closed_compositions':'NOT_ESTABLISHED',
          'complete_formal_package_admission':'NOT_ESTABLISHED',
          'historical_whole_run_rows_carry_to_unchanged_main':'NOT_ESTABLISHED; content/controller/observable dependencies differ.',
          'next_missing_formal_evidence':'A full registered-package transition comparison, including permitted shared-background composition and acquisition context. Do not substitute source inequality or the no-mistbound residual for that proof.'},
        'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'source_relation':result['status'],'shared_functions':len(common),'full_package_admitted':False}))

if __name__=='__main__':
    import sys
    main(*sys.argv[1:])
