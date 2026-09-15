"""Pinned sampling, stage order and legal extractor-record contracts."""
from __future__ import annotations

import reference_kernel as kernel
from evidence_boundary import BoundaryError, obj, integer, text

ARMS = ("R", "B", "K1", "K2", "K3")
STRATA = tuple((p, v) for p in ("A", "B") for v in (0, 5))


def roots(values, size, reason):
    if not isinstance(values, list) or len(values) != size:
        raise BoundaryError(reason)
    effective = [kernel.effective_seed(x) for x in values]
    if len(set(effective)) != size:
        raise BoundaryError("root_duplicates")
    return effective


def producer(record, expected, schema):
    obj(record, schema)
    if (record.get("schema") != schema or
            record.get("producer_sha256") != expected["roles"]["extractor_source"]["sha256"]):
        raise BoundaryError("extractor_record_source_schema")


def validate(records, packet, expected, receipts):
    freeze, sampler = records["freeze"], records["sampler"]
    dev, exposure, features, model = (records[k] for k in ("development", "exposure", "features", "model"))
    for name, record in (("freeze", freeze), ("sampler", sampler), ("development", dev),
                         ("exposure", exposure), ("features", features), ("model", model)):
        obj(record, name)
    dates = [integer(x.get("timestamp"), "stage timestamp") for x in
             (exposure, features, dev, model, freeze, sampler)]
    if dates != sorted(dates):
        raise BoundaryError("timestamp_order")
    if receipts["freeze"]["timestamp"] < dates[-1]:
        raise BoundaryError("receipt_freeze_before_inputs")
    if freeze.get("epoch") != kernel.EPOCH or freeze.get("candidate") != expected["candidate"]:
        raise BoundaryError("freeze_epoch_candidate")
    if sampler.get("method") != "uniform-without-replacement":
        raise BoundaryError("sampler_method")
    frame = obj(sampler.get("frame"), "sampling frame")
    if frame.get("mapping") != "seed & 0xFFFFFFFF" or frame.get("domain") != [0, 2**32 - 1]:
        raise BoundaryError("sampler_frame")
    if sampler.get("draw_scope") != [f"{p}/v{v}" for p, v in STRATA]:
        raise BoundaryError("sampler_joint_draw")
    if exposure.get("status") != "COMPLETE_NAMESPACE_INDEX":
        raise BoundaryError("missing_exposure_authority")
    namespaces = obj(exposure.get("namespaces"), "exposure namespaces")
    if set(namespaces) != set(expected.get("required_namespaces", [])) or not namespaces:
        raise BoundaryError("missing_exposure_namespace")
    exposed = {kernel.effective_seed(x) for values in namespaces.values() for x in values}
    if exposed != {kernel.effective_seed(x) for x in exposure.get("exposed", [])}:
        raise BoundaryError("exposure_index_mismatch")
    protected = {kernel.effective_seed(x) for x in exposure["protected"]}
    if not set(range(3000, 5400)) <= protected:
        raise BoundaryError("protected_seeds")
    if "exposed_seeds" in packet and {kernel.effective_seed(x) for x in packet["exposed_seeds"]} != exposed:
        raise BoundaryError("exposure_claim_mismatch")
    if "protected_seeds" in packet and {kernel.effective_seed(x) for x in packet["protected_seeds"]} != protected:
        raise BoundaryError("protected_claim_mismatch")
    dev_map, manifest = obj(dev.get("roots"), "development roots"), obj(sampler.get("manifest"), "sampler manifest")
    keys = {f"{p}/v{v}" for p, v in STRATA}
    if set(dev_map) != keys or set(manifest) != keys:
        raise BoundaryError("stratum_manifest_keys")
    dev_roots = [r for key in sorted(keys) for r in roots(dev_map[key], 64, "development_size")]
    preflight_roots = roots(exposure.get("preflight_roots"), len(exposure.get("preflight_roots", [])), "preflight_roots")
    forbidden = exposed | protected | set(dev_roots) | set(preflight_roots)
    if len(dev_roots) != len(set(dev_roots)) or set(dev_roots) & (exposed | protected | set(preflight_roots)):
        raise BoundaryError("development_collision")
    if set(preflight_roots) & (exposed | protected):
        raise BoundaryError("preflight_collision")
    if {kernel.effective_seed(x) for x in sampler["forbidden"]} != forbidden:
        raise BoundaryError("sampler_exclusions")
    all_confirm = []
    for panel, vow in STRATA:
        key = f"{panel}/v{vow}"
        assigned = roots(manifest[key], kernel.N, "sampler_size")
        fac = records["factual"][(panel, vow)]
        producer(fac, expected, "D547-FACTUAL-2")
        actual = roots(fac.get("roots"), kernel.N, "factual_size")
        if actual != assigned:
            raise BoundaryError("sampler_root_order")
        crn = obj(fac.get("crn_roots"), "mandatory CRN legs")
        kernel.validate_roots(crn, exposed | set(dev_roots) | set(preflight_roots), protected)
        if any(roots(crn[a], kernel.N, "CRN size") != assigned for a in ARMS):
            raise BoundaryError("crn_mismatch")
        if set(actual) & forbidden:
            raise BoundaryError("exposed_protected_root")
        all_confirm.extend(actual)
        if any(fac.get(field) != value for field, value in {
            "freeze_id": freeze["id"], "sampler_id": sampler["id"], "frame_id": sampler["frame_id"],
            "product": packet["identities"]["product"], "profile": packet["identities"]["profile"][str(vow)],
            "control": packet["identities"]["signed_B"]}.items()):
            raise BoundaryError("factual_input_identity")
        start, finish = integer(fac.get("started_at"), "factual start"), integer(fac.get("timestamp"), "factual finish")
        if not receipts["freeze"]["timestamp"] <= start <= finish <= receipts["extraction"]["timestamp"]:
            raise BoundaryError("factual_chronology")
        for k in (1, 2, 3):
            meas = records["measurement"][(panel, vow, k)]
            producer(meas, expected, "D547-MEASUREMENT-2")
            if not finish <= integer(meas.get("timestamp"), "measurement time") <= receipts["extraction"]["timestamp"]:
                raise BoundaryError("measurement_chronology")
        peer = records["peer"][(panel, vow)]
        producer(peer, expected, "D547-PEER-2")
        if not finish <= integer(peer.get("timestamp"), "peer time") <= receipts["extraction"]["timestamp"]:
            raise BoundaryError("peer_chronology")
    if len(all_confirm) != len(set(all_confirm)):
        raise BoundaryError("root_collision")
    validate_preflight(records, expected, dates[2], preflight_roots)


