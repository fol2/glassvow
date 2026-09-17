"""Linked ordinary-capture checks using the existing D547 evidence boundary.

inspect_sequence is STRUCTURAL validation, not a native replay or authentication.
evaluate_witness obtains bytes/identities only from H's host-supplied context and
calls H's unchanged boundary first. No function issues N0/P9 certificates.
"""
from __future__ import annotations
import hashlib
import importlib
import json
from pathlib import Path
import re
import sys

M = "07b5aa9dec8436132a524511d5438c510e322070"
OPERATION = "DD1-N0-RECOVERY-1"
ROOTS = tuple(range(5421600, 5421616))
REQUIRED_SOURCES = frozenset("res://" + p for p in (
    "application/main.gd", "application/save_service.gd", "domain/game.gd",
    "domain/state/run_state.gd", "domain/state/vigil_state.gd", "domain/state/combat_state.gd",
    "domain/rules/combat.gd", "domain/rules/rewards.gd", "domain/rules/quests.gd",
    "tools/balance_pilot.gd", "tools/balance_policy.gd", "tools/vow_incentives.gd",
    "tests/support/dd1_native_driver_main.gd", "tests/support/dd1_native_main_route.gd",
    "tests/support/dd1_ordinary_capture.gd", "tests/support/dd1_route_journal.gd",
    "tests/support/dd1_unit_grant.gd"))
ACTIONS = frozenset(("new_run", "apply", "store_run", "store_vigil", "clear_run",
    "combat_result", "resume_encounter", "terminal_commit", "dawn_advance", "dawn_finish",
    "pilot_play_turn", "reward_policy", "reward_claim", "reward_finished", "boss_relic_policy",
    "boss_relic_choice", "safe_node", "rest_choice", "shop_choice", "shop_remove",
    "event_choice", "event_pick", "event_story_continue", "node_policy", "node_chosen"))
COMMANDS = frozenset(("startCombat", "playCard", "endTurn", "kindleFromHand", "useArt", "usePotion"))
QUESTS = ("paleOnes", "ownShade", "usurper", "eighthOmen", "unreadablePage", "hollowLamplighter")
SUMMED = ("slain", "shatters", "kindles", "perfects", "smolderKills", "unlitVisited", "embersSpent")


class CaptureError(ValueError):
    pass


def need(value, reason):
    if not value:
        raise CaptureError(reason)


def sha(raw):
    return hashlib.sha256(raw.encode() if isinstance(raw, str) else raw).hexdigest()


def loads(raw):
    def pairs(items):
        out = {}
        for k, v in items:
            need(k not in out, "duplicate JSON key")
            out[k] = v
        return out
    def bad(_):
        raise CaptureError("nonfinite JSON")
    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_constant=bad)
    except (TypeError, ValueError, UnicodeError) as exc:
        raise CaptureError("invalid capture JSON: " + str(exc)) from exc


def obj(raw):
    value = loads(raw)
    need(isinstance(value, dict), "expected JSON object")
    return value


def integer(v, name):
    # Godot JSON may render an integral number with a decimal. Never accept bool/string.
    need(type(v) in (int, float) and v >= 0 and v == int(v), "invalid integer: " + name)
    return int(v)


def blank_vigil():
    return dict(v=2, deeds={k: 0 for k in ("runs", "wins", *SUMMED, "bestVow", "bestWaystone")},
        unlocks=[], vowUnlocked=0, lastFall=None, runsPlayed=0,
        quests={q: dict(state="dormant", progress=0, memory={}) for q in QUESTS},
        shards=[], whispers=0, news=False, receipts=dict(deeds=None, runEnd=None),
        scenesSeen=[], guidanceSkipped=False, hintsSeen=[], pendingScene=None,
        defeatEpitaphs=[], dawnLeaves=[], lineRecent=[], lineOnce=[])


