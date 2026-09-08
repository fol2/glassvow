"""Exact-candidate six-package disposition and Ash hand-size delta, no game runs.

This is a source/evidence audit, not a canonical quotient or admission verifier.
Every positive gate must name its actual evidence; missing evidence stays open.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
from census import require, sha, read as read_census
from read_packet import unpack

BASE='a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
CANDIDATE='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
COMBAT='a6fd99eb53030d3cf1401153bdeceec8b86ccc2af8b7643481855c681906f2ba'
ROOT='research/p9-six-route/'
ROUTES=(('duskblade','facet','resonantLance'),('duskblade','fervor','flurry'),
        ('duskblade','cycle','momentum'),('ashwarden','smolder','catalyst'),
        ('ashwarden','hand','phantomBlades'),('ashwarden','cycle','momentum'))
HISTORICAL_HAND={
 'head':'c802be36510273481b6d0f865b92fac43abf6aff',
 'protocol':'research/issue-421/protocols/post-v38-hand-size-inventory-v1.json',
 'protocol_blob':'9526a5f3280b2e7ac02ba96f68620c00d30ae1cf',
 'correction_protocol':'research/issue-421/protocols/post-v38-hand-size-inventory-v2.json',
 'correction_blob':'38b3a5b7d1ca7e308cb308edf037f9462d1bf73c',
 'producers':['preparation','surge'],'consumer':'phantomBlades',
 'activation':'Final-deck Phantom and present Preparation or Surge; both played; phantomDamage positive.',
 'support_scale':{'policies':128,'active':32,'inactive':32,'reachable':16,'exclusive_each_direction':8},
 'scope':'Historical structuralNull cohort only. These are not automatically transferable current-candidate counts.'}


def resolved(card,up):
    d=dict(card)
    if up:d.update(card.get('up',{}))
    d.pop('up',None)
    return d


def select_effects(cards,predicate):
    out=[]
    for cid,card in cards.items():
        for up in (False,True):
            d=resolved(card,up)
            for index,fx in enumerate(d.get('effects',[])):
                if predicate(d,fx):
                    out.append({'card_id':cid,'up':up,'effect_index':index,
                                'type':d['type'],'cost':d['cost'],'target':d['target'],
                                'exhaust':d.get('exhaust',False),'rarity':d['rarity'],'effect':fx})
    return out


def inventory(cards):
    return {
      'direct_draw':select_effects(cards,lambda d,f:f.get('kind')=='draw'),
      'hand_additions':select_effects(cards,lambda d,f:f.get('kind')=='addCard' and f.get('where')=='hand'),
      'next_turn_draw':select_effects(cards,lambda d,f:f.get('kind')=='status' and f.get('who')=='self' and f.get('id')=='nightsight'),
      'hand_exchange':select_effects(cards,lambda d,f:f.get('kind')=='special' and f.get('id')=='pyreTithe'),
      'strength_or_ritual':select_effects(cards,lambda d,f:f.get('kind')=='status' and f.get('who')=='self' and f.get('id') in ('str','ritual')),
      'poison_or_venomous':select_effects(cards,lambda d,f:f.get('kind')=='status' and ((f.get('id')=='poison' and f.get('who')!='self') or f.get('id')=='venomous')),
      'same_instance_growth':select_effects(cards,lambda d,f:f.get('kind')=='special' and f.get('id')=='momentum'),
      'explicit_chip':select_effects(cards,lambda d,f:f.get('kind')=='chip'),
      'printed_attack_chip':[{'card_id':cid,'up':up,'chip':resolved(c,up).get('chip',0)}
          for cid,c in cards.items() for up in (False,True)
          if resolved(c,up).get('type')=='attack' and resolved(c,up).get('chip',0)>0]}


def payoff(q,fx):
    require(type(q) is int and 0<=q<=9,'post-removal hand domain')
    r=max(0,fx.get('reserve',0))
    return fx['n']*max(0,q-r)+fx.get('floor_per',0)*min(q,r)


def card_delta(base,candidate,ids):
    result={}
    for cid in ids:
        pairs=[]
        for up in (False,True):
            a,b=resolved(base[cid],up),resolved(candidate[cid],up)
            changed={k:{'base':a.get(k),'candidate':b.get(k)} for k in sorted(set(a)|set(b)) if a.get(k)!=b.get(k)}
            pairs.append({'up':up,'changed':changed,'base':a,'candidate':b})
        result[cid]=pairs
    return result


def function_anchors(source):
    matches=list(re.finditer(r'^(?:static )?func (\w+)\(',source,re.M))
    out={}
    for i,m in enumerate(matches):
        name=m.group(1);end=matches[i+1].start() if i+1<len(matches) else len(source)
        require(name not in out,'duplicate function')
        out[name]={'line':source.count('\n',0,m.start())+1,'sha256':sha(source[m.start():end].encode())}
    return out


CONTRACTS={
'facet':{
 'producer':'Connecting Dusk Attack chips, including printed Chisel chip; exact Shatter threshold must be crossed on the same living target before the Echo consumer.',
 'mediator':'Target staggered or vulnerable > 0 at the consumer guard; attributed Shatter must precede this action. Core Shatter also changes shell, overflow, Ember and enemy behaviour.',
 'consumer':'resonantLance, legal living target, cost 1, raw base 7/up 10 doubled by the pre-hit guard.',
 'payoff':'Nominal hit, Block absorbed and HP removed are separate; surplus nominal damage on a lethal target is not extra health benefit.',
 'expiry_reset':'Target-status expiry, Stun consumption, target death and combat reset follow native code; post-hit Shatter cannot cause the preceding Echo.',
 'policy':'Intentionally build and schedule enough same-target chip, then spend a separate legal consumer action before expiry; no forced off-route bans.',
 'alternatives':'Direct Cracked producers can enable the same consumer but are a different complete producer contract; ordinary chip background must not be erased.',
 'formal':'Two named old producer-role aliases refuted; relevant closed-family union comparison still open.',
 'causal':'Old whole-command zero-interaction contract FAIL retained. Four-state shortest words/subwords and selective Echo evidence establish only bounded claims.',
 'priority':4},
'fervor':{
 'producer':'Player Strength supplied by Empower, Ritual or source-defined relic/trigger paths; record actual source and timing rather than require only Empower.',
 'mediator':'Persistent current player str before each eligible hit; shared attack modifiers remain part of the full state.',
 'consumer':'Flurry cost 1, five hits with printed raw 0/up 1; per-hit Strength application preserves hit topology.',
 'payoff':'Incremental per-hit health contribution, with common Weak/Cracked/Block/thorns/death and chip accounting unchanged.',
 'expiry_reset':'Strength persists within combat unless a native operation changes it; new combat resets player combat state.',
 'policy':'Acquire Strength and multihit capacity and choose setup versus immediate attack from public state; other source-defined Strength suppliers remain eligible.',
 'alternatives':'All attacks can benefit from Strength. Multiplicity amplification must separate the package from generic global attack strength.',
 'formal':'Source-level state dependency differs from per-instance growth, but complete closed/admitted-family disposition is open.',
 'causal':'Finite topology-preserving selective Fervor nulls exist. The older five-to-one-hit removal is NOT a pure Fervor intervention and cannot certify this claim.',
 'priority':3},
'cycle':{
 'producer':'An earlier play of one specific Momentum CardInst changes that same instance bonus by grow 14/up 17.',
 'mediator':'The same UID bonus surviving in its native card zone, then returning to a legal hand position.',
 'consumer':'A later play of that exact UID; cost 1 and n 0/up 1 plus accumulated bonus, then guarded ordinary draw 1.',
 'payoff':'Current target health benefit from the prior instance bonus; record actual return path, Energy and combat duration.',
 'expiry_reset':'Combat-copy bonus reset; active card is outside hand/draw/discard during its own effect, so no same-action self-redraw. No intrinsic bonus cap is asserted.',
 'policy':'Arrange economically feasible return and replay rather than merely own/play any Momentum; do not force a route or hide competing cards.',
 'alternatives':'Extra copies and ordinary draw are not evidence of same-instance repeat. Future-turn feedback remains in the complete shared environment.',
 'formal':'Guarded growth-plus-draw expansion is proved; this is neither whole-card equivalence to old Honing nor a complete closed-package decomposition disposition.',
 'causal':'Existing same-UID finite controls and selected witnesses are scoped; whole-run repeated-instance attribution and complete population proof remain open.',
 'priority':5},
'smolder':{
 'producer':'Source-defined player poison suppliers, including Ash starters, Venom Strike, Toxic Mist and venomous hooks, on the eventual Catalyst target.',
 'mediator':'Positive same-target poison immediately before Catalyst; already ticked, transferred, cleared or dead-target stock is not silently attributed.',
 'consumer':'Catalyst cost 1, Exhaust, multiplying poison by 2/up 3; no immediate direct health damage is assumed.',
 'payoff':'Additional realised future poison damage before target/combat death, plus actual setup and duration costs; poison_delta is not health removed.',
 'expiry_reset':'Native poison tick/decrement, death effects/transfer and combat reset; Dusk player Smolder block is preserved.',
 'policy':'Invest in poison then time multiplication on a surviving target; allow alternative poison sources and competing finishing attacks.',
 'alternatives':'Starter/environmental poison may enable Catalyst without the named Venom Strike anchor. Consumer co-play alone is not chain evidence.',
 'formal':'Exact mistbound and historical poison contracts must not be confused with all native poison. Complete comparison remains open.',
 'causal':'Finite multiplier/null and selected temporal evidence exists; full realised DOT attribution and independent population claims remain open.',
 'priority':2},
'hand':{
 'producer':'Preparation/Surge are the historical producer alternatives; additionally enumerate direct draw, generated-hand cards, next-turn Night Sight and exchange hooks. Require actual stock or legal-play opportunity, not a DRAW event alone.',
 'mediator':'Post-consumer-removal hand q in 0..9, available Energy and actual source/UID path; setup cost is not erased.',
 'consumer':'Phantom Blades cost 1: base 2*min(q,4)+6*max(q-4,0); upgraded high slope 7. Consumer is removed before reading q.',
 'payoff':'Intended stock-dependent health benefit of this action; keep raw, blocked, health and setup/duration consequences separate.',
 'expiry_reset':'Native hand cap 10, hand/discard/exhaust transitions, end-turn discard and combat reset. Night Sight persists only under its native lifecycle.',
 'policy':'Acquire adequate stock/energy producers and select setup-versus-consume from public state. Preparation can raise net stock; Surge primarily supplies play capacity/consumer access, not a guaranteed net hand gain.',
 'alternatives':'Night Sight is NOT necessary for the historical package. Generic draw 1 usually replaces the played card; hand exchanges and relic triggers need contextual accounting.',
 'formal':'Including/improving the admitted Ash hand-size family is expressly permitted. No demand for global primitive novelty. Exact current quantitative/causal inheritance is invalidated by changed card/payoff dependencies.',
 'causal':'Old finite Night Sight/Phantom observations do not cover all historical producer alternatives; old phantomDamage population field is absent in the current original-arm capture.',
 'priority':1}}


def build(base,candidate,packet):
    base,candidate,packet=map(Path,(base,candidate,packet))
    require(sha((base/'content/full-content.json').read_bytes())==BASE,'base content')
    require(sha((candidate/'content/full-content.json').read_bytes())==CANDIDATE,'candidate content')
    source=(candidate/'domain/rules/combat.gd').read_text()
    require(sha(source.encode())==COMBAT,'candidate combat')
    b=json.loads((base/'content/full-content.json').read_bytes());c=json.loads((candidate/'content/full-content.json').read_bytes())
    require(set(c['cards'])-set(b['cards'])=={'banklight'} and not set(b['cards'])-set(c['cards']),'declared candidate card delta')
    require([k for k in c['cards'] if k in b['cards']]==list(b['cards']),'existing card relative order')
    for needle in ('cb.hand.size() >= 10','resource_payoff(cb.hand.size(), fx)','cb.hand.remove_at(i)'):
        require(needle in source,'missing source contract:'+needle)
    census=read_census(unpack(packet))
    hand_delta=card_delta(b['cards'],c['cards'],['preparation','surge','phantomBlades','nightSight'])
    curves=[]
    for up in (False,True):
        old=resolved(b['cards']['phantomBlades'],up)['effects'][0]
        new=resolved(c['cards']['phantomBlades'],up)['effects'][0]
        curves.append({'up':up,'q':list(range(10)),'old_raw':[payoff(q,old) for q in range(10)],'candidate_raw':[payoff(q,new) for q in range(10)],'kind':'SOURCE_ARITHMETIC_NOT_NATIVE_REEXECUTION'})
    routes=[]
    for aspect,role,consumer in ROUTES:
        contract=dict(CONTRACTS[role]);contract['consumer_definitions']=[resolved(c['cards'][consumer],u) for u in (False,True)]
        context=[x for x in census['cells'] if x['catalogue']=='candidate' and x['aspect']==aspect and x['route']==role and x['arm']==1]
        routes.append({'id':aspect+'/'+role,'aspect':aspect,'vows':[0,5],'contract':contract,
          'acquisition':'Current native starter/reward/shop/event/deed/reveal rules; preserve card pools, rarity/order and policy/RNG. Neither card locked metadata nor a final-deck example alone proves full reachability.',
          'traces':'Use complete command/state/UID events and realised contribution. Co-play, names and a classifier label are not sufficient.',
          'evidence_scope':{'planned_arm_census':context,'unique_base_policy_vectors':1,'new_independent_samples':0},
          'obligations':{'source_bound_contract':'DEFINED','formal_family':('PERMITTED_INHERITED_FAMILY_DELTA_NOT_QUANTITATIVE_ADMISSION' if role=='hand' else 'OPEN_FULL_PACKAGE_COMPARISON'),
            'complete_causal_subset_null':'PARTIAL_RETAINED_EVIDENCE','competent_multi_policy_support':'MISSING_FOR_EXACT_CANDIDATE',
            'population_reachability':'MISSING_QUALIFIED_SUPPORT','independent_complementarity':'MISSING',
            'descriptor_admission':'MISSING_FINGERPRINT_NOT_SEVEN_DIRECTION_DETECTOR','all_guardrails':'UNPROVED'},
          'admitted':False,'decision':'HOLD_FOR_NAMED_MISSING_EVIDENCE_NOT_INTRINSIC_IMPOSSIBILITY'})
    return {'status':'COMPLETE_SIX_CANDIDATE_DISPOSITION_WITH_EXPLICIT_OPEN_CLAIMS','candidate_sha256':CANDIDATE,
      'combat_sha256':COMBAT,'baseline_sha256':BASE,'source_functions':function_anchors(source),
      'existing_candidate_added_card_ids':['banklight'],'producer_source_inventory':inventory(c['cards']),'inventory_scope':'All current card effect declarations; relic/art/enemy/native lifecycle sources remain explicit shared-context dependencies, not omitted or declared exhaustively enumerated.',
      'routes':routes,'historical_hand_contract':HISTORICAL_HAND,'hand_card_deltas':hand_delta,'hand_payoff_curves':curves,
      'hand_first_decision':{'inherited_family_eligible':True,'old_numerical_admission_carries':False,'requires_night_sight':False,
        'mandatory_next':'Complete the actual Preparation/Surge -> stock/play-opportunity -> Phantom causal/observation contract, then freeze its missing multi-policy/independent support under unchanged gates. Do not rerun the Night Sight demonstration.',
        'why_first':'Explicit inherited-family eligibility removes an unnecessary dependency on unresolved Facet/global-novelty synthesis; this is work ordering, not relaxed acceptance.'},
      'guardrail_screen':{'formal_hard_guardrail_pass':False,'formal_hard_guardrail_failure_proved_by_this_census':False,
        'reason':'Neither one exposed base-policy cohort nor high research-controller win rates are the signed C2/held-out CEM acceptance protocol. Retain the existing negative shifts as warnings; do not promote or universalise them.'},
      'no_repeat':['v25','1024 fixed validation','2048 original-arm simulation','672 command verifier','reunion','Facet language/subwords','composition-v1','frozen model fit'],
      'packages_admitted':0,'p9_certified':False,'new_native_runs':0,'new_independent_samples':0,
      'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}


def markdown(data):
    lines=['# Current six-package disposition and shortest credible delivery path','',
      'This is a complete disposition of the six current hypotheses, not six completed certificates. No negative is reset and no missing proof is marked PASS.','',
      '| Candidate | Next blocking claim | Order |','|---|---|---|']
    for row in sorted(data['routes'],key=lambda r:(r['contract']['priority'],r['id'])):
        lines.append('| '+row['id']+' | '+('Historical-family delta and complete causal/population contract' if row['id']=='ashwarden/hand' else 'Full package identity plus exact-current causal/population support')+' | '+str(row['contract']['priority'])+' |')
    lines += ['', '## What changes now', '',
      'Finish Ash hand-size first under the explicit include/improve permission. Do not hold it behind Facet alias work or demand six globally new primitives. Historical Preparation/Surge suppliers stay in scope; Night Sight is optional. Current changed Phantom/Tinder/Ash context means old quantitative admission cannot be copied.', '',
      'The complete old 2048-row census has one base-policy vector in four modes, not a multi-policy support rectangle. Aggregate co-play is not temporal activation. Current raw lacks the old phantomDamage field. More seeds of this capture would not supply the missing policy or realised-payoff observation.', '',
      '## Executable progression, not human checkpoints', '',
      '1. Source-bound hand-family delta and observer/intervention preflight. Freeze exact causal/UID/cost/reset/null predicates and complete producer alternatives; collect any missing evidence only in that unified package stage. A delivery defect is repaired without editing old study verdicts.', '',
      '2. After those gates pass, freeze and execute the missing competent multi-policy, real-economy and independent confirmation panel, with unchanged support/complementarity/guardrail bars and full raw preservation. PASS admits only the exact scoped package; a conclusive FAIL closes that candidate/claim, not an unlimited retune. INCONCLUSIVE retains the missing evidence and does not advance.', '',
      '3. In the same dependency map, resolve Smolder/Fervor and the two Cycle/Facet formal obligations from retained exact contracts. Batch compatible missing observations only for eligible packages. A non-survivor is replaced only through an already-authorised scientific alternative; no invented fourth rival or relabel rescue.', '',
      '4. With three certified packages per aspect, finish the seven-direction detector and corrected untouched repertoire/endpoint-retention work under all existing numerical bars. The 80.6% route fingerprint is not this detector, and protected archive cells are not retention.', '',
      '5. Freeze admitted interfaces; build only the minimum claim/impact lifecycle, integrate one selected product packet once, run exact-head and exact-merged P9, then post #108 receipt. A research branch, green reader or author review is not release approval.', '',
      'Stages advance autonomously when prerequisites actually hold. No wall-time promise or percentage is inferred from rows, tests, files or commits. There is no honest guarantee that the current six labels survive; the target is six certified strategies, not saving labels.', '',
      '## Current state', '', '0/6 exact-current certificates; no native run or independent sample added by this disposition. Complete old raw archival gap remains explicit.']
    return '\n'.join(lines)+'\n'


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('base',type=Path);p.add_argument('candidate',type=Path);p.add_argument('packet',type=Path);p.add_argument('out',type=Path)
    a=p.parse_args();result=build(a.base,a.candidate,a.packet);a.out.mkdir(parents=True,exist_ok=True)
    (a.out/'DISPOSITION.json').write_text(json.dumps(result,indent=2)+'\n')
    (a.out/'ROADMAP.md').write_text(markdown(result))
    print(json.dumps({'status':result['status'],'routes':len(result['routes']),'first':'ashwarden/hand','admitted':0,'sha256':sha((a.out/'DISPOSITION.json').read_bytes())}))