def validate_preflight(records, expected, before, allowed_roots):
    preflight = records["preflight"]
    if not isinstance(preflight, list):
        raise BoundaryError("preflight_schema")
    disagreements = set()
    for row in preflight:
        producer(row, expected, "D547-PREFLIGHT-2")
        arm = row.get("arm")
        if arm not in ("R", "K1", "K2", "K3"):
            raise BoundaryError("preflight_arm")
        if kernel.effective_seed(row["root"]) not in allowed_roots:
            raise BoundaryError("preflight_root")
        if integer(row.get("timestamp"), "preflight time") > before:
            raise BoundaryError("preflight_chronology")
        state = obj(row.get("state"), "preflight state")
        state_id = text(state.get("ref"), "preflight state reference")
        obj(state.get("public"), "public preflight observation")
        actions = state.get("legal_actions")
        if not isinstance(actions, list) or not actions:
            raise BoundaryError("preflight_legal_actions")
        for action in actions:
            if set(obj(action, "legal action")) != {"command", "arguments"}:
                raise BoundaryError("legal_action_schema")
            text(action["command"], "command")
            obj(action["arguments"], "command arguments")
        for panel in ("A", "B"):
            action = obj(row.get("action_" + panel), "policy action")
            if action not in actions or row.get("policy_" + panel) != records["policies"][(panel, arm)]:
                raise BoundaryError("preflight_policy_action")
            transition = obj(row.get("transition_" + panel), "legal transition")
            if transition.get("state_ref") != state_id or transition.get("action") != action:
                raise BoundaryError("preflight_transition")
            text(transition.get("next_state_ref"), "next state")
        if row["action_A"] != row["action_B"]:
            disagreements.add(arm)
    if not {"K1", "K2", "K3"} <= disagreements:
        raise BoundaryError("panel_disagreement")
