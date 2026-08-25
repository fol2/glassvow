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
    BOOT_SEED,
    aggregate_cells,
    aggregate_controls,
    by_seed,
    deficits,
    evaluation_spec,
    grid_proxies,
    load_control_rows,
    load_landscape_rows,
    observation_bytes,
    seed_block_bootstrap,
)
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
                    n_boot: int, axes: dict[str, Any]) -> dict[str, Any]:
    """Rebuild point and paired bootstrap evidence from immutable raw shards."""
    rebuilt = copy.deepcopy(summary)
    resolved = evaluation_spec(summary["protocol"])
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
        if isinstance(recorded_arms, list):
            selected = {int(arm) for arm in recorded_arms}
            control_rows = [item for item in control_rows if int(item["arm"]) in selected]
            expected_controls = (resolved["controlLast"] - resolved["controlFirst"] + 1) \
                * len(selected) * 4
        else:
            # Legacy F0/first-layer manifests emitted all four diagnostic arms.
            expected_controls = (resolved["controlLast"] - resolved["controlFirst"] + 1) * 16
        land_rows = load_landscape_rows(land_paths) if land_paths else []
        if len(control_rows) != int(row.get("controlRowCount", -1)) \
                or len(land_rows) != int(row.get("landscapeRowCount", -1)):
            raise ValueError(f"raw row count drifted for {candidate_id}")
        identity = {
            "id": candidate_id, "values": row["values"], "fileSha256": row["fileSha256"],
            "semanticSha256": row["semanticSha256"],
            "searchSpaceSha256": summary["searchSpaceSha256"],
            "seedRegistrySha256": summary["seedRegistrySha256"],
            "commit": row["commit"], "driverSha256": summary["driverSha256"],
            "godotVersion": row["godotVersion"], "hostFingerprint": row["hostFingerprint"],
        }
        if sha256_bytes(observation_bytes(control_rows + land_rows, identity)) \
                != str(row["observationsSha256"]):
            raise ValueError(f"raw shards do not reproduce observations for {candidate_id}")
        if row.get("status") == "complete" and not row.get("earlyStop"):
            if len(control_rows) != expected_controls or len(land_rows) != expected_landscape:
                raise ValueError(f"complete raw coverage is truncated for {candidate_id}")
        return control_rows, land_rows

    by_candidate = {str(row["id"]): raw(row) for row in rebuilt["candidates"]}
    baseline_row = next((row for row in rebuilt["candidates"] if row["id"] == "c000"), None)
    if baseline_row is None or baseline_row.get("status") != "complete":
        raise ValueError("raw layer has no complete c000 incumbent")
    baseline_control = by_seed(by_candidate["c000"][0])
    baseline_land = by_seed(by_candidate["c000"][1])
    for row in rebuilt["candidates"]:
        candidate_id = str(row["id"])
        if row.get("status") != "complete" or row.get("earlyStop"):
            continue
        control_rows, land_rows = by_candidate[candidate_id]
        proxies = grid_proxies(aggregate_controls(control_rows), aggregate_cells(land_rows, axes))
        row["proxies"] = proxies
        row["deficits"] = deficits(proxies)
        row["bootstrap"] = seed_block_bootstrap(
            by_seed(control_rows), by_seed(land_rows),
            None if candidate_id == "c000" else baseline_control,
            None if candidate_id == "c000" else baseline_land,
            axes, n_boot, BOOT_SEED,
        )
    return rebuilt


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
    audit_parser.add_argument("--candidates", required=True)
    audit_parser.add_argument("--threshold", type=float, default=0.10)
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
        report["inputs"]["toolSha256ByModule"] = _tool_hashes(
            "balance_f1_cem_evidence.py")
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps({"candidates": [row["id"] for row in report["candidates"]],
                          "out": str(out)}, sort_keys=True))
        return 0
    if args.command == "audit-compare":
        development_path, audit_path = Path(args.development_summary), Path(args.audit_summary)
        report = audit_comparison(
            json.loads(development_path.read_text(encoding="utf-8")),
            json.loads(audit_path.read_text(encoding="utf-8")),
            args.candidates.split(","), args.threshold,
        )
        report["inputs"] = {"developmentSummarySha256": file_sha256(development_path),
                            "auditSummarySha256": file_sha256(audit_path),
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
