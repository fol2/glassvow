#!/usr/bin/env python3
"""D542 fixed-slate SOURCE PROJECTION checks; never a native run or admission.

Default inputs were transcribed from GitHub reads at the pinned blobs. Only the
bundled complete CardInst blob is hash-recomputed by default. --repository adds
read-only git-object/path/fragment verification. Plain combat projections reject
unsupported collateral contexts; UNKNOWN is not zero or scientific futility.
"""
from __future__ import annotations
import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent

class Unknown(ValueError):
    """The projection cannot establish a native continuation."""


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise Unknown(reason)


def blob_sha(text: str) -> str:
    raw = text.encode()
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def legal(energy: int, cost: int, *, hand: bool = True,
          alive: bool = True, over: bool = False) -> bool:
    return hand and alive and not over and energy >= cost


def hit(base: int, strength: int, hp: int, block: int = 0, *,
        weak: bool = False, cracked: bool = False,
        thorns: int = 0, finale: bool = False) -> dict:
    require(all(type(x) is int and x >= 0 for x in (base, strength, hp, block)),
            "nonnegative-integer-domain")
    require(hp > 0, "dead-target:unavailable-tail=UNKNOWN")
    require(thorns == 0 and not finale, "collateral-native-continuation-required")
    damage = base + strength
    if weak:
        damage = damage * 3 // 4
    if cracked:
        damage = damage * 3 // 2
    blocked = min(block, damage)
    reported = damage - blocked
    return dict(nominal=damage, blocked=blocked, reported_loss=reported,
                hp_removed=min(hp, reported), overkill=max(0, reported - hp),
                hp=max(0, hp - reported), block=block - blocked)


def facet(chips: int, maximum: int, earned: int, *, connected: bool = True,
          alive: bool = True, adamant: bool = False, embers: int = 0,
          cap: int = 10, collateral: bool = False) -> dict:
    """One threshold only, no explicit-chip effect; printed chip needs blood."""
    require(maximum >= 2 and 0 <= chips < maximum and earned >= 0,
            "invalid-facet-domain")
    require(not collateral, "full-shatter-collateral-required")
    total = chips + (earned if connected and alive else 0)
    shatter = total >= maximum
    require(not shatter or total - maximum < maximum + 1,
            "multiple-shatter-domain-not-modelled")
    actual = shatter and not adamant
    return dict(chips=total - maximum if shatter else total,
                maximum=maximum + int(shatter), staggered=actual,
                vulnerable=2 if actual else 0,
                embers=min(cap, embers + 2) if actual else embers,
                adamant_spent=shatter and adamant, attributed=actual)


def echo(staggered: bool, vulnerable: int) -> int:
    return 2 if staggered or vulnerable > 0 else 1


def attributed_echo(shatter: dict, *, same_target: bool,
                    preexisting_direct: bool) -> bool:
    return (shatter["attributed"] and same_target and not preexisting_direct)


def flurry(base: int, added: int, *, background: int = 0,
           producer: bool = True, repeated_component: bool = True,
           hp: int = 1000, block: int = 0) -> dict:
    """Three hits; C- removes ONLY producer Strength on hits 2+, not hits."""
    rows = []
    for i in range(3):
        if hp <= 0:
            break  # no invented damage/chip/continuation for a dead target
        contribution = added if producer and (i == 0 or repeated_component) else 0
        row = hit(base, background + contribution, hp, block)
        rows.append(row)
        hp, block = row["hp"], row["block"]
    return dict(hits=rows, removed=sum(x["hp_removed"] for x in rows),
                chip_settlements=int(hp > 0 and any(x["reported_loss"] > 0 for x in rows)),
                hp=hp, block=block, card_lifecycles=1)


def fervor_interaction(base: int, added: int, **kwargs: int) -> int:
    values = {(p, c): flurry(base, added, producer=p, repeated_component=c,
                             **kwargs)["removed"]
              for p in (False, True) for c in (False, True)}
    return values[True, True] - values[True, False] - values[False, True] + values[False, False]


@dataclass
class Instance:
    fight: int
    uid: int
    bonus: int = 0
    zone: str = "hand"


def honing(card: Instance, base: int, growth: int, energy: int) -> tuple[int, int]:
    require(legal(energy, 1, hand=card.zone == "hand"), "illegal-consumer:UNKNOWN-tail")
    amount = base + card.bonus
    card.bonus += growth
    card.zone = "discard"
    return amount, energy - 1


def reshuffle(discard: list[Instance], permutation: list[int], *,
              draw_empty: bool = True) -> list[Instance]:
    require(draw_empty, "no-reshuffle-while-draw-nonempty")
    require(sorted(permutation) == list(range(len(discard))), "not-a-permutation")
    require(all(x.zone == "discard" for x in discard), "wrong-source-zone")
    result = [discard[i] for i in permutation]
    for card in result:
        card.zone = "draw"
    return result


