#!/usr/bin/env python3
"""Deterministic causal-slate research campaign for issue #524."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import shutil
import sqlite3
import statistics
import subprocess
from collections import defaultdict
from functools import lru_cache
from itertools import combinations
from pathlib import Path


ROOT = Path("/Users/jamesto/Research/glassvow-causal-slate-524")
SOURCE = ROOT / "source"
ART = ROOT / "artifacts"
CACHE = ROOT / "cache/sha256"
WORK = ROOT / "work"
SUMMARIES = ROOT / "summaries"
PROTOCOL = ROOT / "protocols/preregistration-v1.json"
DB_PATH = ROOT / "ledger/experiments-v1.sqlite"
ISSUE_514 = Path("/Users/jamesto/Research/glassvow-balance-514")
ISSUE_517 = Path("/Users/jamesto/Research/glassvow-bayes-517")
ISSUE_519 = Path("/Users/jamesto/Research/glassvow-repertoire-519")
ISSUE_520 = Path("/Users/jamesto/Research/glassvow-codesign-520")
ISSUE_521 = Path("/Users/jamesto/Research/glassvow-reward-exposure-521")
POLICIES = ISSUE_520 / "work/detector3-policies-confirmatory-v1.ndjson"
POLICY_COHORT = ISSUE_520 / "artifacts/detector-policy-cohort-v3.json"
SIM_BATCH = ISSUE_520 / "tools/sim_batch.gd"
SOURCE_COMMIT = "0f005282e8881d970da284f4868caedf60cc8142"
GODOT_VERSION = "4.7.2.stable.official.ed1daf0bf"
CONTENT_SHA = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
STAGE_A_SEEDS = tuple(range(20300, 20316))
GRIDS = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")
STAGE_A_FIDELITY = "issue-524-stage-a-mediation-v1"
MECHANISM_RUNNER = ROOT / "tools/mechanism_probe.gd"
STAGE_B_MICRO_SEEDS = tuple(range(22000, 22006))
STAGE_B_PROBE_SEEDS = tuple(range(22100, 22104))
STAGE_B_PANEL_SEEDS = tuple(range(22200, 22208))
STAGE_B_CROSS_SEEDS = tuple(range(22300, 22306))


PACKAGES = (
    {
        "id": "ash-poison-catalyst", "aspects": ("ashwarden",),
        "nodes": ("venomStrike", "toxicMist", "catalyst"),
        "panelResponse": "poisonApplied",
        "edges": (
            {"id": "venomStrike->catalyst", "producer": "venomStrike",
             "consumer": "catalyst", "response": "poisonApplied", "probe": "poison"},
            {"id": "toxicMist->catalyst", "producer": "toxicMist",
             "consumer": "catalyst", "response": "poisonApplied", "probe": "poison"},
        ),
    },
    {
        "id": "dusk-crack-payoff", "aspects": ("duskblade",),
        "nodes": ("warCry", "executioner", "heavyBlow"),
        "panelResponse": "directDamage",
        "edges": (
            {"id": "warCry->executioner", "producer": "warCry",
             "consumer": "executioner", "response": "directDamage", "probe": "vulnerable"},
            {"id": "warCry->heavyBlow", "producer": "warCry",
             "consumer": "heavyBlow", "response": "directDamage", "probe": "vulnerable"},
        ),
    },
    {
        "id": "strength-multihit", "aspects": ("duskblade", "ashwarden"),
        "nodes": ("empower", "twinFangs", "flurry"),
        "panelResponse": "directDamage",
        "edges": (
            {"id": "empower->twinFangs", "producer": "empower",
             "consumer": "twinFangs", "response": "directDamage", "probe": "strength"},
            {"id": "empower->flurry", "producer": "empower",
             "consumer": "flurry", "response": "directDamage", "probe": "strength"},
        ),
    },
    {
        "id": "ward-double", "aspects": ("duskblade", "ashwarden"),
        "nodes": ("brace", "bulwark", "fortify"),
        "panelResponse": "blockGain",
        "edges": (
            {"id": "brace->fortify", "producer": "brace", "consumer": "fortify",
             "response": "blockGain", "probe": "block"},
            {"id": "bulwark->fortify", "producer": "bulwark", "consumer": "fortify",
             "response": "blockGain", "probe": "block"},
        ),
    },
    {
        "id": "ember-spend", "aspects": ("duskblade", "ashwarden"),
        "nodes": ("tithe", "novaflare", "emberdance"),
        "panelResponse": "emberGain",
        "edges": (
            {"id": "tithe->novaflare", "producer": "tithe", "consumer": "novaflare",
             "response": "directDamage", "probe": "embers"},
            {"id": "tithe->emberdance", "producer": "tithe", "consumer": "emberdance",
             "response": "blockGain", "probe": "embers"},
        ),
    },
    {
        "id": "hand-size-payoff", "aspects": ("duskblade", "ashwarden"),
        "nodes": ("preparation", "surge", "phantomBlades"),
        "panelResponse": "directDamage",
        "edges": (
            {"id": "preparation->phantomBlades", "producer": "preparation",
             "consumer": "phantomBlades", "response": "directDamage", "probe": "hand"},
            {"id": "surge->phantomBlades", "producer": "surge",
             "consumer": "phantomBlades", "response": "directDamage", "probe": "hand"},
        ),
    },
    {
        "id": "healing-amplifier", "aspects": ("duskblade", "ashwarden"),
        "nodes": ("regrowth", "leechBlade", "sunBlossom"),
        "panelResponse": "heal",
        "edges": (
            {"id": "regrowth->sunBlossom", "producer": "regrowth",
             "consumer": "sunBlossom", "response": "heal", "probe": "sun-regrowth"},
            {"id": "leechBlade->sunBlossom", "producer": "leechBlade",
             "consumer": "sunBlossom", "response": "heal", "probe": "sun-leech"},
        ),
    },
    {
        "id": "kindle-draw", "aspects": ("duskblade", "ashwarden"),
        "nodes": ("firstSpark", "offering", "verdantBranch"),
        "panelResponse": "draw",
        "edges": (
            {"id": "firstSpark->verdantBranch", "producer": "firstSpark",
             "consumer": "verdantBranch", "response": "draw", "probe": "branch"},
            {"id": "offering->verdantBranch", "producer": "offering",
             "consumer": "verdantBranch", "response": "draw", "probe": "branch"},
        ),
    },
    {
        "id": "ash-venomous-attacks", "aspects": ("ashwarden",),
        "nodes": ("virulence", "twinFangs", "flurry"),
        "panelResponse": "poisonApplied",
        "edges": (
            {"id": "virulence->twinFangs", "producer": "virulence",
             "consumer": "twinFangs", "response": "poisonApplied", "probe": "venomous"},
            {"id": "virulence->flurry", "producer": "virulence",
             "consumer": "flurry", "response": "poisonApplied", "probe": "venomous"},
        ),
    },
    {
        "id": "dusk-shatter-relics", "aspects": ("duskblade",),
        "nodes": ("limitBreak", "prismCharm", "bellOfEndings"),
        "panelResponse": "shatter",
        "edges": (
            {"id": "limitBreak->prismCharm", "producer": "limitBreak",
             "consumer": "prismCharm", "response": "emberGain", "probe": "prism"},
            {"id": "limitBreak->bellOfEndings", "producer": "limitBreak",
             "consumer": "bellOfEndings", "response": "directDamage", "probe": "bell"},
        ),
    },
)

EXPECTED = {
    Path("/opt/homebrew/bin/godot"): "c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf",
    ISSUE_514 / "artifacts/campaign-close-v1.json": "b8c5a2c696eb958cd34c8afb534ce8338302f2ffe92c60734ca4f0e0f082ab83",
    ISSUE_514 / "artifacts/historical-row-cache-v1.parquet": "64229a2f9e48055d9134ddf03fe625c21d2e24a8ef4729e42afe773016da9071",
    ISSUE_514 / "summaries/campaign-close-v1.md": "be40932caf886a3b4223407ac240dd3bbeb4417b6caffdf3bd6faf4852188ea9",
    ISSUE_517 / "manifest-final-v2.json": "577d60eb25de16fbe7ad36bf01f2d212a92b0dc59a09ecbe197b013241bca283",
    ISSUE_517 / "summaries/final-report-v2.md": "077050c4bd8d6b9ead780b1c73cac060594897f724d05b5f387a47d74436f5e9",
    ISSUE_517 / "artifacts/model-comparison-v1.json": "cf7dcf30dabc9d9445ebabf6eb03abad2a85765595efda6b678c3edc8ff3830e",
    ISSUE_517 / "artifacts/policy-bank-v1.parquet": "f8a1dea8fa87d555af970062648251b4ab901dca150ea116a373fe6260b4a74e",
    ISSUE_517 / "work/policies-v1.ndjson": "91cca35e200758b7a3e094398fb5219851256bd814f8adbcdd414e338b269599",
    ISSUE_519 / "immutable-manifest-v2.json": "3b28ec327e3bb19227103f9310145340b795cd3be76d321e5bd45ce1ea9294b2",
    ISSUE_519 / "summaries/final-report-v2.md": "269f3f049d01425555d21fd6a3c5d2974d8c6a15cbbad53455e276e1cea5bd72",
    ISSUE_519 / "ledger/experiments-v1.sqlite": "1597815c08909e619859507ca0841177d7883f7fa03b56c680d7d81f61567e9d",
    ISSUE_519 / "artifacts/ledger-integrity-v2.json": "69e8fded5a2f4aec2c47a29f906358b90c0bcd8cc22f663ee695ead726a7ead5",
    ISSUE_520 / "immutable-manifest-v1.json": "35aa5d25de834a972caaa43a868d7799c0997fe4cfe1ed2f08340ed707656f71",
    ISSUE_520 / "artifacts/scope-insufficiency-finding-v2.json": "583cea411ce5a1612bd9cb530159a983136720e933877089239419b7cbe2662c",
    ISSUE_520 / "artifacts/effective-policy-dimension-v1.json": "e5ddf9428800d9c06be54623041aa77649c1fee5f96398390ecf08d95de05290",
    ISSUE_520 / "artifacts/shipping-lever-inventory-v1.json": "1fe02c14f4e8b59c5ae8064119e9859b4259a68fd34b4dfaec5f1d9124a847c5",
    ISSUE_520 / "artifacts/coverage-complete-probe-audit-v1.json": "215c959a364f2f12426bb28208a4f036f151d24d66f57117fae1485a60497d98",
    ISSUE_520 / "summaries/campaign-close-report-v1.md": "bba8e21e9b76c15b626a2f75f2e4c592bc3816956d02ed8fbc41f4c0144a4d9b",
    ISSUE_520 / "ledger/experiments-v1.sqlite": "26cf346f02faf29c31be41cad9bee280e35b6382ddf236d6cc1bcd7a3f235fd6",
    ISSUE_520 / "protocols/structural-diagnostic-v1.json": "39a84ddb401a7a514d202c15e3e86b9e3f6b7b54c6322ce3449b411a1f085fee",
    POLICY_COHORT: "f87cf811ce584f883faddead261088f0d5e1f50b4ab764e58392a95763864105",
    POLICIES: "834de5668313914fec7dc8b3050a271d350fa30eb9a67bfe5f8f0ecbe72f01f5",
    SIM_BATCH: "b688a29f02530bc1a7de139638a4789347b36e746e42b858d774ea4e1837a749",
    ISSUE_521 / "immutable-manifest-v1.json": "eb188e0305eb0ec2cc09a0806bb5dc4262648c04969a39abab86a8b5917fa709",
    ISSUE_521 / "artifacts/bounded-negative-final-v1.json": "ae29ebbf8f6a9c3660e0b47e00d2e107ca657345318c14103762c0299b20837d",
    ISSUE_521 / "artifacts/post-stop-audit-v1.json": "810cb345b3e9431350ceacae856fb398f1b83b27359a2d5c2f75c1389fad6267",
    ISSUE_521 / "ledger/experiments-v1.sqlite": "ac75cb864b5dee88c3dc4292fde2bebfc34cf0bce6e5dd26413aaba1739aab75",
    ISSUE_521 / "tools/reward_exposure_check.gd": "68d40b47cf1fd8137cfaa93f8694f616a9d07eb39836c3b4f783efcf959caf70",
}

CANDIDATES = {
    "identity-control": ISSUE_521 / "candidates/identity-control.json",
    "single-route-exposure": ISSUE_521 / "candidates/single-route-exposure.json",
    "multi-route-exposure": ISSUE_521 / "candidates/multi-route-exposure.json",
    "random-regression-exposure": ISSUE_521 / "candidates/random-regression-exposure.json",
    "global-difficulty": ISSUE_521 / "candidates/global-difficulty.json",
}

TARGETS = {
    "single-route-exposure": ("quickSlash", "deflect", "regrowth"),
    "multi-route-exposure": ("heavyBlow", "resonantLance", "venomStrike", "toxicMist",
                              "catalyst", "quickSlash", "deflect", "regrowth"),
    "random-regression-exposure": ("hex",),
}


def canonical(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def digest(value: object) -> str:
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def file_sha(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            value.update(block)
    return value.hexdigest()


def command(args: list[str], cwd: Path = SOURCE) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(args)}\n"
            f"{result.stdout[-2000:]}\n{result.stderr[-5000:]}")
    return result


def write_once(path: Path, text: str) -> None:
    if path.exists():
        if path.read_text() != text:
            raise RuntimeError(f"frozen output changed: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def write_json_once(path: Path, value: object) -> None:
    write_once(path, json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def database() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH, timeout=60)
    connection.execute("pragma journal_mode=wal")
    connection.executescript("""
        create table if not exists event(
          seq integer primary key autoincrement, at_utc text not null default current_timestamp,
          stage text not null, identity_sha256 text not null unique, payload text not null);
        create table if not exists authority(
          path text primary key, source_issue integer not null, role text not null,
          sha256 text not null, bytes integer not null);
        create table if not exists exclusion(
          identity_sha256 text primary key, source_issue integer not null, reason text not null);
        create table if not exists quarantined_readout(
          name text primary key, source_issue integer not null, payload_sha256 text not null,
          reason text not null);
        create table if not exists object(
          identity_sha256 text primary key, kind text not null, sha256 text not null,
          relative_path text not null, bytes integer not null);
        create table if not exists sim_row(
          identity_sha256 text primary key, candidate_name text not null,
          candidate_id text not null, policy_sha256 text not null, grid text not null,
          seed integer not null, fidelity text not null, row_json text not null);
        create trigger if not exists authority_no_update before update on authority
          begin select raise(abort, 'authority is append-only'); end;
        create trigger if not exists authority_no_delete before delete on authority
          begin select raise(abort, 'authority is append-only'); end;
        create trigger if not exists exclusion_no_update before update on exclusion
          begin select raise(abort, 'exclusion is append-only'); end;
        create trigger if not exists exclusion_no_delete before delete on exclusion
          begin select raise(abort, 'exclusion is append-only'); end;
        create trigger if not exists quarantine_no_update before update on quarantined_readout
          begin select raise(abort, 'quarantine is append-only'); end;
        create trigger if not exists quarantine_no_delete before delete on quarantined_readout
          begin select raise(abort, 'quarantine is append-only'); end;
        create trigger if not exists sim_row_no_update before update on sim_row
          begin select raise(abort, 'sim_row is append-only'); end;
        create trigger if not exists sim_row_no_delete before delete on sim_row
          begin select raise(abort, 'sim_row is append-only'); end;
    """)
    connection.commit()
    return connection


DB = database()


def record(stage: str, payload: object) -> None:
    raw = canonical(payload)
    identity = digest({"stage": stage, "payload": payload})
    old = DB.execute("select payload from event where identity_sha256=?", (identity,)).fetchone()
    if old is not None:
        assert old[0] == raw
        return
    DB.execute("insert into event(stage,identity_sha256,payload) values(?,?,?)",
               (stage, identity, raw))
    DB.commit()


def cache_path(identity: object) -> Path | None:
    row = DB.execute("select sha256,relative_path from object where identity_sha256=?",
                     (digest(identity),)).fetchone()
    if row is None:
        return None
    path = ROOT / row[1]
    if not path.is_file() or file_sha(path) != row[0]:
        raise RuntimeError(f"corrupt cache object: {path}")
    return path


def cache_file(kind: str, identity: object, source: Path) -> Path:
    found = cache_path(identity)
    if found is not None:
        return found
    sha = file_sha(source)
    target = CACHE / sha
    if target.exists():
        assert file_sha(target) == sha
    else:
        shutil.copyfile(source, target)
    DB.execute("insert into object values(?,?,?,?,?)",
               (digest(identity), kind, sha, str(target.relative_to(ROOT)), target.stat().st_size))
    DB.commit()
    return target


def _issue_for(path: Path) -> int:
    for issue, root in ((514, ISSUE_514), (517, ISSUE_517), (519, ISSUE_519),
                        (520, ISSUE_520), (521, ISSUE_521)):
        if path.is_relative_to(root):
            return issue
    return 0


def verify_authorities() -> dict:
    observed = {str(path): file_sha(path) for path in EXPECTED}
    for path, expected in EXPECTED.items():
        if observed[str(path)] != expected:
            raise RuntimeError(f"authority hash drift: {path}")

    manifest_521 = json.loads((ISSUE_521 / "immutable-manifest-v1.json").read_text())
    for relative, expected in manifest_521["files"].items():
        path = ISSUE_521 / relative
        if file_sha(path) != expected:
            raise RuntimeError(f"issue-521 manifest drift: {relative}")
    candidate_manifest = json.loads(
        (ISSUE_521 / "artifacts/native-candidate-freeze-v1.json").read_text())
    expected_candidates = {row["name"]: row["sha256"] for row in candidate_manifest["candidates"]}
    if set(expected_candidates) != set(CANDIDATES):
        raise RuntimeError("issue-521 candidate set drift")
    for name, path in CANDIDATES.items():
        if file_sha(path) != expected_candidates[name]:
            raise RuntimeError(f"issue-521 candidate drift: {name}")

    integrity_521 = json.loads((ISSUE_521 / "artifacts/ledger-integrity-v1.json").read_text())
    for row in integrity_521["cacheObjects"]:
        path = ISSUE_521 / row["relativePath"]
        if path.stat().st_size != row["bytes"] or file_sha(path) != row["sha256"]:
            raise RuntimeError(f"issue-521 cache drift: {path}")

    prior_519 = sqlite3.connect(
        f"file:{ISSUE_519 / 'ledger/experiments-v1.sqlite'}?mode=ro", uri=True)
    exclusions = dict(prior_519.execute("select identity_sha256,reason from exclusion"))
    physical = list(prior_519.execute("select identity_sha256 from sim_row"))
    registered = sorted(identity for (identity,) in physical if identity not in exclusions)
    assert len(registered) == 1474 and len(exclusions) == 504
    assert digest(registered) == "cc2efa7d60d26c4429d596b7dc81396df48bc29742870ffa955a2888de8bdb19"
    assert digest(sorted(exclusions)) == "8c323817ef7d416c45732f8a097014aed1290cc4239f14f9d77bf8b6142d9f44"
    DB.executemany("insert or ignore into exclusion values(?,519,?)",
                   [(identity, reason) for identity, reason in exclusions.items()])

    quarantine = json.loads((ISSUE_521 / "artifacts/post-stop-audit-v1.json").read_text())
    rows = quarantine["quarantinedReadouts"]
    assert set(rows) == {"aspectIdentityCrossEventCount",
                         "reusedIssue520BaselineIdentityComparison", "vow5IdentityComparison"}
    DB.executemany("insert or ignore into quarantined_readout values(?,521,?,?)", [
        (name, digest(payload), payload["reason"]) for name, payload in sorted(rows.items())])

    for path, sha in EXPECTED.items():
        DB.execute("insert or ignore into authority values(?,?,?,?,?)",
                   (str(path), _issue_for(path), "authoritative-input", sha, path.stat().st_size))
    DB.commit()

    assert command(["git", "rev-parse", "HEAD"]).stdout.strip() == SOURCE_COMMIT
    assert command(["git", "branch", "--show-current"]).stdout.strip() == ""
    assert command(["godot", "--version"]).stdout.strip() == GODOT_VERSION
    hardware = command(["/usr/sbin/system_profiler", "SPHardwareDataType"]).stdout
    assert "Chip: Apple M1 Max" in hardware and "Memory: 64 GB" in hardware
    assert file_sha(SOURCE / "content/full-content.json") == CONTENT_SHA
    assert file_sha(SOURCE / "content/content_db.gd") == \
        "6332ca602daac7fbca6c72f82c2fa888ea2a75634d93e7cc705d255b40685594"
    assert file_sha(SOURCE / "domain/rules/rewards.gd") == \
        "3bfb548daa78928a7ad20f2616fc62aed000576351ab934fb61f9cd2f18c51a7"
    assert file_sha(SOURCE / "tools/balance_pilot.gd") == \
        "5fa70a1090ee53312c1d5c88ba14441da8ee559c25ed9c9797478fc95b281727"
    changed = set(command(["git", "diff", "--name-only"]).stdout.splitlines())
    assert changed == {"content/content_db.gd", "domain/rules/rewards.gd",
                       "tools/balance_pilot.gd", "tools/balance_sim.gd"}
    patch = command(["git", "diff", "--binary"]).stdout
    write_once(ART / "research-runtime-and-mediation-v1.patch", patch)

    result = {
        "schemaVersion": 1,
        "issue": 524,
        "sourceCommit": SOURCE_COMMIT,
        "worktreeMode": "detached",
        "host": {"chip": "Apple M1 Max", "memoryGb": 64, "architecture": "arm64"},
        "godotVersion": GODOT_VERSION,
        "protocolSha256": file_sha(PROTOCOL),
        "researchPatchSha256": file_sha(ART / "research-runtime-and-mediation-v1.patch"),
        "simulatorSha256": file_sha(SOURCE / "tools/balance_sim.gd"),
        "verifiedAuthorities": observed,
        "issue521ManifestFiles": len(manifest_521["files"]),
        "issue521CacheObjects": len(integrity_521["cacheObjects"]),
        "issue519RegisteredRows": len(registered),
        "issue519ExcludedRows": len(exclusions),
        "issue519ExcludedIdentitySetSha256": digest(sorted(exclusions)),
        "issue521QuarantinedReadouts": sorted(rows),
        "confirmatoryInferenceRule": "all exclusions and quarantines fail closed",
    }
    write_json_once(ART / "authority-and-source-freeze-v1.json", result)
    record("authority-and-source-freeze", result)
    return result


def targeted_checks() -> dict:
    parsed = command(["tools/check_scripts.sh", "content/content_db.gd",
                      "domain/rules/rewards.gd", "tools/balance_pilot.gd",
                      "tools/balance_sim.gd"])
    prototype = command(["godot", "--headless", "--path", str(SOURCE), "-s",
                         str(ISSUE_521 / "tools/reward_exposure_check.gd")], ROOT)
    traces = command(["godot", "--headless", "--path", ".", "-s",
                      "res://tests/run_all.gd", "--", "--tests=res://tests/test_combat_traces.gd"])
    assert "scripts OK (4 checked)" in parsed.stdout
    assert "PASS reward exposure prototype (native invariants)" in prototype.stdout
    assert "PASS (1 tests)" in traces.stdout
    result = {
        "schemaVersion": 1,
        "parse": "PASS (4 research-touched scripts)",
        "rewardExposureInvariants": "PASS",
        "legacyCombatTraces": "PASS (1 test; 4 traces; 321 rows)",
    }
    write_json_once(ART / "targeted-checks-v1.json", result)
    record("targeted-checks", result)
    return result


def read_rows(path: Path) -> tuple[dict, list[dict]]:
    with path.open() as handle:
        manifest = json.loads(next(handle))
        rows = [json.loads(line) for line in handle if line.strip()]
    return manifest, rows


def _prior_521_rows(candidate: str) -> dict[tuple[str, str, int], dict]:
    prior = sqlite3.connect(
        f"file:{ISSUE_521 / 'ledger/experiments-v1.sqlite'}?mode=ro", uri=True)
    rows = prior.execute(
        "select row_json from sim_row where candidate_name=? and fidelity='issue-521-native-cheap-v1'",
        (candidate,)).fetchall()
    parsed = [json.loads(raw) for (raw,) in rows]
    assert len(parsed) == 1152
    return {(row["candidateId"], row["grid"], int(row["seed"])): row for row in parsed}


def _insert_stage_a(candidate: str, rows: list[dict]) -> None:
    excluded = {row[0] for row in DB.execute("select identity_sha256 from exclusion")}
    old = _prior_521_rows(candidate)
    assert len(rows) == 1152
    identities: set[str] = set()
    for row in rows:
        identity = row["identitySha256"]
        if identity in excluded:
            raise RuntimeError(f"excluded issue-519 identity reappeared: {identity}")
        if identity in identities:
            raise RuntimeError(f"duplicate stage-A identity: {identity}")
        identities.add(identity)
        key = (row["candidateId"], row["grid"], int(row["seed"]))
        prior = old.get(key)
        if prior is None or row["outcomeDigest"] != prior["outcomeDigest"]:
            raise RuntimeError(f"observational instrumentation changed outcome: {candidate} {key}")
        item = row["identity"]
        raw = canonical(row)
        previous = DB.execute(
            "select row_json from sim_row where identity_sha256=?", (identity,)).fetchone()
        if previous is not None:
            assert previous[0] == raw
            continue
        DB.execute("insert into sim_row values(?,?,?,?,?,?,?,?)", (
            identity, candidate, row["candidateId"], item["policySha256"], row["grid"],
            int(row["seed"]), row["fidelity"], raw))
    DB.commit()


def run_stage_a_candidate(name: str) -> Path:
    content = CANDIDATES[name]
    identity = {
        "kind": "stage-a-mediation",
        "candidate": name,
        "sourceCommit": SOURCE_COMMIT,
        "godotVersion": GODOT_VERSION,
        "contentSha256": file_sha(content),
        "policyCohortSha256": file_sha(POLICIES),
        "seeds": STAGE_A_SEEDS,
        "grids": GRIDS,
        "fidelity": STAGE_A_FIDELITY,
        "protocolSha256": file_sha(PROTOCOL),
        "pilotSha256": file_sha(SOURCE / "tools/balance_pilot.gd"),
        "simulatorSha256": file_sha(SOURCE / "tools/balance_sim.gd"),
        "simBatchSha256": file_sha(SIM_BATCH),
    }
    cached = cache_path(identity)
    if cached is not None:
        print(canonical({"candidate": name, "status": "cache-hit"}), flush=True)
        return cached
    existing = DB.execute(
        "select count(*) from sim_row where candidate_name=? and fidelity=?",
        (name, STAGE_A_FIDELITY)).fetchone()[0]
    if existing:
        raise RuntimeError(f"partial or unarchived complete identity for {name}: {existing}")
    output = WORK / f"stage-a-{digest(identity)}.ndjson"
    if output.exists():
        manifest, rows = read_rows(output)
        if len(rows) != 1152:
            output.rename(output.with_suffix(f".partial-{file_sha(output)[:12]}.ndjson"))
    if not output.exists():
        print(canonical({"candidate": name, "status": "running"}), flush=True)
        command(["godot", "--headless", "--path", str(SOURCE), "-s", str(SIM_BATCH), "--",
                 f"--policies={POLICIES}", f"--out={output}",
                 f"--seeds={','.join(map(str, STAGE_A_SEEDS))}",
                 f"--grids={','.join(GRIDS)}", f"--fidelity={STAGE_A_FIDELITY}",
                 f"--content={content}", f"--source={SOURCE_COMMIT}"], ROOT)
    manifest, rows = read_rows(output)
    assert manifest["type"] == "manifest" and manifest["contentSha256"] == file_sha(content)
    assert manifest["simSha256"] == file_sha(SOURCE / "tools/balance_sim.gd")
    assert len(rows) == 1152
    _insert_stage_a(name, rows)
    cached = cache_file("stage-a-mediation", identity, output)
    record("stage-a-candidate-complete", {
        "candidate": name, "rows": len(rows), "identity": identity,
        "objectSha256": file_sha(cached), "outcomeReplayMismatches": 0,
        "excludedIdentityIntersection": 0,
    })
    print(canonical({"candidate": name, "status": "complete", "rows": len(rows)}), flush=True)
    return cached


def _row_value(row: dict, metric: str, targets: tuple[str, ...]) -> float:
    events = row.get("packageEvents", {})
    mediation = events.get("mediation", {})
    if metric == "offerShare":
        counts = mediation.get("offer", {})
        total = sum(float(value) for value in counts.values())
        return 0.0 if total == 0 else sum(float(counts.get(card, 0)) for card in targets) / total
    if metric in {"pick", "accept", "decline", "acquire", "play"}:
        counts = mediation.get(metric, {})
        return sum(float(counts.get(card, 0)) for card in targets)
    if metric == "activation":
        if targets == ("hex",):
            return float(events.get("hexDrawn", 0))
        counts = mediation.get("activate", {})
        return sum(float(value) for key, value in counts.items()
                   if any(key.startswith(f"{card}|") for card in targets))
    if metric == "unrelatedActivation":
        counts = mediation.get("activate", {})
        return sum(float(value) for key, value in counts.items()
                   if not any(key.startswith(f"{card}|") for card in targets))
    if metric == "win":
        return 1.0 if row.get("outcome") == "win" else 0.0
    if metric == "stall":
        return 1.0 if row.get("outcome") == "stall" else 0.0
    if metric == "error":
        return 1.0 if row.get("error") else 0.0
    if metric == "turns":
        return sum(float(fight.get("turns", 0)) for fight in row.get("fights", []))
    raise KeyError(metric)


def _quantile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    position = min(len(ordered) - 1, max(0, round(q * (len(ordered) - 1))))
    return ordered[position]


def _paired_summary(base: dict, candidate: dict, metric: str,
                    targets: tuple[str, ...]) -> dict:
    keys = sorted(set(base) & set(candidate))
    if not keys:
        raise RuntimeError(f"no paired rows for {metric}")
    base_values = [_row_value(base[key], metric, targets) for key in keys]
    candidate_values = [_row_value(candidate[key], metric, targets) for key in keys]
    deltas = [right - left for left, right in zip(base_values, candidate_values)]
    rng = random.Random(524001 + int(hashlib.sha256(metric.encode()).hexdigest()[:8], 16))
    boots = []
    for _ in range(2000):
        boots.append(statistics.fmean(deltas[rng.randrange(len(deltas))] for _ in deltas))
    scale = statistics.pstdev(base_values + candidate_values)
    raw_delta = statistics.fmean(deltas)
    return {
        "pairs": len(keys),
        "baselineMean": statistics.fmean(base_values),
        "candidateMean": statistics.fmean(candidate_values),
        "delta": raw_delta,
        "standardisedDelta": raw_delta / scale if scale > 1.0e-12 else (0.0 if raw_delta == 0 else math.copysign(math.inf, raw_delta)),
        "pairedBootstrapP05": _quantile(boots, 0.05),
        "pairedBootstrapP95": _quantile(boots, 0.95),
    }


def _cohort_split() -> dict[str, set[str]]:
    cohort = json.loads(POLICY_COHORT.read_text())
    ordered = sorted(cohort["members"], key=lambda row: row["semanticSha256"])
    assert len(ordered) == 16
    return {
        "discovery": {row["simId"] for index, row in enumerate(ordered) if index % 2 == 0},
        "heldOut": {row["simId"] for index, row in enumerate(ordered) if index % 2 == 1},
    }


def _rows_for(candidate: str) -> list[dict]:
    return [json.loads(raw) for (raw,) in DB.execute(
        "select row_json from sim_row where candidate_name=? and fidelity=?",
        (candidate, STAGE_A_FIDELITY))]


def _map_rows(rows: list[dict], candidate_ids: set[str], seed_parity: int) -> dict:
    return {(row["candidateId"], row["grid"], int(row["seed"])): row for row in rows
            if row["candidateId"] in candidate_ids and int(row["seed"]) % 2 == seed_parity}


def analyse_stage_a() -> dict:
    split = _cohort_split()
    rows = {name: _rows_for(name) for name in CANDIDATES}
    assert all(len(value) == 1152 for value in rows.values())
    controls = {
        "randomBuild": {"detector-confirmatory-random-build"},
        "randomPlay": {"detector-confirmatory-random-play"},
    }
    report: dict[str, object] = {}
    thresholds = json.loads(PROTOCOL.read_text())["stageA"]

    for name, targets in TARGETS.items():
        candidate_report: dict[str, object] = {"targets": targets, "splits": {}}
        split_passes = []
        for split_name, policy_ids in split.items():
            parity = 0 if split_name == "discovery" else 1
            arms = {"planned": policy_ids, **controls}
            arm_report = {}
            for arm, ids in arms.items():
                base = _map_rows(rows["identity-control"], ids, parity)
                candidate = _map_rows(rows[name], ids, parity)
                arm_report[arm] = {metric: _paired_summary(base, candidate, metric, targets)
                                   for metric in ("offerShare", "pick", "accept", "decline",
                                                  "acquire", "play", "activation",
                                                  "unrelatedActivation", "win", "stall",
                                                  "error", "turns")}
            planned = arm_report["planned"]
            random_build = arm_report["randomBuild"]
            relevance_arm = random_build if name == "random-regression-exposure" else planned
            relevance = (
                relevance_arm["offerShare"]["delta"] >= thresholds["interventionRelevance"]["offerProbabilityDelta"]
                and relevance_arm["offerShare"]["pairedBootstrapP05"] > 0
                and relevance_arm["acquire"]["delta"] >= thresholds["interventionRelevance"]["acquisitionProbabilityDelta"]
                and relevance_arm["acquire"]["pairedBootstrapP05"] > 0
                and relevance_arm["activation"]["standardisedDelta"] >= thresholds["interventionRelevance"]["mechanismActivationStandardisedDelta"]
                and relevance_arm["activation"]["pairedBootstrapP05"] > 0)
            if name == "random-regression-exposure":
                arm_specificity = (random_build["acquire"]["delta"] >= 0.20
                                   and planned["acquire"]["delta"] <= 0.05
                                   and random_build["win"]["delta"] <= -0.15
                                   and planned["win"]["delta"] >= -0.10)
            else:
                arm_specificity = (
                    planned["acquire"]["delta"] - random_build["acquire"]["delta"] >= 0.05
                    and planned["activation"]["standardisedDelta"]
                    - random_build["activation"]["standardisedDelta"] >= 0.25)
            exclusion = (planned["stall"]["delta"] <= 0
                         and random_build["stall"]["delta"] <= 0
                         and planned["error"]["delta"] <= 0
                         and random_build["error"]["delta"] <= 0
                         and abs(planned["win"]["delta"]) <= 0.05
                         and abs(planned["unrelatedActivation"]["standardisedDelta"]) <= 0.25)
            passes = {"interventionRelevance": relevance, "armSpecificity": arm_specificity,
                      "exclusion": exclusion}
            passes["pass"] = all(passes.values())
            split_passes.append(passes["pass"])
            candidate_report["splits"][split_name] = {"arms": arm_report, "checks": passes}
        candidate_report["heldOutReproducible"] = all(split_passes)
        candidate_report["groundTruthAdmitted"] = all(split_passes)
        report[name] = candidate_report

    global_splits = {}
    for split_name, policy_ids in split.items():
        parity = 0 if split_name == "discovery" else 1
        planned_base = _map_rows(rows["identity-control"], policy_ids, parity)
        planned_candidate = _map_rows(rows["global-difficulty"], policy_ids, parity)
        random_base = _map_rows(rows["identity-control"], controls["randomBuild"], parity)
        random_candidate = _map_rows(rows["global-difficulty"], controls["randomBuild"], parity)
        global_splits[split_name] = {
            "plannedWin": _paired_summary(planned_base, planned_candidate, "win", ()),
            "randomBuildWin": _paired_summary(random_base, random_candidate, "win", ()),
            "plannedStall": _paired_summary(planned_base, planned_candidate, "stall", ()),
            "plannedError": _paired_summary(planned_base, planned_candidate, "error", ()),
        }
    global_admitted = all(value["plannedWin"]["delta"] <= -0.10
                          and value["plannedStall"]["delta"] <= 0
                          and value["plannedError"]["delta"] <= 0
                          for value in global_splits.values())
    report["global-difficulty"] = {"splits": global_splits,
                                   "historicalComparatorAdmitted": global_admitted}

    admitted = [name for name in TARGETS if report[name]["groundTruthAdmitted"]]
    result = {
        "schemaVersion": 1,
        "issue": 524,
        "stage": "A",
        "decision": "PROCEED_TO_MECHANISM_GRAPH",
        "candidateRows": {name: len(value) for name, value in rows.items()},
        "totalNewRows": sum(len(value) for value in rows.values()),
        "outcomeReplayMismatches": 0,
        "excludedIssue519IdentityIntersection": 0,
        "quarantinedIssue521ReadoutsUsedForInference": [],
        "audit": report,
        "oldPackageLabelsAdmitted": admitted,
        "interpretation": "Failed issue-521 labels are not reused as causal ground truth; Stage B starts from authored semantics and controlled interventions.",
    }
    write_json_once(ART / "stage-a-mediation-audit-v1.json", result)
    record("stage-a-decision", result)
    return result


def run_stage_a() -> dict:
    verify_authorities()
    targeted_checks()
    for name in CANDIDATES:
        run_stage_a_candidate(name)
    return analyse_stage_a()


SPECIAL_SEMANTICS = {
    "leech": ({"damage", "healing"}, set()),
    "execute": ({"damage"}, {"enemy:vulnerable"}),
    "momentum": ({"damage"}, {"repeat-play"}),
    "doubleBlock": ({"block"}, {"block"}),
    "phantom": ({"damage"}, {"hand-size"}),
    "devour": ({"damage", "healing", "embers"}, {"lethal-target"}),
    "pyreTithe": ({"draw", "exhaust", "embers"}, {"hand-size"}),
    "catalyst": ({"enemy:poison"}, {"enemy:poison"}),
    "shatterEcho": ({"damage"}, {"enemy:vulnerable", "enemy:staggered"}),
    "flawless": ({"block"}, {"no-hp-loss"}),
    "emberNova": ({"damage"}, {"embers"}),
    "emberdance": ({"block"}, {"embers"}),
}


RELIC_SEMANTICS = {
    "emberHeart": ({"healing"}, {"combat-end"}),
    "ashenCore": ({"enemy:poison"}, {"combat-start"}),
    "basaltIdol": ({"block"}, {"combat-start"}),
    "warFetish": ({"player:str"}, {"combat-start"}),
    "riverPearl": ({"player:dex"}, {"combat-start"}),
    "travelersPack": ({"draw", "hand-size"}, {"first-turn"}),
    "emberLantern": ({"energy"}, {"first-turn"}),
    "vialOfLife": ({"healing"}, {"combat-start"}),
    "thornBand": ({"player:thorns"}, {"combat-start"}),
    "sweetRoot": ({"max-hp"}, {"pickup"}),
    "gravebloom": ({"healing"}, {"combat-end", "low-hp"}),
    "silkFan": ({"block"}, {"card-play"}),
    "reapersBell": ({"energy", "draw", "hand-size"}, {"enemy-death"}),
    "executionersSeal": ({"damage-multiplier"}, {"attack-play"}),
    "ironTalisman": ({"player:str"}, {"attack-play"}),
    "merchantsMark": ({"shop-discount"}, {"shop"}),
    "seersOrb": ({"offer-choice"}, {"card-offer"}),
    "frozenCore": ({"energy"}, {"unspent-energy"}),
    "verdantBranch": ({"draw", "hand-size"}, {"exhaust"}),
    "sunBlossom": ({"healing-amplifier"}, {"healing"}),
    "wardingCharm": ({"damage-mitigation"}, {"small-enemy-hit"}),
    "duskmirror": ({"energy-discount"}, {"first-card", "high-cost-card"}),
    "smolderingCoal": ({"enemy:poison"}, {"combat-start"}),
    "thiefOfWicks": ({"gold"}, {"unlit-node"}),
    "prismCharm": ({"embers"}, {"shatter"}),
    "bellOfEndings": ({"damage"}, {"shatter", "multiple-enemies"}),
    "crownOfCinders": ({"embers", "ember-capacity"}, {"combat-start"}),
    "hollowCrown": ({"energy"}, {"turn-start"}),
    "crownOfTithes": ({"block", "kindle-capacity"}, {"kindle"}),
    "shatterersCrown": ({"facet-reduction"}, {"combat-start", "shatter"}),
    "crownOfTheHearth": ({"healing"}, {"combat-end", "embers"}),
}


def _effect_semantics(definition: dict) -> tuple[set[str], set[str]]:
    produces: set[str] = set()
    consumes: set[str] = set()
    card_type = definition.get("type", "")
    if card_type == "attack":
        produces.update(("attack-play", "facet-chip"))
        consumes.update(("player:str", "enemy:vulnerable", "player:venomous"))
    if definition.get("exhaust"):
        produces.update(("exhaust", "embers"))
    if definition.get("chip", 0):
        produces.add("facet-chip")
    for effect in definition.get("effects", []):
        kind = effect.get("kind", "")
        if kind == "dmg":
            produces.add("damage")
        elif kind == "block":
            produces.add("block")
            consumes.add("player:dex")
        elif kind == "draw":
            produces.update(("draw", "hand-size"))
        elif kind == "energy":
            produces.add("energy")
        elif kind == "heal":
            produces.add("healing")
        elif kind == "loseHp":
            produces.add("self-damage")
        elif kind == "chip":
            produces.add("facet-chip")
        elif kind == "ember":
            produces.add("embers")
        elif kind == "status":
            prefix = "player" if effect.get("who") == "self" else "enemy"
            status_id = str(effect.get("id", ""))
            produces.add(f"{prefix}:{status_id}")
            if prefix == "player":
                produces.update({
                    "regen": {"healing"}, "metallicize": {"block"},
                    "ritual": {"player:str"}, "emberflow": {"embers"},
                    "nightsight": {"draw", "hand-size"}, "energized": {"energy"},
                }.get(status_id, set()))
        elif kind == "special":
            special_produces, special_consumes = SPECIAL_SEMANTICS[effect["id"]]
            produces.update(special_produces)
            consumes.update(special_consumes)
    if "block" in produces:
        consumes.add("player:dex")
    if "healing" in produces:
        consumes.add("healing-amplifier")
    if definition.get("cost", 0) and int(definition.get("cost", 0)) >= 2:
        consumes.update(("energy", "energy-discount"))
    if "facet-chip" in produces:
        produces.add("shatter")
    return produces, consumes


def build_authored_graph() -> dict:
    root = json.loads((SOURCE / "content/full-content.json").read_text())
    cards, relics = root["cards"], root["relics"]
    assert len(cards) == 61 and len(relics) == 31
    assert set(relics) == set(RELIC_SEMANTICS)
    base_pool = {card: tier for tier, ids in root["cardPools"].items() for card in ids}
    base_relic_pool = {relic: tier for tier, ids in root["relicPools"].items() for relic in ids}
    unlocks: dict[str, str] = {}
    for deed, row in root["deeds"].items():
        for unlock in row.get("unlocks", []):
            unlocks[unlock] = deed
    starters = {card for aspect in root["aspects"] for card in aspect["startDeck"]}
    nodes = []
    mechanics: dict[str, dict[str, list[str]]] = {}
    for card_id, definition in cards.items():
        base_produces, base_consumes = _effect_semantics(definition)
        upgraded = definition.copy()
        upgraded.update(definition.get("up", {}))
        up_produces, up_consumes = _effect_semantics(upgraded)
        mechanics[f"card:{card_id}"] = {
            "produces": sorted(base_produces | up_produces),
            "consumes": sorted(base_consumes | up_consumes),
        }
        reward_source = "base-pool" if card_id in base_pool else (
            "deed-unlock" if f"card:{card_id}" in unlocks else (
                "starter" if card_id in starters else "special-only"))
        nodes.append({
            "id": card_id, "kind": "card", "type": definition.get("type"),
            "rarity": definition.get("rarity"), "cost": definition.get("cost"),
            "target": definition.get("target"), "base": definition,
            "upgraded": upgraded if "up" in definition else None,
            "produces": sorted(base_produces), "consumes": sorted(base_consumes),
            "upgradedProduces": sorted(up_produces), "upgradedConsumes": sorted(up_consumes),
            "rewardReachability": {"source": reward_source,
                "tier": base_pool.get(card_id, definition.get("rarity")),
                "reveal": root["poolGate"]["cards"].get(card_id),
                "deed": unlocks.get(f"card:{card_id}")},
        })
    for relic_id, definition in relics.items():
        produces, consumes = RELIC_SEMANTICS[relic_id]
        mechanics[f"relic:{relic_id}"] = {
            "produces": sorted(produces), "consumes": sorted(consumes)}
        reward_source = "base-pool" if relic_id in base_relic_pool else (
            "deed-unlock" if f"relic:{relic_id}" in unlocks else "starter")
        nodes.append({
            "id": relic_id, "kind": "relic", "rarity": definition.get("rarity"),
            "definition": definition, "produces": sorted(produces),
            "consumes": sorted(consumes),
            "rewardReachability": {"source": reward_source,
                "tier": base_relic_pool.get(relic_id, definition.get("rarity")),
                "reveal": root["poolGate"]["relics"].get(relic_id),
                "deed": unlocks.get(f"relic:{relic_id}")},
        })
    edges = []
    for source, source_row in mechanics.items():
        for target, target_row in mechanics.items():
            if source == target:
                continue
            for mediator in sorted(set(source_row["produces"]) & set(target_row["consumes"])):
                scope = "ashwarden" if mediator in {"enemy:poison", "player:venomous"} else (
                    "duskblade" if mediator in {"facet-chip", "shatter", "enemy:staggered"}
                    else "both")
                edges.append({"source": source, "target": target,
                              "mediator": mediator, "aspectScope": scope,
                              "status": "authored-hypothesis"})
    tested = []
    edge_keys = {(row["source"].split(":", 1)[1], row["target"].split(":", 1)[1])
                 for row in edges}
    for package in PACKAGES:
        for edge in package["edges"]:
            producer, consumer = edge["producer"], edge["consumer"]
            if (producer, consumer) not in edge_keys:
                # A relic/card direction can be represented by the reverse authored trigger.
                if (consumer, producer) not in edge_keys:
                    raise RuntimeError(f"tested edge lacks authored support: {edge['id']}")
            tested.append({"package": package["id"], **edge})
    result = {
        "schemaVersion": 1, "issue": 524, "stage": "B-authored",
        "sourceCommit": SOURCE_COMMIT, "contentSha256": file_sha(SOURCE / "content/full-content.json"),
        "combatRulesSha256": file_sha(SOURCE / "domain/rules/combat.gd"),
        "rewardRulesSha256": file_sha(SOURCE / "domain/rules/rewards.gd"),
        "outcomeFieldsUsed": [], "cardCount": len(cards), "relicCount": len(relics),
        "nodes": nodes, "candidateEdges": edges, "testedHypotheses": tested,
        "selectionRule": "authored producer-consumer or runtime trigger match only; no all-pairs outcome search",
    }
    write_json_once(ART / "authored-mechanism-graph-v1.json", result)
    record("stage-b-authored-graph", {key: result[key] for key in (
        "schemaVersion", "issue", "stage", "sourceCommit", "contentSha256",
        "combatRulesSha256", "rewardRulesSha256", "cardCount", "relicCount",
        "selectionRule")})
    return result


def _all_unlocks() -> list[str]:
    root = json.loads((SOURCE / "content/full-content.json").read_text())
    values = ["aspect2"]
    for deed in root["deeds"].values():
        values.extend(str(value) for value in deed.get("unlocks", []))
    return sorted(set(values))


def _probe_row(package: dict, edge: dict, aspect: str, seed: int, treated: bool) -> dict:
    probe = edge["probe"]
    setup: dict = {"energy": 20, "enemyHp": 30}
    actions: list[dict] = []
    hand_fill: list[str] = []
    draw_fill: list[str] = []
    relics: list[str] = []
    enemies = ["gloomslime"]
    if probe == "poison":
        setup["enemyStatus"] = {"poison": 8 if treated else 0}
        actions = [{"card": edge["consumer"]}]
    elif probe == "vulnerable":
        setup["enemyStatus"] = {"vulnerable": 2 if treated else 0}
        actions = [{"card": edge["consumer"]}]
    elif probe == "strength":
        setup["playerStatus"] = {"str": 2 if treated else 0}
        actions = [{"card": edge["consumer"]}]
    elif probe == "block":
        setup["block"] = 12 if treated else 0
        actions = [{"card": "fortify"}]
    elif probe == "embers":
        setup["embers"] = 6 if treated else 0
        actions = [{"card": edge["consumer"]}]
    elif probe == "hand":
        actions = [{"card": "phantomBlades"}]
        hand_fill = ["unreadablePage"] * (4 if treated else 0)
    elif probe == "sun-regrowth":
        setup["playerHp"] = 30
        actions = [{"card": "regrowth"}, {"command": "endTurn"}]
        relics = ["sunBlossom"] if treated else []
    elif probe == "sun-leech":
        setup["playerHp"] = 30
        actions = [{"card": "leechBlade"}]
        relics = ["sunBlossom"] if treated else []
    elif probe == "branch":
        actions = [{"card": edge["producer"]}]
        hand_fill = ["defend", "strike", "defend"] if edge["producer"] == "offering" else []
        draw_fill = ["strike"] * 8
        relics = ["verdantBranch"] if treated else []
    elif probe == "venomous":
        setup["playerStatus"] = {"venomous": 2 if treated else 0}
        actions = [{"card": edge["consumer"]}]
    elif probe in {"prism", "bell"}:
        setup["enemyChipsFromMax"] = -1
        actions = [{"card": "limitBreak"}]
        relics = [edge["consumer"]] if treated else []
        if probe == "bell":
            enemies = ["gloomslime", "gloomslime"]
    else:
        raise RuntimeError(f"unknown probe family: {probe}")
    return {
        "id": f"probe:{package['id']}:{edge['id']}:{aspect}:{seed}:{int(treated)}",
        "stage": "controlled-probe", "package": package["id"], "edge": edge["id"],
        "arm": "mediator" if treated else "control", "split": "discovery",
        "context": probe, "aspect": aspect, "seed": seed, "response": edge["response"],
        "mode": "scripted", "deck": ["strike"] * 5 + ["defend"] * 5,
        "relics": relics, "unlocks": _all_unlocks(), "enemies": enemies,
        "actions": actions, "handFill": hand_fill, "drawFill": draw_fill, "setup": setup,
    }


def controlled_probe_plan() -> dict:
    rows = []
    for package in PACKAGES:
        for edge in package["edges"]:
            for aspect in package["aspects"]:
                for seed in STAGE_B_PROBE_SEEDS:
                    rows.extend((_probe_row(package, edge, aspect, seed, False),
                                 _probe_row(package, edge, aspect, seed, True)))
    assert len(rows) <= json.loads(PROTOCOL.read_text())["stageB"]["budgets"]["controlledProbeStates"]
    return {"schemaVersion": 1, "issue": 524, "stage": "B-controlled-probes",
            "sourceCommit": SOURCE_COMMIT, "rows": rows}


@lru_cache(maxsize=None)
def _is_relic(node: str) -> bool:
    root = json.loads((SOURCE / "content/full-content.json").read_text())
    return node in root["relics"]


def _micro_context(edge: dict, offset: int) -> tuple[str, list[str], str]:
    if edge["probe"] == "bell":
        return "double-gloomslime", ["gloomslime", "gloomslime"], "normal"
    contexts = (
        ("duskfang-sporeling", ["duskfang", "sporeling"], "normal"),
        ("ash-acolyte", ["ashAcolyte"], "normal"),
        ("gravewarden", ["gravewarden"], "elite"),
    )
    return contexts[offset % len(contexts)]


def microdeck_plan() -> dict:
    rows = []
    contrasts = 0
    for package in PACKAGES:
        for edge in package["edges"]:
            for aspect in package["aspects"]:
                for offset, seed in enumerate(STAGE_B_MICRO_SEEDS):
                    context, enemies, kind = _micro_context(edge, offset)
                    split = "discovery" if offset % 2 == 0 else "heldOut"
                    for arm, has_a, has_b in (("00", False, False), ("A", True, False),
                                               ("B", False, True), ("AB", True, True)):
                        deck = ["strike"] * 5 + ["defend"] * 5
                        relics: list[str] = []
                        if has_a:
                            deck[0:2] = [edge["producer"]] * 2
                        if has_b:
                            if _is_relic(edge["consumer"]):
                                relics.append(edge["consumer"])
                            else:
                                deck[2:4] = [edge["consumer"]] * 2
                        rows.append({
                            "id": f"micro:{package['id']}:{edge['id']}:{aspect}:{seed}:{arm}",
                            "stage": "microdeck", "package": package["id"],
                            "edge": edge["id"], "arm": arm, "split": split,
                            "context": context, "aspect": aspect, "seed": seed,
                            "response": edge["response"], "mode": "pilot", "maxTurns": 20,
                            "deck": deck, "relics": relics, "unlocks": _all_unlocks(),
                            "enemies": enemies, "kind": kind,
                        })
                    contrasts += 1
    budgets = json.loads(PROTOCOL.read_text())["stageB"]["budgets"]
    assert contrasts == budgets["microDeckPairEffects"] == 192
    assert len(rows) == contrasts * 4
    return {"schemaVersion": 1, "issue": 524, "stage": "B-microdecks",
            "sourceCommit": SOURCE_COMMIT, "pairContrasts": contrasts, "rows": rows}


def panel_plan() -> dict:
    root = json.loads((SOURCE / "content/full-content.json").read_text())
    aspects = {row["id"]: row for row in root["aspects"]}
    rows = []
    contexts = (
        ("act1-mixed", ["duskfang", "sporeling"], "normal"),
        ("act1-solo", ["ashAcolyte"], "normal"),
        ("act1-elite", ["gravewarden"], "elite"),
        ("act2-mixed", ["drownedOne", "mirelurker"], "normal"),
    )
    for package in PACKAGES:
        for aspect in package["aspects"]:
            base_deck = list(aspects[aspect]["startDeck"])
            base_relic = aspects[aspect]["startRelic"]
            card_nodes = [node for node in package["nodes"] if not _is_relic(node)]
            relic_nodes = [node for node in package["nodes"] if _is_relic(node)]
            package_deck = [node for node in card_nodes for _ in range(2)]
            package_deck.extend(base_deck[:10 - len(package_deck)])
            assert len(package_deck) == 10
            for offset, seed in enumerate(STAGE_B_PANEL_SEEDS):
                context, enemies, kind = contexts[offset % len(contexts)]
                split = "discovery" if offset % 2 == 0 else "heldOut"
                for arm in ("baseline", "package"):
                    rows.append({
                        "id": f"panel:{package['id']}:{aspect}:{seed}:{arm}",
                        "stage": "short-panel", "package": package["id"], "edge": "",
                        "arm": arm, "split": split, "context": context, "aspect": aspect,
                        "seed": seed, "response": package["panelResponse"], "mode": "pilot",
                        "maxTurns": 25, "deck": base_deck if arm == "baseline" else package_deck,
                        "relics": [base_relic] if arm == "baseline" else [base_relic, *relic_nodes],
                        "unlocks": _all_unlocks(), "enemies": enemies, "kind": kind,
                    })
    assert len(rows) <= json.loads(PROTOCOL.read_text())["stageB"]["budgets"]["pairedShortPanelRows"]
    return {"schemaVersion": 1, "issue": 524, "stage": "B-short-panels",
            "sourceCommit": SOURCE_COMMIT, "rows": rows}


def _insert_stage_b_rows(name: str, rows: list[dict], fidelity: str) -> None:
    excluded = {row[0] for row in DB.execute("select identity_sha256 from exclusion")}
    for row in rows:
        identity = digest({"fidelity": fidelity, "row": row})
        if identity in excluded:
            raise RuntimeError(f"excluded issue-519 identity reappeared in {name}")
        raw = canonical({**row, "identitySha256": identity})
        previous = DB.execute("select row_json from sim_row where identity_sha256=?",
                              (identity,)).fetchone()
        if previous is not None:
            assert previous[0] == raw
            continue
        DB.execute("insert into sim_row values(?,?,?,?,?,?,?,?)", (
            identity, f"stage-b:{row.get('package', name)}", row["id"], digest({}),
            f"{row.get('aspect', '')}:{row.get('context', '')}", int(row["seed"]),
            fidelity, raw))
    DB.commit()


def run_probe_plan(name: str, plan: dict) -> list[dict]:
    plan_path = WORK / f"stage-b-{name}-plan-v1.json"
    write_json_once(plan_path, plan)
    identity = {"kind": "stage-b-probe", "name": name, "planSha256": file_sha(plan_path),
                "runnerSha256": file_sha(MECHANISM_RUNNER), "sourceCommit": SOURCE_COMMIT,
                "godotVersion": GODOT_VERSION, "protocolSha256": file_sha(PROTOCOL)}
    cached = cache_path(identity)
    if cached is None:
        output = WORK / f"stage-b-{name}-output-v1.json"
        if not output.exists():
            print(canonical({"stageB": name, "status": "running", "rows": len(plan["rows"])}),
                  flush=True)
            command(["godot", "--headless", "--path", str(SOURCE), "-s",
                     str(MECHANISM_RUNNER), "--", f"--plan={plan_path}", f"--out={output}"], ROOT)
        payload = json.loads(output.read_text())
        assert payload["planSha256"] == file_sha(plan_path)
        assert payload["runnerSha256"] == file_sha(MECHANISM_RUNNER)
        assert len(payload["rows"]) == len(plan["rows"])
        cached = cache_file(f"stage-b-{name}", identity, output)
    payload = json.loads(cached.read_text())
    rows = payload["rows"]
    assert len(rows) == len(plan["rows"])
    fidelity = f"issue-524-stage-b-{name}-v1"
    _insert_stage_b_rows(name, rows, fidelity)
    record("stage-b-batch-complete", {"name": name, "rows": len(rows),
                                      "planSha256": file_sha(plan_path),
                                      "objectSha256": file_sha(cached), "fidelity": fidelity})
    print(canonical({"stageB": name, "status": "complete", "rows": len(rows)}), flush=True)
    return rows


def _response(row: dict, metric: str | None = None) -> float:
    key = metric or row["response"]
    if key in row.get("totals", {}):
        return float(row["totals"][key])
    if key in {"turns", "hpLost", "endingHp", "endingBlock", "peakBlock"}:
        return float(row[key])
    if key == "win":
        return 1.0 if row["outcome"] == "win" else 0.0
    if key == "stall":
        return 1.0 if row["outcome"] == "stall" else 0.0
    raise KeyError(key)


def _bootstrap_summary(deltas: list[float], values: list[float], label: str) -> dict:
    assert deltas and values
    rng = random.Random(524002 + int(hashlib.sha256(label.encode()).hexdigest()[:8], 16))
    boots = [statistics.fmean(deltas[rng.randrange(len(deltas))] for _ in deltas)
             for _ in range(2000)]
    raw = statistics.fmean(deltas)
    scale = statistics.pstdev(values)
    return {"pairs": len(deltas), "delta": raw, "pooledScale": scale,
            "standardisedDelta": raw / scale if scale > 1.0e-12 else 0.0,
            "pairedBootstrapP05": _quantile(boots, 0.05),
            "pairedBootstrapP95": _quantile(boots, 0.95)}


def analyse_controlled(rows: list[dict]) -> dict:
    groups: dict[tuple, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for row in rows:
        groups[(row["package"], row["edge"], row["aspect"])][row["arm"]].append(row)
    results = {}
    for key, arms in sorted(groups.items()):
        control = {row["seed"]: row for row in arms["control"]}
        mediator = {row["seed"]: row for row in arms["mediator"]}
        seeds = sorted(set(control) & set(mediator))
        values = [_response(control[seed]) for seed in seeds] + \
                 [_response(mediator[seed]) for seed in seeds]
        deltas = [_response(mediator[seed]) - _response(control[seed]) for seed in seeds]
        summary = _bootstrap_summary(deltas, values, ":".join(map(str, key)))
        summary["pass"] = summary["delta"] > 0 and summary["pairedBootstrapP05"] > 0
        results["|".join(key)] = summary
    assert all(row["pass"] for row in results.values())
    return {"states": len(rows), "edgeAspectChecks": len(results), "checks": results,
            "allInterventionRelevant": True}


def _micro_groups(rows: list[dict]) -> dict[tuple, list[dict]]:
    groups: dict[tuple, list[dict]] = defaultdict(list)
    for row in rows:
        groups[(row["package"], row["edge"], row["aspect"], row["split"])].append(row)
    return groups


def _grouped_ridge(rows: list[dict]) -> dict[str, float]:
    import numpy as np
    from sklearn.linear_model import Ridge

    groups = _micro_groups(rows)
    keys = sorted(groups)
    columns = {key: index * 4 for index, key in enumerate(keys)}
    x = np.zeros((len(rows), len(keys) * 4), dtype=float)
    y = np.zeros(len(rows), dtype=float)
    cursor = 0
    for key in keys:
        scale = statistics.pstdev([_response(row) for row in groups[key]]) or 1.0
        centre = statistics.fmean(_response(row) for row in groups[key])
        base = columns[key]
        for row in groups[key]:
            a = 1.0 if row["arm"] in {"A", "AB"} else 0.0
            b = 1.0 if row["arm"] in {"B", "AB"} else 0.0
            x[cursor, base:base + 4] = (1.0, a, b, a * b)
            y[cursor] = (_response(row) - centre) / scale
            cursor += 1
    model = Ridge(alpha=1.0, fit_intercept=False).fit(x, y)
    return {"|".join(key): float(model.coef_[columns[key] + 3]) for key in keys}


def _forest_interactions(rows: list[dict]) -> dict[str, float]:
    import numpy as np
    from sklearn.ensemble import ExtraTreesRegressor

    out = {}
    for key, group in sorted(_micro_groups(rows).items()):
        contexts = sorted({row["context"] for row in group})
        context_index = {value: index for index, value in enumerate(contexts)}
        x, y = [], []
        for row in group:
            a = 1.0 if row["arm"] in {"A", "AB"} else 0.0
            b = 1.0 if row["arm"] in {"B", "AB"} else 0.0
            one_hot = [0.0] * len(contexts)
            one_hot[context_index[row["context"]]] = 1.0
            x.append([a, b, *one_hot])
            y.append(_response(row))
        model = ExtraTreesRegressor(n_estimators=256, random_state=524,
                                    max_features=None).fit(np.asarray(x), np.asarray(y))
        effects = []
        for context in contexts:
            one_hot = [0.0] * len(contexts)
            one_hot[context_index[context]] = 1.0
            predictions = {}
            for arm, a, b in (("00", 0.0, 0.0), ("A", 1.0, 0.0),
                              ("B", 0.0, 1.0), ("AB", 1.0, 1.0)):
                predictions[arm] = float(model.predict(np.asarray([[a, b, *one_hot]]))[0])
            effects.append(predictions["AB"] - predictions["A"]
                           - predictions["B"] + predictions["00"])
        out["|".join(key)] = statistics.fmean(effects)
    return out


def analyse_microdecks(rows: list[dict], controlled: dict) -> dict:
    ridge = _grouped_ridge(rows)
    forest = _forest_interactions(rows)
    threshold = json.loads(PROTOCOL.read_text())["stageB"]["interactionAdmission"]
    grouped = _micro_groups(rows)
    results = {}
    for key, group in sorted(grouped.items()):
        by_seed: dict[int, dict[str, dict]] = defaultdict(dict)
        for row in group:
            by_seed[int(row["seed"])][row["arm"]] = row
        deltas, values = [], []
        for seed, arms in sorted(by_seed.items()):
            assert set(arms) == {"00", "A", "B", "AB"}
            values.extend(_response(arms[arm]) for arm in ("00", "A", "B", "AB"))
            deltas.append(_response(arms["AB"]) - _response(arms["A"])
                          - _response(arms["B"]) + _response(arms["00"]))
        label = "|".join(key)
        summary = _bootstrap_summary(deltas, values, label)
        summary["ridgeInteractionCoefficient"] = ridge[label]
        summary["extraTreesFanovaInteraction"] = forest[label]
        controlled_key = "|".join(key[:3])
        summary["controlledProbePass"] = controlled["checks"][controlled_key]["pass"]
        summary["complementarityPass"] = (
            summary["controlledProbePass"]
            and summary["standardisedDelta"] >= threshold["positiveComplementarityStandardised"]
            and summary["pairedBootstrapP05"] > 0
            and summary["ridgeInteractionCoefficient"] > 0
            and summary["extraTreesFanovaInteraction"] > 0)
        summary["antagonismPass"] = (
            summary["standardisedDelta"] <= threshold["negativeAntagonismStandardised"]
            and summary["pairedBootstrapP95"] < 0
            and summary["ridgeInteractionCoefficient"] < 0
            and summary["extraTreesFanovaInteraction"] < 0)
        results[label] = summary
    promoted = []
    antagonistic = []
    for package in PACKAGES:
        for edge in package["edges"]:
            for aspect in package["aspects"]:
                split_rows = [results[f"{package['id']}|{edge['id']}|{aspect}|{split_name}"]
                              for split_name in ("discovery", "heldOut")]
                if all(row["complementarityPass"] for row in split_rows):
                    promoted.append(f"{package['id']}|{edge['id']}|{aspect}")
                if all(row["antagonismPass"] for row in split_rows):
                    antagonistic.append(f"{package['id']}|{edge['id']}|{aspect}")
    return {"rows": len(rows), "pairContrasts": len(rows) // 4,
            "mainEffects": len(grouped), "tripleEffects": 0,
            "model": {"ridge": "pooled edge-aspect fixed effects with shared L2 shrinkage",
                      "extraTrees": "256-tree contextual fANOVA sign check"},
            "checks": results, "promotedEdgeAspects": sorted(promoted),
            "antagonisticEdgeAspects": sorted(antagonistic)}


PANEL_METRICS = ("directDamage", "poisonDamage", "poisonApplied", "vulnerableApplied",
                 "blockGain", "heal", "draw", "emberGain", "shatter")


def _paired_panel(group: list[dict], metric: str, label: str) -> dict:
    arms: dict[str, dict[int, dict]] = defaultdict(dict)
    for row in group:
        arms[row["arm"]][int(row["seed"])] = row
    seeds = sorted(set(arms["baseline"]) & set(arms["package"]))
    base = [_response(arms["baseline"][seed], metric) for seed in seeds]
    candidate = [_response(arms["package"][seed], metric) for seed in seeds]
    return _bootstrap_summary([right - left for left, right in zip(base, candidate)],
                              [*base, *candidate], label)


def analyse_panels(rows: list[dict], micro: dict) -> dict:
    groups: dict[tuple, list[dict]] = defaultdict(list)
    for row in rows:
        groups[(row["package"], row["aspect"], row["split"])].append(row)
    results = {}
    for key, group in sorted(groups.items()):
        package_id, aspect, split = key
        package = next(row for row in PACKAGES if row["id"] == package_id)
        activation = _paired_panel(group, package["panelResponse"], "|".join((*key, "activation")))
        turns = _paired_panel(group, "turns", "|".join((*key, "turns")))
        win = _paired_panel(group, "win", "|".join((*key, "win")))
        stall = _paired_panel(group, "stall", "|".join((*key, "stall")))
        arm_rows: dict[str, list[dict]] = defaultdict(list)
        for row in group:
            arm_rows[row["arm"]].append(row)
        base_turns = statistics.fmean(_response(row, "turns") for row in arm_rows["baseline"])
        turn_reduction = -turns["delta"] / base_turns if base_turns > 0 else 0.0
        mechanism = {}
        for metric in PANEL_METRICS:
            metric_summary = _paired_panel(group, metric, "|".join((*key, metric)))
            if metric_summary["standardisedDelta"] >= 0.25 \
                    and metric_summary["pairedBootstrapP05"] > 0:
                mechanism[metric] = metric_summary
        edge_keys = [f"{package_id}|{edge['id']}|{aspect}" for edge in package["edges"]]
        edges_pass = all(edge_key in micro["promotedEdgeAspects"] for edge_key in edge_keys)
        panel_pass = (activation["standardisedDelta"] >= 0.25
                      and activation["pairedBootstrapP05"] > 0
                      and turn_reduction >= 0.10 and stall["delta"] <= 0
                      and win["delta"] >= 0)
        results["|".join(key)] = {
            "activation": activation, "turns": turns, "turnReductionFraction": turn_reduction,
            "win": win, "stall": stall, "activationSet": sorted(mechanism),
            "bothWithinPackageEdgesPass": edges_pass, "panelPass": panel_pass,
            "packageAspectPass": edges_pass and panel_pass,
        }
    return {"rows": len(rows), "checks": results}


def real_economy_reachability() -> dict:
    content = json.loads((SOURCE / "content/full-content.json").read_text())
    pool_cards = {card for cards in content["cardPools"].values() for card in cards}
    rows = _rows_for("identity-control")
    assert len(rows) == 1152
    out = {}
    for package in PACKAGES:
        card_nodes = [node for node in package["nodes"] if node in content["cards"]
                      and content["cards"][node].get("rarity") not in {"starter", "special"}]
        relic_nodes = [node for node in package["nodes"] if node in content["relics"]]
        components = {}
        for card in card_nodes:
            offers, acquisitions = [], []
            for row in rows:
                mediation = row.get("packageEvents", {}).get("mediation", {})
                offers.append(float(mediation.get("offer", {}).get(card, 0)) > 0)
                acquisitions.append(float(mediation.get("acquire", {}).get(card, 0)) > 0)
            components[card] = {"inLegacyPool": card in pool_cards,
                                "offerProbability": statistics.fmean(offers),
                                "acquisitionProbability": statistics.fmean(acquisitions)}
        minimum_offer = min((row["offerProbability"] for row in components.values()), default=0.0)
        minimum_acquisition = min((row["acquisitionProbability"] for row in components.values()),
                                  default=0.0)
        threshold = json.loads(PROTOCOL.read_text())["stageB"]["packageAdmission"] \
            ["realEconomyOfferAndAcquisitionProbabilityMinimum"]
        out[package["id"]] = {
            "profile": "mature-three-act-no-side-state-v1",
            "sourceRows": len(rows), "cardComponents": components,
            "relicComponentsWithoutOfferInstrumentation": relic_nodes,
            "minimumCardOfferProbability": minimum_offer,
            "minimumCardAcquisitionProbability": minimum_acquisition,
            "pass": minimum_offer >= threshold and minimum_acquisition >= threshold
                    and not relic_nodes,
            "failClosedReason": "relic offer mediation was not instrumented"
                    if relic_nodes else ("card component below threshold"
                                         if minimum_offer < threshold or minimum_acquisition < threshold
                                         else ""),
        }
    return out


def analyse_stage_b(controlled_rows: list[dict], micro_rows: list[dict],
                    panel_rows: list[dict], graph: dict) -> dict:
    controlled = analyse_controlled(controlled_rows)
    micro = analyse_microdecks(micro_rows, controlled)
    panels = analyse_panels(panel_rows, micro)
    reachability = real_economy_reachability()
    admitted_by_aspect: dict[str, list[str]] = {"duskblade": [], "ashwarden": []}
    package_results = {}
    for package in PACKAGES:
        aspect_results = {}
        for aspect in package["aspects"]:
            held = panels["checks"][f"{package['id']}|{aspect}|heldOut"]
            passed = held["packageAspectPass"] and reachability[package["id"]]["pass"]
            aspect_results[aspect] = {"heldOut": held, "reachabilityPass":
                                      reachability[package["id"]]["pass"], "pass": passed}
            if passed:
                admitted_by_aspect[aspect].append(package["id"])
        package_results[package["id"]] = {"nodes": package["nodes"],
                                           "aspects": aspect_results,
                                           "reachability": reachability[package["id"]]}
    overall = sorted({package for values in admitted_by_aspect.values() for package in values})
    thresholds = json.loads(PROTOCOL.read_text())["stageB"]["packageAdmission"]
    minimum_met = (len(overall) >= thresholds["minimumPackagesOverall"]
                   and all(len(values) >= thresholds["minimumReachablePackagesPerAspect"]
                           for values in admitted_by_aspect.values()))
    decision = "PROCEED_TO_MATCHED_MUTATIONS" if minimum_met else "STOP_SCOPE_INSUFFICIENT"
    result = {
        "schemaVersion": 1, "issue": 524, "stage": "B",
        "decision": decision, "authoredGraph": {"cards": graph["cardCount"],
            "relics": graph["relicCount"], "candidateEdges": len(graph["candidateEdges"]),
            "testedEdges": len(graph["testedHypotheses"])},
        "controlled": controlled, "microdecks": micro, "panels": panels,
        "packages": package_results, "admittedPackagesOverall": overall,
        "admittedPackagesByAspect": admitted_by_aspect,
        "separation": {"activationJaccard": "not reached",
                       "crossPackageComplementarity": "not reached",
                       "reason": "fewer than three packages passed edge, panel and reachability gates"},
        "budgetsUsed": {"controlledProbeStates": len(controlled_rows),
                        "microDeckMainEffects": len(_micro_groups(micro_rows)) * 2,
                        "microDeckPairEffects": len(micro_rows) // 4,
                        "microDeckTripleEffects": 0,
                        "pairedShortPanelRows": len(panel_rows),
                        "decisionChangingFullRunRows": 0},
        "excludedIssue519Identities": 504,
        "quarantinedIssue521ReadoutsUsedForInference": [],
        "minimumPackageGateMet": minimum_met,
    }
    write_json_once(ART / "stage-b-mechanism-package-gate-v1.json", result)
    record("stage-b-decision", {"decision": decision, "admittedPackagesOverall": overall,
                                 "admittedPackagesByAspect": admitted_by_aspect,
                                 "budgetsUsed": result["budgetsUsed"]})
    return result


def run_stage_b() -> dict:
    verify_authorities()
    graph = build_authored_graph()
    controlled = run_probe_plan("controlled", controlled_probe_plan())
    micro = run_probe_plan("microdeck", microdeck_plan())
    panels = run_probe_plan("panel", panel_plan())
    return analyse_stage_b(controlled, micro, panels, graph)


def finalise_scope_finding(stage_b: dict) -> dict:
    if stage_b["decision"] != "STOP_SCOPE_INSUFFICIENT":
        raise RuntimeError("scope finding is only valid after the Stage-B hard stop")
    missing = {
        "overall": max(0, 3 - len(stage_b["admittedPackagesOverall"])),
        "duskblade": max(0, 2 - len(stage_b["admittedPackagesByAspect"]["duskblade"])),
        "ashwarden": max(0, 2 - len(stage_b["admittedPackagesByAspect"]["ashwarden"])),
    }
    failures = {}
    for package, row in stage_b["packages"].items():
        aspects = {}
        for aspect, result in row["aspects"].items():
            held = result["heldOut"]
            aspects[aspect] = {
                "withinPackageEdges": held["bothWithinPackageEdgesPass"],
                "heldOutPanel": held["panelPass"],
                "realEconomyReachability": result["reachabilityPass"],
                "admitted": result["pass"],
            }
        failures[package] = aspects
    finding = {
        "schemaVersion": 1, "issue": 524, "parent": 421,
        "kind": "precisely-bounded-negative-scope-finding",
        "verdict": "SCOPE_INSUFFICIENT_AT_CAUSAL_MECHANISM_PACKAGE_GATE",
        "finding": (
            "Within the frozen authored semantics, controlled probes, ten preregistered "
            "package families, 192 matched micro-deck pair contrasts and 256 paired short-panel "
            "rows, only the Ashwarden hand-size payoff package passed intervention, held-out "
            "interaction, panel and real-economy reachability gates. No Duskblade package passed."
        ),
        "admittedPackages": stage_b["admittedPackagesOverall"],
        "admittedByAspect": stage_b["admittedPackagesByAspect"],
        "missingFromPreregisteredMinimum": missing,
        "packageChecks": failures,
        "positiveLocalEvidence": {
            "controlledEdgeAspectChecks": stage_b["controlled"]["edgeAspectChecks"],
            "controlledAllRelevant": stage_b["controlled"]["allInterventionRelevant"],
            "heldOutPromotedEdgeAspects": stage_b["microdecks"]["promotedEdgeAspects"],
            "interpretation": "Local mechanism truth did not establish enough separated route packages.",
        },
        "boundedTo": {
            "mediationGraph": "61 cards including upgrades, 31 relics, 582 authored candidate edges",
            "testedPackages": [package["id"] for package in PACKAGES],
            "methods": ["controlled legal state interventions",
                        "matched-size A/B/AB micro-decks with common seeds",
                        "exact Shapley-Taylor difference-in-differences",
                        "pooled grouped ridge interaction signs",
                        "ExtraTrees fANOVA signs", "paired short combat panels",
                        "legacy real-economy mediation reuse"],
            "budgetsUsed": stage_b["budgetsUsed"],
            "unreached": ["matched causal mutations", "detector calibration",
                          "held-out mutation recovery", "contextual reward slates",
                          "functional causal BO", "contextual bandits", "SlateQ", "QD/BO rows"],
            "slateFamiliesTested": [], "fullRunRowsAddedAtStageB": 0,
        },
        "exclusions": {"issue519ResumeDriftIdentities": 504,
                       "issue521QuarantinedReadoutsUsed": [],
                       "humanLabelsOrCalibration": False},
        "productCandidate": None, "detectorContract": None,
        "automaticSuccessor": None, "recommendedResearchAction": "do not create a successor",
        "sourceCommit": SOURCE_COMMIT, "godotVersion": GODOT_VERSION,
        "protocolSha256": file_sha(PROTOCOL),
        "stageAMediationSha256": file_sha(ART / "stage-a-mediation-audit-v1.json"),
        "authoredGraphSha256": file_sha(ART / "authored-mechanism-graph-v1.json"),
        "stageBGateSha256": file_sha(ART / "stage-b-mechanism-package-gate-v1.json"),
    }
    write_json_once(ART / "scope-insufficiency-finding-v1.json", finding)
    record("campaign-hard-stop", {"verdict": finding["verdict"],
                                   "missing": missing,
                                   "findingSha256": file_sha(ART / "scope-insufficiency-finding-v1.json")})
    write_reports(finding, stage_b)
    return finding


def write_reports(finding: dict, stage_b: dict) -> None:
    hand = stage_b["packages"]["hand-size-payoff"]["aspects"]["ashwarden"]["heldOut"]
    promoted = stage_b["microdecks"]["promotedEdgeAspects"]
    artefacts = {
        "protocols/preregistration-v1.json": file_sha(PROTOCOL),
        "artifacts/authority-and-source-freeze-v1.json":
            file_sha(ART / "authority-and-source-freeze-v1.json"),
        "artifacts/stage-a-mediation-audit-v1.json":
            file_sha(ART / "stage-a-mediation-audit-v1.json"),
        "artifacts/authored-mechanism-graph-v1.json":
            file_sha(ART / "authored-mechanism-graph-v1.json"),
        "artifacts/stage-b-mechanism-package-gate-v1.json":
            file_sha(ART / "stage-b-mechanism-package-gate-v1.json"),
        "artifacts/scope-insufficiency-finding-v1.json":
            file_sha(ART / "scope-insufficiency-finding-v1.json"),
        "tools/mechanism_probe.gd": file_sha(MECHANISM_RUNNER),
    }
    index = "\n".join(f"- `{sha}  {path}`" for path, sha in artefacts.items())
    common = f"""Verdict: **`{finding['verdict']}`**.

