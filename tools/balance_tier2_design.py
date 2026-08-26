#!/usr/bin/env python3
"""Compile #508's complete Tier-2 factorial without mutating live catalogues."""
from __future__ import annotations
import argparse, itertools, json, shutil, subprocess, sys
from copy import deepcopy
from pathlib import Path
from typing import Any
from balance_content_doe import canonical_json_bytes, read_json, sha256_bytes
from balance_s009_reconstruct import catalogue_bytes, reconstruct
from balance_tier1_design import _diff, _pointer_set, pointer_get
REPO = Path(__file__).resolve().parents[1]
REGISTRY_REL = "docs/balance/421-mob-disruption-space-v1.json"; MOB_REL = "content/mob-overrides.json"
TOOL_ID = "glassvow-balance-tier2-design"; MARKER = f".{TOOL_ID}"
LEVELS = ("low", "baseline", "high"); ALLOWED_STATUS = {"poison", "weak", "frail", "vulnerable"}
def _identity(path: Path, value: Any) -> dict[str, str]:
    return {"fileSha256": sha256_bytes(path.read_bytes()),
            "semanticSha256": sha256_bytes(canonical_json_bytes(value))}
def _bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()
def _selected(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {row["id"]: row for pair in ("blockPair", "disruptionPair")
            for row in registry["selection"][pair]}
def _validate_registry(repo: Path, registry: dict[str, Any], base: dict[str, Any],
                       census: dict[str, Any], response: dict[str, Any]) -> None:
    design = registry.get("design", {}); knobs = registry.get("knobs", [])
    if registry.get("schemaVersion") != 1 or registry.get("issue") != 508:
        raise ValueError("registry must be issue #508 schema v1")
    expected_ids = ["blockMitigation", "blockTempoTrade", "disruptionIntensity", "disruptionTempoTrade"]
    if design != {"version": "baseline-anchored-lexicographic-full-factorial-v1",
                  "candidatePrefix": "t2-c", "count": 81, "levels": list(LEVELS),
                  "lexicographicLevelOrder": ["baseline", "low", "high"],
                  "knobOrder": expected_ids} or [row.get("id") for row in knobs] != expected_ids:
        raise ValueError("Tier-2 complete-factorial controls drifted")
    census_spec = registry["frozenCensus"]; census_path = repo / census_spec["path"]
    if sha256_bytes(census_path.read_bytes()) != census_spec["fileSha256"] \
            or census["raw"]["sha256"] != census_spec["rawSha256"] \
            or not census_spec.get("reuseOnly"):
        raise ValueError("frozen #502 census identity drifted")
    response_path = repo / registry["responseContract"]
    if sha256_bytes(response_path.read_bytes()) != registry["responseContractFileSha256"] \
            or response.get("issue") != 508 or response.get("factorialEffects", {}).get("knobOrder") != expected_ids:
        raise ValueError("frozen Tier-2 F0 response contract drifted")
    inherited = response["inheritedTier1"]; inherited_path = repo / inherited["path"]
    if sha256_bytes(inherited_path.read_bytes()) != inherited["fileSha256"]:
        raise ValueError("inherited Tier-1 response fields drifted")
    rows = {row["id"]: row for row in census["enemies"]}; selected = _selected(registry)
    if set(selected) != {"gravewarden", "shellback", "waylayer", "watcherEye"}:
        raise ValueError("selected profile package drifted")
    for pair in ("blockPair", "disruptionPair"):
        entries = registry["selection"].get(pair, [])
        if len(entries) != 2 or len({row["act"] for row in entries}) < 2 \
                or any(sum(row["counts"].get(grid, 0) for row in entries) < 1 for grid in response["grids"]):
            raise ValueError(f"{pair} must span two acts and all four grids")
    if {row["tier"] for row in selected.values()} < {"normal", "elite"}:
        raise ValueError("profile package must contain normal and elite enemies")
    locales = {code: read_json(repo / f"locale/{code}.json")["content"]["enemies"]
               for code in ("en", "zh-Hant")}
    for enemy_id, row in selected.items():
        frozen = rows.get(enemy_id, {})
        for key in ("act", "tier", "counts", "total", "gridsObserved", "localeNames", "moveIds", "startStatus", "aiHandled"):
            if row.get(key) != frozen.get(key): raise ValueError(f"{enemy_id} census field {key} drifted")
        if row["total"] < 24 or row["gridsObserved"] < 2 or any(enemy_id not in locale for locale in locales.values()):
            raise ValueError(f"{enemy_id} is not an admissible reachable localised profile")
        if sorted(base["enemies"][enemy_id]["moves"]) != sorted(row["moveIds"]):
            raise ValueError(f"{enemy_id} move-ID set drifted")
        expected_disruption = {(fx["move"], fx["status"], fx["who"], fx["n"])
                               for fx in frozen.get("statusEffects", [])
                               if fx.get("who") == "player" and fx.get("status") in ALLOWED_STATUS}
        registered_disruption = {(move.get("id"), move.get("status"), move.get("target"), move.get("amount"))
                                  for move in row.get("disruptionMoves", [])}
        if registered_disruption != expected_disruption:
            raise ValueError(f"{enemy_id} attributable disruption inventory drifted")
        for move in row.get("disruptionMoves", []):
            move_def = base["enemies"][enemy_id]["moves"].get(move.get("id"), {})
            effects = [fx for fx in move_def.get("fx", []) if fx.get("who") == move.get("target")
                       and fx.get("id") == move.get("status") and fx.get("n") == move.get("amount")]
            if move.get("target") != "player" or move.get("status") not in ALLOWED_STATUS \
                    or not effects or not move.get("aiPath"):
                raise ValueError(f"{enemy_id} disruption move is not executable and attributable")
    seen: set[str] = set()
    for knob in knobs:
        pair_ids = {row["id"] for row in registry["selection"][knob.get("pair", "")]}
        touched: set[str] = set()
        if set(knob.get("direction", {})) != set(LEVELS) or not knob.get("writes"):
            raise ValueError(f"{knob.get('id')} lacks three mechanistic directions")
        for write in knob["writes"]:
            path, values = write.get("path"), write.get("values", {})
            parts = str(path).split("/")
            if len(parts) < 5 or parts[1] != "enemies" or parts[2] not in pair_ids \
                    or parts[3] not in {"hp", "moves"} or path in seen or set(values) != set(LEVELS) \
                    or any(type(values[level]) is not int for level in LEVELS) or not write.get("evidence"):
                raise ValueError(f"invalid or colliding registered write: {path}")
            if parts[3] == "moves" and parts[-1] not in {"dmg", "block", "heal", "ramp", "times", "n"}:
                raise ValueError(f"non-numeric enemy leaf registered: {path}")
            baseline = pointer_get(base, path)
            minimum = 1 if parts[3] == "hp" or parts[-1] == "times" else 0
            if type(baseline) is not int or baseline != values["baseline"] \
                    or any(values[level] < minimum for level in LEVELS):
                raise ValueError(f"invalid whole-number centre or bound: {path}")
            seen.add(path); touched.add(parts[2])
        if touched != pair_ids: raise ValueError(f"{knob['id']} must couple both selected enemies")
    expected_fixed = {key: True for key in ("completeDefinitions", "sparseBetweenMobs", "names",
        "moveIdSets", "ai", "localeFiles", "tierFlags", "art", "startStatusShape",
        "wholeNumbers", "liveFiles")}
    if registry.get("fixed") != expected_fixed: raise ValueError("fixed candidate invariants drifted")
def _effective(base: dict[str, Any], registry: dict[str, Any], vector: dict[str, str]) \
        -> tuple[dict[str, Any], dict[str, Any]]:
    selected = _selected(registry); definitions = {key: deepcopy(base["enemies"][key]) for key in selected}
    root = {"enemies": definitions}; active: set[str] = set()
    for knob in registry["knobs"]:
        level = vector[knob["id"]]
        for write in knob["writes"]:
            _pointer_set(root, write["path"], write["values"][level])
            if level != "baseline": active.add(write["path"].split("/")[2])
    overlay = {key: definitions[key] for key in sorted(active)}
    content = deepcopy(base); content["enemies"].update(deepcopy(overlay))
    for enemy_id, definition in overlay.items():
        baseline = base["enemies"][enemy_id]
        if set(definition) != set(baseline) or set(definition["moves"]) != set(baseline["moves"]) \
                or definition["name"] != baseline["name"] or definition["art"] != baseline["art"] \
                or definition.get("startStatus", {}) != baseline.get("startStatus", {}) \
                or definition["hp"][0] > definition["hp"][1]:
            raise ValueError(f"incomplete or invalid generated definition: {enemy_id}")
    return overlay, content
def back_map(base: dict[str, Any], registry: dict[str, Any], overlay: dict[str, Any]) -> dict[str, str]:
    effective = deepcopy(base); effective["enemies"].update(deepcopy(overlay)); vector: dict[str, str] = {}
    for knob in registry["knobs"]:
        matches = [level for level in LEVELS if all(pointer_get(effective, write["path"]) == write["values"][level]
                                                   for write in knob["writes"])]
        if len(matches) != 1: raise ValueError(f"mob catalogue does not map uniquely to {knob['id']}")
        vector[knob["id"]] = matches[0]
    allowed = {write["path"] for knob in registry["knobs"] for write in knob["writes"]}
    changed = _diff({"enemies": {key: base["enemies"][key] for key in _selected(registry)}},
                    {"enemies": {key: effective["enemies"][key] for key in _selected(registry)}})
    if any(patch["path"] not in allowed for patch in changed): raise ValueError("unregistered mob change")
    return vector
def compile_design(repo: Path = REPO, registry_path: Path | None = None) \
        -> tuple[dict[str, Any], list[dict[str, Any]]]:
    path = registry_path or repo / REGISTRY_REL; registry = read_json(path)
    census = read_json(repo / registry["frozenCensus"]["path"]); response = read_json(repo / registry["responseContract"])
    packet = reconstruct(repo); base = packet["content"]; mobs_path = repo / MOB_REL; live_mobs = read_json(mobs_path)
    if packet["identity"]["fileSha256"] != registry["base"]["contentFileSha256"] \
            or packet["identity"]["semanticSha256"] != registry["base"]["contentSemanticSha256"] \
            or _identity(mobs_path, live_mobs) != {"fileSha256": registry["base"]["mobOverrideFileSha256"],
                                                   "semanticSha256": registry["base"]["mobOverrideSemanticSha256"]} \
            or live_mobs != {}:
        raise ValueError("registry is not centred on exact s009 plus exact empty mobs")
    _validate_registry(repo, registry, base, census, response)
    registry_id = _identity(path, registry); response_id = _identity(repo / registry["responseContract"], response)
    census_id = _identity(repo / registry["frozenCensus"]["path"], census)
    rows = itertools.product(registry["design"]["lexicographicLevelOrder"], repeat=4)
    candidates, artefacts, semantic = [], [], set()
    for index, levels in enumerate(rows):
        vector = dict(zip(registry["design"]["knobOrder"], levels, strict=True))
        overlay, content = _effective(base, registry, vector); mapped = back_map(base, registry, overlay)
        content_blob = catalogue_bytes(base); mob_blob = mobs_path.read_bytes() if not overlay else _bytes(overlay)
        content_id = {"fileSha256": sha256_bytes(content_blob), "semanticSha256": sha256_bytes(canonical_json_bytes(base))}
        mob_id = {"fileSha256": sha256_bytes(mob_blob), "semanticSha256": sha256_bytes(canonical_json_bytes(overlay))}
        effective_sha = sha256_bytes(canonical_json_bytes(content))
        payload = {"schemaVersion": 1, "id": f"t2-c{index:03d}", "baseline": index == 0,
                   "vector": vector, "backMappedVector": mapped, "mobOverrides": overlay,
                   "contentIdentity": content_id, "mobOverrideIdentity": mob_id,
                   "registryIdentity": registry_id, "effectiveCatalogueSemanticSha256": effective_sha}
        candidate_blob = _bytes(payload); candidate_id = {"fileSha256": sha256_bytes(candidate_blob),
                                                           "semanticSha256": sha256_bytes(canonical_json_bytes(payload))}
        record = {**payload, "candidateFileSha256": candidate_id["fileSha256"],
                  "candidateSemanticSha256": candidate_id["semanticSha256"]}
        candidates.append(record); artefacts.append({"record": record, "candidate": candidate_blob,
                                                      "content": content_blob, "mobs": mob_blob})
        if effective_sha in semantic: raise ValueError("duplicate semantic effective catalogue")
        semantic.add(effective_sha)
    manifest = {"tool": TOOL_ID, "registryPath": REGISTRY_REL, "design": registry["design"],
                "baseIdentity": {key: value for key, value in packet["identity"].items() if key != "livePath"}, "registryIdentity": registry_id,
                "responseContractIdentity": response_id, "frozenCensusIdentity": census_id,
                "seedContractIdentity": _identity(repo / "docs/balance/421-content-search-seeds-v1.json",
                                                   read_json(repo / "docs/balance/421-content-search-seeds-v1.json")),
                "count": len(candidates), "uniqueVectors": len({tuple(row["vector"].values()) for row in candidates}),
                "uniqueEffectiveCatalogues": len(semantic), "candidates": candidates}
    return manifest, artefacts
def _prepare(out: Path, force: bool) -> None:
    if out.is_symlink(): raise ValueError(f"refusing output symlink: {out}")
    if out.exists():
        marker = out / MARKER
        if not force: raise ValueError(f"output exists: {out}; pass --force to replace it")
        if not out.is_dir() or marker.is_symlink() or not marker.is_file() \
                or marker.read_text() != f"{TOOL_ID}\n":
            raise ValueError(f"refusing --force for unmarked output directory: {out}")
        shutil.rmtree(out)
    out.mkdir(parents=True); (out / MARKER).write_text(f"{TOOL_ID}\n")
def validate_bundle(repo: Path, out: Path) -> None:
    run = subprocess.run(["godot", "--headless", "--path", str(repo), "-s",
                          "res://tools/balance_tier2_validate.gd", "--", f"--bundle={out.resolve()}"],
                         cwd=repo, text=True, capture_output=True, check=False)
    combined = run.stderr + run.stdout
    if run.returncode != 0 or "SCRIPT ERROR" in combined or "Failed to load script" in combined \
            or '"validated":81' not in run.stdout:
        raise RuntimeError(combined.strip())
def generate_bundle(repo: Path, out: Path, force: bool = False) -> dict[str, Any]:
    manifest, artefacts = compile_design(repo); _prepare(out, force)
    for artefact in artefacts:
        directory = out / artefact["record"]["id"]; directory.mkdir()
        (directory / "full-content.json").write_bytes(artefact["content"])
        (directory / "mob-overrides.json").write_bytes(artefact["mobs"])
        (directory / "candidate.json").write_bytes(artefact["candidate"])
    (out / "manifest.json").write_bytes(_bytes(manifest)); validate_bundle(repo, out)
    return manifest
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--out", type=Path, default=Path("/tmp/glassvow-508-tier2"))
    parser.add_argument("--check", action="store_true"); parser.add_argument("--force", action="store_true"); args = parser.parse_args()
    if args.check:
        manifest, _ = compile_design(REPO); print(json.dumps({key: value for key, value in manifest.items() if key != "candidates"}, indent=2))
    else:
        manifest = generate_bundle(REPO, args.out, args.force); print(json.dumps({"out": str(args.out), "count": manifest["count"], "design": manifest["design"]}))
    return 0
if __name__ == "__main__":
    try: raise SystemExit(main())
    except (KeyError, OSError, RuntimeError, TypeError, ValueError) as exc:
        print(f"balance_tier2_design: {exc}", file=sys.stderr); raise SystemExit(2) from exc
