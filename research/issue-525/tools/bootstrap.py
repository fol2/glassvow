#!/usr/bin/env python3
"""Immutable bootstrap and zero-row diagnosis for Glassvow issue #525."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import sqlite3
import subprocess
from pathlib import Path


ROOT = Path("/Users/jamesto/Research/glassvow-mechanism-package-synthesis")
SOURCE = ROOT / "source"
AUTHORITY = ROOT / "authority"
ARTIFACTS = ROOT / "artifacts"
CACHE = ROOT / "cache/sha256"
LEDGER = ROOT / "ledger/experiments-v1.sqlite"
PREREGISTRATION = ROOT / "protocols/preregistration-v1.json"
ISSUE_520 = Path("/Users/jamesto/Research/glassvow-codesign-520")
POLICY_COHORT = ISSUE_520 / "artifacts/detector-policy-cohort-v3.json"
POLICIES = ISSUE_520 / "work/detector3-policies-confirmatory-v1.ndjson"

SOURCE_COMMIT = "0f005282e8881d970da284f4868caedf60cc8142"
ARCHIVE_COMMIT = "f305b95d9e1d173e5d8150289afab9688c0ea7f0"
GODOT_VERSION = "4.7.2.stable.official.ed1daf0bf"
GODOT_SHA256 = "c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf"
CONTENT_SHA256 = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
BASE_SIMULATOR_SHA256 = "b169e2588e2ea65b75b94ee94b8e129c2c3ac8a0d5f7076224521a204623cd06"
REGISTERED_AT_UTC = "2026-08-27T13:18:10Z"
EMPTY_PATCH_SHA256 = hashlib.sha256(b"").hexdigest()

KEY_ARCHIVE_HASHES = {
    "artifacts/scope-insufficiency-finding-v1.json":
        "acecbae3171e739aeae4fe71dde2d0635ce98c453c58400de9bde627b2368fa2",
    "artifacts/authored-mechanism-graph-v1.json":
        "61ab0bd24964293df7ea610911a66a32d41850cdb71100d96566607884b3c5ec",
    "artifacts/stage-a-mediation-audit-v1.json":
        "f9408de4d65695ac67a6807991a076572208d1e9c0c84362ea17146e38fc555e",
    "artifacts/stage-b-mechanism-package-gate-v1.json":
        "c7f12c85998b86a345d84c28593256676731733e605a38fbb57b46db777e313a",
}

SEED_FAMILIES = {
    "packageDiscovery": list(range(23000, 23032)),
    "packageValidation": list(range(23100, 23132)),
    "mutationDiscovery": list(range(23200, 23232)),
    "mutationValidation": list(range(23300, 23332)),
    "slateDiscovery": list(range(23400, 23432)),
    "slateValidation": list(range(23500, 23532)),
    "localRetention": list(range(23600, 23632)),
    "finalResearchConfirmation": list(range(23700, 23732)),
}

PACKAGE_ACTIONS = {
    "ash-poison-catalyst": (
        "Retain venomStrike->catalyst; race toxicMist Smolder, Catalyst multiplier/cost "
        "and rarity until the missing second edge passes held-out A/B/AB checks."
    ),
    "ash-venomous-attacks": (
        "Reject the current definition at level 1 unless acquisition and both attack edges move; "
        "escalate to one small Ash-only card only after that expressibility test fails."
    ),
    "dusk-crack-payoff": (
        "Treat the label as unsupported; test the vulnerable producer and payoff separately, then "
        "replace only the missing component with one existing-primitive card if neither edge moves."
    ),
    "dusk-shatter-relics": (
        "Add deterministic relic-offer/acquisition instrumentation before judging reachability; "
        "retain only a relic edge that then passes controlled and held-out activation checks."
    ),
    "ember-spend": (
        "Do not promote the large activation signal: repair zero economy reachability first and "
        "reject any version that keeps the observed combat-duration regression."
    ),
    "hand-size-payoff": (
        "Preserve the admitted Ash package unchanged as a positive control; for Dusk, require two "
        "new held-out edges rather than borrowing the Ash admission."
    ),
    "healing-amplifier": (
        "Retain leechBlade->sunBlossom on Ash; instrument relic acquisition and repair the missing "
        "second edge without accepting longer combats as a package."
    ),
    "kindle-draw": (
        "Retain offering->verdantBranch on Dusk; instrument relic acquisition and repair the "
        "firstSpark edge or add one smallest existing-primitive Kindle producer."
    ),
    "strength-multihit": (
        "Deprioritise as generic utility unless aspect-specific held-out interaction and policy "
        "witnesses separate it from broad damage movement."
    ),
    "ward-double": (
        "Retain all four local edges; race Fortify cost/rarity and Ward producer values, then require "
        "real acquisition, shorter combats and policy sensitivity before admission."
    ),
}


def canonical(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(value: object) -> str:
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def file_sha256(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            result.update(block)
    return result.hexdigest()


def command(args: list[str], cwd: Path = SOURCE) -> str:
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(args)}\n"
            f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
        )
    return result.stdout.strip()


def write_json_once(path: Path, value: object) -> None:
    text = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if path.exists():
        if path.read_text() != text:
            raise RuntimeError(f"immutable output drift: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def open_ledger() -> sqlite3.Connection:
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(LEDGER, timeout=60)
    connection.execute("pragma journal_mode=wal")
    connection.executescript("""
        create table if not exists event(
          seq integer primary key autoincrement,
          at_utc text not null default current_timestamp,
          stage text not null,
          identity_sha256 text not null unique,
          payload text not null);
        create table if not exists authority(
          path text primary key,
          source_issue integer not null,
          role text not null,
          sha256 text not null,
          bytes integer not null);
        create table if not exists exclusion(
          identity_sha256 text primary key,
          source_issue integer not null,
          reason text not null);
        create table if not exists quarantined_readout(
          name text primary key,
          source_issue integer not null,
          payload_sha256 text not null,
          reason text not null);
        create table if not exists object(
          identity_sha256 text primary key,
          source_issue integer not null,
          kind text not null,
          sha256 text not null,
          relative_path text not null,
          bytes integer not null);
        create table if not exists sim_row(
          identity_sha256 text primary key,
          source_issue integer not null,
          is_new integer not null check(is_new in (0,1)),
          candidate_name text not null,
          candidate_id text not null,
          policy_sha256 text not null,
          grid text not null,
          seed integer not null,
          fidelity text not null,
          row_json text not null);
    """)
    for table in ("event", "authority", "exclusion", "quarantined_readout", "object", "sim_row"):
        connection.executescript(f"""
            create trigger if not exists {table}_no_update before update on {table}
              begin select raise(abort, '{table} is append-only'); end;
            create trigger if not exists {table}_no_delete before delete on {table}
              begin select raise(abort, '{table} is append-only'); end;
        """)
    connection.commit()
    return connection


def record(connection: sqlite3.Connection, stage: str, payload: object) -> None:
    raw = canonical(payload)
    identity = digest({"stage": stage, "payload": payload})
    previous = connection.execute(
        "select payload from event where identity_sha256=?", (identity,)
    ).fetchone()
    if previous is not None:
        if previous[0] != raw:
            raise RuntimeError(f"event identity collision at {stage}")
        return
    connection.execute(
        "insert into event(stage,identity_sha256,payload) values(?,?,?)",
        (stage, identity, raw),
    )
    connection.commit()


def verify_authorities() -> dict:
    source_head = command(["git", "rev-parse", "HEAD"])
    source_branch = command(["git", "branch", "--show-current"])
    source_diff = command(["git", "diff", "--binary"])
    if source_head != SOURCE_COMMIT or source_branch or source_diff:
        raise RuntimeError("detached source plane drift")
    if command(["godot", "--version"]) != GODOT_VERSION:
        raise RuntimeError("Godot version drift")
    if file_sha256(Path("/opt/homebrew/bin/godot")) != GODOT_SHA256:
        raise RuntimeError("Godot binary drift")
    hardware = command(["/usr/sbin/system_profiler", "SPHardwareDataType"])
    if "Chip: Apple M1 Max" not in hardware or "Memory: 64 GB" not in hardware:
        raise RuntimeError("host identity drift")
    if file_sha256(SOURCE / "content/full-content.json") != CONTENT_SHA256:
        raise RuntimeError("live content drift")
    if file_sha256(SOURCE / "tools/balance_sim.gd") != BASE_SIMULATOR_SHA256:
        raise RuntimeError("base simulator drift")

    freeze = json.loads((AUTHORITY / "artifacts/authority-and-source-freeze-v1.json").read_text())
    verified = 0
    for name, expected in freeze["verifiedAuthorities"].items():
        authority_path = Path(name)
        if file_sha256(authority_path) != expected:
            raise RuntimeError(f"authority hash drift: {authority_path}")
        verified += 1

    manifest = json.loads((AUTHORITY / "immutable-manifest-v1.json").read_text())
    if manifest["sourceCommit"] != SOURCE_COMMIT or manifest["fileCount"] != 31:
        raise RuntimeError("issue-524 manifest identity drift")
    for relative, identity in manifest["files"].items():
        archive_path = AUTHORITY / relative
        if archive_path.stat().st_size != identity["bytes"] \
                or file_sha256(archive_path) != identity["sha256"]:
            raise RuntimeError(f"issue-524 archive drift: {relative}")
    for relative, expected in KEY_ARCHIVE_HASHES.items():
        if file_sha256(AUTHORITY / relative) != expected:
            raise RuntimeError(f"issue-524 key evidence drift: {relative}")
    if command(["git", "show", "-s", "--format=%P", ARCHIVE_COMMIT]) != SOURCE_COMMIT:
        raise RuntimeError("issue-524 archive parent drift")
    return {
        "sourceCommit": source_head,
        "sourcePatchSha256": hashlib.sha256(source_diff.encode()).hexdigest(),
        "godotVersion": GODOT_VERSION,
        "godotSha256": GODOT_SHA256,
        "contentSha256": CONTENT_SHA256,
        "baseSimulatorSha256": BASE_SIMULATOR_SHA256,
        "mechanismRunnerSha256": file_sha256(ROOT / "tools/mechanism_probe.gd"),
        "issue524ArchiveCommit": ARCHIVE_COMMIT,
        "issue524ManifestFilesVerified": manifest["fileCount"],
        "upstreamAuthoritiesVerified": verified,
        "keyArchiveHashes": KEY_ARCHIVE_HASHES,
        "sourceReconciliation": {
            "currentMainEqualsIssue524Base": True,
            "affectedIdentities": 0,
        },
    }


def import_prior_evidence(connection: sqlite3.Connection) -> dict:
    prior_path = AUTHORITY / "ledger/experiments-v1.sqlite"
    prior = sqlite3.connect(f"file:{prior_path}?mode=ro", uri=True)
    if prior.execute("pragma integrity_check").fetchone()[0] != "ok":
        raise RuntimeError("issue-524 ledger integrity failure")
    exclusions = list(prior.execute(
        "select identity_sha256,source_issue,reason from exclusion order by identity_sha256"
    ))
    quarantines = list(prior.execute(
        "select name,source_issue,payload_sha256,reason from quarantined_readout order by name"
    ))
    rows = list(prior.execute(
        "select identity_sha256,candidate_name,candidate_id,policy_sha256,grid,seed,fidelity,row_json "
        "from sim_row order by identity_sha256"
    ))
    objects = list(prior.execute(
        "select identity_sha256,kind,sha256,relative_path,bytes from object order by identity_sha256"
    ))
    if len(exclusions) != 504 or len(quarantines) != 3 or len(rows) != 7040:
        raise RuntimeError("issue-524 ledger cohort drift")
    connection.executemany("insert or ignore into exclusion values(?,?,?)", exclusions)
    connection.executemany("insert or ignore into quarantined_readout values(?,?,?,?)", quarantines)
    for row in rows:
        connection.execute(
            "insert or ignore into sim_row values(?,524,0,?,?,?,?,?,?,?)", row
        )
    CACHE.mkdir(parents=True, exist_ok=True)
    for identity, kind, sha, relative, size in objects:
        source_path = AUTHORITY / relative
        target = CACHE / sha
        if not target.exists():
            shutil.copy2(source_path, target)
        if target.stat().st_size != size or file_sha256(target) != sha:
            raise RuntimeError(f"cache import drift: {sha}")
        connection.execute(
            "insert or ignore into object values(?,524,?,?,?,?)",
            (identity, kind, sha, str(target.relative_to(ROOT)), size),
        )
    connection.commit()
    return {
        "reusedRows": len(rows),
        "reusedObjects": len(objects),
        "excludedIdentities": len(exclusions),
        "quarantinedReadouts": len(quarantines),
        "newRows": 0,
    }


def register_authorities(connection: sqlite3.Connection, freeze: dict) -> None:
    upstream = json.loads(
        (AUTHORITY / "artifacts/authority-and-source-freeze-v1.json").read_text()
    )["verifiedAuthorities"]
    for name, sha in upstream.items():
        authority_path = Path(name)
        issue = next((value for value in (514, 517, 519, 520, 521)
                      if f"glassvow-{value}" in name or f"-{value}/" in name), 0)
        connection.execute(
            "insert or ignore into authority values(?,?,?,?,?)",
            (name, issue, "upstream-authority", sha, authority_path.stat().st_size),
        )
    for relative, sha in KEY_ARCHIVE_HASHES.items():
        authority_path = AUTHORITY / relative
        connection.execute(
            "insert or ignore into authority values(?,?,?,?,?)",
            (str(authority_path), 524, "issue-524-evidence", sha, authority_path.stat().st_size),
        )
    for authority_path, role in (
        (SOURCE / "content/full-content.json", "live-content"),
        (SOURCE / "tools/balance_sim.gd", "base-simulator"),
        (ROOT / "tools/mechanism_probe.gd", "research-probe"),
    ):
        connection.execute(
            "insert or ignore into authority values(?,?,?,?,?)",
            (str(authority_path), 525, role, file_sha256(authority_path), authority_path.stat().st_size),
        )
    connection.commit()


def policy_split() -> dict:
    cohort = json.loads(POLICY_COHORT.read_text())
    ordered = sorted(cohort["members"], key=lambda row: row["semanticSha256"])
    if len(ordered) != 16:
        raise RuntimeError("policy cohort drift")
    policy_rows = [json.loads(line) for line in POLICIES.read_text().splitlines() if line]
    ids = {row["id"] for row in policy_rows}
    if {row["simId"] for row in ordered} - ids:
        raise RuntimeError("policy authority is missing a cohort member")
    compact = lambda row: {
        "id": row["simId"],
        "semanticSha256": row["semanticSha256"],
        "authoritySha256": row["authoritySha256"],
    }
    return {
        "authorityPath": str(POLICIES),
        "authoritySha256": file_sha256(POLICIES),
        "selectionAuthoritySha256": file_sha256(POLICY_COHORT),
        "discovery": [compact(row) for index, row in enumerate(ordered) if index % 2 == 0],
        "validation": [compact(row) for index, row in enumerate(ordered) if index % 2 == 1],
        "controls": sorted(value for value in ids if "random" in value),
    }


def phase_a_diagnosis() -> tuple[dict, dict]:
    gate = json.loads((AUTHORITY / "artifacts/stage-b-mechanism-package-gate-v1.json").read_text())
    graph = json.loads((AUTHORITY / "artifacts/authored-mechanism-graph-v1.json").read_text())
    promoted = set(gate["microdecks"]["promotedEdgeAspects"])
    hypotheses = {row["package"]: [] for row in graph["testedHypotheses"]}
    for row in graph["testedHypotheses"]:
        hypotheses[row["package"]].append(row)
    matrix = []
    for package_id, package in sorted(gate["packages"].items()):
        for aspect, result in sorted(package["aspects"].items()):
            held = result["heldOut"]
            edge_ids = [row["id"] for row in hypotheses[package_id]]
            promoted_count = sum(
                f"{package_id}|{edge_id}|{aspect}" in promoted for edge_id in edge_ids
            )
            reach = package["reachability"]
            categories = []
            if promoted_count < len(edge_ids):
                categories.append("insufficient within-package complementarity")
            if promoted_count == 1:
                categories.append("missing payoff or prerequisite")
            if promoted_count == 0:
                categories.append("unsupported package definition")
            if not result["reachabilityPass"]:
                categories.append("poor reward/economy reachability")
                if reach["minimumCardAcquisitionProbability"] < 0.05:
                    categories.append("excessive cost or rarity")
            if not held["panelPass"]:
                categories.append("weak activation")
            if held["turnReductionFraction"] < 0:
                categories.append("combat-duration regression")
            if package_id == "strength-multihit":
                categories.append("generic utility instead of route specificity")
            non_identifiable = []
            if "relic offer mediation was not instrumented" in reach["failClosedReason"]:
                non_identifiable.append("real relic offer/acquisition reachability")
            matrix.append({
                "package": package_id,
                "aspect": aspect,
                "admitted": result["pass"],
                "promotedWithinPackageEdges": promoted_count,
                "requiredWithinPackageEdges": len(edge_ids),
                "heldOutActivationStandardisedDelta": held["activation"]["standardisedDelta"],
                "heldOutActivationBootstrapP05": held["activation"]["pairedBootstrapP05"],
                "heldOutTurnReductionFraction": held["turnReductionFraction"],
                "heldOutWinDelta": held["win"]["delta"],
                "heldOutStallDelta": held["stall"]["delta"],
                "minimumOfferProbability": reach["minimumCardOfferProbability"],
                "minimumAcquisitionProbability": reach["minimumCardAcquisitionProbability"],
                "categories": sorted(set(categories)),
                "nonIdentifiable": non_identifiable,
                "policySensitivityWitness": "required in Phase C",
                "globalPowerAndRandomBuild": "not identified by the issue-524 package panel; fail closed in Phase C",
                "action": PACKAGE_ACTIONS[package_id],
            })
    matrix_artifact = {
        "schemaVersion": 1,
        "issue": 525,
        "sourceIssue": 524,
        "newSimulatorRows": 0,
        "oldRouteLabelsUsedAsGroundTruth": [],
        "rows": matrix,
    }

    node_map = {row["id"]: row for row in graph["nodes"]}
    edge_rows = []
    for identity in sorted(promoted):
        package_id, edge_id, aspect = identity.split("|")
        hypothesis = next(row for row in hypotheses[package_id] if row["id"] == edge_id)
        producer = node_map[hypothesis["producer"]]
        consumer = node_map[hypothesis["consumer"]]
        checks = {
            split: gate["microdecks"]["checks"][f"{identity}|{split}"]
            for split in ("discovery", "heldOut")
        }
        edge_rows.append({
            "identity": identity,
            "package": package_id,
            "aspect": aspect,
            "producer": hypothesis["producer"],
            "consumer": hypothesis["consumer"],
            "resourceOrTrigger": hypothesis["probe"],
            "response": hypothesis["response"],
            "producerProduces": producer["produces"],
            "consumerConsumes": consumer["consumes"],
            "producerAcquisition": producer["rewardReachability"],
            "consumerAcquisition": consumer["rewardReachability"],
            "legalContexts": ["controlled legal state", "matched micro-deck", "paired short combat panel"],
            "measuredBoundary": {
                split: {
                    "pairs": checks[split]["pairs"],
                    "standardisedDelta": checks[split]["standardisedDelta"],
                    "pairedBootstrapP05": checks[split]["pairedBootstrapP05"],
                    "ridgeSign": math.copysign(1, checks[split]["ridgeInteractionCoefficient"]),
                    "extraTreesSign": math.copysign(1, checks[split]["extraTreesFanovaInteraction"]),
                } for split in checks
            },
            "claimBoundary": "local context-indexed interaction only; not a route or global DAG",
        })
    edge_artifact = {
        "schemaVersion": 1,
        "issue": 525,
        "sourceIssue": 524,
        "newSimulatorRows": 0,
        "edgeCount": len(edge_rows),
        "edges": edge_rows,
    }
    return matrix_artifact, edge_artifact


def design_grammar() -> dict:
    return {
        "schemaVersion": 1,
        "issue": 525,
        "generation": "deterministic Sobol/QMC over finite conditional families",
        "complexityTieBreak": "fewest changed fields, then smallest normalised L1 distance, then candidate SHA-256",
        "families": [
            {
                "id": "ash-poison-catalyst-l1",
                "aspect": "ashwarden",
                "level": 1,
                "priorEdges": ["ash-poison-catalyst|venomStrike->catalyst|ashwarden"],
                "parameters": {
                    "/cards/toxicMist/effects/0/n": [3, 4, 5, 6],
                    "/cards/toxicMist/up/effects/0/n": [5, 6, 7, 8],
                    "/cards/catalyst/cost": [0, 1],
                    "/cards/catalyst/effects/0/n": [2, 3],
                    "/cards/catalyst/up/effects/0/n": [3, 4],
                    "/cards/toxicMist/rarity": ["common", "uncommon"],
                    "/cards/catalyst/rarity": ["uncommon", "rare"],
                },
                "constraints": ["upgrade values are no weaker than base", "finite valid catalogue"],
            },
            {
                "id": "ward-double-l1",
                "aspect": "duskblade",
                "level": 1,
                "priorEdges": [
                    "ward-double|brace->fortify|duskblade",
                    "ward-double|bulwark->fortify|duskblade",
                ],
                "parameters": {
                    "/cards/brace/effects/0/n": [8, 10, 12],
                    "/cards/brace/up/effects/0/n": [11, 14, 17],
                    "/cards/bulwark/cost": [1, 2],
                    "/cards/bulwark/effects/0/n": [13, 16, 20],
                    "/cards/bulwark/up/effects/0/n": [18, 22, 26],
                    "/cards/fortify/cost": [1, 2],
                    "/cards/fortify/rarity": ["common", "uncommon"],
                },
                "constraints": ["upgrade values are no weaker than base", "Fortify remains deterministic"],
            },
            {
                "id": "dusk-kindle-draw-l1",
                "aspect": "duskblade",
                "level": 1,
                "priorEdges": ["kindle-draw|offering->verdantBranch|duskblade"],
                "parameters": {
                    "/cards/firstSpark/effects/0/n": [1, 2, 3],
                    "/cards/firstSpark/up/effects/0/n": [2, 3, 4],
                    "/cards/offering/cost": [0, 1],
                    "/cards/offering/effects/0/draw": [3, 4, 5],
                    "/cards/offering/up/effects/0/draw": [4, 5, 6],
                    "/cards/offering/rarity": ["uncommon", "rare"],
                    "/relics/verdantBranch/rarity": ["uncommon", "rare"],
                },
                "constraints": ["upgrade draw is no weaker than base", "outer RNG contract unchanged"],
            },
            {
                "id": "hand-size-payoff-positive-control",
                "aspect": "ashwarden",
                "level": 0,
                "parameters": {},
                "frozenAdmission": "issue-524 held-out package admission; must reproduce before detector work",
            },
        ],
        "level2": {
            "rule": "At most one smallest new card or relic per failed family, using existing effects only, after level-1 held-out failure.",
            "maximumNewDefinitionsPerFamily": 1,
        },
        "level3": {
            "rule": "At most one minimal deterministic effect primitive after an explicit level-1 and level-2 expressibility failure.",
            "identityRule": "A new patch hash creates a disjoint simulator identity namespace; no earlier row is treated as equivalent.",
        },
        "antiGenericUtility": {
            "broadRandomBuildWinDeltaMaximum": 0.03,
            "unrelatedPackageStandardisedInteractionMaximum": 0.10,
            "activationSetJaccardMaximum": 0.50,
        },
    }


def preregistration(freeze: dict, policies: dict, grammar_sha256: str) -> dict:
    z_alpha = 1.959963984540054
    z_power = 0.8416212335729143
    required_pairs = math.ceil(((z_alpha + z_power) / 0.25) ** 2)
    return {
        "schemaVersion": 1,
        "issue": 525,
        "registeredAtUtc": REGISTERED_AT_UTC,
        "architecture": {
            "owner": "one continuous GPT Sol Max local session at Max effort",
            "host": "Apple M1 Max 64 GB arm64",
            "researchRoot": str(ROOT),
            "sourceMode": "one detached worktree",
            "forbidden": [
                "subagents", "second synthesis session", "M4 or cloud compute",
                "human labels or calibration", "acceptance seeds 3000-5199",
                "reserve seeds 5200-5399", "research or product pull requests",
                "GitHub Actions", "product-wide CI", "child issues",
                "LLM calls inside candidate, interaction, policy, seed-block, batch or generation loops",
            ],
        },
        "identities": {
            **freeze,
            "cleanDetachedPatchSha256": EMPTY_PATCH_SHA256,
            "authorisedLaterRewardPatchSha256":
                "4b09ca50124b573883902fd644c6cfd8e4ea3540ff1b276f83c43781b3a95dc1",
            "designGrammarSha256": grammar_sha256,
            "policyAuthoritySha256": policies["authoritySha256"],
            "policySelectionAuthoritySha256": policies["selectionAuthoritySha256"],
        },
        "cohorts": {"policies": policies, "seeds": SEED_FAMILIES},
        "exclusions": {
            "issue519ResumeDriftIdentities": 504,
            "issue521QuarantinedReadouts": [
                "aspectIdentityCrossEventCount",
                "reusedIssue520BaselineIdentityComparison",
                "vow5IdentityComparison",
            ],
            "rule": "Excluded and quarantined identities cannot enter generation, selection, fitting, thresholds or confirmatory inference.",
        },
        "estimands": {
            "edgeComplementarity": "paired A/B/AB difference-in-differences under common random numbers",
            "packageActivation": "paired package-minus-baseline mechanism activation divided by pooled predeclared scale",
            "reachability": "offer, pick, accept, acquisition and activation probability on real source-specific paths",
            "behaviouralSeparation": "activation-set Jaccard plus held-out functional policy-response distance",
            "nuisance": ["global win mean", "RandomBuild response", "turns", "stalls", "errors", "unrelated activation"],
        },
        "practicalTargets": {
            "positiveComplementarityStandardised": 0.25,
            "activationStandardised": 0.25,
            "activationSetJaccardMaximum": 0.50,
            "realEconomyProbabilityMinimum": 0.05,
            "additionalStallsOrErrors": 0,
            "materialDurationRegressionTurns": 1.0,
            "broadRandomBuildWinDeltaMaximum": 0.03,
            "globalPowerWinDeltaMaximum": 0.03,
        },
        "precisionAndPower": {
            "alphaTwoSided": 0.05,
            "power": 0.80,
            "targetPairedStandardisedEffect": 0.25,
            "normalApproximationRequiredPairs": required_pairs,
            "microdeckPlan": "4 legal contexts x 32 common seeds = 128 paired contrasts per promoted edge",
            "fullRunPlan": "8 policies x 32 seeds = 256 paired rows per split/aspect before vows are pooled",
            "binaryReachability": "512 validation policy-seed-vow opportunities; exact interval reported and lower bound must exceed zero, point estimate at least 0.05",
        },
        "budgets": {
            "phaseA": {"controlledOrQueryRows": 2048, "wholeRunRows": 0, "wallMinutes": 45},
            "phaseC": {"controlledMicrodeckShortPanelRows": 40000, "fullRunRows": 12288, "wallHours": 10},
            "phaseD": {"partialOrShortRows": 16384, "fullRunRows": 24576, "wallHours": 16},
            "phaseE": {"rewardFamilyFullRunRows": 12288, "jointCodesignFullRunRows": 24576, "wallHours": 20},
            "initialWholeRunCeiling": 73728,
            "conditionalWholeRunExtensionCeiling": 98304,
            "modelContextBytesPerDecisionBoundary": 65536,
        },
        "methodRace": {
            "first": "scrambled Sobol/QMC plus transparent random baseline",
            "second": "TPE and ExtraTrees only if held-out recommendation quality beats baseline at matched cost",
            "highDimension": "TuRBO/SAASBO unavailable and not run unless measured dimension and held-out residual value justify one installed implementation",
            "qualityDiversity": "MAP-Elites/CMA-ME only after unresolved objective is several orthogonal viable packages",
            "continuation": ["held-out package improvement", "recommendation quality", "unique orthogonal package", "positive measured value of information"],
        },
        "stageGates": {
            "phaseA": "Every rejected package has an actionable cause or an explicit instrumentation-bounded non-identifiability; no route inferred from one edge.",
            "phaseC": "At least two independently validated packages per aspect including hand-size-payoff or an improvement; every issue-525 package-admission clause passes.",
            "phaseD": "All seven matched mutations and every detector admission threshold pass on independent policies and seeds.",
            "phaseE": "Sequential reward comparison and joint search continue only after detector admission; legacy wins ties.",
        },
        "outcomes": {
            "success": "one fully simulated product candidate or one validated detector implementation contract",
            "rejection": "candidate/family stops when its mediator fails, held-out uncertainty rules out target, or a matched-cost family dominates",
            "escalation": "level 1 values/cost/rarity/coupling, then one smallest new card/relic, then one minimal primitive after explicit expressibility failure",
            "inconclusive": "precision budget cannot resolve a material boundary; use the one pre-authorised extension only if value of information exceeds cost",
            "terminalStop": [
                "binding product-invariant contradiction",
                "unimplementable deterministic mechanism under runtime/RNG/content contracts",
                "all scalar, structural-card/relic and minimal-primitive families exhausted with sufficient held-out precision ruling out target",
            ],
        },
        "promotion": {
            "maximumOutputs": 1,
            "productCandidate": "minimal deterministic runtime/schema/content changes, exact values, en and zh-Hant hydration, identity proof, detector/repertoire/retention/guardrail evidence and one replay manifest",
            "detectorContract": "exact implementation and thresholds, mutation/probe protocol, calibration/uncertainty and exact #421 integration instructions",
            "issue421Rule": "remain open and unassigned until a validated handoff; no final P9 exam or protected seeds before then",
        },
    }


def bootstrap() -> dict:
    freeze = verify_authorities()
    connection = open_ledger()
    imported = import_prior_evidence(connection)
    register_authorities(connection, freeze)
    failure_matrix, edge_map = phase_a_diagnosis()
    write_json_once(ARTIFACTS / "phase-a-failure-matrix-v1.json", failure_matrix)
    write_json_once(ARTIFACTS / "phase-a-local-edge-map-v1.json", edge_map)
    grammar = design_grammar()
    grammar_path = ARTIFACTS / "design-grammar-v1.json"
    write_json_once(grammar_path, grammar)
    policies = policy_split()
    prereg = preregistration(freeze, policies, file_sha256(grammar_path))
    write_json_once(PREREGISTRATION, prereg)
    freeze_artifact = {
        "schemaVersion": 1,
        "issue": 525,
        "authority": freeze,
        "ledgerImport": imported,
        "preregistrationSha256": file_sha256(PREREGISTRATION),
        "failureMatrixSha256": file_sha256(ARTIFACTS / "phase-a-failure-matrix-v1.json"),
        "localEdgeMapSha256": file_sha256(ARTIFACTS / "phase-a-local-edge-map-v1.json"),
        "designGrammarSha256": file_sha256(grammar_path),
        "bootstrapProgramSha256": file_sha256(Path(__file__)),
        "newSimulatorRows": 0,
    }
    write_json_once(ARTIFACTS / "authority-and-preregistration-freeze-v1.json", freeze_artifact)
    record(connection, "bootstrap-complete", freeze_artifact)
    connection.execute("pragma wal_checkpoint(truncate)").fetchall()
    integrity = connection.execute("pragma integrity_check").fetchone()[0]
    counts = dict(connection.execute(
        "select fidelity,count(*) from sim_row group by fidelity order by fidelity"
    ))
    if integrity != "ok" or sum(counts.values()) != 7040:
        raise RuntimeError("bootstrap ledger integrity failure")
    return {
        "decision": "PROCEED_TO_PHASE_C_PACKAGE_SYNTHESIS",
        "authorityFailures": 0,
        "archiveManifestFailures": 0,
        "reusedRows": imported["reusedRows"],
        "newRows": 0,
        "failureMatrixRows": len(failure_matrix["rows"]),
        "localEdges": edge_map["edgeCount"],
        "preregistrationSha256": file_sha256(PREREGISTRATION),
        "designGrammarSha256": file_sha256(grammar_path),
        "ledgerRowsByFidelity": counts,
    }


def verify() -> dict:
    freeze = verify_authorities()
    connection = open_ledger()
    if connection.execute("pragma integrity_check").fetchone()[0] != "ok":
        raise RuntimeError("ledger integrity failure")
    new_rows = connection.execute("select count(*) from sim_row where is_new=1").fetchone()[0]
    reused_rows = connection.execute("select count(*) from sim_row where is_new=0").fetchone()[0]
    duplicates = connection.execute(
        "select count(*)-count(distinct identity_sha256) from sim_row"
    ).fetchone()[0]
    if reused_rows != 7040 or duplicates != 0:
        raise RuntimeError("ledger cohort drift")
    for required in (
        PREREGISTRATION,
        ARTIFACTS / "phase-a-failure-matrix-v1.json",
        ARTIFACTS / "phase-a-local-edge-map-v1.json",
        ARTIFACTS / "design-grammar-v1.json",
        ARTIFACTS / "authority-and-preregistration-freeze-v1.json",
    ):
        if not required.is_file():
            raise RuntimeError(f"missing immutable bootstrap artefact: {required}")
    return {
        "status": "PASS",
        "sourceCommit": freeze["sourceCommit"],
        "reusedRows": reused_rows,
        "newRows": new_rows,
        "duplicateIdentities": duplicates,
        "preregistrationSha256": file_sha256(PREREGISTRATION),
    }


def self_check() -> dict:
    if digest(["a", "b"]) != "0473ef2dc0d324ab659d3580c1134e9d812035905c4781fdd6d529b0c6860e13":
        raise RuntimeError("canonical digest self-check failed")
    all_seeds = [seed for values in SEED_FAMILIES.values() for seed in values]
    if len(all_seeds) != len(set(all_seeds)) or any(3000 <= seed <= 5399 for seed in all_seeds):
        raise RuntimeError("research seed collision")
    if math.ceil(((1.959963984540054 + 0.8416212335729143) / 0.25) ** 2) != 126:
        raise RuntimeError("power calculation self-check failed")
    return {"status": "PASS", "seedCount": len(all_seeds), "requiredPairs": 126}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("bootstrap", "verify", "self-check"))
    args = parser.parse_args()
    result = {"bootstrap": bootstrap, "verify": verify, "self-check": self_check}[args.command]()
    print(canonical(result))


if __name__ == "__main__":
    main()