The campaign stopped at the preregistered Stage-B package gate. It returned one bounded scope finding, no product candidate and no detector contract.

- Source: detached `{SOURCE_COMMIT}`; Godot `{GODOT_VERSION}`; Apple M1 Max / 64 GB.
- Authorities: #514/#517/#519/#520/#521 hash-verified. All 504 #519 resume-drift identities remained excluded; no #521 quarantined readout entered inference.
- Stage A: 5,760 exact-replay rows. `hex` moved offer/pick but not acceptance/acquisition/activation. The old single/multi labels moved acquisition and activation but also broad RandomBuild power and nuisance outcomes, so no old label was admitted.
- Authored graph: 61 cards (including upgrades), 31 relics and 582 semantics-supported candidate edges. Twenty preregistered edges covered ten package families and 32 applicable edge-aspect checks.
- Controlled probes: all 32 checks passed across 256 legal states.
- Micro-decks: 192 matched common-seed A/B/AB contrasts (768 rows); nine edge-aspect interactions passed discovery and held-out exact DiD, grouped-ridge sign and ExtraTrees fANOVA sign.
- Short panels: 256 rows. Only `hand-size-payoff` on Ashwarden passed both within-package edges, held-out activation (standardised `{hand['activation']['standardisedDelta']:.6f}`, bootstrap p05 `{hand['activation']['pairedBootstrapP05']:.6f}`), turn reduction (`{hand['turnReductionFraction']:.6f}`), no added stall/win loss, and legacy real-economy reachability.
- Package count: overall 1/3; Duskblade 0/2; Ashwarden 1/2. Missing: overall 2, Duskblade 2, Ashwarden 1.
- Hard stop honoured: 0 Stage-B full-run rows, 0 Stage-C mutation rows, 0 detector rows, 0 slate/QD/BO rows. Separation, contextual slates and co-design were not reached because they could not change this gate decision.
- Promoted local edge-aspects (not route packages): `{len(promoted)}`.

