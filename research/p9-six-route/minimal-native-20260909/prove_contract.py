"""Source-complete role mapping and stronger offline checks of the SAME capture.

No new cases, fitted rules or new acceptance threshold. Read the immutable
CONTRACT first. Native primitives are not new topologies merely because roles
are renamed; the complete historical quotient remains a separate obligation.
"""
from __future__ import annotations
import hashlib
import json
import lzma
from pathlib import Path
import re
import sys
import verify

require = verify.require


def source_contract(base):
    base = Path(base)
    c = json.loads((base/'content/full-content.json').read_bytes())
    code = (base/'domain/rules/combat.gd').read_text()
    require(verify.sha(code.encode()) == '3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8','pinned combat')
    require(verify.sha((base/'content/full-content.json').read_bytes()) == 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1','pinned content')
    source_map = {}
    for path in ('domain/rules/combat.gd','domain/rules/rewards.gd','domain/game.gd',
                 'domain/state/card_inst.gd','domain/state/run_state.gd',
                 'domain/state/combat_state.gd','domain/state/player_combatant.gd',
                 'domain/state/enemy_combatant.gd','tools/vow_incentives.gd'):
        p = base/path
        require(p.is_file(), 'source dependency '+path)
        data=p.read_bytes()
        source_map[path]={'sha256':verify.sha(data),'git_blob':hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()}
    cards = {}
    for name in ('empower','flurry','venomStrike','catalyst'):
        card = c['cards'][name]
        cards[name] = {'base':card, 'upgraded':{**card,**card.get('up',{})},
                       'pool_gate':c['poolGate']['cards'].get(name),
                       'tiers':[t for t,ids in c['cardPools'].items() if name in ids]}
        require(card.get('cost')==1, 'native carrier cost')
    require(cards['catalyst']['pool_gate']=='poolWave3','Catalyst reveal requirement')
    require(cards['empower']['pool_gate'] is None and cards['flurry']['pool_gate'] is None,'ungated Fervor carriers')
    anchors = {
        'per_hit_strength':'dmg += _sget(p.statuses, "str")',
        'hit_loop':'for _t: int in range(times):',
        'producer_status':'add_status_player(cb, sid, sn)',
        'consumer_multiplier':'poison * (_ji(fx["n"]) - 1)',
        'poison_decrement':'_tick_status(e.statuses, "poison")',
        'death_transfer':'_jump_smolder(run, cb, e, smolder)',
        'one_card_chips':'facet chips land after the whole card resolves',
        'power_lifecycle':'cb.queue.append({"t": EventTypes.POWER_CONSUMED, "uid": inst.uid})',
        'exhaust_ember':'gain_embers(run, cb, 1)  # everything burned feeds the lantern',
        'ash_scope':'run.aspect == 0 and content.id == "core"'}
    for label, text in anchors.items(): require(text in code,'source law '+label)
    # Full code identity is checked above; anchors locate, not prove, semantics.
    locations={label:code[:code.index(text)].count('\n')+1 for label,text in anchors.items()}
    return {'source_dependencies':source_map,'cards':cards,'source_locations':locations,
            'formal_expressions':{
              'fervor':'NativePlay(P, add_player_str(s)); NativePlay(C, guarded_per_target_repeat(3, NativeHit(d+str))); str is not consumed; native endTurn/newCombat.',
              'smolder':'NativePlay(P, NativeHit(d); if target survives add_target_poison(p)); NativePlay(C, if poison>0 add_target_poison(poison*(m-1))); native Exhaust; native endTurn tick and target transfer.'},
            'guarded_decomposition':{
              'fervor':'The producer is one native status primitive; the consumer is an existing within-card hit loop. Cost/payment, hooks, pending chips and discard surround the entire loop, not each hit.',
              'smolder':'Catalyst is an existing state-dependent increment q*(m-1), not an independent direct-damage primitive. Exhaust and Ember/Branch effects follow at the native card envelope.'},
            'canonical_scope':{
              'new_runtime_or_content_fields':0,'new_primitive_proved':False,
              'complete_historical_quotient_proved':False,
              'important_boundary':'The old Power-to-next-Attack extra-Chip contract already runs on native background containing Strength. Distinguishing its EXTRA bit from native Strength cannot prove that the complete native-background-plus-bit system lacks the Fervor sub-behaviour.'}}


def strict_config(cfg):
    require(set(cfg)=={'family','aspect','vow','up','context','mask'},'config fields')
    require(type(cfg['up']) is bool,'boolean upgrade')
    for field in ('aspect','vow','mask'):require(type(cfg[field]) is int,'integer '+field)


def attack_hits(before, events, base, strength, remove_extra, target_index):
    """Independently replay exactly the emitted three-hit action, including floors.

The fixture contains no damage multiplier relic. A dead target terminates hits;
nominal health-loss events and clipped removed HP are different quantities.
"""
    status=before['statuses']; target=before['targets'][target_index]
    require(all(e['idx']==target_index for e in events),'hit target binding')
    hp=max(0,target['hp']); block=target['block']; actual=[]
    for i in range(3):
        if hp<=0: break
        damage=base+(0 if remove_extra and i>0 else strength)
        if status.get('weak',0)>0:damage=damage*3//4
        if target['statuses'].get('vulnerable',0)>0:damage=damage*3//2
        damage=max(0,damage); soaked=min(block,damage); block-=soaked
        loss=damage-soaked; hp=max(0,hp-loss)
        actual.append((loss,soaked,hp))
    require(actual==[(e['amount'],e['blocked'],e['hpAfter']) for e in events],'per-hit native arithmetic')


def check_semantics(raw, contract_file, base):
    raw,contract_file=Path(raw),Path(contract_file)
    contract=json.loads(contract_file.read_bytes());opener=lzma.open if raw.suffix=='.xz' else open
    with opener(raw,'rt') as f:
        header=json.loads(next(f))
        require(header['contract_sha256']==verify.sha(contract_file.read_bytes()),'exact contract binding')
        rows=[json.loads(line) for line in f if line.strip()]
    groups={}; checks=0; examples={}
    for row in rows:
        cfg=row['config'];strict_config(cfg);groups[verify.key(cfg)]=row
        family=cfg['family'];scope=cfg['aspect']==(0 if family=='fervor' else 1)
        producer_removed=scope and cfg['mask']>=0 and cfg['mask']&1
        amplifier_removed=scope and cfg['mask']>=0 and cfg['mask']&2
        for step in row['steps']:
            if not step['permitted'] or step['command']['t']!='playCard':continue
            uid=step['command']['uid'];a=step['after']['view'];b=step['before']['view']
            if uid in (900,903) and family=='fervor':
                require(a['statuses'].get('str',0)-b['statuses'].get('str',0)==(0 if producer_removed else (3 if cfg['up'] else 2)),'Fervor source law')
                require(uid not in a['discard_uids'] and uid not in a['exhaust_uids'] and all(c['uid']!=uid for c in a['hand']),'Power consumed not discarded/exhausted')
            elif uid in (900,903) and family=='smolder' and cfg['aspect']==1:
                target=step['command']['target'];q=b['targets'][target]['statuses'].get('poison',0)
                expected=0 if a['targets'][target]['hp']<=0 else q+(0 if producer_removed else (5 if cfg['up'] else 4))
                require(a['targets'][target]['statuses'].get('poison',0)==expected,'Smolder source survives guard')
            elif uid in (901,902) and family=='fervor':
                events=[e for e in step['events'] if e['t']=='hitEnemy']
                attack_hits(b,events,3 if cfg['up'] else 2,b['statuses'].get('str',0),bool(amplifier_removed),step['command']['target'])
                require(a['statuses'].get('str',0)==b['statuses'].get('str',0),'persistent Fervor resource')
                require(a['attacks']==b['attacks']+1 and uid in a['discard_uids'],'one Attack envelope, not three cards')
            elif uid in (901,902) and family=='smolder':
                target=step['command']['target'];q=b['targets'][target]['statuses'].get('poison',0)
                factor=1 if cfg['aspect']==0 or amplifier_removed else (3 if cfg['up'] else 2)
                require(a['targets'][target]['statuses'].get('poison',0)==q*factor,'target-local amplifier')
                require(a['targets'][1-target]['statuses']==b['targets'][1-target]['statuses'],'different target unchanged')
                require(uid in a['exhaust_uids'],'each Catalyst instance exhausts')
                require(not [e for e in step['events'] if e['t']=='hitEnemy'],'no instantaneous Catalyst HP damage')
            checks+=1
        if cfg['mask']==0 and scope and cfg['vow']==0 and not cfg['up'] and cfg['context'] in ('repeat','retarget','stacked','exhaust_hook','lethal'):
            examples[family+':'+cfg['context']]=[{'command':s['command'],'permitted':s['permitted'],'before':s['before']['view'],'after':s['after']['view'],'events':s['events']} for s in row['steps']]
    source=source_contract(base)
    return {'status':'SOURCE_COMPLETE_NATIVE_ROLE_MAP_AND_GUARDED_DECOMPOSITION_CHECKED',
      'cases_checked':len(rows),'native_actions_checked':checks,'source':source,'distinguishing_traces':examples,
      'decision':'Both minimal role chains are expressible by the unmodified product. They are existing-grammar research hypotheses, not formally new topologies; the one-bit closed family cannot be mapped by the word Power alone. Do not transfer the two failed bulk candidates or their performance.',
      'remaining':'Full relevant closed/admitted-package equivalence/decomposition classification and population/competence/peer/descriptor evidence; no candidate or package is promoted by these finite cases.',
      'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,'review':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}


if __name__=='__main__':
    print(json.dumps(check_semantics(*sys.argv[1:4]),indent=2))
