"""DD1-X non-native projection. No Godot, RNG, acquisition or balance model.

The one new law is an identity-bound, same-turn, one-use return hit. Native
arithmetic below is a deliberately bounded projection, NOT a native oracle.
Unsupported content, offers, quests and random collateral are not simulated.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional


@dataclass(eq=False)
class Enemy:
    key: str
    hp: int = 40
    block: int = 0
    vulnerable: int = 0
    thorns: int = 0
    chips: int = 0
    facet: int = 20
    staggered: bool = False
    adamant: bool = False
    adamant_spent: bool = False
    handoff: bool = False


@dataclass
class Card:
    uid: int
    role: str
    up: bool = False


@dataclass
class State:
    enemies: list[Enemy] = field(default_factory=lambda: [Enemy(x) for x in 'ABC'])
    hand: list[Card] = field(default_factory=lambda: [Card(1, 'P'), Card(2, 'C')])
    discard: list[Card] = field(default_factory=list)
    energy: int = 3
    hp: int = 30
    block: int = 0
    strength: int = 0
    dex: int = 0
    weak: bool = False
    frail: bool = False
    aspect: int = 0
    turn: int = 1
    over: bool = False
    anchor: Optional[Enemy] = None
    embers: int = 0
    beacon: int = 0
    seal_mult: int = 1
    bell: bool = False
    reaper: bool = False
    reaper_draws_owed: int = 0
    first_discount: int = 0
    plays: int = 0
    attacks: int = 0
    pending: list[Enemy] = field(default_factory=list)
    trace: list[dict] = field(default_factory=list)

    def event(self, kind: str, **fields: object) -> None:
        self.trace.append({'kind': kind, **fields})


def member(s: State, e: Optional[Enemy], mutant: str = '') -> bool:
    if e is None:
        return False
    if mutant == 'copy-alias':
        return any(x.key == e.key and x.hp > 0 for x in s.enemies)
    return any(x is e and x.hp > 0 for x in s.enemies)


def stop(s: State, reason: str) -> None:
    s.over = True
    s.anchor = None
    s.event('terminal', reason=reason)


def hurt_player(s: State, n: int, mutant: str = '') -> None:
    if mutant == 'ignore-thorns':
        return
    blocked = min(s.block, n)
    s.block -= blocked
    s.hp = max(0, s.hp - n + blocked)
    s.event('thorns', blocked=blocked, hp=s.hp)
    if s.hp == 0:
        stop(s, 'loss')


def hit(s: State, e: Enemy, base: int, phase: str, mutant: str = '', attack: bool = True) -> None:
    if s.over or e.hp <= 0:
        return
    damage = base
    if attack:
        damage += s.strength
        if s.weak:
            damage = damage * 3 // 4
        if e.vulnerable:
            damage = damage * 3 // 2
        damage *= s.seal_mult
    damage = max(0, damage)
    blocked = min(e.block, damage)
    e.block -= blocked
    reported = damage - blocked
    before = e.hp
    handing_off = e.handoff and reported >= before
    e.hp = max(1 if handing_off else 0, before - reported)
    physical = before - e.hp
    s.event('hit', phase=phase, target=e.key, physical=physical,
            reported=physical if handing_off else reported, blocked=blocked)
    if attack and physical > 0 and all(x is not e for x in s.pending):
        s.pending.append(e)
    if attack and e.hp > 0 and not handing_off and e.thorns:
        hurt_player(s, e.thorns, mutant)
    if handing_off:
        stop(s, 'finale-handoff')
    elif e.hp == 0:
        e.vulnerable = 0
        e.staggered = False
        if s.anchor is e:
            s.anchor = None
        if any(x.hp > 0 for x in s.enemies):
            s.embers = min(9, s.embers + 1)
            if s.reaper:
                s.energy += 1
                s.reaper_draws_owed += 1  # no invented drawn card or shuffle
        elif not s.over:
            stop(s, 'win')


def settle(s: State) -> None:
    # Native per-connected-target insertion order; no chip for fully blocked hits.
    if s.aspect == 0:
        for e in list(s.pending):
            if s.over or e.hp <= 0:
                continue
            e.chips += 1 + s.beacon
            while e.chips >= e.facet and e.hp > 0 and not s.over:
                e.chips -= e.facet
                e.facet += 1
                if e.adamant and not e.adamant_spent:
                    e.adamant_spent = True
                    s.event('adamant', target=e.key)
                    continue
                e.staggered = True
                e.vulnerable += 2
                s.embers = min(9, s.embers + 2)
                s.event('shatter', target=e.key, stun=True, cracked=e.vulnerable)
                if s.bell:
                    for other in s.enemies:
                        if other is not e and other.hp > 0 and not s.over:
                            hit(s, other, 4, 'bell', attack=False)
    s.pending.clear()


def play(s: State, uid: int, target: Enemy, *, producer: bool = True,
         consumer: bool = True, mutant: str = '') -> str:
    """ILLEGAL_UNAVAILABLE leaves the state untouched. Masks remove only new law.

    P's native Block and C's primary Attack, costs and lifecycle remain on both
    sides. Thus missing-component controls never manufacture a whole-command zero.
    """
    card = next((c for c in s.hand if c.uid == uid), None)
    cost = max(0, 1 - s.first_discount) if s.plays == 0 else 1
    if s.over or card is None or not member(s, target) or s.energy < cost:
        return 'ILLEGAL_UNAVAILABLE'
    s.energy -= cost
    s.hand.remove(card)
    s.plays += 1
    s.pending.clear()
    s.event('play', role=card.role, uid=uid, target=target.key, cost=cost)
    if card.role == 'P':
        block = max(0, (6 if card.up else 4) + s.dex)
        if s.frail:
            block = block * 3 // 4
        s.block += block
        if producer and s.aspect == 0:
            s.anchor = target
        s.event('block', amount=block)
    elif card.role == 'C':
        s.attacks += 1
        anchor = s.anchor
        if mutant != 'retain-on-consume':
            s.anchor = None
        n = 7 if card.up else 5
        hit(s, target, n, 'primary', mutant)
        if mutant == 'eager-settlement':
            settle(s)
        eligible = (consumer and s.aspect == 0 and not s.over and s.hp > 0
                    and member(s, anchor, mutant)
                    and (anchor is not target or mutant == 'same-target'))
        if eligible:
            if mutant == 'copy-alias':
                anchor = next(x for x in s.enemies if x.key == anchor.key and x.hp > 0)
            hit(s, anchor, n, 'return', mutant)
    else:
        raise ValueError('projection supports only declared P and C roles')
    if not s.over:
        settle(s)
    else:
        s.pending.clear()
    s.discard.append(card)
    return 'LEGAL'


def end_turn(s: State, mutant: str = '') -> None:
    # This models the expiry boundary, NOT the enemy phase or a full next turn.
    if mutant != 'sticky-reset':
        s.anchor = None
    s.turn += 1
    s.event('expiry')


def view(s: State, include_anchor: bool = True) -> dict:
    result = {
        'enemies': [(e.key, e.hp, e.block, e.vulnerable, e.chips, e.facet,
                     e.staggered, e.adamant_spent) for e in s.enemies],
        'player': [s.hp, s.block, s.energy, s.strength, s.dex, s.weak, s.frail],
        'zones': [[(c.uid, c.role, c.up) for c in a] for a in [s.hand, s.discard]],
        'other': [s.aspect, s.turn, s.over, s.embers, s.plays, s.attacks, s.reaper_draws_owed],
    }
    if include_anchor:
        result['anchor'] = next((i for i, e in enumerate(s.enemies) if e is s.anchor), None)
    return result


def return_hp(s: State) -> int:
    return sum(int(e['physical']) for e in s.trace if e['kind'] == 'hit' and e['phase'] == 'return')
