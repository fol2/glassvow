"""D547-PC1 §8 adapter around the recovered numerical kernel.

Runner-owned trusted context supplies expected identities and a bounded
content store. Claim JSON names locators and optional summaries; it does
not choose the verifier, supply a verdict, or pass because a hash, URI
prefix, or flag is well formed. Counts are derived from resolved per-root
records. Does not issue certificates, bind #547, or start native outcomes.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os

import reference_kernel as kernel

EPOCH = kernel.EPOCH
ARMS = ("R", "B", "K1", "K2", "K3")
PANELS = ("A", "B")
VOWS = (0, 5)
PACKAGES = (1, 2, 3)
PAIRS = ((1, 2), (1, 3), (2, 3))
PROTECTED = frozenset(range(3000, 5400))
LEAK_TOKENS = (
    "win", "seed", "policy", "package", "card", "arm", "filename", "trace",
)
ROUTE_ARMS = ("R", "K1", "K2", "K3")
PACKET_VERDICT_KEYS = (
    "trusted_verifier", "source_raw_complete", "invalid_ground_truth",
    "all_abstain", "identical_traces_renamed", "full_equals_blind",
    "everything_verified", "trusted_context", "context_kind",
    "trusted_resolver",
)
STRATA = tuple((panel, vow) for panel in PANELS for vow in VOWS)


class AdapterReject(Exception):
    def __init__(self, reason):
        self.reason = reason
        super().__init__(reason)


class TrustedContext:
    """Runner-owned. Packets cannot construct or select this object."""

    def __init__(
        self,
        kind,
        expected_identities,
        expected_allocation,
        store,
        receipts=None,
        expected_authority="D547-PC1",
        synthetic_ledger_bound=False,
    ):
        if kind not in ("synthetic", "empirical"):
            raise ValueError("context kind")
        self.kind = kind
        self.expected_identities = expected_identities
        self.expected_allocation = expected_allocation
        self.store = store
        self.receipts = receipts or {}
        self.expected_authority = expected_authority
        self.synthetic_ledger_bound = bool(synthetic_ledger_bound)

    def resolve(self, locator):
        if not isinstance(locator, str) or locator not in self.store:
            return None
        value = self.store[locator]
        if not isinstance(value, (bytes, bytearray)):
            raise AdapterReject("resolver_must_return_bytes")
        return bytes(value)

    def has_required_empirical_receipts(self):
        needed = ("binding", "freeze", "independent_review")
        return all(
            isinstance(self.receipts.get(name), (bytes, bytearray))
            and len(self.receipts[name]) > 0
            for name in needed
        )

    def copy(self):
        return TrustedContext(
            kind=self.kind,
            expected_identities=copy.deepcopy(self.expected_identities),
            expected_allocation=copy.deepcopy(self.expected_allocation),
            store=dict(self.store),
            receipts=copy.deepcopy(self.receipts),
            expected_authority=self.expected_authority,
            synthetic_ledger_bound=self.synthetic_ledger_bound,
        )


def _reason_result(reason, extra=None):
    out = {
        "integrity": "REJECT",
        "reason": reason,
        "predicates": {},
        "certificate": False,
        "game_outcome_rows": 0,
        "native_invocations": 0,
    }
    if extra:
        out.update(extra)
    return out


def _blocked(reason, extra=None):
    out = _reason_result(reason, extra)
    out["integrity"] = "BLOCKED"
    return out


def _pass_result(predicates):
    return {
        "integrity": "PASS",
        "reason": "SYNTHETIC_PACKET_WELL_FORMED",
        "predicates": predicates,
        "certificate": False,
        "game_outcome_rows": 0,
        "native_invocations": 0,
        "empirical_certificate": False,
    }


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def _int_bit_list(values, n, name):
    if not isinstance(values, list) or len(values) != n:
        raise AdapterReject(name)
    out = []
    for item in values:
        if type(item) is not int or item not in (0, 1):
            raise AdapterReject("schema_integrity")
        out.append(item)
    return out


def _int_nonneg(value, name):
    if type(value) is not int or value < 0:
        raise AdapterReject(name)
    return value


def _require_no_labels(packet):
    for banned in ("role", "expected_reason", "expected", "known_bad"):
        if banned in packet:
            raise AdapterReject("label_in_decision_input")


def _reject_packet_verdicts(packet):
    for key in PACKET_VERDICT_KEYS:
        if key in packet:
            raise AdapterReject("packet_supplied_verdict_flag")


def _check_binding(packet):
    if packet.get("bound") is True or packet.get("approved") is True:
        raise AdapterReject("fabricated_binding")
    if packet.get("binding_receipt"):
        raise AdapterReject("fabricated_binding")
    if packet.get("certificate") is True:
        raise AdapterReject("certificate_forbidden")


def _resolve_locator(context, locator, reason="missing_evidence"):
    if not isinstance(locator, str) or not locator:
        raise AdapterReject(reason)
    data = context.resolve(locator)
    if data is None:
        raise AdapterReject(reason)
    return data


def _load_json(context, locator, reason="missing_evidence"):
    raw = _resolve_locator(context, locator, reason)
    try:
        return json.loads(raw.decode("utf-8")), raw
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AdapterReject("malformed_evidence") from exc


def _evidence_map(packet):
    evidence = packet.get("evidence")
    if not isinstance(evidence, dict):
        raise AdapterReject("missing_evidence")
    return evidence


def _ingest_resolved_records(packet, context):
    """Resolve locators to bytes/typed records. Returns records, not verdicts."""
    evidence = _evidence_map(packet)
    required = (
        "product", "content", "native_oracle", "profile_0", "profile_5",
        "signed_B", "preflight", "development_manifest", "sampler_manifest",
        "freeze", "exposure_manifest", "features", "model", "cost",
    )
    for key in required:
        if key not in evidence:
            if key == "development_manifest":
                raise AdapterReject("missing_development_manifest")
            raise AdapterReject("missing_evidence")

    product_obj, product_raw = _load_json(context, evidence["product"])
    content_obj, content_raw = _load_json(context, evidence["content"])
    oracle_obj, oracle_raw = _load_json(context, evidence["native_oracle"])
    profile = {}
    profile_raw = {}
    for vow in VOWS:
        profile[vow], profile_raw[vow] = _load_json(
            context, evidence[f"profile_{vow}"], "profile_identity"
        )
    signed_obj, signed_raw = _load_json(context, evidence["signed_B"], "signed_B_mismatch")
    freeze, freeze_raw = _load_json(context, evidence["freeze"], "freeze_mismatch")
    sampler, sampler_raw = _load_json(context, evidence["sampler_manifest"], "sampler_provenance")
    development, _ = _load_json(
        context, evidence["development_manifest"], "missing_development_manifest"
    )
    exposure, _ = _load_json(context, evidence["exposure_manifest"], "missing_exposure_authority")
    features, _ = _load_json(context, evidence["features"], "features")
    model, _ = _load_json(context, evidence["model"], "features")
    cost, _ = _load_json(context, evidence["cost"], "cost_envelope")
    preflight, _ = _load_json(context, evidence["preflight"], "panel_disagreement")

    policies = {}
    policy_raw = {}
    pol_map = evidence.get("policies")
    if not isinstance(pol_map, dict):
        raise AdapterReject("policy_identity")
    for panel in PANELS:
        if panel not in pol_map or not isinstance(pol_map[panel], dict):
            raise AdapterReject("policy_identity")
        for arm in ARMS:
            loc = pol_map[panel].get(arm)
            raw = _resolve_locator(context, loc, "policy_identity")
            policies[(panel, arm)] = _sha256(raw)
            policy_raw[(panel, arm)] = raw

    factual = {}
    factual_map = evidence.get("factual")
    if not isinstance(factual_map, dict):
        raise AdapterReject("missing_source_raw")
    for panel, vow in STRATA:
        key = f"{panel}/v{vow}"
        payload, _ = _load_json(context, factual_map.get(key), "missing_source_raw")
        if payload.get("panel") != panel or payload.get("vow") != vow:
            raise AdapterReject("stratum_key_mismatch")
        factual[(panel, vow)] = payload

    measurement = {}
    meas_map = evidence.get("measurement")
    if not isinstance(meas_map, dict):
        raise AdapterReject("missing_evidence")
    for panel, vow in STRATA:
        for k in PACKAGES:
            key = f"{panel}/v{vow}/K{k}"
            payload, _ = _load_json(context, meas_map.get(key), "missing_evidence")
            if (
                payload.get("panel") != panel
                or payload.get("vow") != vow
                or payload.get("k") != k
            ):
                raise AdapterReject("stratum_key_mismatch")
            measurement[(panel, vow, k)] = payload

    peer = {}
    peer_map = evidence.get("peer")
    if not isinstance(peer_map, dict):
        raise AdapterReject("missing_evidence")
    for panel, vow in STRATA:
        key = f"{panel}/v{vow}"
        payload, _ = _load_json(context, peer_map.get(key), "missing_evidence")
        if payload.get("panel") != panel or payload.get("vow") != vow:
            raise AdapterReject("stratum_key_mismatch")
        peer[(panel, vow)] = payload

    return {
        "product_obj": product_obj,
        "product_raw": product_raw,
        "content_raw": content_raw,
        "oracle_raw": oracle_raw,
        "profile": profile,
        "profile_raw": profile_raw,
        "signed_obj": signed_obj,
        "signed_raw": signed_raw,
        "freeze": freeze,
        "freeze_raw": freeze_raw,
        "sampler": sampler,
        "sampler_raw": sampler_raw,
        "development": development,
        "exposure": exposure,
        "features": features,
        "model": model,
        "cost": cost,
        "preflight": preflight,
        "policies": policies,
        "policy_raw": policy_raw,
        "factual": factual,
        "measurement": measurement,
        "peer": peer,
        "content_obj": content_obj,
        "oracle_obj": oracle_obj,
    }


def _check_identities_from_records(packet, records, context):
    expected = context.expected_identities
    authority = packet.get("authority")
    if authority is None:
        raise AdapterReject("missing_authority")
    if authority != context.expected_authority:
        raise AdapterReject("missing_authority")
    if packet.get("epoch") != EPOCH or records["freeze"].get("epoch") != EPOCH:
        raise AdapterReject("epoch_mismatch")
    if records["freeze"].get("epoch") != expected.get("epoch", EPOCH):
        raise AdapterReject("epoch_mismatch")

    product_digest = _sha256(records["product_raw"])
    if product_digest != expected["product"]:
        raise AdapterReject("product_identity")
    if _sha256(records["content_raw"]) != expected["content"]:
        raise AdapterReject("identity_mismatch")
    if _sha256(records["oracle_raw"]) != expected["native_oracle"]:
        raise AdapterReject("identity_mismatch")
    if _sha256(records["signed_raw"]) != expected["signed_B"]:
        raise AdapterReject("signed_B_mismatch")

    for vow in VOWS:
        if _sha256(records["profile_raw"][vow]) != expected["profile"][str(vow)]:
            raise AdapterReject("profile_identity")

    claim = packet.get("identities")
    if not isinstance(claim, dict):
        raise AdapterReject("identities")
    if claim.get("product") != product_digest:
        raise AdapterReject("product_identity")
    if claim.get("content") != expected["content"]:
        raise AdapterReject("identity_mismatch")
    if claim.get("native_oracle") != expected["native_oracle"]:
        raise AdapterReject("identity_mismatch")
    if claim.get("signed_B") != expected["signed_B"]:
        raise AdapterReject("signed_B_mismatch")
    if claim.get("signed_B_authority") != "landscape-arm2-random-build-competent-play":
        raise AdapterReject("signed_B_authority")
    profiles = claim.get("profile")
    if not isinstance(profiles, dict):
        raise AdapterReject("profile_identity")
    for vow in VOWS:
        if profiles.get(str(vow)) != expected["profile"][str(vow)]:
            raise AdapterReject("profile_identity")

    signed = expected["signed_B"]
    for panel in PANELS:
        if records["policies"][(panel, "B")] != signed:
            raise AdapterReject("signed_B_mismatch")
        for arm in ARMS:
            digest = records["policies"][(panel, arm)]
            want = expected["policies"][panel][arm]
            if digest != want:
                raise AdapterReject("policy_identity")

    if records["model"].get("fitted_on") != "development":
        raise AdapterReject("fitted_on_confirmation")
    full = records["model"].get("full_features")
    blind = records["model"].get("blind_features")
    if not isinstance(full, list) or not isinstance(blind, list):
        raise AdapterReject("features")
    if list(full) == list(blind):
        raise AdapterReject("full_equals_blind")
    if not set(blind).issubset(set(full)):
        raise AdapterReject("features")

    preflight = records["preflight"]
    if not isinstance(preflight, list):
        raise AdapterReject("panel_disagreement")
    for arm in ROUTE_ARMS:
        rows = [
            row for row in preflight
            if isinstance(row, dict) and row.get("arm") == arm and row.get("legal") is True
        ]
        if not rows:
            raise AdapterReject("panel_disagreement")
        if not any(row.get("action_A") != row.get("action_B") for row in rows):
            raise AdapterReject("panel_disagreement")
        for row in rows:
            if row.get("policy_A") != records["policies"][("A", arm)]:
                raise AdapterReject("panel_disagreement")
            if row.get("policy_B") != records["policies"][("B", arm)]:
                raise AdapterReject("panel_disagreement")


def _check_cost_features(records):
    cost = records["cost"]
    if not isinstance(cost, dict):
        raise AdapterReject("cost_envelope")
    cap = None
    for arm in ("R", "K1", "K2", "K3"):
        row = cost.get(arm)
        if not isinstance(row, dict):
            raise AdapterReject("cost_envelope")
        if row.get("hidden_rng") or row.get("privileged"):
            raise AdapterReject("privileged_information")
        c = row.get("forward_evals_per_decision")
        if type(c) is not int or c <= 0 or c > 128:
            raise AdapterReject("cost_envelope")
        if cap is None:
            cap = c
        elif c != cap:
            raise AdapterReject("cost_unmatched")

    features = records["features"]
    names = features.get("names") if isinstance(features, dict) else None
    if not isinstance(names, list) or not 1 <= len(names) <= 32:
        raise AdapterReject("features")
    lowered = [str(n).lower() for n in names]
    if len(set(lowered)) != len(lowered):
        raise AdapterReject("features")
    for name in lowered:
        if any(tok in name for tok in LEAK_TOKENS):
            raise AdapterReject("leaked_features")
    if features.get("includes_win_label"):
        raise AdapterReject("leaked_features")
    if names != records["model"].get("full_features"):
        raise AdapterReject("features")


def _exposure_sets(records):
    exposure = records["exposure"]
    if not isinstance(exposure, dict):
        raise AdapterReject("missing_exposure_authority")
    try:
        exposed = {kernel.effective_seed(x) for x in exposure.get("exposed")}
        protected = {kernel.effective_seed(x) for x in exposure.get("protected")}
    except (TypeError, ValueError) as exc:
        raise AdapterReject("schema_integrity") from exc
    if not PROTECTED <= protected:
        raise AdapterReject("protected_seeds")
    return exposed, protected


def _check_roots_from_records(records, packet):
    exposed, protected = _exposure_sets(records)
    if "exposed_seeds" in packet:
        try:
            claimed = {kernel.effective_seed(x) for x in packet["exposed_seeds"]}
        except (TypeError, ValueError) as exc:
            raise AdapterReject("schema_integrity") from exc
        if claimed != exposed:
            raise AdapterReject("missing_exposure_authority")
    if "protected_seeds" in packet:
        try:
            claimed_p = {kernel.effective_seed(x) for x in packet["protected_seeds"]}
        except (TypeError, ValueError) as cr:
            raise AdapterReject("schema_integrity") from cr
        if claimed_p != protected:
            raise AdapterReject("protected_seeds")

    freeze = records["freeze"]
    sampler = records["sampler"]
    freeze_ts = _int_nonneg(freeze.get("timestamp"), "timestamp_order")
    sampler_ts = _int_nonneg(sampler.get("timestamp"), "sampler_provenance")
    if sampler_ts < freeze_ts:
        raise AdapterReject("timestamp_order")
    frame_id = sampler.get("frame_id")
    freeze_id = freeze.get("id")
    sampler_id = sampler.get("id")
    if not frame_id or not freeze_id or not sampler_id:
        raise AdapterReject("sampler_provenance")

    confirm_roots = {}
    all_confirm = []
    for panel, vow in STRATA:
        fac = records["factual"][(panel, vow)]
        roots = fac.get("roots")
        if not isinstance(roots, list) or len(roots) != kernel.N:
            raise AdapterReject("roots")
        try:
            eff = [kernel.effective_seed(x) for x in roots]
        except ValueError as exc:
            text = str(exc)
            if "integer" in text or "bool" in text:
                raise AdapterReject("schema_integrity") from exc
            raise AdapterReject("seed_alias") from exc
        if len(set(eff)) != kernel.N:
            raise AdapterReject("root_duplicates")
        arms = {arm: eff[:] for arm in ARMS}
        crn = fac.get("crn_roots")
        if isinstance(crn, dict):
            for arm in ARMS:
                try:
                    arms[arm] = [kernel.effective_seed(x) for x in crn[arm]]
                except (KeyError, TypeError, ValueError) as exc:
                    raise AdapterReject("crn_mismatch") from exc
        try:
            kernel.validate_roots(arms, exposed, protected)
        except ValueError as exc:
            text = str(exc)
            if "exposed/protected" in text:
                raise AdapterReject("exposed_protected_root") from exc
            if "CRN" in text:
                raise AdapterReject("crn_mismatch") from exc
            if "duplicate" in text or "incomplete" in text:
                raise AdapterReject("root_duplicates") from exc
            if "effective" in text or "alias" in text:
                raise AdapterReject("seed_alias") from exc
            raise AdapterReject("roots") from exc
        if fac.get("freeze_id") != freeze_id or fac.get("sampler_id") != sampler_id:
            raise AdapterReject("sampler_provenance")
        if fac.get("frame_id") != frame_id:
            raise AdapterReject("sampler_provenance")
        ts = _int_nonneg(fac.get("timestamp"), "timestamp_order")
        if ts < sampler_ts:
            raise AdapterReject("timestamp_order")
        if fac.get("product") != _sha256(records["product_raw"]):
            raise AdapterReject("product_identity")
        if fac.get("profile") != _sha256(records["profile_raw"][vow]):
            raise AdapterReject("profile_identity")
        if fac.get("control") != _sha256(records["signed_raw"]):
            raise AdapterReject("signed_B_mismatch")
        confirm_roots[(panel, vow)] = set(eff)
        all_confirm.extend(eff)

        behavior = fac.get("behavior")
        if not isinstance(behavior, dict):
            raise AdapterReject("identical_traces_renamed")
        vecs = []
        for k in PACKAGES:
            vec = behavior.get(f"K{k}")
            if not isinstance(vec, list) or len(vec) != kernel.N:
                raise AdapterReject("identical_traces_renamed")
            vecs.append(tuple(vec))
        if len(set(vecs)) != 3:
            raise AdapterReject("identical_traces_renamed")

    keys = list(confirm_roots)
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            if confirm_roots[a] & confirm_roots[b]:
                if a[0] != b[0]:
                    raise AdapterReject("panel_root_overlap")
                raise AdapterReject("root_collision")

    development = records["development"]
    if not isinstance(development, dict) or "roots" not in development:
        raise AdapterReject("missing_development_manifest")
    dev_map = development["roots"]
    if not isinstance(dev_map, dict) or set(dev_map) != {f"{p}/v{v}" for p, v in STRATA}:
        raise AdapterReject("missing_development_manifest")
    dev_all = []
    for panel, vow in STRATA:
        rows = dev_map[f"{panel}/v{vow}"]
        if not isinstance(rows, list) or not rows:
            raise AdapterReject("missing_development_manifest")
        try:
            dev_eff = [kernel.effective_seed(x) for x in rows]
        except ValueError as exc:
            raise AdapterReject("schema_integrity") from exc
        if set(dev_eff) & confirm_roots[(panel, vow)]:
            raise AdapterReject("dev_confirm_overlap")
        dev_all.extend(dev_eff)
    if set(dev_all) & set(all_confirm):
        raise AdapterReject("dev_confirm_overlap")
    if len(set(dev_all)) != len(dev_all):
        raise AdapterReject("root_collision")


def _bits(payload, key, n, reason="missing_source_raw"):
    bits = payload.get("bits")
    if not isinstance(bits, dict) or key not in bits:
        raise AdapterReject(reason)
    return _int_bit_list(bits[key], n, reason)


def _derive_counts(records):
    counts = {key: 0 for key in kernel.registry()}
    n = kernel.N
    n_meas = kernel.N_MEAS
    for panel, vow in STRATA:
        p = f"{panel}/v{vow}"
        fac = records["factual"][(panel, vow)]
        counts[f"{p}/B.win"] = sum(_bits(fac, "B.win", n))
        counts[f"{p}/R_B.gain"] = sum(_bits(fac, "R_B.gain", n))
        counts[f"{p}/R_B.loss"] = sum(_bits(fac, "R_B.loss", n))
        enact = {}
        for k in PACKAGES:
            q = f"{p}/K{k}"
            counts[f"{q}/acquire"] = sum(_bits(fac, f"K{k}/acquire", n))
            enact[k] = _bits(fac, f"K{k}/enact", n)
            counts[f"{q}/enact"] = sum(enact[k])
            counts[f"{q}/win_enact"] = sum(_bits(fac, f"K{k}/win_enact", n))
            counts[f"{q}/K_R.gain"] = sum(_bits(fac, f"K{k}/K_R.gain", n))
            counts[f"{q}/K_R.loss"] = sum(_bits(fac, f"K{k}/K_R.loss", n))

            meas = records["measurement"][(panel, vow, k)]
            selected = meas.get("roots")
            if not isinstance(selected, list):
                raise AdapterReject("measurement_selection")
            if len(selected) < n_meas:
                raise AdapterReject("insufficient_measurement_roots")
            if len(selected) != n_meas:
                raise AdapterReject("measurement_selection")
            order = fac.get("roots")
            first = [order[i] for i, flag in enumerate(enact[k]) if flag][:n_meas]
            if first != selected:
                raise AdapterReject("measurement_selection")
            on_gt = _int_bit_list(meas.get("on_gt"), n_meas, "invalid_ground_truth")
            on_native = _int_bit_list(meas.get("on_native"), n_meas, "invalid_ground_truth")
            off_gt = _int_bit_list(meas.get("off_gt"), n_meas, "invalid_ground_truth")
            off_native = _int_bit_list(meas.get("off_native"), n_meas, "invalid_ground_truth")
            if on_gt != on_native or off_gt != off_native:
                raise AdapterReject("invalid_ground_truth")
            if any(v != 1 for v in on_gt) or any(v != 0 for v in off_gt):
                raise AdapterReject("invalid_ground_truth")
            on_pred = meas.get("on_pred")
            if not isinstance(on_pred, list) or len(on_pred) != n_meas:
                raise AdapterReject("all_abstain")
            if all(x == -1 for x in on_pred):
                raise AdapterReject("all_abstain")

            counts[f"{q}/on.correct"] = sum(_bits(meas, "on.correct", n_meas))
            counts[f"{q}/off.correct"] = sum(_bits(meas, "off.correct", n_meas))
            counts[f"{q}/natural_negative.not_negative"] = sum(
                _bits(meas, "natural_negative.not_negative", n_meas)
            )
            counts[f"{q}/blind_on.gain"] = sum(_bits(meas, "blind_on.gain", n_meas))
            counts[f"{q}/blind_on.loss"] = sum(_bits(meas, "blind_on.loss", n_meas))
            counts[f"{q}/blind_off.gain"] = sum(_bits(meas, "blind_off.gain", n_meas))
            counts[f"{q}/blind_off.loss"] = sum(_bits(meas, "blind_off.loss", n_meas))

        peer = records["peer"][(panel, vow)]
        for k, ell in PAIRS:
            pair = f"{p}/pair{k}{ell}"
            counts[f"{pair}/correct_k"] = sum(_bits(peer, f"pair{k}{ell}/correct_k", n))
            counts[f"{pair}/correct_l"] = sum(_bits(peer, f"pair{k}{ell}/correct_l", n))
            counts[f"{pair}/exclusive_k"] = sum(_bits(peer, f"pair{k}{ell}/exclusive_k", n))
            counts[f"{pair}/exclusive_l"] = sum(_bits(peer, f"pair{k}{ell}/exclusive_l", n))
    return counts


def _check_count_consistency(counts):
    n = kernel.N
    n_meas = kernel.N_MEAS
    for panel, vow in STRATA:
        p = f"{panel}/v{vow}"
        b = counts[f"{p}/B.win"]
        g = counts[f"{p}/R_B.gain"]
        loss = counts[f"{p}/R_B.loss"]
        if loss > b:
            raise AdapterReject("rb_loss_exceeds_B_win")
        if g > n - b:
            raise AdapterReject("rb_gain_exceeds_B_loss")
        r = b + g - loss
        if not 0 <= r <= n:
            raise AdapterReject("implied_R_wins")
        for k in PACKAGES:
            q = f"{p}/K{k}"
            kg = counts[f"{q}/K_R.gain"]
            kl = counts[f"{q}/K_R.loss"]
            if kl > r:
                raise AdapterReject("kr_loss_exceeds_R_win")
            if kg > n - r:
                raise AdapterReject("kr_gain_exceeds_R_loss")
            k_win = r + kg - kl
            if not 0 <= k_win <= n:
                raise AdapterReject("implied_K_wins")
            acquire = counts[f"{q}/acquire"]
            enact = counts[f"{q}/enact"]
            win_enact = counts[f"{q}/win_enact"]
            if not (0 <= win_enact <= enact <= acquire):
                raise AdapterReject("win_enact_order")
            if win_enact > k_win:
                raise AdapterReject("win_enact_exceeds_K_win")
            on_c = counts[f"{q}/on.correct"]
            off_c = counts[f"{q}/off.correct"]
            if counts[f"{q}/blind_on.gain"] > on_c:
                raise AdapterReject("blind_gain_exceeds_full_correct")
            if counts[f"{q}/blind_on.loss"] > n_meas - on_c:
                raise AdapterReject("blind_loss_exceeds_full_incorrect")
            if counts[f"{q}/blind_off.gain"] > off_c:
                raise AdapterReject("blind_gain_exceeds_full_correct")
            if counts[f"{q}/blind_off.loss"] > n_meas - off_c:
                raise AdapterReject("blind_loss_exceeds_full_incorrect")
        for k, ell in PAIRS:
            pair = f"{p}/pair{k}{ell}"
            if counts[f"{pair}/exclusive_k"] > counts[f"{p}/K{k}/enact"]:
                raise AdapterReject("exclusive_exceeds_enact")
            if counts[f"{pair}/exclusive_l"] > counts[f"{p}/K{ell}/enact"]:
                raise AdapterReject("exclusive_exceeds_enact")


def _rows_from_counts(counts):
    return [{"key": key, "successes": counts[key], "n": n} for key, n in kernel.registry().items()]


def _compare_summaries(packet, counts):
    rows = packet.get("rows")
    if rows is None:
        return
    if not isinstance(rows, list):
        raise AdapterReject("rows")
    try:
        kernel.validate_counts(rows)
    except KeyError as exc:
        raise AdapterReject("schema_integrity") from exc
    except ValueError as exc:
        text = str(exc)
        if "duplicate" in text or "undeclared" in text or "foreign" in text:
            raise AdapterReject("undeclared_or_duplicate_metric") from exc
        if "incomplete" in text:
            raise AdapterReject("incomplete_registry") from exc
        raise AdapterReject("sample_size") from exc
    derived = {row["key"]: row["successes"] for row in _rows_from_counts(counts)}
    for row in rows:
        if "successes" not in row:
            raise AdapterReject("schema_integrity")
        if derived.get(row["key"]) != row["successes"]:
            raise AdapterReject("summary_mismatch")


def _canonical_caps(alloc):
    return {
        "schema": alloc.get("schema"),
        "epoch": alloc.get("epoch"),
        "status": alloc.get("status"),
        "owner_authority": alloc.get("owner_authority"),
        "historical_accounts": alloc.get("historical_accounts"),
        "candidate_attempts": {
            "maximum": (alloc.get("candidate_attempts") or {}).get("maximum"),
            "consume_at": (alloc.get("candidate_attempts") or {}).get("consume_at"),
        },
        "alpha": {
            "total_new_cap": (alloc.get("alpha") or {}).get("total_new_cap"),
            "542_cap": ((alloc.get("alpha") or {}).get("542") or {}).get("cap"),
            "548_reserved": ((alloc.get("alpha") or {}).get("548") or {}).get("reserved"),
            "548_spendable": ((alloc.get("alpha") or {}).get("548") or {}).get("spendable"),
            "interval_slots_542": (alloc.get("alpha") or {}).get("interval_slots_542"),
            "occupied_slots_542": (alloc.get("alpha") or {}).get("occupied_slots_542"),
            "sealed_unused_slots_542": (alloc.get("alpha") or {}).get("sealed_unused_slots_542"),
            "refund_or_transfer_allowed": (alloc.get("alpha") or {}).get("refund_or_transfer_allowed"),
        },
        "native_caps": {
            stage: (alloc.get("native_starts") or {}).get(stage, {}).get("cap")
            for stage in kernel.CAPS
        },
        "limits": alloc.get("limits"),
        "sample_sizes": alloc.get("sample_sizes"),
        "effective_seed_mapping": alloc.get("effective_seed_mapping"),
    }


def _fold_allocation_events(alloc, context):
    events = alloc.get("event_log") or []
    if events and context.kind != "synthetic":
        raise AdapterReject("allocation_event")
    ledger = kernel.Ledger(bound=context.synthetic_ledger_bound)
    for event in events:
        if not isinstance(event, dict):
            raise AdapterReject("allocation_event")
        try:
            count = event["count"]
            raw = event.get("raw", 0)
            cpu = event.get("cpu", 0.0)
            elapsed = event.get("elapsed", 0.0)
            kernel.integer(count, "count")
            kernel.integer(raw, "raw")
        except (KeyError, TypeError, ValueError) as exc:
            raise AdapterReject("schema_integrity") from exc
        if count < 0 or (isinstance(cpu, bool) or isinstance(elapsed, bool)):
            raise AdapterReject("allocation_event")
        try:
            ledger.debit(
                event.get("event_id"),
                event.get("candidate"),
                event.get("stage"),
                count,
                cpu=cpu,
                elapsed=elapsed,
                raw=raw,
            )
        except ValueError as exc:
            text = str(exc)
            if "second candidate" in text:
                raise AdapterReject("second_candidate") from exc
            raise AdapterReject("allocation_event") from exc
    return ledger


def _check_allocation(packet, context):
    alloc = packet.get("allocation")
    if not isinstance(alloc, dict):
        raise AdapterReject("allocation")
    loc = (_evidence_map(packet)).get("allocation")
    if loc:
        resolved, _ = _load_json(context, loc, "allocation")
        if resolved != alloc:
            raise AdapterReject("allocation")
    canonical = context.expected_allocation
    if _canonical_caps(alloc) != _canonical_caps(canonical):
        raise AdapterReject("allocation_template")
    hist = alloc.get("historical_accounts") or {}
    if hist.get("status") != "UNKNOWN_WHERE_UNRECOVERED":
        raise AdapterReject("historical_unknown")
    if hist.get("spent") is not None:
        raise AdapterReject("historical_unknown")
    if hist.get("remaining") is not None:
        raise AdapterReject("historical_credit")
    attempts = alloc.get("candidate_attempts") or {}
    if attempts.get("used") not in (0, 0.0) and not (alloc.get("event_log") or []):
        raise AdapterReject("candidate_attempt_spent")
    if attempts.get("used") not in (0, 0.0) and context.kind == "synthetic" and not context.synthetic_ledger_bound:
        raise AdapterReject("candidate_attempt_spent")
    alpha = alloc.get("alpha") or {}
    committed = (alpha.get("542") or {}).get("committed")
    if committed not in (0, 0.0):
        raise AdapterReject("allocation_alpha")
    if (alpha.get("548") or {}).get("spendable") not in (0, 0.0):
        raise AdapterReject("alpha_548_borrow")
    if alpha.get("refund_or_transfer_allowed"):
        raise AdapterReject("allocation_alpha")
    if alloc.get("binding_receipt") not in (None,):
        receipt = context.receipts.get("binding")
        if not receipt or alloc.get("binding_receipt") != _sha256(receipt):
            raise AdapterReject("fabricated_binding")
    if alloc.get("independent_review") not in (None,):
        review = context.receipts.get("independent_review")
        if not review or alloc.get("independent_review") != _sha256(review):
            raise AdapterReject("fabricated_binding")
    if alloc.get("new_game_outcomes_in_this_planner_pass") != 0:
        raise AdapterReject("game_outcomes")
    if packet.get("credit_from_history"):
        raise AdapterReject("historical_credit")
    if packet.get("borrow_548"):
        raise AdapterReject("alpha_548_borrow")
    if packet.get("second_candidate"):
        raise AdapterReject("second_candidate")
    if packet.get("top_up"):
        raise AdapterReject("top_up")

    ledger = _fold_allocation_events(alloc, context)
    usage = alloc.get("usage") or {}
    if not events_present(alloc):
        for key in ("cpu_seconds", "active_elapsed_seconds", "raw_emitted_bytes_cumulative"):
            if usage.get(key) not in (0, 0.0):
                raise AdapterReject("allocation_spend")
        starts = alloc.get("native_starts") or {}
        for stage, cap in kernel.CAPS.items():
            row = starts.get(stage) or {}
            if row.get("used") != 0 or row.get("cap") != cap:
                raise AdapterReject("allocation_template")
        return
    if usage.get("cpu_seconds") != ledger.cpu:
        raise AdapterReject("allocation_event")
    if usage.get("active_elapsed_seconds") != ledger.elapsed:
        raise AdapterReject("allocation_event")
    if usage.get("raw_emitted_bytes_cumulative") != ledger.raw:
        raise AdapterReject("allocation_event")
    starts = alloc.get("native_starts") or {}
    for stage, cap in kernel.CAPS.items():
        row = starts.get(stage) or {}
        if row.get("cap") != cap or row.get("used") != ledger.spent[stage]:
            raise AdapterReject("allocation_event")


def events_present(alloc):
    return bool(alloc.get("event_log"))


def _rows_map(rows):
    out = {}
    for row in rows:
        out[row["key"]] = row
    return out


def _predicates(rows):
    mapped = _rows_map(rows)
    out = {}
    for panel in PANELS:
        for vow in VOWS:
            p = f"{panel}/v{vow}"
            b_win = mapped[f"{p}/B.win"]["successes"]
            out[f"{p}/B_ceiling"] = kernel.decide(
                kernel.interval(b_win, kernel.N), 0.50, "<"
            )
            out[f"{p}/R_minus_B"] = kernel.decide(
                kernel.paired(
                    mapped[f"{p}/R_B.gain"]["successes"],
                    mapped[f"{p}/R_B.loss"]["successes"],
                    kernel.N,
                ),
                0.35,
                ">=",
            )
            for k in PACKAGES:
                q = f"{p}/K{k}"
                out[f"{q}/quality"] = kernel.decide(
                    kernel.paired(
                        mapped[f"{q}/K_R.gain"]["successes"],
                        mapped[f"{q}/K_R.loss"]["successes"],
                        kernel.N,
                    ),
                    -0.10,
                    ">=",
                )
                out[f"{q}/acquire"] = kernel.decide(
                    kernel.interval(mapped[f"{q}/acquire"]["successes"], kernel.N),
                    0.30,
                    ">=",
                )
                out[f"{q}/enact"] = kernel.decide(
                    kernel.interval(mapped[f"{q}/enact"]["successes"], kernel.N),
                    0.25,
                    ">=",
                )
                out[f"{q}/win_enact"] = kernel.decide(
                    kernel.interval(mapped[f"{q}/win_enact"]["successes"], kernel.N),
                    0.10,
                    ">=",
                )
                out[f"{q}/on"] = kernel.decide(
                    kernel.interval(mapped[f"{q}/on.correct"]["successes"], kernel.N_MEAS),
                    0.80,
                    ">=",
                )
                out[f"{q}/off"] = kernel.decide(
                    kernel.interval(mapped[f"{q}/off.correct"]["successes"], kernel.N_MEAS),
                    0.90,
                    ">=",
                )
                out[f"{q}/natural_null"] = kernel.decide(
                    kernel.interval(
                        mapped[f"{q}/natural_negative.not_negative"]["successes"],
                        kernel.N_MEAS,
                    ),
                    0.05,
                    "<=",
                )
                out[f"{q}/blind_gain"] = kernel.decide(
                    kernel.balanced_gain(
                        mapped[f"{q}/blind_on.gain"]["successes"],
                        mapped[f"{q}/blind_on.loss"]["successes"],
                        mapped[f"{q}/blind_off.gain"]["successes"],
                        mapped[f"{q}/blind_off.loss"]["successes"],
                    ),
                    0.10,
                    ">=",
                )
            for k, ell in PAIRS:
                pair = f"{p}/pair{k}{ell}"
                out[f"{pair}/correct_k"] = kernel.decide(
                    kernel.interval(mapped[f"{pair}/correct_k"]["successes"], kernel.N),
                    0.75,
                    ">=",
                )
                out[f"{pair}/correct_l"] = kernel.decide(
                    kernel.interval(mapped[f"{pair}/correct_l"]["successes"], kernel.N),
                    0.75,
                    ">=",
                )
                out[f"{pair}/exclusive_k"] = kernel.decide(
                    kernel.interval(mapped[f"{pair}/exclusive_k"]["successes"], kernel.N),
                    0.10,
                    ">=",
                )
                out[f"{pair}/exclusive_l"] = kernel.decide(
                    kernel.interval(mapped[f"{pair}/exclusive_l"]["successes"], kernel.N),
                    0.10,
                    ">=",
                )
    return out


def evaluate_packet(packet, context=None):
    """Shipped admission entry. Does not read role/id/expected reason."""
    if not isinstance(packet, dict):
        return _reason_result("packet")
    try:
        _require_no_labels(packet)
        _reject_packet_verdicts(packet)
        _check_binding(packet)
        if context is None:
            return _blocked("missing_trusted_context")
        if not isinstance(context, TrustedContext):
            return _reason_result("trusted_context")
        mode = packet.get("mode")
        if mode == "empirical":
            if context.kind != "empirical":
                return _blocked("empirical_cannot_select_synthetic_context")
            if not context.has_required_empirical_receipts():
                return _blocked("empirical_missing_binding_freeze_receipts")
        elif mode == "synthetic":
            if context.kind != "synthetic":
                return _reason_result("synthetic_requires_synthetic_context")
        else:
            return _reason_result("mode")
        if packet.get("game_outcome_rows"):
            raise AdapterReject("game_outcomes")
        records = _ingest_resolved_records(packet, context)
        _check_identities_from_records(packet, records, context)
        _check_cost_features(records)
        _check_roots_from_records(records, packet)
        counts = _derive_counts(records)
        _check_count_consistency(counts)
        _compare_summaries(packet, counts)
        _check_allocation(packet, context)
        predicates = _predicates(_rows_from_counts(counts))
        if any(v != "PASS" for v in predicates.values()):
            failed = [k for k, v in predicates.items() if v != "PASS"]
            return {
                "integrity": "PASS",
                "reason": "PREDICATE_NOT_PASS",
                "failed_predicates": failed,
                "predicates": predicates,
                "certificate": False,
                "game_outcome_rows": 0,
                "native_invocations": 0,
            }
        return _pass_result(predicates)
    except AdapterReject as exc:
        return _reason_result(exc.reason)
    except (KeyError, TypeError, ValueError) as exc:
        return _reason_result(
            "schema_integrity",
            extra={"detail": f"{type(exc).__name__}: {exc}"},
        )


def passing_rows():
    rows = []
    for key, n in kernel.registry().items():
        if key.endswith("/B.win"):
            k = 512
        elif key.endswith("/R_B.gain"):
            k = 1150
        elif key.endswith("/R_B.loss"):
            k = 40
        elif key.endswith("/acquire"):
            k = 1024
        elif key.endswith("/enact"):
            k = 900
        elif key.endswith("/win_enact"):
            k = 600
        elif key.endswith("/K_R.gain") or key.endswith("/K_R.loss"):
            k = 205
        elif key.endswith("/on.correct"):
            k = 250
        elif key.endswith("/off.correct"):
            k = 254
        elif key.endswith("/natural_negative.not_negative"):
            k = 0
        elif "blind_" in key and key.endswith(".gain"):
            k = 128
        elif "blind_" in key and key.endswith(".loss"):
            k = 0
        elif "/correct_" in key:
            k = 1850
        elif "/exclusive_" in key:
            k = 500
        else:
            k = n // 2
        rows.append({"key": key, "successes": k, "n": n})
    return rows


def load_allocation(path=None):
    here = os.path.dirname(os.path.abspath(__file__))
    with open(path or os.path.join(here, "ALLOCATION.json"), encoding="utf-8") as handle:
        return json.load(handle)


def good_bundle():
    import synthetic_evidence as se
    return se.good_bundle()


def good_packet():
    return good_bundle()[0]


def with_fault(packet, path, value):
    out = copy.deepcopy(packet)
    cursor = out
    *parents, leaf = path
    for key in parents:
        cursor = cursor[key]
    cursor[leaf] = value
    return out


OBLIGATION_MAP = [
    ("§8 out-of-band identities/receipts; locators are not proof",
     "TrustedContext.resolve, _ingest_resolved_records, _resolve_locator",
     "ProvenanceRecordTests, EmpiricalGateTests"),
    ("§8 packet cannot supply verifier/verdict flags",
     "_reject_packet_verdicts",
     "AuthorGateTests"),
    ("§8 empirical BLOCKED without binding/freeze/review receipts; cannot select synthetic context",
     "evaluate_packet mode branch, TrustedContext.has_required_empirical_receipts",
     "EmpiricalGateTests"),
    ("§8 derive 204 counts from per-root records; summaries compared only",
     "_derive_counts, _compare_summaries",
     "CountDerivationTests, KernelWiringTests"),
    ("§8 consistency: l<=b, g<=n-b, r in [0,n]; K support; exclusive; blind vs full",
     "_check_count_consistency",
     "ConsistencyTests"),
    ("§8 identical signed B permitted; K/R disagreement from legal preflight actions",
     "_check_identities_from_records",
     "IdentityRuleTests"),
    ("§8 frozen frame/sampler/timestamps; cross-vow/panel/dev collisions; missing development",
     "_check_roots_from_records",
     "RootManifestTests"),
    ("§8 first-eligible-root measurement selection; immediate GT vs native check",
     "_derive_counts measurement block",
     "MeasurementProvenanceTests"),
    ("§8 allocation template + kernel Ledger event fold; malformed schema rejection",
     "_check_allocation, _fold_allocation_events",
     "AllocationTests"),
    ("§4/§5 152 predicates via restored kernel.decide/interval/paired",
     "_predicates",
     "KernelWiringTests, NumericalMutantTests"),
]
