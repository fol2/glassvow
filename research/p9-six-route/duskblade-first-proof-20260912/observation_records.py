"""Per-effective-root reductions of pinned typed native/extractor observations.

Native legality/MEC meaning is verified by the runner's authenticated extraction
and guardrail receipts, not simulated here. References below must resolve into
those exact export bytes. Supplied counts/predictions are optional cross-checks.
"""
from __future__ import annotations

import reference_kernel as kernel
import frozen_models as models
from primitive_reduction import paired
from evidence_boundary import BoundaryError, obj, integer, text
from record_io import ARMS, STRATA, PACKAGES, PAIRS, reference, child, bit, array, crosscheck


class InsufficientSupport(BoundaryError):
    pass


def label(native):
    native = obj(native, "native immediate check")
    eligible, payoff = bit(native.get("eligible")), bit(native.get("payoff"))
    if payoff > eligible:
        raise BoundaryError("payoff_without_eligible_consumer")
    if not eligible and native.get("unavailable_tail") != "UNKNOWN":
        raise BoundaryError("illegal_prefix_tail_not_unknown")
    return eligible * payoff


def acquired(snapshot, definition):
    snapshot = obj(snapshot, "native acquisition snapshot")
    components = snapshot.get("components")
    if not isinstance(components, list) or any(not isinstance(x, str) for x in components):
        raise BoundaryError("snapshot_components")
    resources = obj(snapshot.get("resources"), "native resources")
    for quantity in resources.values():
        integer(quantity, "native resource quantity")
    if not set(definition["resources"]) <= set(resources):
        raise BoundaryError("missing_native_resource_observation")
    return int(set(definition["components"]) <= set(components) and all(
        resources[name] >= minimum for name, minimum in definition["resources"].items()))


def normalize(row, root, row_ref, definitions, oracle_digest):
    row = obj(row, "native trajectory")
    if kernel.effective_seed(row.get("root")) != root:
        raise BoundaryError("native_root_mismatch")
    terminal = obj(row.get("terminal"), "terminal observation")
    if terminal.get("kind") != "ordinary" or terminal.get("outcome") not in ("win", "loss"):
        raise BoundaryError("missing_or_invalid_terminal")
    terminal_sequence = integer(terminal.get("sequence"), "terminal sequence")
    snapshots = row.get("snapshots")
    if not isinstance(snapshots, list):
        raise BoundaryError("snapshot_schema")
    snapshot_sequences = [integer(obj(s, "snapshot").get("sequence"), "snapshot sequence") for s in snapshots]
    if snapshot_sequences != sorted(set(snapshot_sequences)) or any(x >= terminal_sequence for x in snapshot_sequences):
        raise BoundaryError("snapshot_order")
    decisions = obj(row.get("decisions"), "all route memberships")
    if set(decisions) != {"K1", "K2", "K3"}:
        raise BoundaryError("missing_route_membership")
    out = {"root": root, "ref": row_ref, "win": int(terminal["outcome"] == "win"),
           "fingerprint": obj(row.get("public_fingerprint"), "public fingerprint"), "routes": {}}
    for k in PACKAGES:
        name, definition = f"K{k}", definitions[f"K{k}"]
        acquisitions = [i for i, s in enumerate(snapshots) if acquired(s, definition)]
        route_decisions = decisions[name]
        if not isinstance(route_decisions, list):
            raise BoundaryError("decision_list")
        first_enact, first_negative, previous = None, None, -1
        for i, decision in enumerate(route_decisions):
            decision = obj(decision, "decision observation")
            sequence = integer(decision.get("sequence"), "decision sequence")
            if not previous < sequence < terminal_sequence:
                raise BoundaryError("decision_order")
            previous = sequence
            native = obj(decision.get("native"), "native chain reader")
            if native.get("reader_sha256") != oracle_digest:
                raise BoundaryError("native_reader_identity")
            immediate = label(native)
            complete = bit(native.get("chain_complete"), "complete chain")
            views = obj(decision.get("views"), "native decision views")
            if definition["full_mask"] not in views:
                raise BoundaryError("missing_full_view")
            if complete:
                snapshot_index = integer(decision.get("snapshot_index"), "acquisition reference")
                if snapshot_index not in acquisitions or snapshots[snapshot_index]["sequence"] >= sequence:
                    raise BoundaryError("enactment_without_acquisition")
                if not immediate:
                    raise BoundaryError("complete_chain_without_payoff")
                if first_enact is None:
                    first_enact = i
            if not native["eligible"] and first_negative is None:
                first_negative = i
            for mask, view in views.items():
                view = obj(view, "native view")
                if mask not in definition["masks"] or view.get("mask") != mask:
                    raise BoundaryError("unregistered_native_mask")
                if (kernel.effective_seed(view.get("root")), view.get("sequence"), view.get("package")) != (root, sequence, name):
                    raise BoundaryError("view_origin")
                if type(view["root"]) is not int or type(view["sequence"]) is not int:
                    raise BoundaryError("view_origin")
                if view.get("reader_sha256") != oracle_digest:
                    raise BoundaryError("native_reader_identity")
                obj(view.get("public"), "public preconsumer state")
                label(obj(view.get("native"), "native view label"))
            if label(views[definition["full_mask"]]["native"]) != immediate:
                raise BoundaryError("full_view_native_disagreement")
        out["routes"][name] = {"acquire": int(bool(acquisitions)), "enact": int(first_enact is not None),
                               "first_enact": first_enact, "first_negative": first_negative,
                               "decisions": route_decisions}
    return out


