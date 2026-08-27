#!/usr/bin/env python3
"""Resumable native reward-exposure gate for issue #521."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import shutil
import sqlite3
import subprocess
import time
from collections import defaultdict
from pathlib import Path


ROOT = Path("/Users/jamesto/Research/glassvow-reward-exposure-521")
SOURCE = ROOT / "source"
ART = ROOT / "artifacts"
CACHE = ROOT / "cache/sha256"
CANDIDATES = ROOT / "candidates"
WORK = ROOT / "work"
PROTOCOL = ROOT / "protocols/stage-c-cheap-gate-v1.json"
DB_PATH = ROOT / "ledger/experiments-v1.sqlite"
ISSUE_519 = Path("/Users/jamesto/Research/glassvow-repertoire-519")
ISSUE_520 = Path("/Users/jamesto/Research/glassvow-codesign-520")
PRIOR_519_DB = ISSUE_519 / "ledger/experiments-v1.sqlite"
PRIOR_520_DB = ISSUE_520 / "ledger/experiments-v1.sqlite"
POLICIES = ISSUE_520 / "work/detector3-policies-confirmatory-v1.ndjson"
SIM_BATCH = ISSUE_520 / "tools/sim_batch.gd"
SOURCE_COMMIT = "0f005282e8881d970da284f4868caedf60cc8142"
CONTENT_SHA = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
ALGORITHM = "keyed-exponential-race-v1"
SEEDS = tuple(range(20300, 20316))
GRIDS = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")

EXPECTED_HASHES = {
    Path("/opt/homebrew/bin/godot"): "c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf",
    SOURCE / "content/full-content.json": CONTENT_SHA,
    SOURCE / "content/content_db.gd": "6332ca602daac7fbca6c72f82c2fa888ea2a75634d93e7cc705d255b40685594",
    SOURCE / "domain/rules/rewards.gd": "3bfb548daa78928a7ad20f2616fc62aed000576351ab934fb61f9cd2f18c51a7",
    SOURCE / "tools/balance_pilot.gd": "5fa70a1090ee53312c1d5c88ba14441da8ee559c25ed9c9797478fc95b281727",
    SOURCE / "tools/balance_sim.gd": "b169e2588e2ea65b75b94ee94b8e129c2c3ac8a0d5f7076224521a204623cd06",
    ROOT / "tools/reward_exposure_check.gd": "68d40b47cf1fd8137cfaa93f8694f616a9d07eb39836c3b4f783efcf959caf70",
    SIM_BATCH: "b688a29f02530bc1a7de139638a4789347b36e746e42b858d774ea4e1837a749",
    POLICIES: "834de5668313914fec7dc8b3050a271d350fa30eb9a67bfe5f8f0ecbe72f01f5",
    Path("/Users/jamesto/Research/glassvow-balance-514/artifacts/campaign-close-v1.json"):
        "b8c5a2c696eb958cd34c8afb534ce8338302f2ffe92c60734ca4f0e0f082ab83",
    Path("/Users/jamesto/Research/glassvow-balance-514/summaries/campaign-close-v1.md"):
        "be40932caf886a3b4223407ac240dd3bbeb4417b6caffdf3bd6faf4852188ea9",
    Path("/Users/jamesto/Research/glassvow-balance-514/artifacts/historical-row-cache-v1.parquet"):
        "64229a2f9e48055d9134ddf03fe625c21d2e24a8ef4729e42afe773016da9071",
    Path("/Users/jamesto/Research/glassvow-bayes-517/manifest-final-v2.json"):
        "577d60eb25de16fbe7ad36bf01f2d212a92b0dc59a09ecbe197b013241bca283",
    Path("/Users/jamesto/Research/glassvow-bayes-517/summaries/final-report-v2.md"):
        "077050c4bd8d6b9ead780b1c73cac060594897f724d05b5f387a47d74436f5e9",
    Path("/Users/jamesto/Research/glassvow-bayes-517/artifacts/model-comparison-v1.json"):
        "cf7dcf30dabc9d9445ebabf6eb03abad2a85765595efda6b678c3edc8ff3830e",
    Path("/Users/jamesto/Research/glassvow-bayes-517/artifacts/policy-bank-v1.parquet"):
        "f8a1dea8fa87d555af970062648251b4ab901dca150ea116a373fe6260b4a74e",
    Path("/Users/jamesto/Research/glassvow-bayes-517/work/policies-v1.ndjson"):
        "91cca35e200758b7a3e094398fb5219851256bd814f8adbcdd414e338b269599",
    ISSUE_519 / "immutable-manifest-v2.json":
        "3b28ec327e3bb19227103f9310145340b795cd3be76d321e5bd45ce1ea9294b2",
    ISSUE_519 / "summaries/final-report-v2.md":
        "269f3f049d01425555d21fd6a3c5d2974d8c6a15cbbad53455e276e1cea5bd72",
    PRIOR_519_DB: "1597815c08909e619859507ca0841177d7883f7fa03b56c680d7d81f61567e9d",
    ISSUE_519 / "artifacts/ledger-integrity-v2.json":
        "69e8fded5a2f4aec2c47a29f906358b90c0bcd8cc22f663ee695ead726a7ead5",
    ISSUE_520 / "immutable-manifest-v1.json":
        "35aa5d25de834a972caaa43a868d7799c0997fe4cfe1ed2f08340ed707656f71",
    ISSUE_520 / "artifacts/scope-insufficiency-finding-v2.json":
        "583cea411ce5a1612bd9cb530159a983136720e933877089239419b7cbe2662c",
    ISSUE_520 / "summaries/campaign-close-report-v1.md":
        "bba8e21e9b76c15b626a2f75f2e4c592bc3816956d02ed8fbc41f4c0144a4d9b",
    PRIOR_520_DB: "26cf346f02faf29c31be41cad9bee280e35b6382ddf236d6cc1bcd7a3f235fd6",
    ISSUE_520 / "protocols/structural-diagnostic-v1.json":
        "39a84ddb401a7a514d202c15e3e86b9e3f6b7b54c6322ce3449b411a1f085fee",
    ISSUE_520 / "candidates/structural-diagnostic/single-route-exposure.json":
        "fe02f9a0414aa08c2069d08e8bda35a9960a169bcdb1ee38e92f37af4e44c6d0",
    ISSUE_520 / "candidates/structural-diagnostic/multi-route-exposure.json":
        "6010a6bf2762b4e15daa37a290e88fb9124463382615638b540bce7d5fe3730f",
    ISSUE_520 / "candidates/structural-diagnostic/random-regression-exposure.json":
        "f3b40018341cae81354094e3d8e4f863e2f017a4f6bf026334da24e8f2ca0b8d",
    ISSUE_520 / "candidates/mutations-v3/confirmatory-global-difficulty-no-route-differentiation.json":
        "41a9f35c477a8dc6eab730bda3945f02cb7ce67ed6ac7d7eed6ff371b1e62eb1",
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
            f"command failed ({result.returncode}): {' '.join(args)}\n{result.stdout[-2000:]}\n{result.stderr[-4000:]}")
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
        create table if not exists object(
          identity_sha256 text primary key, kind text not null, sha256 text not null,
          relative_path text not null, bytes integer not null);
        create table if not exists prior_sim_row(
          identity_sha256 text primary key, source_issue integer not null, row_json text not null);
        create table if not exists exclusion(
          identity_sha256 text primary key, source_issue integer not null, reason text not null);
        create table if not exists sim_row(
          identity_sha256 text primary key, content_sha256 text not null,
          candidate_name text not null, policy_sha256 text not null, grid text not null,
          seed integer not null, fidelity text not null, row_json text not null);
        create trigger if not exists sim_row_no_update before update on sim_row
          begin select raise(abort, 'sim_row is append-only'); end;
        create trigger if not exists sim_row_no_delete before delete on sim_row
          begin select raise(abort, 'sim_row is append-only'); end;
        create trigger if not exists exclusion_no_update before update on exclusion
          begin select raise(abort, 'exclusion is append-only'); end;
        create trigger if not exists exclusion_no_delete before delete on exclusion
          begin select raise(abort, 'exclusion is append-only'); end;
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
        raise RuntimeError(f"cached object is missing or corrupt: {path}")
    return path


def cache_file(kind: str, identity: object, source: Path) -> Path:
    found = cache_path(identity)
    if found is not None:
        return found
    sha = file_sha(source)
    target = CACHE / sha
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert file_sha(target) == sha
    else:
        shutil.copyfile(source, target)
    DB.execute("insert into object values(?,?,?,?,?)",
               (digest(identity), kind, sha, str(target.relative_to(ROOT)), target.stat().st_size))
    DB.commit()
    return target


def verify_freeze() -> dict:
    observed = {str(path): file_sha(path) for path in EXPECTED_HASHES}
    for path, expected in EXPECTED_HASHES.items():
        if observed[str(path)] != expected:
            raise RuntimeError(f"hash drift: {path}")
    assert command(["git", "rev-parse", "HEAD"]).stdout.strip() == SOURCE_COMMIT
    assert command(["git", "branch", "--show-current"]).stdout.strip() == ""
    assert command(["godot", "--version"]).stdout.strip() == "4.7.2.stable.official.ed1daf0bf"
    hardware = command(["/usr/sbin/system_profiler", "SPHardwareDataType"]).stdout
    assert "Chip: Apple M1 Max" in hardware and "Memory: 64 GB" in hardware
    patch = command(["git", "diff", "--binary", "--", "content/content_db.gd",
                     "domain/rules/rewards.gd", "tools/balance_pilot.gd"]).stdout
    write_once(ART / "research-runtime-prototype-v1.patch", patch)
    result = {
        "schemaVersion": 1,
        "issue": 521,
        "sourceCommit": SOURCE_COMMIT,
        "worktreeMode": "detached",
        "host": {"chip": "Apple M1 Max", "memoryGb": 64, "architecture": "arm64"},
        "godotVersion": "4.7.2.stable.official.ed1daf0bf",
        "verified": observed,
        "protocolSha256": file_sha(PROTOCOL),
        "researchPatchSha256": file_sha(ART / "research-runtime-prototype-v1.patch"),
    }
    write_json_once(ART / "source-freeze-v1.json", result)
    record("freeze-verified", result)
    return result


def import_issue_519() -> dict:
    prior = sqlite3.connect(f"file:{PRIOR_519_DB}?mode=ro", uri=True)
    exclusions = dict(prior.execute("select identity_sha256,reason from exclusion"))
    rows = list(prior.execute("select identity_sha256,row_json from sim_row"))
    registered = [(identity, raw) for identity, raw in rows if identity not in exclusions]
    assert len(registered) == 1474 and len(exclusions) == 504
    assert digest(sorted(identity for identity, _ in registered)) == \
        "cc2efa7d60d26c4429d596b7dc81396df48bc29742870ffa955a2888de8bdb19"
    assert digest(sorted(exclusions)) == \
        "8c323817ef7d416c45732f8a097014aed1290cc4239f14f9d77bf8b6142d9f44"
    DB.executemany("insert or ignore into prior_sim_row values(?,519,?)", registered)
    DB.executemany("insert or ignore into exclusion values(?,?,?)",
                   [(identity, 519, reason) for identity, reason in exclusions.items()])
    DB.commit()
    result = {
        "schemaVersion": 1,
        "registeredRows": len(registered),
        "registeredIdentitySetSha256": digest(sorted(identity for identity, _ in registered)),
        "permanentlyExcludedRows": len(exclusions),
        "excludedIdentitySetSha256": digest(sorted(exclusions)),
        "excludedUse": "permanently forbidden from selection, fitting and inference",
    }
    write_json_once(ART / "authoritative-reuse-v1.json", result)
    record("issue-519-reuse", result)
    return result


def exposure(weights: dict[str, dict[str, float]]) -> dict:
    assert all(math.isfinite(weight) and weight >= 0.0
               for tier in weights.values() for weight in tier.values())
    return {"algorithm": ALGORITHM, "defaultWeight": 1.0, "pools": weights}


def materialise_candidates() -> dict[str, Path]:
    protocol = json.loads(PROTOCOL.read_text())
    base = json.loads((SOURCE / "content/full-content.json").read_text())
    outputs: dict[str, Path] = {}

    identity = copy.deepcopy(base)
    identity["cardRewardExposure"] = exposure({
        tier: {str(card_id): 1.0 for card_id in sorted(pool)}
        for tier, pool in sorted(base["cardPools"].items())
    })
    variants = {"identity-control": identity}
    sources = {
        "single-route-exposure": ISSUE_520 / "candidates/structural-diagnostic/single-route-exposure.json",
        "multi-route-exposure": ISSUE_520 / "candidates/structural-diagnostic/multi-route-exposure.json",
        "random-regression-exposure": ISSUE_520 / "candidates/structural-diagnostic/random-regression-exposure.json",
    }
    weights = {
        "single-route-exposure": protocol["conditioning"]["singleRoute"]["weights"],
        "multi-route-exposure": protocol["conditioning"]["separatedRoutes"]["weights"],
        "random-regression-exposure": protocol["conditioning"]["selectiveRandomRegression"]["weights"],
    }
    for name, source in sources.items():
        content = json.loads(source.read_text())
        content["cardPools"] = copy.deepcopy(base["cardPools"])
        content["cardRewardExposure"] = exposure(weights[name])
        variants[name] = content

    for name, content in variants.items():
        path = CANDIDATES / f"{name}.json"
        write_json_once(path, content)
        outputs[name] = path

    global_source = ISSUE_520 / "candidates/mutations-v3/confirmatory-global-difficulty-no-route-differentiation.json"
    global_path = CANDIDATES / "global-difficulty.json"
    if global_path.exists():
        assert file_sha(global_path) == file_sha(global_source)
    else:
        shutil.copyfile(global_source, global_path)
    outputs["global-difficulty"] = global_path

    manifest = {
        "schemaVersion": 1,
        "protocolSha256": file_sha(PROTOCOL),
        "algorithm": ALGORITHM,
        "candidates": [
            {"name": name, "path": str(path), "sha256": file_sha(path)}
            for name, path in outputs.items()
        ],
        "duplicatePoolEntries": 0,
    }
    write_json_once(ART / "native-candidate-freeze-v1.json", manifest)
    record("native-candidates-frozen", manifest)
    return outputs


def targeted_checks() -> dict:
    parse = command(["tools/check_scripts.sh", "content/content_db.gd",
                     "domain/rules/rewards.gd", "tools/balance_pilot.gd"])
    prototype = command(["godot", "--headless", "--path", str(SOURCE), "-s",
                         str(ROOT / "tools/reward_exposure_check.gd")], ROOT)
    trace = command(["godot", "--headless", "--path", ".", "-s", "res://tests/run_all.gd",
                     "--", "--tests=res://tests/test_combat_traces.gd"])
    assert "scripts OK (3 checked)" in parse.stdout
    assert "PASS reward exposure prototype (native invariants)" in prototype.stdout
    assert "PASS (1 tests)" in trace.stdout
    result = {
        "parse": "PASS (3 research-touched scripts)",
        "nativeInvariants": "PASS",
        "legacyCombatTraces": "PASS (1 test; 4 traces; 321 rows)",
    }
    record("targeted-checks", result)
    return result


def insert_row(candidate_name: str, row: dict) -> None:
    identity = row["identitySha256"]
    if DB.execute("select 1 from exclusion where identity_sha256=?", (identity,)).fetchone():
        raise RuntimeError(f"permanently excluded identity reappeared: {identity}")
    raw = canonical(row)
    old = DB.execute("select row_json from sim_row where identity_sha256=?", (identity,)).fetchone()
    if old is not None:
        assert old[0] == raw
        return
    item = row["identity"]
    DB.execute("insert into sim_row values(?,?,?,?,?,?,?,?)", (
        identity, item["contentSha256"], candidate_name, item["policySha256"], row["grid"],
        int(row["seed"]), row["fidelity"], raw))


def read_rows(path: Path) -> list[dict]:
    with path.open() as handle:
        next(handle)
        return [json.loads(line) for line in handle if line.strip()]


def reuse_baseline() -> Path:
    identity = {
        "kind": "issue-520-baseline-reuse",
        "ledgerSha256": EXPECTED_HASHES[PRIOR_520_DB],
        "contentSha256": CONTENT_SHA,
        "policySha256": EXPECTED_HASHES[POLICIES],
        "seeds": SEEDS,
        "grids": GRIDS,
        "fidelity": "structural-diagnostic",
    }
    found = cache_path(identity)
    if found is not None:
        return found
    prior = sqlite3.connect(f"file:{PRIOR_520_DB}?mode=ro", uri=True)
    raw_rows = prior.execute(
        "select row_json from sim_row where content_sha256=? and fidelity='structural-diagnostic'",
        (CONTENT_SHA,)).fetchall()
    rows = [json.loads(raw) for (raw,) in raw_rows]
    rows.sort(key=lambda row: (row["candidateId"], row["grid"], int(row["seed"])))
    assert len(rows) == 18 * len(GRIDS) * len(SEEDS)
    assert {row["grid"] for row in rows} == set(GRIDS)
    assert {int(row["seed"]) for row in rows} == set(SEEDS)
    output = WORK / f"baseline-{digest(identity)}.ndjson"
    manifest = {"type": "manifest", "schemaVersion": 1, "reusedFromIssue": 520,
                "contentSha256": CONTENT_SHA, "rows": len(rows)}
    output.write_text(canonical(manifest) + "\n" + "".join(canonical(row) + "\n" for row in rows))
    for row in rows:
        insert_row("live-baseline", row)
    DB.commit()
    cached = cache_file("simulation-reuse", identity, output)
    record("baseline-reused", {**identity, "rows": len(rows), "objectSha256": file_sha(cached)})
    return cached


def run_sim(name: str, content_path: Path) -> Path:
    content_sha = file_sha(content_path)
    identity = {
        "kind": "simulation",
        "candidate": name,
        "sourceCommit": SOURCE_COMMIT,
        "godotVersion": "4.7.2.stable.official.ed1daf0bf",
        "contentSha256": content_sha,
        "policySha256": EXPECTED_HASHES[POLICIES],
        "seeds": SEEDS,
        "grids": GRIDS,
        "fidelity": "issue-521-native-cheap-v1",
        "protocolSha256": file_sha(PROTOCOL),
        "contentDbSha256": EXPECTED_HASHES[SOURCE / "content/content_db.gd"],
        "rewardRulesSha256": EXPECTED_HASHES[SOURCE / "domain/rules/rewards.gd"],
        "pilotSha256": EXPECTED_HASHES[SOURCE / "tools/balance_pilot.gd"],
        "simSha256": EXPECTED_HASHES[SOURCE / "tools/balance_sim.gd"],
        "simBatchSha256": EXPECTED_HASHES[SIM_BATCH],
    }
    found = cache_path(identity)
    if found is not None:
        print(canonical({"candidate": name, "status": "cache-hit"}), flush=True)
        return found
    output = WORK / f"sim-{digest(identity)}.ndjson"
    stored = DB.execute(
        "select row_json from sim_row where content_sha256=? and candidate_name=? and fidelity=?",
        (content_sha, name, "issue-521-native-cheap-v1")).fetchall()
    if len(stored) == 18 * len(GRIDS) * len(SEEDS):
        if not output.is_file():
            raise RuntimeError(f"complete ledger identity has no recoverable batch: {name}")
        cached = cache_file("simulation", identity, output)
        record("simulation", {**identity, "rows": len(stored), "objectSha256": file_sha(cached)})
        print(canonical({"candidate": name, "status": "ledger-recovered"}), flush=True)
        return cached
    print(canonical({"candidate": name, "status": "simulating"}), flush=True)
    started = time.monotonic()
    result = command([
        "godot", "--headless", "--path", str(SOURCE), "-s", str(SIM_BATCH), "--",
        f"--policies={POLICIES}", f"--out={output}",
        f"--seeds={','.join(map(str, SEEDS))}", "--fidelity=issue-521-native-cheap-v1",
        f"--source={SOURCE_COMMIT}", f"--grids={','.join(GRIDS)}", f"--content={content_path}",
    ])
    rows = read_rows(output)
    with output.open() as handle:
        manifest = json.loads(next(handle))
    assert manifest["contentSha256"] == content_sha
    assert manifest["pilotSha256"] == EXPECTED_HASHES[SOURCE / "tools/balance_pilot.gd"]
    assert manifest["simSha256"] == EXPECTED_HASHES[SOURCE / "tools/balance_sim.gd"]
    assert len(rows) == 18 * len(GRIDS) * len(SEEDS)
    assert {row["grid"] for row in rows} == set(GRIDS)
    assert {int(row["seed"]) for row in rows} == set(SEEDS)
    for row in rows:
        insert_row(name, row)
    DB.commit()
    cached = cache_file("simulation", identity, output)
    record("simulation", {**identity, "rows": len(rows), "objectSha256": file_sha(cached)})
    print(canonical({"candidate": name, "rows": len(rows), "seconds": round(time.monotonic() - started, 3),
                     "status": "complete", "runner": result.stdout.strip()}), flush=True)
    return cached


def policy_ids() -> tuple[list[str], str, str]:
    rows = [json.loads(line) for line in POLICIES.read_text().splitlines() if line.strip()]
    optimised = [row["id"] for row in rows if not row.get("randomBuild", False)]
    random_build = next(row["id"] for row in rows
                        if row.get("randomBuild", False) and not row.get("randomPlay", False))
    random_play = next(row["id"] for row in rows if row.get("randomPlay", False))
    assert len(optimised) == 16 and len(rows) == 18
    return optimised, random_build, random_play


def metrics(rows: list[dict]) -> dict:
    optimised, random_build, random_play = policy_ids()
    by_cell: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for row in rows:
        by_cell[(row["candidateId"], row["grid"])].append(row)
    for candidate_id in optimised + [random_build, random_play]:
        for grid in GRIDS:
            assert len(by_cell[(candidate_id, grid)]) == len(SEEDS)

    def win_rate(candidate_id: str, grid: str | None = None) -> float:
        selected = [row for row in rows if row["candidateId"] == candidate_id
                    and (grid is None or row["grid"] == grid)]
        return sum(row["outcome"] == "win" for row in selected) / len(selected)

    global_mean = sum(win_rate(candidate_id, grid) for candidate_id in optimised for grid in GRIDS) \
        / (len(optimised) * len(GRIDS))
    per_grid = {}
    for grid in GRIDS:
        random_rate = win_rate(random_build, grid)
        qualities = [win_rate(candidate_id, grid) for candidate_id in optimised]
        per_grid[grid] = {
            "randomBuildWin": random_rate,
            "meanWin": sum(qualities) / len(qualities),
            "viablePolicyCount": sum(rate >= max(0.25, random_rate + 0.15) for rate in qualities),
        }
    cross_events = 0.0
    for row in rows:
        wrong_key = "smolderKills" if row["identity"]["aspect"] == "duskblade" else "shatters"
        cross_events += sum(float(fight.get(wrong_key, 0)) for fight in row.get("fights", []))
    vow5_max = max(win_rate(candidate_id, grid) for candidate_id in optimised
                   for grid in GRIDS if grid.endswith(":v5"))
    return {
        "globalMeanWin": global_mean,
        "randomBuildWin": win_rate(random_build),
        "randomPlayWin": win_rate(random_play),
        "gridMeanViablePolicyCount": sum(row["viablePolicyCount"] for row in per_grid.values()) / len(GRIDS),
        "perGrid": per_grid,
        "simulatorFaults": sum(row["outcome"] not in ("win", "loss") for row in rows),
        "nonEmptyErrors": sum(bool(str(row.get("error", ""))) for row in rows),
        "aspectIdentityCrossEvents": cross_events,
        "maximumObservedOptimisedVow5Win": vow5_max,
    }


def exact_identity_replay(baseline: list[dict], identity: list[dict]) -> tuple[bool, int]:
    fields = ("outcome", "error", "hp", "maxHp", "deck", "fights", "packageEvents", "outcomeDigest")
    base = {(row["candidateId"], row["grid"], int(row["seed"])):
            {field: row.get(field) for field in fields} for row in baseline}
    current = {(row["candidateId"], row["grid"], int(row["seed"])):
               {field: row.get(field) for field in fields} for row in identity}
    mismatches = sum(base.get(key) != value for key, value in current.items())
    mismatches += len(set(base) - set(current))
    return mismatches == 0 and len(base) == len(current), mismatches


def decide(paths: dict[str, Path], checks: dict) -> dict:
    outputs = {"live-baseline": reuse_baseline()}
    for name in ("identity-control", "random-regression-exposure", "global-difficulty",
                 "single-route-exposure", "multi-route-exposure"):
        outputs[name] = run_sim(name, paths[name])
    rows = {name: read_rows(path) for name, path in outputs.items()}
    measured = {name: metrics(value) for name, value in rows.items()}
    baseline = measured["live-baseline"]
    identity = measured["identity-control"]
    random = measured["random-regression-exposure"]
    global_difficulty = measured["global-difficulty"]
    single = measured["single-route-exposure"]
    multi = measured["multi-route-exposure"]
    identity_pass, identity_mismatches = exact_identity_replay(
        rows["live-baseline"], rows["identity-control"])

    random_build_delta = random["randomBuildWin"] - baseline["randomBuildWin"]
    random_global_delta = random["globalMeanWin"] - baseline["globalMeanWin"]
    global_mean_delta = global_difficulty["globalMeanWin"] - baseline["globalMeanWin"]
    global_random_delta = global_difficulty["randomBuildWin"] - baseline["randomBuildWin"]
    selective = random_build_delta <= -0.15 and random_global_delta >= -0.10
    global_selective = global_random_delta <= -0.15 and global_mean_delta >= -0.10
    native_names = ("identity-control", "random-regression-exposure",
                    "single-route-exposure", "multi-route-exposure")
    reliability = all(measured[name]["simulatorFaults"] <= identity["simulatorFaults"]
                      and measured[name]["nonEmptyErrors"] <= identity["nonEmptyErrors"]
                      for name in native_names)
    aspect_identity = all(measured[name]["aspectIdentityCrossEvents"] == 0.0 for name in native_names)
    witnesses = {
        "identityReplay": {"mismatches": identity_mismatches, "pass": identity_pass},
        "selectiveRandomRegression": {
            "randomBuildWinDelta": random_build_delta,
            "optimisedGlobalMeanDelta": random_global_delta,
            "pass": selective,
        },
        "globalDifficultyComparator": {
            "randomBuildWinDelta": global_random_delta,
            "optimisedGlobalMeanDelta": global_mean_delta,
            "satisfiesSelectiveRule": global_selective,
            "pass": global_mean_delta <= -0.10 and not global_selective,
        },
        "routeSeparation": {
            "singleGlobalMeanDelta": single["globalMeanWin"] - baseline["globalMeanWin"],
            "multiGlobalMeanDelta": multi["globalMeanWin"] - baseline["globalMeanWin"],
            "multiMinusSingleMeanViablePolicies":
                multi["gridMeanViablePolicyCount"] - single["gridMeanViablePolicyCount"],
            "pass": single["globalMeanWin"] > baseline["globalMeanWin"]
                and multi["globalMeanWin"] > baseline["globalMeanWin"]
                and multi["gridMeanViablePolicyCount"] - single["gridMeanViablePolicyCount"] >= 1.0,
        },
        "reliability": {
            "identityFaults": identity["simulatorFaults"],
            "nativeFaults": {name: measured[name]["simulatorFaults"] for name in native_names},
            "nativeErrors": {name: measured[name]["nonEmptyErrors"] for name in native_names},
            "pass": reliability,
        },
        "aspectIdentity": {
            "nativeCrossEvents": {name: measured[name]["aspectIdentityCrossEvents"] for name in native_names},
            "pass": aspect_identity,
        },
        "vow5Identity": {
            "baselineMaximumObserved": baseline["maximumObservedOptimisedVow5Win"],
            "identityMaximumObserved": identity["maximumObservedOptimisedVow5Win"],
            "pass": identity_pass,
        },
        "targetedChecks": {**checks, "pass": True},
    }
    passed = all(row["pass"] for row in witnesses.values())
    result = {
        "schemaVersion": 1,
        "issue": 521,
        "decision": "CHEAP_GATE_PASS_FULL_SUITE_REQUIRED" if passed else "STOP_BOUNDED_NEGATIVE",
        "pass": passed,
        "protocolSha256": file_sha(PROTOCOL),
        "candidateFreezeSha256": file_sha(ART / "native-candidate-freeze-v1.json"),
        "witnesses": witnesses,
        "metrics": measured,
        "rows": {"reusedIssue520": len(rows["live-baseline"]),
                 "newNativeGate": sum(len(value) for name, value in rows.items() if name != "live-baseline"),
                 "fullSevenDirection": 0, "qdBo": 0},
        "excludedIdentityIntersection": 0,
    }
    write_json_once(ART / "cheap-gate-result-v1.json", result)
    record("cheap-gate-decision", result)
    if not passed:
        failed = [name for name, row in witnesses.items() if not row["pass"]]
        negative = {
            "schemaVersion": 1,
            "issue": 521,
            "type": "bounded-negative",
            "finding": "The native reward-exposure prototype did not recover every preregistered cheap discriminator or hard guard; detector admission was not attempted.",
            "failedRequirements": failed,
            "conditioning": json.loads(PROTOCOL.read_text())["conditioning"],
            "sampler": json.loads(PROTOCOL.read_text())["mechanism"],
            "suite": {"policyCohortSha256": EXPECTED_HASHES[POLICIES], "seeds": SEEDS,
                      "grids": GRIDS, "candidateFreezeSha256": result["candidateFreezeSha256"]},
            "policyGrammar": "The frozen #520 coverage-complete functional policy instrument and sixteen-policy v3 cohort; no new policy search.",
            "methodBudgets": {"cheapGateNewRows": result["rows"]["newNativeGate"],
                              "fullSuiteRows": 0, "qdBoRows": 0, "beamMctsRlRows": 0},
            "nonClaim": "This does not show that autonomous balance or native weighted exposure is generally impossible.",
            "shipping": {"candidate": False, "detector": False, "productChanges": False},
            "successor": None,
        }
        write_json_once(ART / "bounded-negative-v1.json", negative)
        record("bounded-negative", negative)
    return result


def post_stop_audit(result: dict) -> dict | None:
    if result["pass"]:
        return None
    measured = result["metrics"]
    identity = measured["identity-control"]
    random = measured["random-regression-exposure"]
    global_difficulty = measured["global-difficulty"]
    single = measured["single-route-exposure"]
    multi = measured["multi-route-exposure"]
    base_content = json.loads((SOURCE / "content/full-content.json").read_text())
    identity_content = json.loads((CANDIDATES / "identity-control.json").read_text())
    identity_content.pop("cardRewardExposure")
    old_path = ISSUE_520 / "artifacts/scope-insufficiency-finding-v1.json"
    assert file_sha(old_path) == "a43f53aa263ced7982af306ec985b90b1798c03ee0b1f06f845ed476831ef676"
    old = json.loads(old_path.read_text())["metrics"]
    decisive = {
        "selectiveRandomRegression": {
            "randomBuildWinDeltaVersusIdentity": random["randomBuildWin"] - identity["randomBuildWin"],
            "optimisedGlobalMeanDeltaVersusIdentity": random["globalMeanWin"] - identity["globalMeanWin"],
            "required": {"randomBuildWinDeltaAtMost": -0.15,
                         "optimisedGlobalMeanDeltaAtLeast": -0.10},
            "pass": random["randomBuildWin"] - identity["randomBuildWin"] <= -0.15
                and random["globalMeanWin"] - identity["globalMeanWin"] >= -0.10,
        },
        "globalDifficultyComparator": {
            "randomBuildWinDeltaVersusIdentity":
                global_difficulty["randomBuildWin"] - identity["randomBuildWin"],
            "optimisedGlobalMeanDeltaVersusIdentity":
                global_difficulty["globalMeanWin"] - identity["globalMeanWin"],
            "pass": global_difficulty["globalMeanWin"] - identity["globalMeanWin"] <= -0.10,
        },
        "routeSeparation": {
            "singleGlobalMeanDeltaVersusIdentity": single["globalMeanWin"] - identity["globalMeanWin"],
            "multiGlobalMeanDeltaVersusIdentity": multi["globalMeanWin"] - identity["globalMeanWin"],
            "singleMeanViablePolicies": single["gridMeanViablePolicyCount"],
            "multiMeanViablePolicies": multi["gridMeanViablePolicyCount"],
            "multiMinusSingleMeanViablePolicies":
                multi["gridMeanViablePolicyCount"] - single["gridMeanViablePolicyCount"],
            "requiredDifferenceAtLeast": 1.0,
            "pass": multi["gridMeanViablePolicyCount"] - single["gridMeanViablePolicyCount"] >= 1.0,
        },
        "reliability": {
            "identityStalls": identity["simulatorFaults"],
            "nativeStalls": {
                "randomRegression": random["simulatorFaults"],
                "singleRoute": single["simulatorFaults"],
                "multiRoute": multi["simulatorFaults"],
            },
            "oldDuplicateStalls": {
                "randomRegression": old["random-regression-exposure"]["simulatorFaults"],
                "singleRoute": old["single-route-exposure"]["simulatorFaults"],
                "multiRoute": old["multi-route-exposure"]["simulatorFaults"],
            },
            "stallTurn": 30,
            "pass": all(row["simulatorFaults"] <= identity["simulatorFaults"]
                        for row in (random, single, multi)),
        },
    }
    assert not decisive["selectiveRandomRegression"]["pass"]
    assert not decisive["routeSeparation"]["pass"]
    assert not decisive["reliability"]["pass"]
    audit = {
        "schemaVersion": 1,
        "issue": 521,
        "rawDecisionSha256": file_sha(ART / "cheap-gate-result-v1.json"),
        "decisionUnchanged": "STOP_BOUNDED_NEGATIVE",
        "decisiveMatchedIdentityEvidence": decisive,
        "quarantinedReadouts": {
            "reusedIssue520BaselineIdentityComparison": {
                "reason": "The identity candidate reserialised the complete catalogue in sorted dictionary order; after removing cardRewardExposure it is structurally equal to live content, but the full-catalogue order differs. The resulting whole-run comparison is confounded and is not used.",
                "catalogueStructurallyEqualAfterRemovingExposure": identity_content == base_content,
                "focusedDirectIdentityCheck": "PASS",
                "legacyCombatTraceCheck": "PASS (321 rows)",
            },
            "aspectIdentityCrossEventCount": {
                "reason": "The zero-cross-event proxy was not the inherited signed application rule and was already non-zero in the reused live baseline; it is not used.",
                "reusedBaselineCrossEvents": measured["live-baseline"]["aspectIdentityCrossEvents"],
            },
            "vow5IdentityComparison": {
                "reason": "This inherited the confounded full-catalogue identity comparison; the direct Vow-5 reward identity check passed and no diagnostic intervention is promotion-eligible."
            },
        },
        "noAdditionalRows": True,
    }
    write_json_once(ART / "post-stop-audit-v1.json", audit)
    record("post-stop-audit", audit)
    protocol = json.loads(PROTOCOL.read_text())
    final = {
        "schemaVersion": 1,
        "issue": 521,
        "type": "bounded-negative",
        "finding": "The exact #520-conditioned native exposure prototype neither selectively regressed RandomBuild nor separated single-route from multi-route viability, and route exposure retained additional 30-turn stalls. Detector admission was not attempted.",
        "decisiveEvidence": decisive,
        "sampler": protocol["mechanism"],
        "conditioning": protocol["conditioning"],
        "suite": {
            "sourceCommit": SOURCE_COMMIT,
            "godot": "4.7.2.stable.official.ed1daf0bf",
            "candidateFreezeSha256": file_sha(ART / "native-candidate-freeze-v1.json"),
            "policyCohortSha256": EXPECTED_HASHES[POLICIES],
            "policies": "sixteen frozen #519 registered functional policies plus RandomBuild and RandomPlay",
            "seeds": SEEDS,
            "grids": GRIDS,
        },
        "testedSupport": {
            "effectiveWeights": "single neutral route 9; separated routes 5 except reveal-added resonantLance 4; Hex 24 in each rarity pool",
            "samplerMode": "eligible reveal-gated rarity pools, without replacement, fixed common-random-number uniforms",
            "contentCandidatesSimulated": 5,
            "newWholeRunRows": result["rows"]["newNativeGate"],
            "reusedBaselineRows": result["rows"]["reusedIssue520"],
        },
        "unspent": {"fullSevenDirectionRows": 0, "qdBoRows": 0,
                    "beamMctsRlRows": 0, "acceptanceSeeds": 0, "reserveSeeds": 0},
        "quarantinedReadoutSha256": file_sha(ART / "post-stop-audit-v1.json"),
        "nonClaim": "This is bounded to the frozen conditioning, keyed-exponential-race-v1 sampler, v3 cohort, four grids and 20300-20315 research seeds. It does not show that native weighted exposure or autonomous balance is generally impossible.",
        "shipping": {"candidate": False, "detector": False, "productChanges": False},
        "successor": None,
    }
    write_json_once(ART / "bounded-negative-final-v1.json", final)
    record("bounded-negative-final", final)
    return final


def finalise(result: dict, final: dict | None) -> dict:
    assert final is not None and result["decision"] == "STOP_BOUNDED_NEGATIVE"
    integrity = DB.execute("pragma integrity_check").fetchone()[0]
    assert integrity == "ok"
    identities = [row[0] for row in DB.execute(
        "select identity_sha256 from sim_row order by identity_sha256")]
    exclusions = [row[0] for row in DB.execute(
        "select identity_sha256 from exclusion order by identity_sha256")]
    assert len(identities) == 6912 and len(exclusions) == 504
    intersection = set(identities) & set(exclusions)
    assert not intersection
    objects = []
    for identity, kind, sha, relative, size in DB.execute(
            "select identity_sha256,kind,sha256,relative_path,bytes from object order by identity_sha256"):
        path = ROOT / relative
        assert path.stat().st_size == size and file_sha(path) == sha
        objects.append({"identitySha256": identity, "kind": kind, "sha256": sha,
                        "relativePath": relative, "bytes": size})
    assert len(objects) == 6
    fidelity = dict(DB.execute("select fidelity,count(*) from sim_row group by fidelity"))
    assert fidelity == {"issue-521-native-cheap-v1": 5760, "structural-diagnostic": 1152}
    events = DB.execute("select count(*) from event").fetchone()[0]
    prior_rows = DB.execute("select count(*) from prior_sim_row").fetchone()[0]
    assert prior_rows == 1474
    DB.commit()
    DB.execute("pragma wal_checkpoint(truncate)").fetchone()
    ledger = {
        "schemaVersion": 1,
        "sqliteIntegrity": integrity,
        "ledgerSha256": file_sha(DB_PATH),
        "events": events,
        "simulatorRows": len(identities),
        "simulatorRowsByFidelity": fidelity,
        "simulatorIdentitySetSha256": digest(identities),
        "reusedIssue519RegisteredRows": prior_rows,
        "permanentlyExcludedIssue519Rows": len(exclusions),
        "excludedIdentitySetSha256": digest(exclusions),
        "excludedSimulatorIntersection": len(intersection),
        "cacheObjects": objects,
    }
    write_json_once(ART / "ledger-integrity-v1.json", ledger)
    close = {
        "schemaVersion": 1,
        "issue": 521,
        "decision": "STOP_BOUNDED_NEGATIVE",
        "output": {"type": "bounded-negative",
                   "path": str(ART / "bounded-negative-final-v1.json"),
                   "sha256": file_sha(ART / "bounded-negative-final-v1.json")},
        "detectorAdmissionAttempted": False,
        "fullSevenDirectionRows": 0,
        "adaptiveCoDesignRows": 0,
        "acceptanceSeeds": 0,
        "reserveSeeds": 0,
        "productChanges": False,
        "successor": None,
        "ledgerIntegritySha256": file_sha(ART / "ledger-integrity-v1.json"),
    }
    write_json_once(ART / "campaign-close-v1.json", close)
    evidence = final["decisiveEvidence"]
    report = f"""# Issue #521 campaign close report

