#!/usr/bin/env python3
"""Decision ledger and mini-CEM evidence preparation for #458."""
from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from typing import Any

from balance_f1_racing import racing_decisions
from balance_f0 import (
    ASPECTS,
    BOOT_SEED,
    VOWS,
    aggregate_cells,
    aggregate_controls,
    by_seed,
    control_fault,
    deficits,
    evaluation_spec,
    grid_proxies,
    is_tier1_profile,
    load_control_rows,
    load_landscape_rows,
    observation_bytes,
    seed_block_bootstrap,
    validate_candidate_manifest,
)
from balance_f0_tier1 import attach_tier1_fields, bootstrap_breadth, identity_load
from balance_seed_contract import file_sha256, load_contract, sha256_bytes
from balance_f1_cem_evidence import mini_cem_comparison, prepare_cem_seeds
from balance_f1_finalists import audit_comparison, finalist_contract


def _tool_hashes(*module_names: str) -> dict[str, str]:
    tools_dir = Path(__file__).parent
    names = (Path(__file__).name, *module_names)
    return {name: file_sha256(tools_dir / name) for name in names}


def decision_record(summary: dict[str, Any], decisions: list[dict[str, str]],
                    evaluation: str) -> dict[str, Any]:
    """Bind every decision to exactly the evidence available at that layer."""
    by_id = {row["id"]: row for row in summary["candidates"]}
    recorded: list[dict[str, Any]] = []
    for decision in decisions:
        row = by_id[decision["id"]]
        recorded.append({
            **decision,
            "evidence": {
                "status": row.get("status"), "earlyStop": row.get("earlyStop"),
                "deficits": row.get("deficits", {}), "proxies": row.get("proxies", {}),
                "bootstrap": row.get("bootstrap", {}),
                "inputHash": row.get("inputHash", ""),
                "candidateFileSha256": row.get("fileSha256", ""),
                "candidateSemanticSha256": row.get("semanticSha256", ""),
                "observationsSha256": row.get("observationsSha256", ""),
                "controlRowCount": row.get("controlRowCount", 0),
                "landscapeRowCount": row.get("landscapeRowCount", 0),
                "commit": row.get("commit", ""), "godotVersion": row.get("godotVersion", ""),
                "hostFingerprint": row.get("hostFingerprint", ""),
                "controlStalls": row.get("controlStalls", 0),
                "controlErrors": row.get("controlErrors", 0),
                "landscapeStalls": row.get("landscapeStalls", 0),
                "landscapeErrors": row.get("landscapeErrors", 0),
            },
        })
    return {
        "issue": 458, "evaluation": evaluation, "decisions": recorded,
        "promoted": [row["id"] for row in recorded if row["decision"] == "promote"],
        "stopped": [row["id"] for row in recorded if row["decision"] == "stop"],
    }


