"""Fabricated linked records for inert falsifiers, NEVER earned/native evidence."""
from copy import deepcopy
import json
import dd1_provenance as p


def text(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


class Journal:
    def __init__(self, seed, vow, vigil, manifest):
        self.rows, self.stack = [], []
        self.s = dict(vigil=text(vigil), run=None)
        self.add(dict(phase="header", operation=p.OPERATION, seed=seed, vow=vow,
                      initial_vigil=text(vigil), initial_vigil_sha=p.sha(text(vigil)),
                      sources=manifest["files"], pilot=manifest["pilot"]))

    def add(self, row):
        row = deepcopy(row)
        row.update(seq=len(self.rows), previous=p.sha(text(self.rows[-1])) if self.rows else "")
        self.rows.append(row)

    def begin(self, action, inputs=None):
        token = len(self.rows)
        self.add(dict(phase="begin", token=token, parent=self.stack[-1] if self.stack else -1,
                      action=action, inputs=inputs or {}, state=self.s))
        self.stack.append(token)

    def end(self, observed=None):
        self.add(dict(phase="end", token=self.stack.pop(), observed=observed or {}, state=self.s))

    def run(self, r):
        self.s.update(run=text(r), run_id=r["runId"], rng=str(r["rngState"]), uid_next=2,
                      act=r["act"], node_id=r["nodeId"], map=r["map"])

    def store(self, key):
        self.begin("store_" + key)
        self.end(dict(ok=True, bytes=self.s[key]))

    def packet(self):
        return dict(schema="DD1-ORDINARY-JOURNAL-2", rows=deepcopy(self.rows), errors=[], open_actions=[],
                    durable=True, sink="synthetic:memory", raw_bytes=len(self.raw().encode()),
                    last_link=p.sha(text(self.rows[-1])), journal_bytes=self.raw())

    def raw(self):
        return "".join(text(r) + "\n" for r in self.rows)


def manifest():
    return dict(operation=p.OPERATION, scientific_m=p.M,
                files={name: p.sha("SYNTHETIC SOURCE:" + name) for name in sorted(p.REQUIRED_SOURCES)},
                pilot=dict(version="p8-d0-v1", snapshot={"synthetic": True}, random_build=False, random_play=False))


def route(seed, previous, source, combats=1):
    # Five synthetic wins build a schema fixture; they are not observations.
    vow, rid = min(previous["vowUnlocked"], 4), "SYNTHETIC-" + str(seed)
    j = Journal(seed, vow, previous, source)
    initial_vigil = text(previous)
    r = dict(v=2, seed=seed, runId=rid, rngState=10, act=0, nodeId="fixture-node", vow=vow, aspect=0,
             map={"nodes": [{"id": "fixture-node"}], "at": 0}, pendingEnemyIds=["fixture-enemy"],
             pendingCombat="monster", pendingRunEnd=None, pendingDawn=None,
             stats={key: 15 if key == "shatters" else 0 for key in p.SUMMED})
    j.begin("new_run", dict(aspect=0, vow=vow, seed=seed))
    j.run(r)
    j.store("run")
    initial_run = text(r)
    j.end()
    for combat_index in range(combats):
        if combat_index:
            j.begin("node_chosen", {"index": combat_index})
            r.update(nodeId="fixture-node-" + str(combat_index), pendingCombat="monster",
                     pendingEnemyIds=["fixture-enemy"], pendingRunEnd=None)
            j.run(r); j.store("run"); j.end({"entered": True})
        j.begin("resume_encounter")
        j.begin("apply", dict(t="startCombat", enemies=["fixture-enemy"], kind="normal"))
        cb = dict(object_id="synthetic-object-" + str(combat_index), turn=1, queue_size=1, over=False, result=None,
                  hand=[dict(uid=1, id="fixture-card", up=False)], draw=[], discard=[], exhaust=[])
        j.s["combat"] = cb
        j.end(dict(events=[{"t": "SYNTHETIC_START"}], ret=None))
        j.end()
        j.begin("pilot_play_turn")
        j.begin("apply", dict(t="playCard", uid=1, target=0))
        cb.update(over=True, result="win", queue_size=2, discard=cb["hand"], hand=[])
        j.end(dict(events=[{"t": "SYNTHETIC_WIN"}], ret=True))
        j.end()
        j.begin("combat_result", dict(encounter=text([rid, 0, r["nodeId"]]), result="win"))
        r.update(pendingCombat=None, pendingEnemyIds=None,
                 pendingRunEnd={"outcome": "win"} if combat_index == combats - 1 else None)
        j.run(r); j.store("run"); j.end()
        if combat_index < combats - 1:
            j.begin("reward_finished")
            j.store("run"); j.end()
            j.begin("safe_node", {"node_id": "safe-node", "type": "rest"})
            r["nodeId"] = "safe-node"
            j.run(r); j.store("run"); j.end({"choices": [{"choice": "heal"}]})
    pre = text(r)
    j.begin("terminal_commit", {"choice": "commit"})
    v = deepcopy(previous)
    v["runsPlayed"] += 1
    v["vowUnlocked"] = min(5, vow + 1)
    v["deeds"]["runs"] += 1
    v["deeds"]["wins"] += 1
    for key in p.SUMMED:
        v["deeds"][key] += r["stats"][key]
    v["unlocks"] = ["card:resonantLance"]
    v["receipts"] = dict(deeds=dict(runId=rid, won=True), runEnd=dict(runId=rid, outcome="win", completed=[]))
    committed = text(v)
    j.s["vigil"] = committed
    j.store("vigil")
    r.update(pendingRunEnd=None, pendingDawn=dict(events=[{"kind": "SYNTHETIC_MEMORY"}], cursor=0))
    j.run(r)
    j.store("run")
    terminal = dict(run_id=rid, outcome="win", pre_terminal_run=pre, commit_vigil=committed,
                    receipt=v["receipts"]["runEnd"], run_cleared=False, rng_final="10", map_at=0, shatters=15)
    j.end(terminal)
    j.begin("dawn_advance")
    r["pendingDawn"]["cursor"] = 1
    j.run(r)
    j.store("run")
    j.end()
    j.begin("dawn_finish")
    j.begin("clear_run", {"expected_run_id": rid})
    j.end(dict(ok=True, before_bytes=text(r)))
    j.s = dict(vigil=committed, run=None)
    j.end()
    terminal.update(run_cleared=True, final_vigil=committed)
    j.add(dict(phase="footer", complete=True, reason="", starts=combats, dispatches=combats, terminal=terminal))
    row = dict(seed=seed, vow=vow, status="win", incomplete_reason="", run_id=rid, starts=combats, combat_dispatches=combats,
               initial_vigil=initial_vigil, initial_vigil_sha=p.sha(initial_vigil), initial_run=initial_run,
               initial_run_sha=p.sha(initial_run), pre_terminal_run=pre, run_sha=p.sha(pre),
               commit_vigil=committed, vigil_sha=p.sha(committed), terminal=terminal,
               pilot_version="p8-d0-v1", sources=source["files"], capture=j.packet(), commands=deepcopy(j.rows))
    return row, v


def bundle():
    source, previous, traces = manifest(), p.blank_vigil(), []
    for seed in p.ROOTS[:5]:
        row, previous = route(seed, previous, source)
        traces.append(row)
    profiles = {name: dict(root=traces[i]["seed"], run_bytes=traces[i]["pre_terminal_run"],
                          vigil_bytes=traces[i]["commit_vigil"]) for name, i in (("p0", 0), ("p5", 4))}
    return dict(traces=traces, profiles=profiles, environment="SYNTHETIC_ONLY"), source


def repack(row):
    """Test mutations repair every hash so semantic guards, not stale hashes, fail."""
    capture, previous = row["capture"], ""
    for i, item in enumerate(capture["rows"]):
        item.update(seq=i, previous=previous)
        previous = p.sha(text(item))
    raw = "".join(text(r) + "\n" for r in capture["rows"])
    capture.update(journal_bytes=raw, raw_bytes=len(raw.encode()), last_link=previous)
    row["commands"] = deepcopy(capture["rows"])
