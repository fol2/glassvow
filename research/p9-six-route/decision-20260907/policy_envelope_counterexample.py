"""Exact mathematical counterexample, NOT Glassvow execution or P9 admission.

A two-policy, binary-outcome decision problem demonstrates why absence of a
loss in the best adapted policy's value does not prove absence of a mechanism.
The producer/consumer family needs both components; the alternative does not.
No empirical outcomes, simulator results, or statistical significance are used.
This source is a test specification; its publication alone is not a test PASS.
"""
from fractions import Fraction
from itertools import permutations, product
import json

COMPONENTS = ("producer", "consumer", "alternative")


def policy_values(present):
    present = frozenset(present)
    return {
        "combination": int({"producer", "consumer"} <= present),
        "alternative": int("alternative" in present),
    }


def envelope(present):
    return max(policy_values(present).values())


def shapley():
    """Exact allocation for this declared finite game, not a P9 metric."""
    totals = {key: Fraction(0) for key in COMPONENTS}
    orders = list(permutations(COMPONENTS))
    for order in orders:
        before = frozenset()
        for component in order:
            after = before | {component}
            totals[component] += Fraction(
                envelope(after) - envelope(before), len(orders)
            )
            before = after
    return totals


def verify():
    rows = []
    for bits in product((0, 1), repeat=len(COMPONENTS)):
        present = frozenset(c for c, enabled in zip(COMPONENTS, bits) if enabled)
        values = policy_values(present)
        rows.append({"present": sorted(present), "policy_values": values,
                     "best_policy_value": envelope(present)})
        assert all(v in (0, 1) for v in values.values())
    full = frozenset(COMPONENTS)
    fixed_policy_loss = {}
    adapted_envelope_loss = {}
    for component in ("producer", "consumer"):
        removed = full - {component}
        fixed_policy_loss[component] = (
            policy_values(full)["combination"]
            - policy_values(removed)["combination"]
        )
        adapted_envelope_loss[component] = envelope(full) - envelope(removed)
        assert fixed_policy_loss[component] == 1
        assert adapted_envelope_loss[component] == 0
    assert envelope(full - {"alternative"}) == 1
    combination_interaction = (
        policy_values({"producer", "consumer"})["combination"]
        - policy_values({"producer"})["combination"]
        - policy_values({"consumer"})["combination"]
        + policy_values(set())["combination"]
    )
    assert combination_interaction == 1
    with_alternative = lambda subset: envelope(set(subset) | {"alternative"})
    envelope_interaction = (
        with_alternative({"producer", "consumer"})
        - with_alternative({"producer"})
        - with_alternative({"consumer"})
        + with_alternative(set())
    )
    assert envelope_interaction == 0
    allocation = shapley()
    assert allocation == {"producer": Fraction(1, 6),
                          "consumer": Fraction(1, 6),
                          "alternative": Fraction(2, 3)}
    assert sum(allocation.values()) == 1
    return {
        "scope": "EXACT_FINITE_MATHEMATICAL_COUNTEREXAMPLE_NOT_P9",
        "enumerated_states": len(rows), "rows": rows,
        "fixed_policy_loss": fixed_policy_loss,
        "adapted_envelope_loss": adapted_envelope_loss,
        "combination_interaction": combination_interaction,
        "envelope_interaction_with_alternative": envelope_interaction,
        "exact_shapley": {k: str(v) for k, v in allocation.items()},
        "claim": "A zero adapted-envelope loss is not a necessary failure of mechanism contribution.",
        "limits": ["This finite game is defined here; it is not a Glassvow rollout.",
                   "A frozen program can still adapt its build and actions to changed content.",
                   "Native same-state/sequence effects and whole-run adaptation are different estimands.",
                   "Natural acquisition, viability, detector validity, retention and release gates remain required.",
                   "Shapley values here neither rank Glassvow strategies nor certify plurality."]
    }


if __name__ == "__main__":
    print(json.dumps(verify(), indent=2, sort_keys=True))