Artefact SHA-256 index:

{index}
"""
    report = f"""# Issue #524 campaign close

{common}

## Scope boundary

This negative applies only to the frozen mediation graph, the ten tested package families, the controlled and micro-deck interventions, the paired short-panel contexts, the grouped ridge and ExtraTrees sign checks, the legacy real-economy profile, and the recorded budgets. It says nothing about untested mechanisms, mutations, detectors or slate families. No successor was created.
"""
    write_once(SUMMARIES / "campaign-close-v1.md", report)
    machine = (ART / "scope-insufficiency-finding-v1.json").read_text().rstrip()
    issue_524 = f"""Campaign complete — hard stop at Stage B.

{common}

<details><summary>Exact machine-readable bounded finding</summary>

```json
{machine}
```

</details>

No branch, commit, PR or GitHub Actions run was created. The detached research copy remains at `{ROOT}`.
"""
    write_once(SUMMARIES / "issue-524-comment-v1.md", issue_524)
    issue_421 = f"""#524 returned one bounded negative: **`{finding['verdict']}`**.

Within the frozen 61-card/31-relic semantics graph, ten preregistered package families, 192 matched micro-deck contrasts and 256 paired short-panel rows, only `hand-size-payoff` on Ashwarden passed all interaction, panel and real-economy gates. The preregistered minimum was 3 packages overall and 2 per aspect; observed was 1 overall, 0 Duskblade and 1 Ashwarden.