def normalize_factual(records, expected):
    normalized, source_refs = {}, {}
    definitions = records["features"]["packages"]
    for panel, vow in STRATA:
        fac = records["factual"][(panel, vow)]
        key = f"{panel}/v{vow}"
        refs = obj(fac.get("trajectories"), "factual native references")
        if set(refs) != set(ARMS):
            raise BoundaryError("factual_arm_set")
        for arm in ARMS:
            ref = refs[arm]
            # One exact export role per stratum. Its header binds all five legs.
            if ref != {"role": f"native_export/{key}", "path": ["arms", arm]}:
                raise BoundaryError("native_export_reference")
            export = obj(records["documents"][ref["role"]], "native export")
            checks = {"schema": "D547-NATIVE-EXPORT-2", "panel": panel, "vow": vow,
                      "producer_sha256": expected["roles"]["extractor_source"]["sha256"],
                      "product": records["identities"]["product"],
                      "profile": records["identities"]["profile"][str(vow)],
                      "native_oracle": records["identities"]["native_oracle"],
                      "policies": records["identities"]["policies"][panel]}
            if any(export.get(field) != value for field, value in checks.items()):
                raise BoundaryError("native_export_identity")
            rows = array(reference(records["documents"], ref), kernel.N, "native_row_completeness")
            normalized[(panel, vow, arm)] = [normalize(row, kernel.effective_seed(root), child(ref, i),
                definitions, records["identities"]["native_oracle"]) for i, (root, row) in enumerate(zip(fac["roots"], rows))]
            source_refs[(panel, vow, arm)] = ref
    return normalized, source_refs


def prediction(model, view):
    return models.predict(model, models.features(view["public"], model["features"]))


def _cached_bits(record, actual):
    if "bits" not in record:
        return
    bits = obj(record["bits"], "optional derived bits")
    if not set(bits) <= set(actual):
        raise BoundaryError("undeclared_derived_bits")
    for key, wanted in actual.items():
        crosscheck(bits, key, wanted)


def measurement(records, key, k, rows, fitted):
    panel, vow = key
    document = records["measurement"][(panel, vow, k)]
    prefix = f"{panel}/v{vow}/K{k}"
    order = records["sampler"]["measurement_orders"][prefix]
    by_root = {row["root"]: row for row in rows}
    order = [kernel.effective_seed(root) for root in order]
    route_name = f"K{k}"
    selected = [root for root in order if by_root[root]["routes"][route_name]["enact"]][:kernel.N_MEAS]
    negatives = [root for root in order if by_root[root]["routes"][route_name]["first_negative"] is not None][:kernel.N_MEAS]
    if min(len(selected), len(negatives)) < kernel.N_MEAS:
        raise InsufficientSupport("insufficient_measurement_roots:" + prefix)
    if ([kernel.effective_seed(x) for x in array(document.get("roots"), kernel.N_MEAS, "measurement roots")] != selected or
            [kernel.effective_seed(x) for x in array(document.get("natural_roots"), kernel.N_MEAS, "natural roots")] != negatives):
        raise BoundaryError("measurement_selection")
    cases = array(document.get("cases"), kernel.N_MEAS, "measurement_case_size")
    natural_cases = array(document.get("natural_cases"), kernel.N_MEAS, "natural_case_size")
    definition = records["features"]["packages"][route_name]
    model = fitted[f"{panel}/v{vow}"][route_name]
    on, off, natural, blind_on, blind_off = [], [], [], [], []
    for root, case in zip(selected, cases):
        case = obj(case, "paired measurement case")
        row = by_root[root]
        i = row["routes"][route_name]["first_enact"]
        base = child(row["ref"], "decisions", route_name, i, "views")
        masks = obj(case.get("views"), "registered native masks")
        if set(masks) != set(definition["masks"]) or kernel.effective_seed(case.get("root")) != root:
            raise BoundaryError("measurement_mask_set")
        views = {}
        for mask in definition["masks"]:
            if masks[mask] != child(base, mask):
                raise BoundaryError("measurement_native_reference")
            views[mask] = obj(reference(records["documents"], masks[mask]), "resolved native view")
        full, disabled = views[definition["full_mask"]], views[definition["disabled_mask"]]
        if label(full["native"]) != 1 or label(disabled["native"]) != 0:
            raise BoundaryError("invalid_manipulation_ground_truth")
        on.append(prediction(model["full"], full))
        off.append(prediction(model["full"], disabled))
        blind_on.append(prediction(model["blind"], full))
        blind_off.append(prediction(model["blind"], disabled))
    for root, case in zip(negatives, natural_cases):
        case = obj(case, "natural-negative case")
        row = by_root[root]
        i = row["routes"][route_name]["first_negative"]
        wanted = child(row["ref"], "decisions", route_name, i, "views", definition["full_mask"])
        if kernel.effective_seed(case.get("root")) != root or case.get("view") != wanted:
            raise BoundaryError("natural_negative_reference")
        view = obj(reference(records["documents"], wanted), "natural native view")
        if label(view["native"]) != 0:
            raise BoundaryError("natural_negative_ground_truth")
        natural.append(prediction(model["full"], view))
    predictions = {"on_pred": on, "off_pred": off, "natural_pred": natural,
                   "blind_on_pred": blind_on, "blind_off_pred": blind_off}
    for name, values in predictions.items():
        crosscheck(document, name, values)
    for name, value in (("on_gt", 1), ("off_gt", 0), ("on_native", 1), ("off_native", 0)):
        crosscheck(document, name, [value] * kernel.N_MEAS)
    correct_on = [int(value == 1) for value in on]
    correct_off = [int(value == 0) for value in off]
    gain_on, loss_on = paired(correct_on, [int(value == 1) for value in blind_on])
    gain_off, loss_off = paired(correct_off, [int(value == 0) for value in blind_off])
    bits = {"on.correct": correct_on, "off.correct": correct_off,
            "natural_negative.not_negative": [int(value != 0) for value in natural],
            "blind_on.gain": gain_on, "blind_on.loss": loss_on,
            "blind_off.gain": gain_off, "blind_off.loss": loss_off}
    _cached_bits(document, bits)
    return bits, predictions