def state(s):
    need(isinstance(s, dict) and isinstance(s.get("vigil"), str), "missing state/Vigil bytes")
    obj(s["vigil"])
    if s.get("run") is None:
        return None
    r = obj(s["run"])
    need(r.get("runId") == s.get("run_id") and r.get("act") == s.get("act") and
         r.get("nodeId") == s.get("node_id") and str(r.get("rngState")) == str(s.get("rng")),
         "run/RNG/map identity disagreement")
    integer(s.get("uid_next"), "UID cursor")
    need(isinstance(s.get("map"), dict), "missing live map")
    c = s.get("combat")
    if c is not None:
        need(isinstance(c, dict) and isinstance(c.get("object_id"), str) and c["object_id"], "combat identity")
        integer(c.get("queue_size"), "queue size")
        uids = []
        for zone in ("draw", "hand", "discard", "exhaust"):
            need(isinstance(c.get(zone), list), "missing UID zone:" + zone)
            for card in c[zone]:
                need(isinstance(card, dict), "invalid card record")
                uids.append(integer(card.get("uid"), "card UID"))
        need(len(uids) == len(set(uids)), "duplicate live card UID")
    return r


def journal(capture):
    need(isinstance(capture, dict) and capture.get("schema") == "DD1-ORDINARY-JOURNAL-2", "missing detailed journal")
    need(capture.get("durable") is True and capture.get("errors") == [] and
         capture.get("open_actions") == [], "incomplete or nondurable capture")
    raw = capture.get("journal_bytes")
    need(isinstance(raw, str) and raw.endswith("\n"), "missing/truncated journal bytes")
    need(len(raw.encode()) == capture.get("raw_bytes"), "journal length")
    rows, previous = [], ""
    for i, line in enumerate(raw.splitlines(keepends=True)):
        need(line.endswith("\n"), "partial journal line")
        row = obj(line)
        need(row.get("seq") == i and row.get("previous") == previous, "journal order/hash link")
        previous = sha(line[:-1])  # Exact writer bytes, never Python-reserialised hashes.
        rows.append(row)
    need(rows == capture.get("rows") and previous == capture.get("last_link"), "journal raw/summary mismatch")
    need(len(rows) >= 4 and rows[0].get("phase") == "header" and rows[-1].get("phase") == "footer",
         "missing journal endpoints")
    need(rows[-1].get("complete") is True and rows[-1].get("reason") == "", "incomplete footer")
    stack, pairs, last_root = [], [], None
    for row in rows[1:-1]:
        phase = row.get("phase")
        state(row.get("state"))
        if phase == "begin":
            need(row.get("token") == row["seq"] and row.get("action") in ACTIONS, "opaque/unknown command or token")
            need(row.get("parent") == (stack[-1]["token"] if stack else -1), "action parent")
            if not stack and last_root is not None:
                need(row["state"] == last_root, "unobserved change between actions")
            need(isinstance(row.get("inputs"), dict), "missing action inputs")
            stack.append(row)
        elif phase == "end":
            need(stack and row.get("token") == stack[-1]["token"], "unbalanced action")
            begin = stack.pop()
            need(isinstance(row.get("observed"), dict), "missing native observations")
            pairs.append((begin, row))
            if not stack:
                last_root = row["state"]
        else:
            raise CaptureError("unexpected interior journal phase")
    need(not stack, "unclosed action")
    return rows, sorted(pairs, key=lambda p: p[0]["seq"])


