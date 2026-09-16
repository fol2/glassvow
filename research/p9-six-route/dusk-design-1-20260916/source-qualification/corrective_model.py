"""Only the K1 interventions and unchanged DD1 seams needed for source peers.

Imports the retained native-role projection. No engine, outcomes, random draws,
policy, export adapter or closure/verdict input. Source correspondence and limits
are in PROOF.md. This is not a native save/turn simulator.
"""
from __future__ import annotations
from copy import deepcopy
from dataclasses import dataclass
from role_model import Enemy, State, candidate, card, play, hit, settle, phase_boundary


@dataclass
class ProductState(State):
    anchor: Enemy | None = None


class OrderedTargets:
    """Native pending-chip dictionaries retain first-hit insertion order."""
    def __init__(self):
        self.values = {}

    def add(self, target):
        self.values[target] = None


def anchor_index(s):
    return next((i for i, e in enumerate(s.enemies) if e is s.anchor), None)


def clear_dead_anchor(s):
    if s.anchor is not None and (s.over or s.anchor.hp <= 0 or anchor_index(s) is None):
        s.anchor = None


def play_named(s, name, uid, target=0, up=False, *, p_on=True, c_on=True,
               controls=True, dd1_on=True, mutant=""):
    """Masks are interventions, not claims that resulting states are reachable.

    K1 P-off removes printed chip only. C-off removes the special echo multiplier,
    not ordinary Cracked scaling. Existing K2 play/Strength code is unchanged.
    DD1 off removes only its anchor/return law; ordinary Block/hit remains.
    """
    if name in ("chisel", "resonantLance"):
        c = candidate(up, up)["P" if name == "chisel" else "C"]
        if name == "chisel" and s.dusk and controls and not p_on:
            c["chip"] = 0
        if name == "chisel" and mutant == "drop-printed-chip":
            c["chip"] = 0
        r = play(s, c, uid, target, c_enabled=c_on, enabled=controls, mutant=mutant)
        clear_dead_anchor(s)
        return r
    if name not in ("setTheAngle", "crosscut"):
        r = play(s, card(name, up), uid, target, p_enabled=p_on,
                 c_enabled=c_on, enabled=controls, mutant=mutant)
        clear_dead_anchor(s)
        return r

    # Both proposed cards are targeted, unlike a generic self-Block Skill.
    cost = max(0, 1 - (s.discount if s.first else 0))
    if (s.over or uid not in s.hand or s.energy < cost or target is None or
            target < 0 or target >= len(s.enemies) or s.enemies[target].hp <= 0):
        return "ILLEGAL_UNAVAILABLE"
    attack = name == "crosscut"
    s.hand.remove(uid)
    s.energy -= cost
    s.first = False
    s.cards += 1
    s.attacks += int(attack)
    s.events.append(["play", uid, "attack" if attack else "skill", cost, target])
    if not attack:
        # The fixtures have no Dex/Frail/ward multiplier. Native Block remains
        # a separate qualification dependency; no claim to implement all modifiers.
        s.block += 6 if up else 4
        if s.dusk and dd1_on:
            s.anchor = s.enemies[target]
    else:
        a = s.anchor
        if mutant != "retain-anchor":
            s.anchor = None
        pending = OrderedTargets()
        hit(s, target, 7 if up else 5, pending, mutant=mutant)
        if mutant == "eager-settlement":
            for t in list(pending.values):
                settle(s, {t}, 1, mutant)
            pending.values.clear()
        ai = next((i for i, e in enumerate(s.enemies) if e is a), None)
        valid = (s.dusk and dd1_on and not s.over and s.hp > 0 and
                 ai is not None and a.hp > 0 and ai != target)
        if valid:
            rt = target if mutant == "wrong-return-target" else ai
            hit(s, rt, 7 if up else 5, pending, mutant=mutant)
        order = list(pending.values)
        if mutant == "sorted-pending":
            order.sort()
        for t in order:
            settle(s, {t}, 1, mutant)
    s.discard.append(uid)
    clear_dead_anchor(s)
    return "PLAYED"


def boundary(s, mutant=""):
    """Native expiry slice, not an enemy turn or draw invocation."""
    if mutant != "sticky-anchor":
        s.anchor = None
    phase_boundary(s, mutant)


def observe(s):
    # No origin/route bit enters the transitions or this canonical projection.
    return {"player": [s.hp, s.block, s.energy, s.strength],
            "enemies": [[e.key, e.hp, e.block, e.chips, e.facet, e.cracked,
                         e.stunned, e.spent] for e in s.enemies],
            "anchor": anchor_index(s), "over": s.over,
            "zones": deepcopy([s.hand, s.discard, s.consumed]),
            "counts": [s.cards, s.attacks], "embers": s.embers,
            "draws_owed": s.draws_owed, "events": deepcopy(s.events)}