def derive(records, expected, fitted):
    normalized, source_refs = normalize_factual(records, expected)
    counts, predictions, root_checks = {}, {}, {"factual_records": 0, "paired_overlap": 0}
    for panel, vow in STRATA:
        prefix = f"{panel}/v{vow}"
        arms = {arm: normalized[(panel, vow, arm)] for arm in ARMS}
        wins = {arm: [row["win"] for row in rows] for arm, rows in arms.items()}
        gain, loss = paired(wins["R"], wins["B"])
        root_checks["paired_overlap"] += sum(g * l for g, l in zip(gain, loss))
        bits = {"B.win": wins["B"], "R_B.gain": gain, "R_B.loss": loss}
        root_checks["factual_records"] += sum(len(rows) for rows in arms.values())
        for k in PACKAGES:
            name = f"K{k}"
            acquired_bits = [row["routes"][name]["acquire"] for row in arms[name]]
            enacted = [row["routes"][name]["enact"] for row in arms[name]]
            gain, loss = paired(wins[name], wins["R"])
            root_checks["paired_overlap"] += sum(g * l for g, l in zip(gain, loss))
            for metric, values in {"acquire": acquired_bits, "enact": enacted,
                "win_enact": [w * e for w, e in zip(wins[name], enacted)],
                "K_R.gain": gain, "K_R.loss": loss}.items():
                bits[f"{name}/{metric}"] = values
            measurement_bits, predictions[f"{prefix}/{name}"] = measurement(
                records, (panel, vow), k, arms[name], fitted)
            counts.update({f"{prefix}/{name}/{metric}": sum(values) for metric, values in measurement_bits.items()})
        _cached_bits(records["factual"][(panel, vow)], bits)
        counts.update({f"{prefix}/{metric}": sum(values) for metric, values in bits.items()})
        peer = records["peer"][(panel, vow)]
        if [kernel.effective_seed(x) for x in array(peer.get("roots"), kernel.N, "peer roots")] != [row["root"] for row in arms["R"]]:
            raise BoundaryError("peer_root_order")
        if peer.get("sources") != {f"K{k}": source_refs[(panel, vow, f"K{k}")] for k in PACKAGES}:
            raise BoundaryError("peer_native_sources")
        peer_bits, peer_predictions = {}, {}
        for k, ell in PAIRS:
            pair = f"pair{k}{ell}"
            model = fitted[prefix][pair]
            for role, a, b in (("k", k, ell), ("l", ell, k)):
                predicted = [models.predict(model, models.features(row["fingerprint"], model["features"])) for row in arms[f"K{a}"]]
                peer_predictions[f"{pair}/{role}"] = predicted
                peer_bits[f"{pair}/correct_{role}"] = [int(value == a) for value in predicted]
                peer_bits[f"{pair}/exclusive_{role}"] = [row["routes"][f"K{a}"]["enact"] *
                    (1 - row["routes"][f"K{b}"]["enact"]) for row in arms[f"K{a}"]]
        crosscheck(peer, "predictions", peer_predictions)
        _cached_bits(peer, peer_bits)
        counts.update({f"{prefix}/{metric}": sum(values) for metric, values in peer_bits.items()})
        predictions[f"{prefix}/peer"] = peer_predictions
    if set(counts) != set(kernel.registry()):
        raise BoundaryError("derived_registry")
    return counts, predictions, root_checks