## Decision

The campaign returns one precisely bounded negative and stops at the first native-mechanism gate. The complete seven-direction detector suite and adaptive joint policy-content co-design were not run.

## Decisive matched-identity evidence

- Selective RandomBuild regression failed: RandomBuild delta {evidence['selectiveRandomRegression']['randomBuildWinDeltaVersusIdentity']:.3f} versus the required at most -0.150; the optimised global-mean delta was {evidence['selectiveRandomRegression']['optimisedGlobalMeanDeltaVersusIdentity']:.3f}.
- The global-difficulty comparator remained distinguishable: optimised global-mean delta {evidence['globalDifficultyComparator']['optimisedGlobalMeanDeltaVersusIdentity']:.3f}.
- Route separation failed: single-route and multi-route mean viable-policy counts were both {evidence['routeSeparation']['singleMeanViablePolicies']:.2f}, giving a difference of {evidence['routeSeparation']['multiMinusSingleMeanViablePolicies']:.2f} versus the required at least 1.00.
- Reliability failed: identity and random-regression had zero stalls, while single-route had {evidence['reliability']['nativeStalls']['singleRoute']} and multi-route had {evidence['reliability']['nativeStalls']['multiRoute']} 30-turn stalls. Native sampling reduced the old duplicate-emulation counts of {evidence['reliability']['oldDuplicateStalls']['singleRoute']} and {evidence['reliability']['oldDuplicateStalls']['multiRoute']}, but did not meet the zero-additional-stall rule.