def draw(card: Instance, hand_size: int) -> None:
    require(card.zone == "draw" and 0 <= hand_size < 10, "no-legal-draw")
    card.zone = "hand"


def exact_repeat(events: list[tuple[int, int]]) -> bool:
    return any(n >= 2 for n in Counter(events).values())


def nominal_grammar(events: list[str], kind: str) -> list[bool]:
    """Archived nomination predicates ONLY; native background not deleted."""
    power = cycle = False
    out = []
    for action in events:
        power |= action == "power"
        cycle |= action == "cycle"
        if action == "attack":
            eligible = power and (cycle if kind == "two-bit" else True)
            out.append(eligible)
            if kind == "one-bit" or eligible:
                power = False
                if kind == "two-bit":
                    cycle = False
    return out


def validate_parameters(values: dict) -> None:
    expected = {"chisel": [1, 4, 7, 1], "resonantLance": [1, 7, 10],
                "empower": [1, 2, 3], "flurry": [1, 2, 3, 3],
                "momentum": [1, 6, 4, 8, 6, 0], "deflect": [1, 6, 9, 1]}
    require(values == expected, "not-the-fixed-shipping-projection")


def verify_repository(repo: str, manifest: dict) -> list[str]:
    checked = []
    for entry in manifest["sources"]:
        raw = subprocess.check_output(["git", "--no-optional-locks", "-C", repo,
                                       "show", entry["commit"] + ":" + entry["path"]])
        text = raw.decode("utf-8")
        require(blob_sha(text) == entry["blob"], "source-blob-mismatch:" + entry["id"])
        for fragment in entry.get("fragments", []):
            require(fragment in text, "source-fragment-mismatch:" + entry["id"])
        checked.append(entry["id"])
    return checked


