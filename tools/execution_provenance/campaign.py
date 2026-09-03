#!/usr/bin/env python3
"""Run the frozen one-valid, ten-control execution-provenance campaign."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


SOURCE_ROOT = Path(__file__).resolve().parent
RUNNER = SOURCE_ROOT / "runner.py"
VERIFIER = SOURCE_ROOT / "verify.py"
CASE_IDS = ["V00"] + [f"N{index:02d}" for index in range(1, 11)]


class CampaignError(RuntimeError):
    """The frozen campaign could not complete exactly once."""


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise CampaignError(f"JSON object required: {path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_bytes(canonical_bytes(value) + b"\n")


def run(command: Sequence[str], *, timeout: int = 30) -> None:
    result = subprocess.run(
        list(command), check=False, capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise CampaignError(f"command failed ({result.returncode}): {command[1]}: {detail}")


def make_writable(root: Path) -> None:
    for path in sorted(root.rglob("*"), reverse=True):
        os.chmod(path, 0o755 if path.is_dir() else 0o644)
    os.chmod(root, 0o755)


def refresh_statement(packet: Path) -> None:
    statement = read_json(packet / "statement.json")
    files = {
        "traceSha256": "trace.tsv", "subjectSha256": "subject.bin",
        "stdoutSha256": "stdout.bin", "stderrSha256": "stderr.bin",
    }
    for key, name in files.items():
        statement[key] = sha256_bytes((packet / name).read_bytes())
    names = (
        "protocolSha256", "capsuleRoot", "case", "challenge", "command",
        "traceSha256", "subjectSha256", "stdoutSha256", "stderrSha256",
        "externalTiming",
    )
    statement["invocation"] = sha256_bytes(canonical_bytes(
        {name: statement.get(name) for name in names}))
    write_json(packet / "statement.json", statement)


def copy_replay(source: Path, destination: Path) -> None:
    for name in ("trace.tsv", "subject.bin", "stdout.bin", "stderr.bin", "statement.json"):
        shutil.copyfile(source / name, destination / name)


def run_campaign(protocol_path: Path, output: Path) -> dict[str, Any]:
    if output.exists():
        raise CampaignError("campaign output must be a fresh path")
    output.mkdir(parents=True)
    workspace = output / "workspace"
    workspace.mkdir()
    results = output / "cases"
    challenges = output / "challenges"
    supplied_root = output / "supplied-capsules"
    outside = output / "outside"
    for directory in (results, challenges, supplied_root, outside):
        directory.mkdir()
    run([sys.executable, str(RUNNER), "build", "--protocol", str(protocol_path),
         "--workspace", str(workspace)])
    build = read_json(workspace / "build.json")
    capsule = Path(build["capsule"])
    protocol = read_json(protocol_path)
    cases = {case["id"]: case for case in protocol["cases"]}
    mounted: list[Path] = []
    try:
        for case_id in CASE_IDS:
            challenge = challenges / f"{case_id}.json"
            run([sys.executable, str(VERIFIER), "challenge",
                 "--protocol", str(protocol_path), "--case", case_id,
                 "--output", str(challenge)])
            supplied = supplied_root / case_id
            shutil.copytree(capsule, supplied)
            make_writable(supplied)
            packet = results / case_id
            runtime = packet / "runtime-capsule"
            actual_input = runtime / "opaque-role.bin"
            actual_exec = runtime / "expected-executable"
            actual_request = cases[case_id].get(
                "actualRequestToken", cases[case_id]["requestToken"])
            extra = ""
            if case_id == "N01":
                (supplied / "opaque-role.bin").write_bytes(bytes(reversed(range(32))))
            elif case_id == "N02":
                attack = outside / case_id
                attack.mkdir()
                actual_input = attack / "opaque-role.bin"
                actual_input.write_bytes(bytes(reversed(range(32))))
            elif case_id == "N03":
                attack = outside / case_id
                attack.mkdir()
                actual_exec = attack / "expected-executable"
                shutil.copyfile(capsule / "expected-executable", actual_exec)
                with actual_exec.open("ab") as handle:
                    handle.write(b"\nBYTE-DISTINCT-ELF\n")
                os.chmod(actual_exec, 0o555)
            elif case_id == "N09":
                attack = outside / case_id
                attack.mkdir()
                alternative = attack / "undeclared-role.bin"
                alternative.write_bytes(b"undeclared")
                extra = str(alternative.resolve())
            run_command = [
                sys.executable, str(RUNNER), "run",
                "--protocol", str(protocol_path), "--workspace", str(workspace),
                "--capsule-source", str(supplied), "--input", str(actual_input),
                "--executable", str(actual_exec), "--request", actual_request,
                "--challenge", str(challenge), "--packet", str(packet),
            ]
            if extra:
                run_command.extend(["--extra", extra])
            run(run_command, timeout=15)
            mounted.append(runtime)
            if case_id == "N05":
                copy_replay(results / "V00", packet)
            elif case_id == "N06":
                shutil.copyfile(results / "V00" / "subject.bin", packet / "subject.bin")
                refresh_statement(packet)
            elif case_id == "N07":
                statement = read_json(packet / "statement.json")
                statement["externalTiming"] = read_json(
                    results / "V00" / "statement.json")["externalTiming"]
                write_json(packet / "statement.json", statement)
                refresh_statement(packet)
            for name in ("verdict.json", "verdict-replay.json"):
                run([sys.executable, str(VERIFIER), "case",
                     "--protocol", str(protocol_path), "--capsule", str(capsule),
                     "--challenge", str(challenge), "--packet", str(packet),
                     "--output", str(packet / name)])
        receipt = output / "campaign-receipt.json"
        run([sys.executable, str(VERIFIER), "campaign",
             "--protocol", str(protocol_path), "--capsule", str(capsule),
             "--results", str(results), "--output", str(receipt)])
        result = read_json(receipt)
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
    parser.add_argument("--protocol", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = run_campaign(args.protocol.resolve(), args.output.resolve())
    except (OSError, ValueError, json.JSONDecodeError,
            subprocess.SubprocessError, CampaignError) as error:
        print(f"execution provenance campaign failed: {error}", file=sys.stderr)
        return 1
    print(f"execution provenance campaign PASS: {result['gitHead']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