The campaign therefore stopped before matched mutations, detector calibration, contextual reward slates or any QD/BO spend. It produced no product candidate and no detector contract, and created no successor. Full evidence, exact hashes and the machine-readable finding are on #524.

Finding SHA-256: `{file_sha(ART / 'scope-insufficiency-finding-v1.json')}`.
"""
    write_once(SUMMARIES / "issue-421-comment-v1.md", issue_421)


def seal_campaign() -> dict:
    finding_path = ART / "scope-insufficiency-finding-v1.json"
    stage_b_path = ART / "stage-b-mechanism-package-gate-v1.json"
    if not finding_path.exists() or not stage_b_path.exists():
        raise RuntimeError("final finding and Stage-B gate must exist before sealing")
    before = DB.execute("select count(*) from sim_row").fetchone()[0]
    rerun = command(["python3", str(ROOT / "tools/campaign.py"), "stage-b"], ROOT)
    after = DB.execute("select count(*) from sim_row").fetchone()[0]
    if before != after:
        raise RuntimeError(f"deterministic rerun added rows: {before} -> {after}")
    parsed = command(["tools/check_scripts.sh", "content/content_db.gd",
                      "domain/rules/rewards.gd", "tools/balance_pilot.gd",
                      "tools/balance_sim.gd", str(MECHANISM_RUNNER)])
    prototype = command(["godot", "--headless", "--path", str(SOURCE), "-s",
                         str(ISSUE_521 / "tools/reward_exposure_check.gd")], ROOT)
    traces = command(["godot", "--headless", "--path", ".", "-s",
                      "res://tests/run_all.gd", "--",
                      "--tests=res://tests/test_combat_traces.gd"])
    command(["git", "diff", "--check"])
    command(["python3", "-m", "py_compile", str(ROOT / "tools/campaign.py")], ROOT)
    assert "scripts OK (5 checked)" in parsed.stdout
    assert "PASS reward exposure prototype (native invariants)" in prototype.stdout
    assert "PASS (1 tests)" in traces.stdout
    checks = {
        "schemaVersion": 1, "issue": 524,
        "godotVersion": command(["godot", "--version"]).stdout.strip(),
        "researchScripts": "PASS (5 checked)",
        "nativeRewardExposureInvariants": "PASS",
        "legacyCombatTraces": "PASS (1 test; 4 traces; 321 rows)",
        "pythonCompile": "PASS", "gitDiffCheck": "PASS",
        "deterministicStageBRerun": {"rowsBefore": before, "rowsAfter": after,
                                      "batchesReused": all(f'\"stageB\":\"{name}\"' in rerun.stdout
                                                           for name in ("controlled", "microdeck", "panel"))},
        "productWideCiRun": False,
    }
    assert checks["godotVersion"] == GODOT_VERSION \
        and checks["deterministicStageBRerun"]["batchesReused"]
    write_json_once(ART / "final-targeted-verification-v1.json", checks)
    close = {
        "schemaVersion": 1, "issue": 524, "parent": 421,
        "status": "COMPLETE_BOUNDED_NEGATIVE", "verdict":
            "SCOPE_INSUFFICIENT_AT_CAUSAL_MECHANISM_PACKAGE_GATE",
        "returned": {"productCandidate": None, "detectorContract": None,
                     "scopeFinding": "artifacts/scope-insufficiency-finding-v1.json"},
        "sourceCommit": SOURCE_COMMIT, "detachedWorktree": True,
        "branchCreated": False, "commitCreated": False, "pullRequestCreated": False,
        "githubActionsRun": False, "successorCreated": False,
        "simRows": after, "stageARows": 5760, "stageBRows": after - 5760,
        "campaignProgramSha256": file_sha(ROOT / "tools/campaign.py"),
        "mechanismRunnerSha256": file_sha(MECHANISM_RUNNER),
        "findingSha256": file_sha(finding_path),
        "stageBGateSha256": file_sha(stage_b_path),
        "verificationSha256": file_sha(ART / "final-targeted-verification-v1.json"),
    }
    write_json_once(ART / "campaign-close-v1.json", close)
    record("campaign-close", close)
    DB.commit()
    DB.execute("pragma wal_checkpoint(truncate)").fetchall()
    objects = []
    for identity, kind, sha, relative, size in DB.execute(
            "select identity_sha256,kind,sha256,relative_path,bytes from object order by identity_sha256"):
        path = ROOT / relative
        if not path.is_file() or path.stat().st_size != size or file_sha(path) != sha:
            raise RuntimeError(f"cache integrity failure: {relative}")
        objects.append({"identitySha256": identity, "kind": kind, "sha256": sha,
                        "relativePath": relative, "bytes": size})
    duplicate_rows = DB.execute(
        "select count(*)-count(distinct identity_sha256) from sim_row").fetchone()[0]
    counts = {fidelity: count for fidelity, count in DB.execute(
        "select fidelity,count(*) from sim_row group by fidelity order by fidelity")}
    assert duplicate_rows == 0 and counts == {
        STAGE_A_FIDELITY: 5760,
        "issue-524-stage-b-controlled-v1": 256,
        "issue-524-stage-b-microdeck-v1": 768,
        "issue-524-stage-b-panel-v1": 256,
    }
    integrity = {
        "schemaVersion": 1, "issue": 524, "databaseSha256": file_sha(DB_PATH),
        "simRows": after, "duplicateIdentityRows": duplicate_rows,
        "rowsByFidelity": counts,
        "issue519Exclusions": DB.execute(
            "select count(*) from exclusion where source_issue=519").fetchone()[0],
        "issue521Quarantines": DB.execute(
            "select count(*) from quarantined_readout where source_issue=521").fetchone()[0],
        "cacheObjects": objects, "cacheObjectsVerified": len(objects),
        "stageCOrLaterRows": DB.execute(
            "select count(*) from sim_row where fidelity like 'issue-524-stage-c%' ").fetchone()[0],
    }
    assert integrity["issue519Exclusions"] == 504
    assert integrity["issue521Quarantines"] == 3
    assert integrity["stageCOrLaterRows"] == 0
    write_json_once(ART / "ledger-integrity-v1.json", integrity)
    manifest_paths = [
        PROTOCOL,
        *(path for path in sorted(ART.glob("*.json"))),
        ART / "research-runtime-and-mediation-v1.patch",
        *(path for path in sorted(SUMMARIES.glob("*.md"))),
        ROOT / "tools/campaign.py", MECHANISM_RUNNER,
        *(path for path in sorted(WORK.glob("stage-b-*-plan-v1.json"))),
        *(path for path in sorted(WORK.glob("stage-b-*-output-v1.json"))),
        DB_PATH,
        *(ROOT / row["relativePath"] for row in objects),
    ]
    files = {}
    for path in manifest_paths:
        relative = str(path.relative_to(ROOT))
        files[relative] = {"sha256": file_sha(path), "bytes": path.stat().st_size}
    manifest = {"schemaVersion": 1, "issue": 524, "sourceCommit": SOURCE_COMMIT,
                "godotVersion": GODOT_VERSION, "files": files,
                "fileCount": len(files), "verdict": close["verdict"]}
    write_json_once(ROOT / "immutable-manifest-v1.json", manifest)
    return {**close, "ledgerSha256": file_sha(DB_PATH),
            "ledgerIntegritySha256": file_sha(ART / "ledger-integrity-v1.json"),
            "manifestSha256": file_sha(ROOT / "immutable-manifest-v1.json"),
            "manifestFiles": len(files)}


def self_check() -> None:
    assert digest(["a", "b"]) == "0473ef2dc0d324ab659d3580c1134e9d812035905c4781fdd6d529b0c6860e13"
    sample = {"packageEvents": {"mediation": {"offer": {"x": 2, "y": 1},
                                                "activate": {"x|damage": 4}}},
              "outcome": "win", "fights": [{"turns": 3}], "error": ""}
    assert math.isclose(_row_value(sample, "offerShare", ("x",)), 2 / 3)
    assert _row_value(sample, "activation", ("x",)) == 4
    assert _row_value(sample, "win", ()) == 1
    assert len(PACKAGES) == 10 and sum(len(row["edges"]) for row in PACKAGES) == 20
    assert len(microdeck_plan()["rows"]) == 768
    print(canonical({"selfCheck": "PASS"}))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("verify", "stage-a", "stage-b", "finalise",
                                             "seal", "self-check"))
    args = parser.parse_args()
    if args.command == "verify":
        print(canonical(verify_authorities()))
    elif args.command == "stage-a":
        print(canonical(run_stage_a()))
    elif args.command == "stage-b":
        print(canonical(run_stage_b()))
    elif args.command == "finalise":
        stage_b = json.loads((ART / "stage-b-mechanism-package-gate-v1.json").read_text())
        print(canonical(finalise_scope_finding(stage_b)))
    elif args.command == "seal":
        print(canonical(seal_campaign()))
    else:
        self_check()


if __name__ == "__main__":
    main()
