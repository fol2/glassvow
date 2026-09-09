"""One public-state acquisition adapter; no new gameplay or fitted parameters.
The two coefficients are inherited from the recorded controller, not selected
from this experiment. All combat scoring and random-build branches are intact.
"""
from pathlib import Path
import hashlib
import re

PILOT_SHA='4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47'
SIM_SHA='b169e2588e2ea65b75b94ee94b8e129c2c3ac8a0d5f7076224521a204623cd06'
METHODS='''
## Research acquisition adapter. Reads only the offered definition and owned deck.
static func bloodfire_source(d: Dictionary) -> bool:
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) == "status" and str(fx.get("id", "")) == "bloodfire" and str(fx.get("who", "")) == "self" and int(fx.get("n", 0)) > 0:
			return true
	return false

static func bloodfire_consumer(d: Dictionary) -> bool:
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) == "special" and str(fx.get("id", "")) == "leech" and int(fx.get("bonus", 0)) > 0:
			return true
	return false

static func card_reward_score(d: Dictionary, aspect: int, card_id: String, deck: Array, content: ContentDB) -> float:
	var score: float = card_score(d, aspect, card_id)
	if random_build or aspect != 1:
		return score
	var source: bool = bloodfire_source(d)
	var consumer: bool = bloodfire_consumer(d)
	if not source and not consumer:
		return score
	if not bloodfire_source(content.cards.get("bloodRite", {})) or not bloodfire_consumer(content.cards.get("leechBlade", {})):
		return score
	if source:
		score += _w("status", "venomousAsh")
	for inst: CardInst in deck:
		var other: Dictionary = content.cards.get(String(inst.id), {}).duplicate(true)
		if inst.up:
			other.merge(other.get("up", {}), true)
		if (source and bloodfire_consumer(other)) or (consumer and bloodfire_source(other)):
			return score + 2.0 * _w("card", "aspectBonus")
	return score
'''


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(data):return hashlib.sha256(data).hexdigest()


def replace_once(source,old,new):
    require(source.count(old)==1,'UNIQUE_PATCH_SITE:'+old[:80])
    return source.replace(old,new,1)


def funcs(source):
    matches=list(re.finditer(r'^(?:static )?func (\w+)\(',source,re.M))
    out={}
    for i,m in enumerate(matches):
        require(m.group(1) not in out,'DUPLICATE_FUNCTION')
        body=source[m.start():matches[i+1].start() if i+1<len(matches) else len(source)].strip().splitlines()
        while body and (not body[-1].strip() or body[-1].startswith('#')):body.pop()
        out[m.group(1)]='\n'.join(body)
    return out


def patch(pilot,sim):
    require(sha(pilot.encode())==PILOT_SHA,'PILOT_IDENTITY')
    require(sha(sim.encode())==SIM_SHA,'SIM_IDENTITY')
    before_p,before_s=funcs(pilot),funcs(sim)
    pilot=replace_once(pilot,'static func choose_card(ids: Array, content: ContentDB, aspect: int, rng: Rng = null) -> String:',
                      'static func choose_card(ids: Array, content: ContentDB, aspect: int, rng: Rng = null, deck: Array = []) -> String:')
    pilot=replace_once(pilot,'var candidate: float = card_score(definition, aspect, id)',
                      'var candidate: float = card_reward_score(definition, aspect, id, deck, content)')
    pilot=replace_once(pilot,'value = card_score(definition, run.aspect, id)',
                      'value = card_reward_score(definition, run.aspect, id, run.player.deck, content)')
    pilot += METHODS
    sim=replace_once(sim,'Pilot.choose_card(rewards.get("cards", []), game.content, game.run.aspect,\n\t\tgame.run.rng)',
                    'Pilot.choose_card(rewards.get("cards", []), game.content, game.run.aspect,\n\t\tgame.run.rng, game.run.player.deck)')
    sim=replace_once(sim,'Pilot.card_score(game.content.cards.get(card, {}), game.run.aspect, card)',
                    'Pilot.card_reward_score(game.content.cards.get(card, {}), game.run.aspect, card, game.run.player.deck, game.content)')
    sim=replace_once(sim,'Pilot.choose_card(pending.get("cards", []), game.content, game.run.aspect,\n\t\t\t\tgame.run.rng)',
                    'Pilot.choose_card(pending.get("cards", []), game.content, game.run.aspect,\n\t\t\t\tgame.run.rng, game.run.player.deck)')
    after_p,after_s=funcs(pilot),funcs(sim)
    changed_p=[n for n,b in before_p.items() if after_p.get(n)!=b]
    changed_s=[n for n,b in before_s.items() if after_s.get(n)!=b]
    require(set(changed_p)=={'choose_card','choose_shop'},'PILOT_SCOPE:'+repr(changed_p))
    require(set(changed_s)=={'_claim_rewards','_resolve_event'},'SIM_SCOPE:'+repr(changed_s))
    for name in ('_pick_play','play_turn','_play_cards','_combat_score','card_score','_status_value','_special_value','_random_shop','choose_node'):
        require(before_p[name]==after_p[name],'COMBAT_OR_RANDOM_CHANGED:'+name)
    return pilot,sim,{'changed_pilot_functions':changed_p,'changed_simulator_functions':changed_s,
                     'added_pilot_functions':sorted(set(after_p)-set(before_p)),
                     'combat_and_random_function_bodies_equal':True}


def install(project):
    project=Path(project)
    pp=project/'tools/balance_pilot.gd';sp=project/'tools/balance_sim.gd'
    p,s,proof=patch(pp.read_text(),sp.read_text())
    pp.write_text(p);sp.write_text(s)
    old='var game: GlassvowGame = GlassvowGame.new(content, run)'
    observed=replace_once(s,'class_name BalanceSim\n','')
    observed=replace_once(observed,old,'var game: GlassvowGame = preload("res://observed_game.gd").new(content, run)')
    (project/'tools/observed_sim.gd').write_text(observed)
    proof['pilot_sha256']=sha(p.encode());proof['sim_sha256']=sha(s.encode())
    proof['observed_sim_sha256']=sha(observed.encode())
    return proof
