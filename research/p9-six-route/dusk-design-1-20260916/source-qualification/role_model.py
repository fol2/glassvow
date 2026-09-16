"""DD1-SOURCE-1 non-native projection. No engine, RNG sampling or population.

The shared interpreter exposes only named command seams. Full callback equality
is a source proof in PROOF.md, not a claim that this model is a native simulator.
"""
from __future__ import annotations
from copy import deepcopy
from dataclasses import dataclass, field, asdict


@dataclass
class Enemy:
    key: int
    hp: int = 40
    block: int = 0
    chips: int = 0
    facet: int = 5
    cracked: int = 0
    stunned: bool = False
    weak: int = 0
    adamant: bool = False
    spent: bool = False
    thorns: int = 0
    finale: bool = False


@dataclass
class State:
    enemies: list[Enemy] = field(default_factory=lambda: [Enemy(0), Enemy(1)])
    hp: int = 40
    block: int = 0
    energy: int = 4
    strength: int = 0
    attributed: int = 0  # analysis-only additive contribution, not game state
    weak: bool = False
    dusk: bool = True
    hand: list[int] = field(default_factory=lambda: [1, 2, 3, 4])
    discard: list[int] = field(default_factory=list)
    consumed: list[int] = field(default_factory=list)
    over: bool = False
    first: bool = True
    discount: int = 0
    cards: int = 0
    attacks: int = 0
    embers: int = 0
    bell: bool = False
    reaper: bool = False
    draws_owed: int = 0
    ready: bool = False
    flow: bool = False
    events: list = field(default_factory=list)


def candidate(up_p=False, up_c=False):
    # Direct transcription of M content and the SOURCE-ENTRY named tuple.
    return {"P": {"type": "attack", "cost": 1, "chip": 1,
                   "ops": [("hit", 7 if up_p else 4, 1)]},
            "C": {"type": "attack", "cost": 1, "chip": 0,
                   "ops": [("echo", 10 if up_c else 7)]}}


def registered_composition(up_p=False, up_c=False):
    # Independently assembled registered role interfaces, NOT whole Flow.
    # Flow protocol shatterProducers[0] binds this complete native command.
    shatter_producer = {"cost": 1, "chip": 1, "type": "attack",
                        "ops": [("hit", (4, 7)[int(up_p)], 1)]}
    # Resonance protocol candidate.consumer binds the native echo command.
    echo_consumer = {"chip": 0, "cost": 1, "type": "attack",
                     "ops": [("echo", (7, 10)[int(up_c)])]}
    return {"P": shatter_producer, "C": echo_consumer}


def card(name: str, up=False):
    table = {
        "empower": {"type": "power", "cost": 1, "chip": 0,
                    "ops": [("strength", 3 if up else 2)]},
        "flurry": {"type": "attack", "cost": 1, "chip": 0,
                   "ops": [("hit", 3 if up else 2, 3)]},
        "eclipseSlash": {"type": "attack", "cost": 2, "chip": 0,
                         "ops": [("hit", 9 if up else 7, 1),
                                 ("cracked", 2 if up else 1)]},
        "warCry": {"type": "skill", "cost": 1, "chip": 0,
                   "ops": [("cry", 2 if up else 1)]},
        "strike": {"type": "attack", "cost": 1, "chip": 0,
                   "ops": [("hit", 9 if up else 6, 1)]},
    }
    return deepcopy(table[name])


def physical(s: State, target=0):
    return sum(e[4] for e in s.events if e[0] == "hit" and e[1] == target)


def public(s: State):
    d = asdict(s)
    d.pop("attributed")
    return d


def hit(s: State, t: int, base: int, pending: set, *, attack=True,
        omit=0, mutant=""):
    e = s.enemies[t]
    if e.hp <= 0 or s.over:
        return
    n = base + (s.strength - omit if attack else 0)
    if attack and s.weak:
        n = n * 3 // 4
    if attack and e.cracked > 0:
        n = n * 3 // 2
    n = max(0, n)
    blocked = min(e.block, n)
    e.block -= blocked
    amount = n - blocked
    before = e.hp
    handoff = e.finale and amount >= before
    if handoff:
        amount = max(0, before - 1)
    overkill = 0 if handoff else max(0, amount - before)
    removed = min(before, amount)
    e.hp = max(0, before - amount)
    # native HIT_ENEMY.amount is unclipped except for finale handoff
    reported = removed if mutant == "clamp-amount" else amount
    s.events.append(["hit", t, reported, overkill, removed, blocked])
    if attack and amount > 0:
        pending.add(t)
    if attack and e.thorns and e.hp > 0 and not handoff:
        b = min(s.block, e.thorns)
        s.block -= b
        s.hp = max(0, s.hp - (e.thorns - b))
        s.events.append(["thorns", e.thorns - b])
        if s.hp == 0:
            s.over = True
    if handoff:
        s.events.append(["handoff", t])
        s.over = True
    elif e.hp == 0:
        e.cracked, e.stunned = 0, False
        s.events.append(["die", t])
        if any(o.hp > 0 for o in s.enemies):
            s.embers = min(10, s.embers + 1)
            if s.reaper:
                s.energy += 1
                s.draws_owed += 1  # not a fabricated drawn card
        else:
            s.over = True


