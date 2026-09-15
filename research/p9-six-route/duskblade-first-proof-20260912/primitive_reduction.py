"""D547-PC1 Boolean reductions from validated, root-aligned observations.

No authentication, numerical thresholds, binding, or execution authority lives
here. The adapter must establish the identity and alignment of each input first.
"""
from __future__ import annotations


def binary(values: list[int]) -> list[int]:
    if not isinstance(values, list) or not values:
        raise ValueError("nonempty binary list required")
    if any(type(value) is not int or value not in (0, 1) for value in values):
        raise ValueError("binary integer required")
    return values


def aligned(*values: list[int]) -> None:
    if len({len(value) for value in values}) != 1:
        raise ValueError("mismatched per-root rows")


def paired(left: list[int], right: list[int]) -> tuple[list[int], list[int]]:
    """Paired gain/loss are mutually exclusive at every effective root."""
    left, right = binary(left), binary(right)
    aligned(left, right)
    return ([a * (1 - b) for a, b in zip(left, right)],
            [(1 - a) * b for a, b in zip(left, right)])


def route(win: list[int], acquired: list[int], enacted: list[int],
          other_in_same_arm: list[int]) -> dict[str, list[int]]:
    """Other membership is observed in this arm, never in the other arm."""
    win, acquired, enacted, other = map(
        binary, (win, acquired, enacted, other_in_same_arm))
    aligned(win, acquired, enacted, other)
    if any(e > a for e, a in zip(enacted, acquired)):
        raise ValueError("enactment without acquisition at that root")
    return {"acquire": acquired[:], "enact": enacted[:],
            "win_enact": [w * e for w, e in zip(win, enacted)],
            "exclusive": [e * (1 - o) for e, o in zip(enacted, other)]}