def inspect_route(row, expected_sources, expected_pilot):
    need(isinstance(row, dict) and row.get("status") in ("win", "death") and
         row.get("incomplete_reason") == "", "route not a captured ordinary terminal")
    rows, actions = journal(row.get("capture"))
    header, footer = rows[0], rows[-1]
    need(row.get("commands") == rows, "command summary differs from actual journal")
    need(header.get("operation") == OPERATION and header.get("seed") == row.get("seed") and
         header.get("vow") == row.get("vow"), "procedure identity")
    need(header.get("sources") == expected_sources == row.get("sources"), "source manifest mismatch")
    need(header.get("pilot") == expected_pilot and row.get("pilot_version") == "p8-d0-v1", "Pilot identity/refit")
    for key, digest_key in (("initial_vigil", "initial_vigil_sha"), ("initial_run", "initial_run_sha"),
                            ("pre_terminal_run", "run_sha"), ("commit_vigil", "vigil_sha")):
        need(isinstance(row.get(key), str) and row[key] and sha(row[key]) == row.get(digest_key), "missing/changed bytes:" + key)
    need(header.get("initial_vigil") == row["initial_vigil"] and
         header.get("initial_vigil_sha") == row["initial_vigil_sha"], "ordinary initial bytes")
    initial, pre, committed = map(obj, (row["initial_run"], row["pre_terminal_run"], row["commit_vigil"]))
    rid = row.get("run_id")
    need(isinstance(rid, str) and rid and initial.get("runId") == pre.get("runId") == rid, "run identity splice")
    for save in (initial, pre):
        need(save.get("seed") == row["seed"] and save.get("vow") == row["vow"] and save.get("aspect") == 0 and
             save.get("v") == 2 and save.get("map", {}).get("nodes"), "constructed/unrelated run")
    need(pre.get("pendingRunEnd", {}).get("outcome") == row["status"], "terminal outcome splice")
    terminal = row.get("terminal", {})
    receipt = committed.get("receipts", {}).get("runEnd", {})
    need(receipt.get("runId") == rid and receipt.get("outcome") == row["status"], "unrelated native terminal receipt")
    need(terminal.get("receipt") == receipt and terminal.get("pre_terminal_run") == row["pre_terminal_run"] and
         terminal.get("commit_vigil") == terminal.get("final_vigil") == row["commit_vigil"] and
         terminal.get("run_cleared") is True and footer.get("terminal") == terminal, "unfinished terminal/save chain")
    saves, vigil_saves, created, handled = [], [], {}, set()
    terminal_actions, clears, applied, new_runs = [], [], 0, []
    for begin, end in actions:
        action, inputs, observed = begin["action"], begin["inputs"], end["observed"]
        before, after = begin["state"], end["state"]
        for s in (before, after):
            if s.get("run") is not None:
                need(s.get("run_id") == rid, "state from another run")
        if action == "new_run":
            new_runs.append(begin)
            need(inputs == dict(aspect=0, seed=row["seed"], vow=row["vow"]) and
                 before.get("run") is None and before["vigil"] == row["initial_vigil"] and
                 after["run"] == row["initial_run"], "unearned initial state")
        elif action in ("store_run", "store_vigil"):
            key = "run" if action == "store_run" else "vigil"
            need(observed.get("ok") is True and observed.get("bytes") == after.get(key), "failed/mismatched durable save")
            (saves if key == "run" else vigil_saves).append(observed["bytes"])
        elif action == "apply":
            applied += 1
            cmd = inputs.get("t")
            need(cmd in COMMANDS and observed.get("denied") is not True and
                 isinstance(observed.get("events"), list), "opaque/denied native command")
            cb0, cb1 = before.get("combat", {}), after.get("combat", {})
            q0 = 0 if cmd == "startCombat" else integer(cb0.get("queue_size"), "queue before")
            need(integer(cb1.get("queue_size"), "queue after") - q0 == len(observed["events"]), "command/event count splice")
            if cmd == "startCombat":
                key = (before["run_id"], before["act"], before["node_id"])
                pending = obj(before["run"])
                need(inputs.get("enemies") == pending.get("pendingEnemyIds") and inputs.get("enemies"), "encounter input splice")
                need(inputs.get("kind") == ("normal" if pending.get("pendingCombat") == "monster" else pending.get("pendingCombat")), "encounter kind")
                need(key not in created and cb1.get("object_id") != cb0.get("object_id"), "duplicate combat creation")
                created[key] = cb1["object_id"]
            else:
                need(cb0.get("object_id") == cb1.get("object_id") and cb0.get("over") is False, "command outside active combat")
                if cmd in ("playCard", "kindleFromHand"):
                    uid = integer(inputs.get("uid"), "command UID")
                    need(any(c.get("uid") == uid for c in cb0.get("hand", [])), "unavailable command UID")
                if cmd in ("playCard", "usePotion"):
                    need(observed.get("ret") is True, "failed legal action claim")
        elif action == "combat_result":
            key = (before["run_id"], before["act"], before["node_id"])
            cb = before.get("combat", {})
            need(key in created and created[key] == cb.get("object_id") and key not in handled and
                 cb.get("over") is True and inputs.get("result") == cb.get("result") and
                 loads(inputs.get("encounter")) == list(key), "stale/duplicate/misbound combat dispatch")
            handled.add(key)
        elif action == "terminal_commit":
            terminal_actions.append((begin, end))
            need(before.get("run") == row["pre_terminal_run"] and
                 observed.get("pre_terminal_run") == row["pre_terminal_run"] and
                 observed.get("commit_vigil") == row["commit_vigil"], "terminal evidence missing exact bytes")
        elif action == "clear_run":
            clears.append((begin, end))
            need(inputs.get("expected_run_id") == rid and observed.get("ok") is True and
                 isinstance(observed.get("before_bytes"), str) and
                 obj(observed["before_bytes"]).get("runId") == rid, "unidentified/failed clear")
    need(len(new_runs) == len(terminal_actions) == len(clears) == 1, "missing/repeated run/terminal/clear")
    need(actions[0][0]["action"] == "new_run" and applied > 0 and created and set(created) == handled, "incomplete action chain")
    need(row["pre_terminal_run"] in saves and row["initial_run"] in saves and row["commit_vigil"] in vigil_saves,
         "missing durable initial/preterminal/Vigil observations")
    need(row.get("starts") == footer.get("starts") == len(created) and
         row.get("combat_dispatches") == footer.get("dispatches") == len(handled), "counter not tied to identity")
    parent = next((a for a, _ in actions if a["token"] == clears[0][0]["parent"]), {})
    need(parent.get("action") == ("dawn_finish" if row["status"] == "win" else "terminal_commit"), "wrong native clear route")
    need(clears[0][0]["seq"] > terminal_actions[0][0]["seq"], "clear before terminal")
    if row["status"] == "win":
        dawn = obj(clears[0][1]["observed"]["before_bytes"]).get("pendingDawn", {})
        need(isinstance(dawn.get("events"), list) and integer(dawn.get("cursor"), "Dawn cursor") >= len(dawn["events"]),
             "unfinished Dawn cleared")
    return committed