def run(manifest: dict) -> list[dict]:
    checks = []
    def eq(name: str, actual: object, expected: object) -> None:
        require(actual == expected, "check-failed:" + name)
        checks.append(dict(name=name, observed=actual, expected=expected, result="MATCH"))
    def rejected(name: str, fn) -> None:
        try:
            fn()
        except Unknown as exc:
            checks.append(dict(name=name, result="EXPECTED_REJECTION", reason=str(exc)))
            return
        raise Unknown("contrary-not-rejected:" + name)
    validate_parameters(manifest["parameters"])
    inst_source = next(x for x in manifest["sources"] if x["id"] == "card_inst")
    eq("complete-CardInst-git-blob", blob_sha(manifest["card_inst_complete"]), inst_source["blob"])
    bad = dict(manifest["parameters"], flurry=[1, 0, 1, 5])
    rejected("closed-five-hit-card-not-shipping", lambda: validate_parameters(bad))
    for vow in (0, 5):
        prefix = "V" + str(vow) + ":"  # rules projection, NOT vow reachability
        sh = facet(0, 2, 2)
        eq(prefix + "Chisel-coupled-Shatter", sh,
           dict(chips=0, maximum=3, staggered=True, vulnerable=2,
                embers=2, adamant_spent=False, attributed=True))
        eq(prefix + "retarget-does-not-transfer-Echo", [echo(True, 2), echo(False, 0)], [2, 1])
        eq(prefix + "direct-Cracked-aliases-Echo-guard", echo(False, 2), echo(True, 2))
        eq(prefix + "preexisting-Cracked-not-attributed", attributed_echo(sh, same_target=True, preexisting_direct=True), False)
        eq(prefix + "other-target-not-attributed", attributed_echo(sh, same_target=False, preexisting_direct=False), False)
        eq(prefix + "blocked-Chisel-earns-no-printed-chip", facet(0, 2, 2, connected=False)["chips"], 0)
        eq(prefix + "dead-target-earns-no-Shatter", facet(0, 2, 2, alive=False)["attributed"], False)
        adamant = facet(0, 2, 2, adamant=True)
        eq(prefix + "adamant-first-break-is-not-Shatter", [adamant["maximum"], adamant["attributed"], adamant["embers"]], [3, False, 0])
        eq(prefix + "Echo-reads-before-own-chip-settlement", hit(7 * echo(False, 0), 0, 100)["nominal"], 7)
        eq(prefix + "later-Echo-keeps-Cracked-modifier", hit(7 * echo(True, 2), 0, 100, cracked=True)["nominal"], 21)
        for base, strength in ((2, 2), (3, 3)):
            eq(prefix + f"Fervor-plain-interaction-{base}-{strength}", fervor_interaction(base, strength), 2 * strength)
        eq(prefix + "Fervor-one-chip-settlement-not-three", flurry(2, 2)["chip_settlements"], 1)
        eq(prefix + "Fervor-one-lifecycle", flurry(2, 2)["card_lifecycles"], 1)
        eq(prefix + "Fervor-background-Strength-retained", fervor_interaction(2, 2, background=5), 4)
        eq(prefix + "blocked-Fervor-refutes-universal-formula", fervor_interaction(2, 2, block=100), 0)
        eq(prefix + "terminal-Fervor-no-later-hits-or-chip", [len(flurry(2, 2, hp=1)["hits"]), flurry(2, 2, hp=1)["chip_settlements"]], [1, 0])
        first = Instance(vow, 101)
        eq(prefix + "Honing-hits-before-growth", honing(first, 6, 4, 3), (6, 2))
        returned = reshuffle([first], [0])[0]  # singleton admissible permutation, not a sampled deck
        draw(returned, 0)
        eq(prefix + "same-object-returned", returned is first, True)
        eq(prefix + "same-UID-replay", honing(returned, 6, 4, 1), (10, 0))
        eq(prefix + "second-copy-has-no-growth", honing(Instance(vow, 102), 6, 4, 1), (6, 0))
        eq(prefix + "new-combat-same-UID-resets", honing(Instance(vow + 10, 101), 6, 4, 1), (6, 0))
        eq(prefix + "same-ID-not-same-UID", exact_repeat([(vow, 101), (vow, 102)]), False)
        eq(prefix + "same-UID-not-same-combat", exact_repeat([(vow, 101), (vow + 1, 101)]), False)
        eq(prefix + "archive-exact-repeat-projection", exact_repeat([(vow, 101), (vow, 101)]), True)
        eq(prefix + "later-damage-alone-not-growth-proof", hit(10, 0, 100), hit(6, 4, 100))
    eq("Power-bit-consumed-before-later-Attack", nominal_grammar(["power", "attack", "attack"], "one-bit"), [True, False])
    eq("Power-cycle-requires-distinct-cycle", nominal_grammar(["power", "attack"], "two-bit"), [False])
    eq("Power-cycle-accepts-either-order", nominal_grammar(["cycle", "power", "attack"], "two-bit"), [True])
    eq("overkill-not-physical-hp-removal", [hit(10, 0, 3)["reported_loss"], hit(10, 0, 3)["hp_removed"]], [10, 3])
    eq("Block-carried-between-hits", flurry(2, 2, block=6)["removed"], 6)
    eq("consumer-independently-affordable-without-mediator", legal(1, 1), True)
    eq("energy-denial-not-payoff-zero", legal(0, 1), False)
    rejected("Thorns-not-erased", lambda: hit(6, 0, 100, thorns=1))
    rejected("finale-not-ordinary-terminal", lambda: hit(6, 0, 100, finale=True))
    rejected("dead-target-tail-UNKNOWN", lambda: hit(6, 0, 0))
    rejected("Bell-Prism-Smolder-not-erased", lambda: facet(0, 2, 2, collateral=True))
    rejected("duplicate-instance-in-reshuffle", lambda: reshuffle([Instance(0, 1, zone="discard")], [0, 0]))
    rejected("no-forced-discard-to-hand", lambda: draw(Instance(0, 1, zone="discard"), 0))
    rejected("hand-cap-preserved", lambda: draw(Instance(0, 1, zone="draw"), 10))
    rejected("unaffordable-replay", lambda: honing(Instance(0, 1), 6, 4, 0))
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", type=Path, default=HERE / "SOURCE-INPUTS.json")
    parser.add_argument("--repository", help="Optional read-only full git-object validation")
    args = parser.parse_args()
    try:
        manifest = json.loads(args.inputs.read_text())
        source_verified = verify_repository(args.repository, manifest) if args.repository else []
        checks = run(manifest)
        result = dict(kind="SOURCE_PROJECTION_CHECKS_NOT_NATIVE_EVIDENCE", checks=checks,
                      check_count=len(checks), all_checks_matched=True,
                      checker_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                      inputs_sha256=hashlib.sha256(args.inputs.read_bytes()).hexdigest(),
                      full_repository_blobs_verified=source_verified,
                      default_source_transport="GitHub read pins and manual source correspondence; complete CardInst recomputed",
                      source_qualified_leads=[], full_closed_family_quotient_proved=False,
                      native_calls=0, empirical_spend=0, certificates=0)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (Unknown, OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print("SOURCE_CHECK_REJECTED: " + str(exc), file=sys.stderr)
        return 2

if __name__ == "__main__":
    sys.exit(main())
