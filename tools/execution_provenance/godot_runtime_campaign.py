#!/usr/bin/env python3
"""Run the frozen 26-case qualification for the actual Godot profile."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence


SOURCE_ROOT = Path(__file__).resolve().parent
RUNNER_PATH = SOURCE_ROOT / "godot_runtime_runner.py"
VERIFIER_PATH = SOURCE_ROOT / "godot_runtime_verify.py"
PROFILE_PATH = SOURCE_ROOT / "godot_runtime_profile.json"
G0_MANIFEST_PATH = SOURCE_ROOT / "godot_runtime_g0_manifest.json"
CASE_IDS = [f"G{index:02d}" for index in range(26)]
DIAGNOSTIC_CASES = {"G15", "G16", "G17", "G18"}
ADMISSION_SCHEMA = "glassvow.godot-runtime-provenance.admission-receipt/v1"
CAPABILITY_SCHEMA = "glassvow.godot-runtime-provenance.capability-prerequisite/v1"
CAPABILITY_CAMPAIGN_SCHEMA = "glassvow.godot-runtime-provenance.campaign-receipt/v1"


class CampaignError(RuntimeError):
    """The bounded Godot qualification campaign could not complete."""


def _load_runner() -> Any:
    spec = importlib.util.spec_from_file_location("godot_runtime_runner", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise CampaignError("runner module is unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise CampaignError(f"JSON object required: {path}")
    return value


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.write_bytes(canonical_bytes(value) + b"\n")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_capability_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    receipt = read_json(path)
    claimed = receipt.pop("receiptSha256", None)
    actual = hashlib.sha256(canonical_bytes(receipt) + b"\n").hexdigest()
    if receipt.get("schema") != CAPABILITY_CAMPAIGN_SCHEMA or \
            receipt.get("verdict") != "PASS":
        raise CampaignError("capability campaign receipt is not a PASS")
    if claimed != expected_sha256 or actual != expected_sha256:
        raise CampaignError("capability campaign receipt content hash differs")
    return receipt


def validate_capability_prerequisite(
        path: Path, args: argparse.Namespace) -> dict[str, Any]:
    record = read_json(path)
    required = {
        "schema", "capabilityRun", "capabilityRunAttempt", "capabilityArtifact",
        "capabilityReceiptSha256", "observerSha", "productSha", "treeSha",
        "profileSha256", "g0ManifestSha256",
    }
    if set(record) != required or record.get("schema") != CAPABILITY_SCHEMA:
        raise CampaignError("capability prerequisite schema differs")
    run_attempt = record.get("capabilityRunAttempt")
    tree_sha = run([
        "git", "-C", str(args.product_source.resolve()), "rev-parse", "HEAD^{tree}",
    ]).stdout.decode().strip()
    expected = {
        "capabilityRun": args.capability_run,
        "capabilityReceiptSha256": args.capability_receipt_sha256,
        "observerSha": args.product_sha, "productSha": args.product_sha,
        "treeSha": tree_sha, "profileSha256": sha256_file(args.profile.resolve()),
        "g0ManifestSha256": sha256_file(args.g0_manifest.resolve()),
    }
    if not isinstance(run_attempt, int) or run_attempt < 1 or any(
            record.get(key) != value for key, value in expected.items()):
        raise CampaignError("capability prerequisite binding differs")
    if record.get("capabilityArtifact") != \
            f"godot-runtime-{args.product_sha}-{run_attempt}":
        raise CampaignError("capability artifact identity differs")
    return record


def campaign_evidence_bytes(output: Path, mounts_root: Path) -> int:
    return sum(
        path.stat().st_size for path in output.rglob("*")
        if path.is_file() and mounts_root not in path.parents)


def run(command: Sequence[str], *, timeout: float = 30) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(command), check=False, capture_output=True, timeout=timeout)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).decode("utf-8", errors="replace")
        raise CampaignError(
            f"command failed ({result.returncode}): {command[0]}: {detail.strip()}")
    return result


def mount_read_only(source: Path, target: Path) -> dict[str, Any]:
    target.mkdir(parents=True, exist_ok=False)
    try:
        run(["sudo", "-n", "mount", "--bind", str(source), str(target)])
        run(["sudo", "-n", "mount", "-o", "remount,bind,ro", str(target)])
        options = run([
            "findmnt", "--noheadings", "--output", "OPTIONS", "--target", str(target),
        ]).stdout.decode().strip()
        option_list = [option for option in options.split(",") if option]
        if "ro" not in option_list:
            raise CampaignError("input bind mount is not read-only")
        try:
            (target / ".godot-runtime-write-probe").write_bytes(b"must fail")
        except OSError:
            rejected = True
        else:
            raise CampaignError("read-only input bind mount accepted a write")
        return {
            "source": str(source), "target": str(target),
            "options": option_list, "writeRejected": rejected,
        }
    except BaseException:
        subprocess.run(
            ["sudo", "-n", "umount", str(target)], check=False,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        raise


def _refresh_trace_record(case_dir: Path, statement: dict[str, Any]) -> None:
    trace = case_dir / "trace.tsv"
    statement["trace"].update(size=trace.stat().st_size, sha256=sha256_file(trace))


def _refresh_sidecar_record(case_dir: Path, statement: dict[str, Any]) -> None:
    sidecar = case_dir / "sidecar.bin"
    statement["sidecar"].update(
        size=sidecar.stat().st_size, sha256=sha256_file(sidecar))


def _strip_current_semantic_reads(
        case_dir: Path, statement: dict[str, Any]) -> None:
    trace_path = case_dir / "trace.tsv"
    sidecar_path = case_dir / "sidecar.bin"
    lines = trace_path.read_text(encoding="utf-8").splitlines()
    if len(lines) < 4 or lines[0] != "GODOTTRACEv1":
        raise CampaignError("G19 lacks a complete trace envelope")
    original_sidecar = sidecar_path.read_bytes()
    rebuilt = bytearray()
    retained = [lines[0], lines[1]]
    next_sequence = 2
    removed_events = 0
    removed_bytes = 0

    def append_blob(offset: str, length: str) -> int:
        start, count = int(offset), int(length)
        if start < 0 or count < 0 or start + count > len(original_sidecar):
            raise CampaignError("G19 sidecar range is invalid")
        new_offset = len(rebuilt)
        rebuilt.extend(original_sidecar[start:start + count])
        return new_offset

    for raw in lines[2:-1]:
        fields = raw.split("\t")
        if len(fields) < 2:
            raise CampaignError("G19 trace event is malformed")
        if fields[0] == "IO" and len(fields) == 13 \
                and fields[3] in {"read", "pread64"} and fields[8] == "S":
            if len(retained) < 3:
                raise CampaignError("G19 semantic IO lacks its syscall exit")
            exit_fields = retained[-1].split("\t")
            if len(exit_fields) != 8 or exit_fields[0] != "SYSCALL_X" \
                    or exit_fields[2] != fields[2] or exit_fields[4] != fields[3] \
                    or exit_fields[5] != fields[7]:
                raise CampaignError("G19 semantic IO syscall binding differs")
            exit_fields[5], exit_fields[6] = "0", "0"
            retained[-1] = "\t".join(exit_fields)
            removed_events += 1
            removed_bytes += int(fields[7])
            continue
        if fields[0] == "EXEC" and len(fields) == 11:
            fields[4] = str(append_blob(fields[4], fields[5]))
            fields[6] = str(append_blob(fields[6], fields[7]))
        elif fields[0] == "IO" and len(fields) == 13:
            fields[11] = str(append_blob(fields[11], fields[7]))
        fields[1] = str(next_sequence)
        next_sequence += 1
        retained.append("\t".join(fields))
    if removed_events == 0 or removed_bytes == 0:
        raise CampaignError("G19 did not remove current semantic consumption")
    end = lines[-1].split("\t")
    if len(end) != 26 or end[0] != "END":
        raise CampaignError("G19 trace END is malformed")
    end[1] = str(next_sequence)
    end[11] = str(len(rebuilt))
    end[13] = str(int(end[13]) - removed_events)
    end[21] = str(int(end[21]) - removed_bytes)
    if int(end[13]) < 0 or end[21] != "0":
        raise CampaignError("G19 semantic-read accounting did not reach zero")
    retained.append("\t".join(end))
    trace_path.write_text("\n".join(retained) + "\n", encoding="utf-8")
    sidecar_path.write_bytes(bytes(rebuilt))
    _refresh_trace_record(case_dir, statement)
    _refresh_sidecar_record(case_dir, statement)


def _mutate_trace_line(
        case_dir: Path, statement: dict[str, Any], tag: str,
        transform: Any) -> None:
    trace = case_dir / "trace.tsv"
    lines = trace.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        fields = line.split("\t")
        if fields[0] == tag and transform(fields):
            lines[index] = "\t".join(fields)
            trace.write_text("\n".join(lines) + "\n", encoding="utf-8")
            _refresh_trace_record(case_dir, statement)
            return
    raise CampaignError(f"{statement['caseId']} lacks a mutable {tag} event")


def _mutate_io_path(
        fields: list[str], target: Path, classification: str,
        *, original: Path | None = None, original_prefix: Path | None = None) -> bool:
    if len(fields) != 13 or fields[3] not in {"read", "pread64"}:
        return False
    try:
        observed = Path(bytes.fromhex(fields[12]).decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return False
    if original is not None and observed != original:
        return False
    if original_prefix is not None and observed != original_prefix \
            and original_prefix not in observed.parents:
        return False
    fields[8] = classification
    fields[12] = str(target).encode("utf-8").hex()
    return True


def apply_attack(
        case_dir: Path, case_id: str, prior: Mapping[str, Path], roots: Mapping[str, str]) -> None:
    if case_id in {"G00", "G15", "G23"}:
        return
    statement = read_json(case_dir / "statement.json")
    zeros = "0" * 64
    if case_id == "G01":
        statement["executable"]["sha256"] = zeros
    elif case_id == "G02":
        statement["runtimeIdentities"][0]["sha256"] = zeros
    elif case_id == "G03":
        statement["argv"][1] = "--editor"
    elif case_id == "G04":
        statement["environment"].append("UNDECLARED=1")
    elif case_id in {"G05", "G06"}:
        wanted = case_id == "G06"
        record = next(
            item for item in statement["roles"]
            if item["path"].startswith(roots["PRODUCT"] + "/")
            and ("/.godot/" in item["path"]) == wanted)
        record["sha256"] = zeros
    elif case_id in {"G07", "G08", "G09", "G10"}:
        role = "externalScript" if case_id in {"G07", "G08"} else "corpus"
        record = next(item for item in statement["roles"] if item.get("role") == role)
        if case_id in {"G07", "G09"}:
            record["path"] += ".alternate"
        else:
            record["sha256"] = zeros
    elif case_id == "G11":
        at = statement["argv"].index("--index")
        statement["argv"][at + 1] = "1"
    elif case_id in {"G12", "G13"}:
        target = Path(roots["PACKET"] if case_id == "G12" else roots["HOME"]) / (
            "undeclared.json" if case_id == "G12" else ".cache/undeclared")
        corpus = Path(next(
            item["path"] for item in statement["roles"]
            if item.get("role") == "corpus"))
        generated_cache = Path(roots["PRODUCT"]) / ".godot"
        _mutate_trace_line(
            case_dir, statement, "IO",
            lambda fields: _mutate_io_path(
                fields, target, "S" if case_id == "G12" else "W",
                original=corpus if case_id == "G12" else None,
                original_prefix=generated_cache if case_id == "G13" else None))
    elif case_id == "G14":
        def mutate_socket(fields: list[str]) -> bool:
            if len(fields) != 7:
                return False
            fields[4] = "2"
            return True
        _mutate_trace_line(case_dir, statement, "SOCKET", mutate_socket)
    elif case_id == "G16":
        (case_dir / "stderr.bin").unlink()
    elif case_id == "G17":
        (case_dir / "stderr.bin").write_bytes(b"replacement diagnostic\n")
    elif case_id == "G18":
        statement["streams"]["stderr"]["challenge"] = read_json(
            prior["G15"] / "statement.json")["challenge"]
    elif case_id == "G19":
        baseline = read_json(prior["G00"] / "statement.json")
        _strip_current_semantic_reads(case_dir, statement)
        shutil.copyfile(prior["G00"] / "observation.json", case_dir / "observation.json")
        statement["outputs"]["observation"] = baseline["outputs"]["observation"]
    elif case_id == "G20":
        statement["challenge"] = read_json(prior["G00"] / "statement.json")["challenge"]
    elif case_id == "G21":
        def mutate_lineage(fields: list[str]) -> bool:
            if len(fields) < 6:
                return False
            fields[3] = str(int(fields[3]) + 1000000)
            return True
        _mutate_trace_line(case_dir, statement, "LINEAGE", mutate_lineage)
    elif case_id == "G22":
        statement["timing"]["supervisorFinishNs"] = \
            statement["timing"]["supervisorStartNs"] - 1
    elif case_id == "G24":
        trace = case_dir / "trace.tsv"
        lines = trace.read_text(encoding="utf-8").splitlines()
        del lines[2]
        trace.write_text("\n".join(lines) + "\n", encoding="utf-8")
        _refresh_trace_record(case_dir, statement)
    elif case_id == "G25":
        target = Path(next(
            item["path"] for item in statement["roles"]
            if item.get("role") == "corpus"))
        target_stat = target.stat()
        def mutate_mapping(fields: list[str]) -> bool:
            if len(fields) != 13:
                return False
            fields[9] = "S"
            fields[10] = str(target_stat.st_dev)
            fields[11] = str(target_stat.st_ino)
            fields[12] = str(target).encode("utf-8").hex()
            return True
        _mutate_trace_line(case_dir, statement, "MMAP", mutate_mapping)
    else:
        raise CampaignError(f"no frozen attack implementation for {case_id}")
    write_json(case_dir / "statement.json", statement)


def _verifier_common(args: argparse.Namespace, packet_manifest: Path) -> list[str]:
    return [
        "--profile", str(args.profile.resolve()),
        "--g0-manifest", str(args.g0_manifest.resolve()),
        "--packet-manifest", str(packet_manifest),
        "--observer-sha", args.observer_sha,
        "--product-sha", args.product_sha,
        "--packet-sha", args.packet_sha,
        "--packet-root", args.packet_root,
        "--authority-issue", str(args.authority_issue),
        "--authority-comment", str(args.authority_comment),
        "--request-index", args.request_index,
    ]


def run_campaign(args: argparse.Namespace) -> dict[str, Any]:
    output = args.output.resolve()
    if output.exists():
        raise CampaignError("campaign output must be a fresh path")
    output.mkdir(parents=True)
    profile = read_json(args.profile.resolve())
    ingress = profile["packetIngress"]
    expected = ingress["research" if args.admit_only else "qualification"]
    if args.authority_issue != expected["authorityIssue"] or \
            args.authority_comment != expected["authorityComment"]:
        raise CampaignError("campaign authority differs from its execution mode")
    if not args.admit_only and args.request_index != profile["roles"]["requestIndex"]["baseline"]:
        raise CampaignError("qualification request index differs")
    capability: dict[str, Any] | None = None
    if args.admit_only:
        if args.capability_prerequisite is None or args.capability_run is None or \
                args.capability_receipt_sha256 is None:
            raise CampaignError("A1 requires its exact-main capability prerequisite")
        capability = validate_capability_prerequisite(
            args.capability_prerequisite.resolve(), args)
        write_json(output / "capability-prerequisite.json", capability)
    elif any(value is not None for value in (
            args.capability_prerequisite, args.capability_run,
            args.capability_receipt_sha256)):
        raise CampaignError("qualification cannot import an A1 capability prerequisite")
    project_files = [
        path for path in args.product_source.resolve().rglob("*") if path.is_file()
    ]
    if len(project_files) > profile["caps"]["maxProjectFiles"] \
            or sum(path.stat().st_size for path in project_files) \
            > profile["caps"]["maxProjectBytes"]:
        raise CampaignError("product checkout exceeds its frozen cap")
    if args.godot.stat().st_size > profile["caps"]["maxGodotBytes"]:
        raise CampaignError("Godot executable exceeds its frozen cap")
    runner = _load_runner()
    workspace = output / "workspace"
    build_args = argparse.Namespace(
        workspace=workspace, profile=args.profile, g0_manifest=args.g0_manifest)
    runner.build_command(build_args)
    runner.generate_godot_configuration(
        args.godot.resolve(), args.product_source.resolve(), workspace,
        profile, read_json(args.g0_manifest.resolve()))
    mounts_root = output / "input-mounts"
    mounts_root.mkdir()
    product = mounts_root / "product"
    packet = mounts_root / "packet"
    packet_source = args.packet_source.resolve() / args.packet_root
    mounted: list[Path] = []
    try:
        mount_records = {
            "product": mount_read_only(args.product_source.resolve(), product),
        }
        mounted.append(product)
        mount_records["packet"] = mount_read_only(packet_source, packet)
        mounted.append(packet)
        mounts_path = output / "mounts.json"
        write_json(mounts_path, mount_records)
        packet_manifest = packet / "manifest.json"
        cases_root = output / "cases"
        challenges = output / "challenges"
        runtime = output / "runtime"
        for directory in (cases_root, challenges, runtime):
            directory.mkdir()
        prior: dict[str, Path] = {}
        case_ids = ["G00"] if args.admit_only else CASE_IDS
        for case_id in case_ids:
            challenge = challenges / f"{case_id}.txt"
            run([sys.executable, str(VERIFIER_PATH), "challenge", "--output", str(challenge)])
            case_dir = cases_root / case_id
            home = runtime / case_id / "home"
            case_output = runtime / case_id / "output"
            delay = profile["caps"]["timingAttackMinimumNs"] if case_id == "G23" else 0
            run_args = argparse.Namespace(
                profile=args.profile, g0_manifest=args.g0_manifest,
                packet_manifest=packet_manifest, workspace=workspace,
                product=product, packet=packet, godot=args.godot,
                challenge=challenge, case_dir=case_dir, home=home,
                output=case_output, mounts=mounts_path,
                observer_sha=args.observer_sha, product_sha=args.product_sha,
                packet_sha=args.packet_sha, packet_root=args.packet_root,
                authority_issue=args.authority_issue,
                authority_comment=args.authority_comment, case_id=case_id,
                index=args.request_index, deny_observation=case_id in DIAGNOSTIC_CASES,
                post_reap_delay_ns=delay,
            )
            runner.run_case(run_args)
            statement = read_json(case_dir / "statement.json")
            if case_id in DIAGNOSTIC_CASES and (
                    statement["outputs"]["observation"]["present"]
                    or not (case_dir / "stderr.bin").read_bytes()):
                raise CampaignError("real Godot diagnostic baseline was not produced")
            if not args.admit_only:
                apply_attack(case_dir, case_id, prior, statement["roots"])
            case_bytes = sum(
                path.stat().st_size for path in case_dir.rglob("*") if path.is_file())
            if case_bytes > profile["caps"]["maxCasePacketBytes"]:
                raise CampaignError(f"{case_id} evidence exceeds its frozen cap")
            receipt = case_dir / "receipt.json"
            replay = case_dir / "receipt-replay.json"
            common = _verifier_common(args, packet_manifest)
            for destination in (receipt, replay):
                run([
                    sys.executable, str(VERIFIER_PATH), "case", *common,
                    "--challenge", str(challenge), "--case-dir", str(case_dir),
                    "--receipt-out", str(destination),
                ])
            if receipt.read_bytes() != replay.read_bytes():
                raise CampaignError(f"{case_id} verifier replay differs")
            prior[case_id] = case_dir
        if args.admit_only:
            case_receipt = read_json(cases_root / "G00" / "receipt.json")
            capability_path = output / "capability-prerequisite.json"
            assert capability is not None
            result = {
                "schema": ADMISSION_SCHEMA, "verdict": case_receipt["verdict"],
                "reason": case_receipt["reason"], "requestIndex": args.request_index,
                "observerSha": args.observer_sha, "productSha": args.product_sha,
                "packetSha": args.packet_sha, "packetRoot": args.packet_root,
                "authorityIssue": args.authority_issue,
                "authorityComment": args.authority_comment,
                "caseReceiptSha256": case_receipt["receiptSha256"],
                "capabilityRun": capability["capabilityRun"],
                "capabilityReceiptSha256": capability["capabilityReceiptSha256"],
                "capabilityPrerequisiteSha256": sha256_file(capability_path),
            }
            result["receiptSha256"] = hashlib.sha256(canonical_bytes(result)).hexdigest()
            write_json(output / "admission-receipt.json", result)
            if (result["verdict"], result["reason"]) != ("PASS", "ADMITTED"):
                raise CampaignError("admitted G00 invocation did not pass")
            return result
        campaign_receipt = output / "campaign-receipt.json"
        run([
            sys.executable, str(VERIFIER_PATH), "campaign",
            *_verifier_common(args, packet_manifest),
            "--challenges-dir", str(challenges), "--campaign-dir", str(cases_root),
            "--receipt-out", str(campaign_receipt),
        ])
        total = campaign_evidence_bytes(output, mounts_root)
        if total > profile["caps"]["maxCampaignBytes"]:
            raise CampaignError("campaign byte cap exceeded")
        result = read_json(campaign_receipt)
        if result.get("verdict") != "PASS":
            raise CampaignError("frozen case expectations did not all match")
        return result
    finally:
        for target in reversed(mounted):
            subprocess.run(
                ["sudo", "-n", "umount", str(target)], check=False,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, default=PROFILE_PATH)
    parser.add_argument("--g0-manifest", type=Path, default=G0_MANIFEST_PATH)
    for name in ("product-source", "packet-source", "godot", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    for name in ("observer-sha", "product-sha", "packet-sha", "packet-root"):
        parser.add_argument(f"--{name}", required=True)
    parser.add_argument("--authority-issue", type=int, required=True)
    parser.add_argument("--authority-comment", type=int, required=True)
    parser.add_argument("--request-index", default="0")
    parser.add_argument("--admit-only", action="store_true")
    parser.add_argument("--capability-prerequisite", type=Path)
    parser.add_argument("--capability-run", type=int)
    parser.add_argument("--capability-receipt-sha256")
    args = parser.parse_args(argv)
    try:
        result = run_campaign(args)
    except (OSError, ValueError, json.JSONDecodeError,
            subprocess.SubprocessError, CampaignError) as error:
        print(f"Godot runtime qualification failed: {error}", file=sys.stderr)
        return 1
    label = "admission" if args.admit_only else "qualification"
    print(f"Godot runtime {label} PASS: {result['receiptSha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
