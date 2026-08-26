#!/usr/bin/env python3
"""Versioned #454 development-seed contract. Fail closed on overlap with the exam."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
CONTRACT_REL = "docs/balance/421-content-search-seeds-v1.json"
SPACE_REL = "docs/balance/421-content-search-space-v1.json"
LIVE_REL = "content/full-content.json"
MOBS_REL = "content/mob-overrides.json"
DRIVER_RELS = (
    "tools/balance_sim.gd",
    "tools/balance_sweep.gd",
    "tools/balance_cem.gd",
    "tools/balance_pilot.gd",
    "tools/balance_policy.gd",
    "tools/balance_catalogue.gd",
)


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON {path}: {exc}") from exc


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def semantic_sha256(path: Path) -> str:
    return sha256_bytes(canonical_json_bytes(read_json(path)))


def driver_sha256(repo: Path = REPO) -> str:
    acc = "".join(rel + "\n" + (repo / rel).read_text(encoding="utf-8") for rel in DRIVER_RELS)
    return sha256_bytes(acc.encode())


def load_contract(repo: Path = REPO) -> dict[str, Any]:
    path = repo / CONTRACT_REL
    contract = read_json(path)
    if contract.get("schemaVersion") != 1 or contract.get("id") != "421-content-search-seeds-v1":
        raise ValueError(f"unsupported seed contract: {path}")
    return contract


def _span(first: int, last: int) -> tuple[int, int]:
    if last < first:
        raise ValueError(f"empty seed span {first}..{last}")
    return first, last


def _band_span(band: dict[str, Any]) -> tuple[int, int]:
    return _span(int(band["first"]), int(band["last"]))


def _overlaps(left: tuple[int, int], right: tuple[int, int]) -> bool:
    return left[0] <= right[1] and right[0] <= left[1]


def _contains(outer: tuple[int, int], inner: tuple[int, int]) -> bool:
    return outer[0] <= inner[0] and inner[1] <= outer[1]


def _named_bands(contract: dict[str, Any]) -> dict[str, tuple[int, int]]:
    exam = contract["exam"]
    bands = {row["id"]: _band_span(row) for row in exam["seedBands"]}
    bands[exam["reserve"]["id"]] = _band_span(exam["reserve"])
    for name, stage in contract["stages"].items():
        if name == "exam":
            continue
        bands[name] = _band_span(stage["seeds"])
        if "holdout" in stage:
            bands[f"{name}-holdout"] = _band_span(stage["holdout"])
    unused = contract.get("tier2", {}).get("unused")
    if unused:
        bands[str(unused["id"])] = _band_span(unused)
    return bands


def protected_spans(contract: dict[str, Any]) -> list[tuple[int, int]]:
    exam = contract["exam"]
    spans = [_band_span(row) for row in exam["seedBands"]]
    spans.append(_band_span(exam["reserve"]))
    return spans


def development_spans(contract: dict[str, Any]) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    for name, stage in contract["stages"].items():
        if name == "exam":
            continue
        spans.append(_band_span(stage["seeds"]))
        if "holdout" in stage:
            spans.append(_band_span(stage["holdout"]))
    return spans


def validate_contract(contract: dict[str, Any]) -> None:
    exam_roots = set(int(r) for r in contract["exam"]["roots"])
    if exam_roots != {215, 216}:
        raise ValueError("exam roots must remain 215 and 216")
    development = contract["development"]
    for key, expected in (("f0PolicyRoot", 454), ("f1PolicyRoot", 1454), ("miniCemRoot", 2454)):
        if int(development[key]) != expected:
            raise ValueError(f"{key} must be {expected}")
        if int(development[key]) in exam_roots:
            raise ValueError(f"{key} overlaps the frozen exam roots")
    tier1 = contract["tier1"]
    for key, expected in (("f0PolicyRoot", 3454), ("f1PolicyRoot", 4454), ("miniCemRoot", 6454)):
        if int(tier1[key]) != expected:
            raise ValueError(f"tier1.{key} must be {expected}")
        if int(tier1[key]) in exam_roots:
            raise ValueError(f"tier1.{key} overlaps the frozen exam roots")
        if int(tier1[key]) in {int(development["f0PolicyRoot"]), int(development["f1PolicyRoot"]),
                               int(development["miniCemRoot"])}:
            raise ValueError(f"tier1.{key} overlaps a #454 development root")
    prior_roots = exam_roots | {int(development["f0PolicyRoot"]), int(development["f1PolicyRoot"]),
                                int(development["miniCemRoot"]), int(tier1["f0PolicyRoot"]),
                                int(tier1["f1PolicyRoot"]), int(tier1["miniCemRoot"])}
    tier2 = contract["tier2"]
    for key, expected in (("f0PolicyRoot", 7454), ("f1PolicyRoot", 8454), ("miniCemRoot", 9454),
                          ("profileCensusRoot", 7354)):
        if int(tier2[key]) != expected:
            raise ValueError(f"tier2.{key} must be {expected}")
        if int(tier2[key]) in prior_roots:
            raise ValueError(f"tier2.{key} overlaps a prior exam or development root")
    unused = _band_span(tier2["unused"])
    if unused != (13400, 13999):
        raise ValueError("tier2 unused band must remain 13400–13999")
    bands = _named_bands(contract)
    unique_spans: dict[tuple[int, int], list[str]] = {}
    for name, span in bands.items():
        unique_spans.setdefault(span, []).append(name)
    spans = list(unique_spans)
    for i, left in enumerate(spans):
        for right in spans[i + 1:]:
            if _overlaps(left, right):
                raise ValueError(
                    f"seed bands overlap: {unique_spans[left]} {left} and {unique_spans[right]} {right}"
                )
    axes = contract["frozenLandscape"]
    if axes["tieOrder"] != ["shatter", "smolder", "attrition"]:
        raise ValueError("frozen landscape tie order must stay shatter, smolder, attrition")
    cuts = axes["deckCuts"]
    if int(cuts["thinMax"]) != 25 or int(cuts["midMax"]) != 35:
        raise ValueError("frozen #215 deck cuts must stay thinMax=25, midMax=35")


def _in_any(span: tuple[int, int], bands: list[tuple[int, int]]) -> bool:
    return any(_overlaps(span, band) for band in bands)


def _inside_one(span: tuple[int, int], bands: list[tuple[int, int]]) -> bool:
    return any(_contains(band, span) for band in bands)


def check_invocation(contract: dict[str, Any], stage: str, seed_first: int, seed_last: int,
                     root: int | None = None, holdout_first: int | None = None,
                     holdout_last: int | None = None, sealed_token: str | None = None) -> str:
    if not stage:
        return ""
    stages = contract["stages"]
    if stage not in stages:
        return f"unknown --stage {stage}"
    spec = stages[stage]
    if spec.get("sealedUntil") and sealed_token != str(spec["sealedUntil"]):
        return f"--stage {stage} is sealed until {spec['sealedUntil']}"
    seed_span = _span(seed_first, seed_last)
    exam_roots = {int(r) for r in contract["exam"]["roots"]}
    if stage == "exam":
        bands = [_band_span(row) for row in spec["seedBands"]]
        if not _inside_one(seed_span, bands):
            return f"exam seeds {seed_first}..{seed_last} are outside the frozen exam bands"
        if _in_any(seed_span, development_spans(contract)):
            return f"exam seeds {seed_first}..{seed_last} overlap a development band"
        if root is not None and int(root) not in exam_roots:
            return f"exam --rootSeed {root} is not 215 or 216"
        if holdout_first is not None:
            holdout_span = _span(holdout_first, holdout_last if holdout_last is not None else holdout_first)
            if not _inside_one(holdout_span, bands):
                return f"exam holdout {holdout_span[0]}..{holdout_span[1]} is outside the frozen exam bands"
        return ""
    allowed = _band_span(spec["seeds"])
    if not _contains(allowed, seed_span):
        return f"--stage {stage} seeds {seed_first}..{seed_last} must sit inside {allowed[0]}..{allowed[1]}"
    if _in_any(seed_span, protected_spans(contract)):
        return f"--stage {stage} overlaps the frozen exam or reserve"
    allowed_roots = [int(r) for r in spec.get("roots", [])]
    if root is not None:
        if int(root) in exam_roots:
            return f"--stage {stage} cannot use frozen exam root {root}"
        if allowed_roots and int(root) not in allowed_roots:
            return f"--stage {stage} --rootSeed must be {allowed_roots}, got {root}"
    if "holdout" in spec:
        if holdout_first is None:
            return f"--stage {stage} requires a holdout inside {spec['holdout']['first']}..{spec['holdout']['last']}"
        holdout_span = _span(holdout_first, holdout_last if holdout_last is not None else holdout_first)
        if not _contains(_band_span(spec["holdout"]), holdout_span):
            return (
                f"--stage {stage} holdout {holdout_span[0]}..{holdout_span[1]} must sit inside "
                f"{spec['holdout']['first']}..{spec['holdout']['last']}"
            )
        if _in_any(holdout_span, protected_spans(contract)):
            return f"--stage {stage} holdout overlaps the frozen exam or reserve"
    elif holdout_first is not None:
        holdout_span = _span(holdout_first, holdout_last if holdout_last is not None else holdout_first)
        if _in_any(holdout_span, protected_spans(contract)):
            return f"--stage {stage} holdout overlaps the frozen exam or reserve"
    return ""


def resolve_mobs_path(candidate: dict[str, Any] | None = None, bundle: Path | None = None,
                      repo: Path = REPO) -> Path:
    if candidate:
        raw = candidate.get("mobsPath") or candidate.get("mobs")
        if raw:
            return Path(str(raw))
        ident = str(candidate.get("id", ""))
        if bundle is not None and ident:
            sibling = bundle / ident / "mob-overrides.json"
            if sibling.is_file():
                return sibling
    return repo / MOBS_REL


def catalogue_identity(content_path: Path, space_path: Path, repo: Path = REPO,
                       mobs_path: Path | None = None) -> dict[str, str]:
    mobs = Path(mobs_path) if mobs_path is not None else repo / MOBS_REL
    return {
        "contentPath": str(content_path),
        "contentFileSha256": file_sha256(content_path),
        "contentSemanticSha256": semantic_sha256(content_path),
        "mobOverridePath": str(mobs),
        "mobOverrideFileSha256": file_sha256(mobs),
        "mobOverrideSemanticSha256": semantic_sha256(mobs),
        "searchSpacePath": str(space_path),
        "searchSpaceSha256": file_sha256(space_path),
        "seedContractSha256": file_sha256(repo / CONTRACT_REL),
        "driverSha256": driver_sha256(repo),
    }


def self_test() -> int:
    contract = load_contract()
    validate_contract(contract)
    err = check_invocation(contract, "f0-controls", 5000, 5000)
    assert err, "F0 must reject acceptance seed 5000"
    err = check_invocation(contract, "f0-controls", 5200, 5200)
    assert err, "F0 must reject reserve seed 5200"
    err = check_invocation(contract, "f0-mini-landscape", 6100, 6107, root=215)
    assert err, "F0 must reject exam policy root 215"
    err = check_invocation(contract, "f1-racing", 6200, 6200, root=216)
    assert err, "F1 must reject exam CEM root 216"
    err = check_invocation(contract, "exam", 5600, 5600, root=215)
    assert err, "exam must reject fingerprint seeds"
    err = check_invocation(contract, "exam", 5000, 5199, root=454)
    assert err, "exam must reject development policy root 454"
    err = check_invocation(contract, "f1-mini-cem", 6400, 6439, root=2454, holdout_first=5000, holdout_last=5039)
    assert err, "mini-CEM must reject acceptance holdout 5000"
    err = check_invocation(contract, "f1-mini-cem-train", 6400, 6439, root=2454,
                           holdout_first=5000, holdout_last=5199)
    assert err, "mini-CEM train must reject CEM's default exam holdout 5000"
    err = check_invocation(contract, "audit", 8000, 8000, root=454)
    assert err, "audit must stay sealed until finalist"
    assert not check_invocation(contract, "audit", 8000, 8199, root=1454,
                                sealed_token="finalist")
    assert not check_invocation(contract, "f0-controls", 6000, 6031, root=454)
    assert not check_invocation(contract, "f0-mini-landscape", 6100, 6107, root=454)
    assert not check_invocation(contract, "fingerprint", 5600, 5663)
    assert not check_invocation(contract, "f1-mini-cem", 6400, 6439, root=2454, holdout_first=6800, holdout_last=6839)
    assert not check_invocation(contract, "f1-mini-cem-train", 6400, 6439, root=2454,
                                holdout_first=6800, holdout_last=6999)
    assert not check_invocation(contract, "exam", 5000, 5199, root=215)
    assert check_invocation(contract, "nope", 6000, 6000)
    tier1 = contract["tier1"]
    assert int(tier1["f0PolicyRoot"]) == 3454
    assert int(tier1["f1PolicyRoot"]) == 4454
    assert int(tier1["miniCemRoot"]) == 6454
    assert not check_invocation(contract, "tier1-fingerprint", 9000, 9063)
    assert not check_invocation(contract, "tier1-f0-controls", 9100, 9131, root=3454)
    assert not check_invocation(contract, "tier1-f0-mini-landscape", 9200, 9207, root=3454)
    assert not check_invocation(contract, "tier1-f1-racing", 9300, 9599, root=4454)
    assert not check_invocation(contract, "tier1-mini-cem", 9600, 9639, root=6454,
                                holdout_first=10000, holdout_last=10039)
    assert not check_invocation(contract, "tier1-mini-cem-train", 9600, 9999, root=6454,
                                holdout_first=10000, holdout_last=10399)
    assert not check_invocation(contract, "tier1-mini-cem-validate", 10000, 10399, root=6454)
    assert not check_invocation(contract, "tier1-audit", 11000, 11199, root=3454,
                                sealed_token="tier1-finalist")
    assert check_invocation(contract, "tier1-fingerprint", 5600, 5663), (
        "Tier-1 fingerprint must reject the #456 host-fingerprint band")
    assert check_invocation(contract, "tier1-f0-controls", 5000, 5000, root=3454), (
        "Tier-1 F0 must reject acceptance seed 5000")
    assert check_invocation(contract, "tier1-f0-controls", 6000, 6000, root=3454), (
        "Tier-1 F0 must reject the #454 F0 control band")
    assert check_invocation(contract, "tier1-f0-controls", 9100, 9131, root=454), (
        "Tier-1 F0 must reject the #454 policy root")
    assert check_invocation(contract, "tier1-f1-racing", 9300, 9300, root=215), (
        "Tier-1 F1 must reject exam policy root 215")
    assert check_invocation(contract, "tier1-f1-racing", 9300, 9300, root=1454), (
        "Tier-1 F1 must reject the #454 F1 policy root")
    assert check_invocation(contract, "tier1-mini-cem", 9600, 9639, root=6454,
                            holdout_first=5000, holdout_last=5039), (
        "Tier-1 mini-CEM must reject acceptance holdout 5000")
    assert check_invocation(contract, "tier1-mini-cem", 9600, 9639, root=6454,
                            holdout_first=6800, holdout_last=6839), (
        "Tier-1 mini-CEM must reject the #454 development holdout")
    assert check_invocation(contract, "tier1-audit", 11000, 11000, root=3454), (
        "Tier-1 audit must stay sealed until a Tier-1 finalist")
    assert check_invocation(contract, "tier1-audit", 8000, 8000, root=3454,
                            sealed_token="tier1-finalist"), (
        "Tier-1 audit must reject the #454 audit band")
    tier2 = contract["tier2"]
    assert int(tier2["f0PolicyRoot"]) == 7454
    assert int(tier2["f1PolicyRoot"]) == 8454
    assert int(tier2["miniCemRoot"]) == 9454
    assert int(tier2["profileCensusRoot"]) == 7354
    assert not check_invocation(contract, "tier2-fingerprint", 12000, 12063)
    assert not check_invocation(contract, "tier2-profile-census", 12064, 12095, root=7354)
    assert not check_invocation(contract, "tier2-f0-controls", 12100, 12131, root=7454)
    assert not check_invocation(contract, "tier2-f0-mini-landscape", 12200, 12207, root=7454)
    assert not check_invocation(contract, "tier2-f1-racing", 12300, 12599, root=8454)
    assert not check_invocation(contract, "tier2-mini-cem", 12600, 12639, root=9454,
                                holdout_first=13000, holdout_last=13039)
    assert not check_invocation(contract, "tier2-mini-cem-train", 12600, 12999, root=9454,
                                holdout_first=13000, holdout_last=13399)
    assert not check_invocation(contract, "tier2-mini-cem-validate", 13000, 13399, root=9454)
    assert not check_invocation(contract, "tier2-audit", 14000, 14199, root=7454,
                                sealed_token="tier2-finalist")
    assert check_invocation(contract, "tier2-fingerprint", 9000, 9063), (
        "Tier-2 fingerprint must reject the Tier-1 host-fingerprint band")
    assert check_invocation(contract, "tier2-fingerprint", 12064, 12064), (
        "Tier-2 fingerprint must reject the profile-census band")
    assert check_invocation(contract, "tier2-f0-controls", 5000, 5000, root=7454), (
        "Tier-2 F0 must reject acceptance seed 5000")
    assert check_invocation(contract, "tier2-f0-controls", 9100, 9100, root=7454), (
        "Tier-2 F0 must reject the Tier-1 F0 control band")
    assert check_invocation(contract, "tier2-f0-controls", 12100, 12131, root=3454), (
        "Tier-2 F0 must reject the Tier-1 policy root")
    assert check_invocation(contract, "tier2-f0-controls", 13400, 13400, root=7454), (
        "Tier-2 F0 must reject the unused 13400–13999 band")
    assert check_invocation(contract, "tier2-profile-census", 12064, 12095, root=7454), (
        "profile census must reject the Tier-2 F0 policy root")
    assert check_invocation(contract, "tier2-f1-racing", 12300, 12300, root=215), (
        "Tier-2 F1 must reject exam policy root 215")
    assert check_invocation(contract, "tier2-mini-cem", 12600, 12639, root=9454,
                            holdout_first=5000, holdout_last=5039), (
        "Tier-2 mini-CEM must reject acceptance holdout 5000")
    assert check_invocation(contract, "tier2-mini-cem", 12600, 12639, root=9454,
                            holdout_first=10000, holdout_last=10039), (
        "Tier-2 mini-CEM must reject the Tier-1 holdout")
    assert check_invocation(contract, "tier2-audit", 14000, 14000, root=7454), (
        "Tier-2 audit must stay sealed until a Tier-2 finalist")
    assert check_invocation(contract, "tier2-audit", 11000, 11000, root=7454,
                            sealed_token="tier2-finalist"), (
        "Tier-2 audit must reject the Tier-1 audit band")
    live = REPO / LIVE_REL
    space = REPO / SPACE_REL
    identity = catalogue_identity(live, space)
    assert len(identity["contentFileSha256"]) == 64
    assert identity["contentFileSha256"] != identity["contentSemanticSha256"]
    assert identity["mobOverrideFileSha256"] != identity["mobOverrideSemanticSha256"]
    assert identity["mobOverrideSemanticSha256"] == semantic_sha256(REPO / MOBS_REL)
    print("balance seed contract self-test OK")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--stage", default="")
    parser.add_argument("--seed0", type=int)
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--rootSeed", type=int)
    parser.add_argument("--holdoutSeed0", type=int)
    parser.add_argument("--holdoutCount", type=int, default=1)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    contract = load_contract()
    validate_contract(contract)
    if not args.stage:
        print(json.dumps({"id": contract["id"], "stages": list(contract["stages"])}, sort_keys=True))
        return 0
    if args.seed0 is None:
        raise ValueError("--seed0 is required with --stage")
    last = args.seed0 + args.runs - 1
    holdout_last = None if args.holdoutSeed0 is None else args.holdoutSeed0 + args.holdoutCount - 1
    error = check_invocation(contract, args.stage, args.seed0, last, args.rootSeed,
                             args.holdoutSeed0, holdout_last)
    if error:
        print(f"balance_seed_contract: {error}", file=sys.stderr)
        return 2
    print(json.dumps({"stage": args.stage, "seeds": {"first": args.seed0, "last": last}}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError) as exc:
        print(f"balance_seed_contract: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