def settle(s: State, targets: set, chips: int, mutant=""):
    if not s.dusk or s.over:
        return
    for t in sorted(targets):
        e = s.enemies[t]
        if e.hp <= 0 or s.over:
            continue
        e.chips += chips
        s.events.append(["chip", t, chips])
        while e.chips >= e.facet and e.hp > 0:
            e.chips -= e.facet
            e.facet += 1
            if e.adamant and not e.spent:
                e.spent = True
                s.events.append(["hold", t])
                continue
            e.stunned = mutant != "drop-stun"
            e.cracked += 2
            s.embers = min(10, s.embers + 2)
            s.events.append(["shatter", t])
            if s.bell:
                for j, other in enumerate(s.enemies):
                    if j != t and other.hp > 0 and not s.over:
                        hit(s, j, 4, set(), attack=False, mutant=mutant)


def play(s: State, c: dict, uid: int, target=0, *, p_enabled=True,
         c_enabled=True, family="", enabled=True, mutant=""):
    # These controls operate on the designated native component only in Dusk.
    if not s.dusk or not enabled:
        p_enabled = c_enabled = True
    cost = max(0, c["cost"] - (s.discount if s.first else 0))
    targeted = c["type"] == "attack"
    if (s.over or uid not in s.hand or cost > s.energy or
            (targeted and (target < 0 or target >= len(s.enemies) or
                           s.enemies[target].hp <= 0))):
        return "ILLEGAL_UNAVAILABLE"
    s.hand.remove(uid)
    s.energy -= cost
    s.first = False
    s.cards += 1
    s.attacks += int(c["type"] == "attack")
    s.events.append(["play", uid, c["type"], cost, target if targeted else None])
    pending: set[int] = set()
    for op in c["ops"]:
        if s.over:
            break
        if op[0] == "strength":
            if p_enabled:
                s.strength += op[1]
                s.attributed += op[1]
                s.events.append(["strength", op[1]])
            if family in ("one-bit", "power-cycle") and enabled and s.dusk:
                s.ready = True
        elif op[0] == "hit":
            for k in range(op[2]):
                omit = s.attributed if not c_enabled and k > 0 else 0
                hit(s, target, op[1], pending, omit=omit, mutant=mutant)
                if mutant == "per-hit-chips" and pending:
                    settle(s, pending, 1 + c["chip"], mutant)
                    pending.clear()
        elif op[0] == "echo":
            e = s.enemies[target]
            guard = e.stunned or e.cracked > 0
            if mutant == "wrong-target":
                guard = s.enemies[(target + 1) % len(s.enemies)].stunned
            hit(s, target, op[1] * (2 if guard and c_enabled else 1),
                pending, mutant=mutant)
        elif op[0] == "cracked":
            if s.enemies[target].hp > 0:
                s.enemies[target].cracked += op[1]
        elif op[0] == "cry":
            for e in s.enemies:
                if e.hp > 0:
                    e.cracked += op[1]
                    e.weak += op[1]
    extra = 0
    if c["type"] == "attack" and s.ready:
        qualifies = family == "one-bit" or (family == "power-cycle" and s.flow)
        if qualifies:
            extra = int(enabled and s.dusk)
            s.ready = s.flow = False
    settle(s, pending, 1 + c["chip"] + extra, mutant)
    if mutant == "consume-strength" and c["type"] == "attack":
        s.strength -= s.attributed
        s.attributed = 0
    if c["type"] == "power":
        if mutant == "power-exhaust":
            s.embers = min(10, s.embers + 1)
        s.consumed.append(uid)
    else:
        s.discard.append(uid)
    return "PLAYED"


def phase_boundary(s: State, mutant=""):
    """Expiry projection ONLY. No enemy combat, draws, turns or RNG simulated."""
    for e in s.enemies:
        e.stunned = False
        e.cracked = max(0, e.cracked - 1)
    if mutant == "reset-strength":
        s.strength = s.attributed = 0