def inspect_sequence(bundle, source_manifest):
    need(isinstance(bundle, dict) and isinstance(source_manifest, dict), "missing trace/source bundle")
    need(source_manifest.get("scientific_m") == M and source_manifest.get("operation") == OPERATION, "wrong source/procedure")
    sources, pilot = source_manifest.get("files"), source_manifest.get("pilot")
    need(isinstance(sources, dict) and REQUIRED_SOURCES <= sources.keys(), "incomplete source closure")
    need(all(isinstance(v, str) and re.fullmatch(r"[0-9a-f]{64}", v) for v in sources.values()), "bad source digest")
    need(isinstance(pilot, dict) and pilot.get("version") == "p8-d0-v1" and pilot.get("random_build") is False and
         pilot.get("random_play") is False and isinstance(pilot.get("snapshot"), dict), "unfrozen Pilot")
    traces = bundle.get("traces")
    need(isinstance(traces, list) and 0 < len(traces) <= len(ROOTS), "missing/oversized sequence")
    expected_bytes, previous, ids, first = None, blank_vigil(), set(), {}
    for i, row in enumerate(traces):
        need(row.get("seed") == ROOTS[i] and row.get("vow") == min(previous["vowUnlocked"], 4), "wrong root order/cohort/vow")
        initial = obj(row.get("initial_vigil"))
        need(initial == previous and (expected_bytes is None or row["initial_vigil"] == expected_bytes), "unearned/spliced initial Vigil")
        committed = inspect_route(row, sources, pilot)
        need(row["run_id"] not in ids, "repeated ordinary run")
        ids.add(row["run_id"])
        pre = obj(row["pre_terminal_run"])
        win = row["status"] == "win"
        need(committed.get("runsPlayed") == previous["runsPlayed"] + 1 and
             committed.get("vowUnlocked") == max(previous["vowUnlocked"], min(5, row["vow"] + 1) if win else 0),
             "unearned run count/Vow promotion")
        for key in ("runs", "wins", *SUMMED):
            delta = 1 if key == "runs" else int(win) if key == "wins" else integer(pre.get("stats", {}).get(key, 0), key)
            need(committed.get("deeds", {}).get(key) == previous["deeds"][key] + delta, "unearned terminal deeds:" + key)
        p0 = "card:resonantLance" in committed.get("unlocks", []) and committed["deeds"]["shatters"] >= 15
        if p0:
            first.setdefault("p0", i)
            if committed["vowUnlocked"] >= 5:
                first.setdefault("p5", i)
        previous, expected_bytes = committed, row["commit_vigil"]
    profiles = bundle.get("profiles", {})
    need(isinstance(profiles, dict) and set(profiles) == set(first), "missing/extra first-valid profiles")
    for name, index in first.items():
        need(profiles[name] == dict(root=traces[index]["seed"], run_bytes=traces[index]["pre_terminal_run"],
                                   vigil_bytes=traces[index]["commit_vigil"]), "unrelated/not-first profile:" + name)
    return dict(result="STRUCTURALLY_CONSISTENT_NOT_NATIVE_PROOF", roots=len(traces),
                first_profiles=first, both_profiles=set(first) == {"p0", "p5"}, n0_accepted=False)