def reanalyse_layer(summary: dict[str, Any], layer_dir: Path,
                    n_boot: int, axes: dict[str, Any],
                    candidate_bundle: Path | None = None) -> dict[str, Any]:
    """Rebuild point and paired bootstrap evidence from immutable raw shards."""
    rebuilt = copy.deepcopy(summary)
    resolved = evaluation_spec(summary["protocol"])
    tier1 = is_tier1_profile(summary["protocol"])
    baseline_id = str(summary["protocol"].get("baseline", "c000"))
    bundle_by_id: dict[str, dict[str, Any]] = {}
    repo = Path(__file__).resolve().parents[1]
    if candidate_bundle is not None:
        bundle = json.loads((candidate_bundle / "manifest.json").read_text(encoding="utf-8"))
        frozen_manifest = summary["protocol"].get("candidateManifest")
        if tier1 and frozen_manifest:
            validate_candidate_manifest(
                bundle, json.loads((repo / str(frozen_manifest)).read_text(encoding="utf-8")))
        bundle_by_id = {str(row["id"]): row for row in bundle["candidates"]}
    expected_landscape = resolved["policyCount"] * 4 \
        * (resolved["landscapeLast"] - resolved["landscapeFirst"] + 1)

    def raw(row: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
        candidate_id = str(row["id"])
        candidate_dir = layer_dir / candidate_id
        observation_path = candidate_dir / "observations.jsonl"
        if not observation_path.is_file() \
                or file_sha256(observation_path) != str(row.get("observationsSha256", "")):
            raise ValueError(f"raw observation digest is missing or stale for {candidate_id}")
        control_paths = sorted((candidate_dir / "controls").glob("shard-*.json"))
        land_paths = sorted((candidate_dir / "landscape").glob("shard-*.ndjson"))
        control_rows = load_control_rows(control_paths) if control_paths else []
        recorded_arms = row.get("controlArms")
        if tier1:
            if recorded_arms != resolved["controlArms"]:
                raise ValueError(f"control-arm coverage drifted for {candidate_id}")
            selected = set(resolved["controlArms"])
            control_rows = [item for item in control_rows if int(item["arm"]) in selected]
            expected_controls = (resolved["controlLast"] - resolved["controlFirst"] + 1) \
                * len(selected) * 4
        elif isinstance(recorded_arms, list):
            selected = {int(arm) for arm in recorded_arms}
            control_rows = [item for item in control_rows if int(item["arm"]) in selected]
            expected_controls = (resolved["controlLast"] - resolved["controlFirst"] + 1) \
                * len(selected) * 4
        else:
            # Legacy F0/first-layer manifests emitted all four diagnostic arms.
            expected_controls = (resolved["controlLast"] - resolved["controlFirst"] + 1) * 16
        land_rows = load_landscape_rows(land_paths) if land_paths else []
        control_keys = {(int(item["arm"]), str(item["aspect"]), int(item["vow"]),
                         int(item["seed"])) for item in control_rows}
        expected_control_keys = {
            (arm, aspect, vow, seed)
            for arm in resolved["controlArms"]
            for aspect in ASPECTS for vow in VOWS
            for seed in range(resolved["controlFirst"], resolved["controlLast"] + 1)
        }
        landscape_keys = {(int(item["policyIndex"]), str(item["aspect"]),
                           int(item["vow"]), int(item["seed"])) for item in land_rows}
        expected_landscape_keys = {
            (policy, aspect, vow, seed)
            for policy in range(resolved["policyFirst"],
                                resolved["policyFirst"] + resolved["policyCount"])
            for aspect in ASPECTS for vow in VOWS
            for seed in range(resolved["landscapeFirst"], resolved["landscapeLast"] + 1)
        }
        if len(control_rows) != expected_controls \
                or len(land_rows) not in (0, expected_landscape) \
                or control_keys != expected_control_keys \
                or (land_rows and landscape_keys != expected_landscape_keys) \
                or (not land_rows and row.get("status") != "early-stop"):
            raise ValueError(f"raw row count drifted for {candidate_id}")
        if bundle_by_id:
            expected = bundle_by_id.get(candidate_id)
            if expected is None or any(row.get(key) != expected.get(key) for key in
                                       ("values", "fileSha256", "semanticSha256")):
                raise ValueError(f"candidate identity drifted for {candidate_id}")
            content_path = candidate_bundle / candidate_id / "full-content.json"
            if not content_path.is_file() or file_sha256(content_path) != str(row["fileSha256"]):
                raise ValueError(f"candidate content digest drifted for {candidate_id}")
        identity = {
            "id": candidate_id, "values": row["values"], "fileSha256": row["fileSha256"],
            "semanticSha256": row["semanticSha256"],
            "searchSpaceSha256": summary["searchSpaceSha256"],
            "seedRegistrySha256": summary["seedRegistrySha256"],
            "commit": row["commit"], "driverSha256": summary["driverSha256"],
            "godotVersion": row["godotVersion"], "hostFingerprint": row["hostFingerprint"],
        }
        if sha256_bytes(observation_bytes(control_rows + land_rows, identity, extras=tier1)) \
                != str(row["observationsSha256"]):
            raise ValueError(f"raw shards do not reproduce observations for {candidate_id}")
        return control_rows, land_rows

    by_candidate = {str(row["id"]): raw(row) for row in rebuilt["candidates"]}
    baseline_row = next((row for row in rebuilt["candidates"] if row["id"] == baseline_id), None)
    if baseline_row is None or not by_candidate[baseline_id][1]:
        raise ValueError(f"raw layer has no complete {baseline_id} incumbent")
    baseline_control = by_seed(by_candidate[baseline_id][0])
    baseline_land = by_seed(by_candidate[baseline_id][1])
    baseline_stalls = sum(str(row.get("outcome")) == "stall"
                          for row in by_candidate[baseline_id][0])
    baseline_cells = aggregate_cells(by_candidate[baseline_id][1], axes)
    response_contract = json.loads((repo / str(summary["protocol"].get(
        "responseContract", "docs/balance/490-f0-response-contract-v1.json"))).read_text()) \
        if tier1 else None
    for row in rebuilt["candidates"]:
        candidate_id = str(row["id"])
        control_rows, land_rows = by_candidate[candidate_id]
        control_stalls = sum(str(item.get("outcome")) == "stall" for item in control_rows)
        control_errors = sum(str(item.get("outcome")) == "error" for item in control_rows)
        row.update({"controlArms": resolved["controlArms"],
                    "controlRowCount": len(control_rows), "landscapeRowCount": len(land_rows),
                    "controlStalls": control_stalls, "controlErrors": control_errors,
                    "landscapeStalls": sum(str(item.get("outcome")) == "stall"
                                           for item in land_rows),
                    "landscapeErrors": sum(str(item.get("outcome")) == "error"
                                           for item in land_rows)})
        if not land_rows:
            raw_fault = control_fault(
                control_rows, baseline_stalls,
                complete_rectangle=bool(summary["protocol"].get("completeRectangle")))
            if not raw_fault:
                raise ValueError(f"unexplained missing landscape rows for {candidate_id}")
            row["status"] = "early-stop"
            row["earlyStop"] = raw_fault
            if candidate_id == baseline_id:
                raise ValueError(f"raw layer has no complete {baseline_id} incumbent")
            continue
        row["status"], row["earlyStop"] = "complete", None
        controls = aggregate_controls(control_rows)
        cells = aggregate_cells(land_rows, axes)
        proxies = grid_proxies(controls, cells)
        row["controls"], row["cells"] = controls, cells
        row["proxies"] = proxies
        row["deficits"] = deficits(proxies)
        row["bootstrap"] = seed_block_bootstrap(
            by_seed(control_rows), by_seed(land_rows),
            None if candidate_id == baseline_id else baseline_control,
            None if candidate_id == baseline_id else baseline_land,
            axes, n_boot, int(summary["protocol"].get("bootSeed", BOOT_SEED)),
        )
        if tier1:
            if candidate_bundle is None or response_contract is None:
                raise ValueError("Tier-1 raw reanalysis requires the candidate bundle")
            attach_tier1_fields(
                row, axes, response_contract,
                identity_load(json.loads((candidate_bundle / candidate_id / "full-content.json")
                                         .read_text(encoding="utf-8"))),
                land_rows, control_rows,
                strict=bool(summary["protocol"].get("strictGuardrails", False)))
            extra = bootstrap_breadth(
                by_seed(control_rows), by_seed(land_rows),
                None if candidate_id == baseline_id else baseline_control,
                None if candidate_id == baseline_id else baseline_land,
                axes, response_contract, cells, n_boot,
                int(summary["protocol"].get("bootSeed", BOOT_SEED)),
                baseline_cells=None if candidate_id == baseline_id else baseline_cells)
            row["bootstrap"] = {**row["bootstrap"], **extra}
    return rebuilt


def raw_fault_rows(layer_dir: Path, candidate_ids: list[str]) -> dict[str, list[dict[str, Any]]]:
    """Retain the exact simulator rows behind any fail-closed audit decision."""
    fields = ("arm", "policyIndex", "aspect", "vow", "seed", "outcome", "error")
    result: dict[str, list[dict[str, Any]]] = {}
    for candidate_id in candidate_ids:
        candidate_dir = layer_dir / candidate_id
        rows = load_control_rows(sorted((candidate_dir / "controls").glob("shard-*.json")))
        rows += load_landscape_rows(sorted(
            (candidate_dir / "landscape").glob("shard-*.ndjson")))
        result[candidate_id] = [
            {key: row[key] for key in fields if key in row}
            for row in rows if row.get("outcome") in ("stall", "error")
        ]
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    decide = sub.add_parser("decide")
    decide.add_argument("--summary", required=True)
    decide.add_argument("--protocol", default="docs/balance/458-f1-f2-protocol-v1.json")
    decide.add_argument("--evaluation", required=True)
    decide.add_argument("--layer-dir", required=True,
                        help="raw evaluator directory used to reconstruct paired evidence")
    decide.add_argument("--out", required=True)
    cem = sub.add_parser("cem-seeds")
    cem.add_argument("--layer-dir", required=True)
    cem.add_argument("--candidates", required=True)
    cem.add_argument("--out", required=True)
    compare = sub.add_parser("cem-compare")
    compare.add_argument("--cem-dir", required=True)
    compare.add_argument("--seeds-dir", required=True)
    compare.add_argument("--candidates", required=True)
    compare.add_argument("--boot", type=int, default=4000)
    compare.add_argument("--out", required=True)
    audit_parser = sub.add_parser("audit-compare")
    audit_parser.add_argument("--development-summary", required=True)
    audit_parser.add_argument("--audit-summary", required=True)
    audit_parser.add_argument("--audit-dir", required=True)
    audit_parser.add_argument("--candidates", required=True)
    audit_parser.add_argument("--threshold", type=float, default=0.10)
    audit_parser.add_argument("--boot", type=int, default=4000)
    audit_parser.add_argument("--out", required=True)
    finalist_parser = sub.add_parser("finalists")
    finalist_parser.add_argument("--candidate-manifest", required=True)
    finalist_parser.add_argument("--layer-decisions", required=True)
    finalist_parser.add_argument("--cem-report", required=True)
    finalist_parser.add_argument("--audit-report", required=True)
    finalist_parser.add_argument("--space", default="docs/balance/421-content-search-space-v1.json")
    finalist_parser.add_argument("--candidates", required=True)
    finalist_parser.add_argument("--out", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "cem-seeds":
        packet = prepare_cem_seeds(Path(args.layer_dir), args.candidates.split(","), Path(args.out))
        print(json.dumps(packet, sort_keys=True))
        return 0
    if args.command == "cem-compare":
        report = mini_cem_comparison(
            Path(args.cem_dir), args.candidates.split(","), Path(args.seeds_dir), args.boot)
        report["inputs"]["entrypointSha256ByModule"] = _tool_hashes(
            "balance_f1_cem_evidence.py")
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps({"candidates": [row["id"] for row in report["candidates"]],
                          "out": str(out)}, sort_keys=True))
        return 0
    if args.command == "audit-compare":
        development_path, audit_path = Path(args.development_summary), Path(args.audit_summary)
        candidate_ids = args.candidates.split(",")
        audit_summary = reanalyse_layer(
            json.loads(audit_path.read_text(encoding="utf-8")), Path(args.audit_dir),
            args.boot, load_contract()["frozenLandscape"],
        )
        report = audit_comparison(
            json.loads(development_path.read_text(encoding="utf-8")),
            audit_summary, candidate_ids, args.threshold,
        )
        faults = raw_fault_rows(Path(args.audit_dir), candidate_ids)
        for row in report["candidates"]:
            row["auditFaultRows"] = faults[str(row["id"])]
        report["inputs"] = {"developmentSummarySha256": file_sha256(development_path),
                            "auditSummarySha256": file_sha256(audit_path),
                            "auditObservationSha256ByCandidate": {
                                str(row["id"]): str(row.get("observationsSha256", ""))
                                for row in audit_summary["candidates"]
                            },
                            "toolSha256ByModule": _tool_hashes(
                                "balance_f1_finalists.py")}
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps({"confidenceBlocked": {
            row["id"]: row["confidenceBlocked"] for row in report["candidates"]},
            "out": str(out)}, sort_keys=True))
        return 0
    if args.command == "finalists":
        paths = {name: Path(getattr(args, name)) for name in
                 ("candidate_manifest", "layer_decisions", "cem_report", "audit_report", "space")}
        report = finalist_contract(
            args.candidates.split(","),
            json.loads(paths["candidate_manifest"].read_text(encoding="utf-8")),
            json.loads(paths["layer_decisions"].read_text(encoding="utf-8")),
            json.loads(paths["cem_report"].read_text(encoding="utf-8")),
            json.loads(paths["audit_report"].read_text(encoding="utf-8")),
            json.loads(paths["space"].read_text(encoding="utf-8")),
        )
        report["inputs"] = {name: file_sha256(path) for name, path in paths.items()}
        report["inputs"]["toolSha256ByModule"] = _tool_hashes(
            "balance_f1_finalists.py")
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
        print(json.dumps({"finalists": [row["id"] for row in report["orderedFinalists"]],
                          "out": str(out)}, sort_keys=True))
        return 0
    summary_path, protocol_path = Path(args.summary), Path(args.protocol)
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    layer = protocol["evaluations"][args.evaluation]
    summary = reanalyse_layer(
        summary, Path(args.layer_dir), int(layer["bootstrap"]),
        load_contract()["frozenLandscape"],
    )
    decisions = racing_decisions(summary["candidates"], int(layer["maxPromotions"]))
    record = decision_record(summary, decisions, args.evaluation)
    record["inputs"] = {"summarySha256": file_sha256(summary_path),
                        "protocolSha256": file_sha256(protocol_path),
                        "toolSha256ByModule": _tool_hashes(
                            "balance_f0.py", "balance_f1_racing.py"),
                        "observationSha256ByCandidate": {
                            str(row["id"]): str(row.get("observationsSha256", ""))
                            for row in summary["candidates"]
                        }}
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                   encoding="utf-8")
    print(json.dumps({"evaluation": args.evaluation, "promoted": record["promoted"],
                      "stopped": len(record["stopped"]), "out": str(out)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_f1_evidence: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