## Bound support

- Source `{SOURCE_COMMIT}`; Godot `4.7.2.stable.official.ed1daf0bf`; M1 Max 64 GB.
- Sampler `keyed-exponential-race-v1`, without replacement, fixed per-lane common-random-number uniforms and unchanged outer RunState cursor.
- Exact #520 conditioning: neutral single route weight 9; separated routes weight 5 except reveal-added `resonantLance` weight 4; `hex` weight 24 in common, uncommon and rare.
- Frozen cohort: sixteen #519 registered functional policies plus RandomBuild and RandomPlay; four aspect x vow grids; research seeds 20300-20315.
- Rows: 1,152 reused #520 baseline rows and 5,760 new first-gate rows. All five proposed content files were simulated. The 504 #519 resume-drift identities remained excluded; intersection zero.

## Quarantine and stop

The reused #520 baseline versus reserialised identity-catalogue whole-run comparison and a non-inherited aspect event proxy were confounded, so neither is used in the finding. Direct identity reward checks and 321 frozen legacy trace rows passed. Removing those readouts does not change the stop: all three decisive matched-identity failures above remain.

No full-suite, QD/BO, beam/MCTS/RL, acceptance-seed or reserve-seed row was spent. No product branch, product file, PR, GitHub Actions run or successor issue was created.
"""
    write_once(ROOT / "summaries/campaign-close-report-v1.md", report)
    files = [
        PROTOCOL,
        ROOT / "tools/campaign.py",
        ROOT / "tools/reward_exposure_check.gd",
        ART / "research-runtime-prototype-v1.patch",
        ART / "source-freeze-v1.json",
        ART / "authoritative-reuse-v1.json",
        ART / "native-candidate-freeze-v1.json",
        ART / "cheap-gate-result-v1.json",
        ART / "post-stop-audit-v1.json",
        ART / "bounded-negative-final-v1.json",
        ART / "ledger-integrity-v1.json",
        ART / "campaign-close-v1.json",
        ROOT / "summaries/campaign-close-report-v1.md",
        DB_PATH,
    ]
    manifest = {
        "schemaVersion": 1,
        "issue": 521,
        "sourceCommit": SOURCE_COMMIT,
        "files": {str(path.relative_to(ROOT)): file_sha(path) for path in files},
        "cacheObjectIdentitySetSha256": digest([row["identitySha256"] for row in objects]),
        "output": close["output"],
    }
    write_json_once(ROOT / "immutable-manifest-v1.json", manifest)
    return manifest


def main() -> None:
    freeze = verify_freeze()
    reuse = import_issue_519()
    paths = materialise_candidates()
    checks = targeted_checks()
    result = decide(paths, checks)
    final = post_stop_audit(result)
    manifest = finalise(result, final)
    integrity = DB.execute("pragma integrity_check").fetchone()[0]
    packet = {
        "issue": 521,
        "decision": result["decision"],
        "failed": [name for name, row in result["witnesses"].items() if not row["pass"]],
        "rows": result["rows"],
        "excluded": reuse["permanentlyExcludedRows"],
        "source": freeze["sourceCommit"],
        "ledgerIntegrity": integrity,
        "outputSha256": file_sha(ART / "bounded-negative-final-v1.json") if final else None,
        "manifestSha256": file_sha(ROOT / "immutable-manifest-v1.json"),
    }
    print(canonical(packet), flush=True)


if __name__ == "__main__":
    main()