def _load_boundary():
    # Same accepted H module, not a packet-selectable authentication callback.
    root = Path(__file__).resolve().parents[1] / "research/p9-six-route/duskblade-first-proof-20260912"
    sys.path.insert(0, str(root))
    try:
        boundary = importlib.import_module("evidence_boundary")
        if Path(boundary.__file__).resolve() != root / "evidence_boundary.py" or \
                Path(boundary.kernel.__file__).resolve() != root / "reference_kernel.py":
            raise ImportError("unexpected cached H boundary/module source")
        return boundary
    finally:
        sys.path.pop(0)


def evaluate_witness(packet, context=None):
    if context is None:
        return dict(result="BLOCKED", reason="missing H host-authenticated context", n0_accepted=False)
    try:
        boundary = _load_boundary()
        expected, _receipts = boundary.verify(packet, context)
        def role(name):
            binding = expected["roles"].get(name)
            need(isinstance(binding, dict), "missing bound role:" + name)
            return obj(context.resolve(binding["locator"]))
        report = inspect_sequence(role("preflight_trace"), role("extractor_source"))
        if not report["both_profiles"]:
            return dict(report, result="INCOMPLETE", reason="no complete captured P_0/P_5 chain")
        return dict(report, result="SYNTHETIC_ONLY" if context.kind == "synthetic" else "LINKED_PROVENANCE_VERIFIED",
                    reason="Native semantics depend on H's authenticated extraction/guardrail receipts; not N0 acceptance")
    except (ImportError, AttributeError) as exc:
        return dict(result="BLOCKED", reason="H boundary unavailable:" + str(exc), n0_accepted=False)
    except Exception as exc:
        # H MissingAuthority is BLOCKED; malformed linked content is REJECT.
        return dict(result="BLOCKED" if type(exc).__name__ == "MissingAuthority" else "REJECT",
                    reason=str(exc), n0_accepted=False)
