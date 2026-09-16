"""Executed source-projection checks; reports observations, never certificates."""
from __future__ import annotations
import argparse
import hashlib
import json
from copy import deepcopy
from itertools import product
from role_model import (Enemy, State, candidate, registered_composition, card,
                        play, physical, public, phase_boundary)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def run(mutant=""):
    checks = []
    def check(name, predicate, observation):
        checks.append({"name": name, "pass": bool(predicate), "observation": observation})
    def word(s, recipe, **kw):
        a = play(s, recipe["P"], 1, 0, **kw)
        b = play(s, recipe["C"], 2, 0, **kw)
        return [a, b]

    recipe_matches = [candidate(p, c) == registered_composition(p, c)
                      for p, c in product((False, True), repeat=2)]
    check("Q1-complete-paid-role-recipes", all(recipe_matches), recipe_matches)
    count = 0
    mismatches = []
    digest = hashlib.sha256()
    for up_p, up_c, hp, block, facet, strength, weak, adamant in product(
            (False, True), (False, True), (2, 40), (0, 6), (3, 5),
            (0, 2), (False, True), (False, True)):
        for chips in range(facet):
            a = State(enemies=[Enemy(0, hp=hp, block=block, facet=facet,
                    chips=chips, adamant=adamant), Enemy(1)],
                    strength=strength, weak=weak)
            b = deepcopy(a)
            r1 = word(a, candidate(up_p, up_c))
            r2 = word(b, registered_composition(up_p, up_c), mutant=mutant)
            same = (r1, public(a)) == (r2, public(b))
            if not same:
                mismatches.append(count)
            digest.update((canonical([count, r1, public(a), r2, public(b)]) + "\n").encode())
            count += 1
    check("Q1-bidirectional-projection-equality", not mismatches,
          {"cells": count, "mismatches": mismatches, "all_pairs_sha256": digest.hexdigest()})

    q1 = candidate()
    a = State(enemies=[Enemy(0, chips=3), Enemy(1)])
    word(a, q1, mutant=mutant)
    b = State(enemies=[Enemy(0, chips=3), Enemy(1)])
    play(b, card("warCry"), 1)
    play(b, q1["C"], 2)
    check("Q1-direct-Cracked-is-not-complete-threshold-producer",
          (a.enemies[0].facet, a.enemies[0].stunned, a.embers) !=
          (b.enemies[0].facet, b.enemies[0].stunned, b.embers),
          {"coupled": public(a), "direct": public(b)})
    a = State(enemies=[Enemy(0, block=40), Enemy(1)])
    b = deepcopy(a)
    play(a, q1["P"], 1)
    play(b, card("eclipseSlash"), 1)
    check("Q1-reverse-direction-blocked-direct-status",
          a.enemies[0].cracked == 0 and b.enemies[0].cracked == 1,
          [a.enemies[0].cracked, b.enemies[0].cracked])
    a = State(enemies=[Enemy(0, cracked=1), Enemy(1)])
    b = deepcopy(a)
    play(a, q1["C"], 2)
    play(b, q1["C"], 2, c_enabled=False)
    check("Q1-existing-Cracked-substitutes-consumer-guard",
          physical(a) > physical(b), [physical(a), physical(b)])
    check("Q1-disabled-echo-command-is-not-zero-null",
          physical(b) > 7, {"physical": physical(b), "base": 7,
          "reason": "ordinary Cracked mitigation persists; not a repair of R3"})
    a = State(enemies=[Enemy(0, chips=3, adamant=True), Enemy(1)])
    play(a, q1["P"], 1, mutant=mutant)
    check("Q1-Adamant-hold-not-real-Shatter",
          (a.enemies[0].facet, a.enemies[0].stunned, a.enemies[0].cracked, a.embers)
          == (6, False, 0, 0), public(a))
    a = State(enemies=[Enemy(0, chips=3), Enemy(1)])
    play(a, q1["P"], 1, mutant=mutant)
    check("Q1-coupled-Stun-and-Cracked", a.enemies[0].stunned and a.enemies[0].cracked == 2,
          [a.enemies[0].stunned, a.enemies[0].cracked])
    before = physical(a, 1)
    play(a, q1["C"], 2, 1, mutant=mutant)
    check("Q1-target-equality-is-material", physical(a, 1) - before == 7,
          {"other_target_physical": physical(a, 1) - before})

    q2_count = 0
    algebra_cases = []
    cells_digest = hashlib.sha256()
    component_counterexamples = []
    for up_p, up_c, hp, block, background, weak, cracked in product(
            (False, True), (False, True), (2, 40), (0, 6, 40),
            (0, 2), (False, True), (False, True)):
        cells = {}
        for p_on, c_on in product((False, True), repeat=2):
            s = State(enemies=[Enemy(0, hp=hp, block=block, cracked=int(cracked)), Enemy(1)],
                      strength=background, weak=weak)
            play(s, card("empower", up_p), 1, p_enabled=p_on, mutant=mutant)
            play(s, card("flurry", up_c), 2, c_enabled=c_on, mutant=mutant)
            cells[f"{int(p_on)}{int(c_on)}"] = {"physical": physical(s), "state": public(s)}
        i = cells["11"]["physical"] - cells["10"]["physical"] - cells["01"]["physical"] + cells["00"]["physical"]
        if hp == 40 and block == 0 and not weak and not cracked:
            algebra_cases.append(i == 2 * (3 if up_p else 2))
        if i != 2 * (3 if up_p else 2):
            component_counterexamples.append(q2_count)
        cells_digest.update((canonical([q2_count, cells, i]) + "\n").encode())
        q2_count += 1
    check("Q2-restricted-component-algebra", all(algebra_cases),
          {"plain_cases": len(algebra_cases), "cells": q2_count,
           "factor_cells": q2_count * 4, "all_cells_sha256": cells_digest.hexdigest()})
    check("Q2-2s-is-not-universal-HP", bool(component_counterexamples),
          {"counterexample_count": len(component_counterexamples),
           "first_indices": component_counterexamples[:8]})

    a = State(strength=2)
    play(a, card("empower"), 1, mutant=mutant)
    play(a, card("flurry"), 2, mutant=mutant)
    phase_boundary(a, mutant)
    play(a, card("flurry"), 3, 1, mutant=mutant)
    check("Q2-persistent-retargeted-second-consumer", a.strength == 4 and physical(a, 1) == 18,
          {"strength": a.strength, "second_target_physical": physical(a, 1)})
    check("Q2-one-Power-not-Exhaust", a.consumed == [1] and a.embers == 0,
          {"consumed": a.consumed, "embers": a.embers})
    check("Q2-one-card-three-hits-one-chip-settlement",
          a.attacks == 2 and sum(e[0] == "chip" for e in a.events) == 2,
          {"attack_commands": a.attacks, "chip_events": [e for e in a.events if e[0] == "chip"]})
    a = State(strength=2)
    play(a, card("empower"), 1, p_enabled=False)
    play(a, card("flurry"), 2, c_enabled=False)
    check("Q2-producer-erasure-preserves-other-Strength", a.strength == 2 and physical(a) == 12,
          {"strength": a.strength, "physical": physical(a)})
    a = State()
    play(a, card("flurry"), 2)
    play(a, card("empower"), 1)
    check("Q2-reverse-order-no-retroactive-payoff", physical(a) == 6, physical(a))
    a = State()
    play(a, card("empower"), 1)
    check("Q2-producer-only-no-hit", physical(a) == 0 and a.strength == 2, public(a))
    a = State()
    r = play(a, card("flurry"), 2)
    check("Q2-consumer-independently-enabled", r == "PLAYED" and physical(a) == 6, [r, physical(a)])

    # The old chip factors do not remove native Strength on either side.
    old = {}
    for family, enabled in product(("one-bit", "power-cycle"), (False, True)):
        s = State()
        play(s, card("empower"), 1, family=family, enabled=enabled)
        play(s, card("flurry"), 2, family=family, enabled=enabled)
        old[f"{family}:{enabled}"] = [s.strength, physical(s), s.enemies[0].chips, s.ready]
    check("Q2-common-native-background-present-in-old-factors",
          all(v[:2] == [2, 12] for v in old.values()), old)
    native, disabled = State(), State()
    for c, uid in [(card("empower"), 1), (card("flurry"), 2)]:
        play(native, c, uid)
        play(disabled, c, uid, family="one-bit", enabled=False)
    check("old-factor-off-is-full-native-identity", public(native) == public(disabled),
          {"equal": public(native) == public(disabled), "ready": disabled.ready})
    check("Q2-old-active-payoff-not-Fervor-payoff",
          old["one-bit:True"][2] == 2 and old["one-bit:False"][2] == 1 and
          old["power-cycle:True"][2] == 1, old)
    a = State()
    play(a, card("empower"), 1)
    play(a, card("empower", True), 3)
    check("Q2-additive-state-not-setup-Boolean", a.strength == 5, a.strength)
    other = []
    for p_on, c_on in product((False, True), repeat=2):
        s = State(dusk=False)
        play(s, card("empower"), 1, p_enabled=p_on)
        play(s, card("flurry"), 2, c_enabled=c_on)
        other.append(public(s))
    check("other-aspect-wrapper-null-not-absence-of-native-Strength",
          all(x == other[0] for x in other) and physical(s) == 12,
          {"four_paths_equal": all(x == other[0] for x in other), "physical": physical(s)})
    a, b = State(), State()
    play(a, card("empower"), 1)
    play(a, card("flurry"), 2)
    play(b, card("empower"), 1, enabled=False, p_enabled=False)
    play(b, card("flurry"), 2, enabled=False, c_enabled=False)
    check("omitted-explicit-off-wrapper-identity", public(a) == public(b), public(b))

    for label, s, c, uid in [
            ("energy", State(energy=0), q1["P"], 1),
            ("copy", State(hand=[9]), q1["P"], 1),
            ("terminal", State(over=True), q1["P"], 1)]:
        before = deepcopy(s)
        r = play(s, c, uid)
        check("denial-" + label, r == "ILLEGAL_UNAVAILABLE" and s == before,
              {"result": r, "unchanged": s == before, "continuation": "UNKNOWN"})
    a = State(energy=1, discount=1)
    r = word(a, q1)
    check("effective-costs-not-fixed-two-Energy", r == ["PLAYED", "PLAYED"] and a.energy == 0,
          {"results": r, "paid": [e[3] for e in a.events if e[0] == "play"]})
    a = State(enemies=[Enemy(0, hp=2), Enemy(1)])
    play(a, q1["C"], 2, mutant=mutant)
    h = next(e for e in a.events if e[0] == "hit")
    check("native-amount-includes-ordinary-overkill", h[2:5] == [7, 5, 2], h)
    a = State(enemies=[Enemy(0, hp=2, finale=True), Enemy(1)])
    play(a, q1["C"], 2, mutant=mutant)
    h = next(e for e in a.events if e[0] == "hit")
    check("native-finale-handoff-clamps-amount", h[2:5] == [1, 0, 1] and a.over, h)
    a = State(hp=2, enemies=[Enemy(0, thorns=3), Enemy(1)])
    play(a, card("flurry"), 2, mutant=mutant)
    check("lethal-Thorns-interrupts-sequential-hits", a.over and physical(a) == 2,
          {"physical": physical(a), "over": a.over})
    a = State(enemies=[Enemy(0, hp=2), Enemy(1)], reaper=True)
    play(a, card("flurry"), 2)
    check("nonfinal-death-keeps-resource-obligation", a.energy == 4 and a.draws_owed == 1,
          {"energy": a.energy, "draws_owed_not_cards": a.draws_owed})
    a = State(enemies=[Enemy(0, chips=4), Enemy(1)], bell=True)
    play(a, card("flurry"), 2, mutant=mutant)
    kinds = [e[0] for e in a.events]
    check("deferred-Shatter-after-all-hits", kinds.index("shatter") > max(i for i, e in enumerate(a.events) if e[0] == "hit" and e[1] == 0), a.events)
    a = State(strength=5, attributed=3)
    phase_boundary(a, mutant)
    fresh = State()
    check("combat-reset-not-turn-reset", a.strength == 5 and fresh.strength == 0,
          {"after_phase": a.strength, "new_combat": fresh.strength})
    failed = [c["name"] for c in checks if not c["pass"]]
    return {"schema": "DD1-SOURCE-1-CHECKS-1", "native": False,
            "certificate": False, "mutant": mutant, "checks": checks,
            "summary": {"named_checks": len(checks), "q1_cells": count,
                        "q2_contexts": q2_count, "q2_factor_cells": q2_count * 4,
                        "failed": failed}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mutant", default="", choices=("", "drop-stun", "wrong-target",
                        "per-hit-chips", "consume-strength", "reset-strength",
                        "power-exhaust", "clamp-amount"))
    args = parser.parse_args()
    result = run(args.mutant)
    print(canonical(result))
    raise SystemExit(2 if result["summary"]["failed"] else 0)
