"""D547-PC1 §8 adapter around the recovered numerical kernel.

Authenticates identities, seeds, exposure, counts, matching roots, and
binding/evidence provenance that the kernel cannot. Synthetic fixtures may
use the test-only verifier; empirical mode cannot. Does not issue certificates,
bind #547, or start native game outcomes.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
import re

import reference_kernel as kernel

EPOCH = kernel.EPOCH
TEST_VERIFIER = "D547-PC1-TEST-VERIFIER"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
ARMS = ("R", "B", "K1", "K2", "K3")
PANELS = ("A", "B")
VOWS = (0, 5)
PACKAGES = (1, 2, 3)
PAIRS = ((1, 2), (1, 3), (2, 3))
PROTECTED = frozenset(range(3000, 5400))
LEAK_TOKENS = (
    "win", "seed", "policy", "package", "card", "arm", "filename", "trace",
)


class AdapterReject(Exception):
    def __init__(self, reason):
        self.reason = reason
        super().__init__(reason)


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


def _hash64(name):
    if not isinstance(name, str) or not HEX64.match(name):
        raise AdapterReject("identity_hash")
    return name


def _int_nonneg(value, name):
    if type(value) is not int or value < 0:
        raise AdapterReject(name)
    return value


def _require_no_labels(packet):
    # GUARD:label_not_decision_input
    for banned in ("role", "expected_reason", "expected", "known_bad"):
        if banned in packet:
            raise AdapterReject("label_in_decision_input")


def _check_mode(packet):
    mode = packet.get("mode")
    verifier = packet.get("trusted_verifier")
    if mode == "synthetic":
        if verifier != TEST_VERIFIER:
            raise AdapterReject("synthetic_verifier")
        return "synthetic"
    if mode == "empirical":
        if verifier == TEST_VERIFIER:
            raise AdapterReject("empirical_test_verifier")
        raise AdapterReject("empirical_not_authorised")
    raise AdapterReject("mode")


def _check_binding(packet):
    # GUARD:fabricated_binding
    if packet.get("bound") is True or packet.get("approved") is True:
        raise AdapterReject("fabricated_binding")
    if packet.get("binding_receipt"):
        raise AdapterReject("fabricated_binding")
    if packet.get("certificate") is True:
        raise AdapterReject("certificate_forbidden")


def _check_identities(packet):
    # GUARD:identities
    ident = packet.get("identities")
    if not isinstance(ident, dict):
        raise AdapterReject("identities")
    for key in ("product", "content", "native_oracle"):
        _hash64(ident.get(key))
    profiles = ident.get("profile")
    if not isinstance(profiles, dict) or set(map(str, profiles)) != {"0", "5"}:
        raise AdapterReject("profile_identity")
    for value in profiles.values():
        _hash64(value)
    if ident.get("signed_B_authority") != "landscape-arm2-random-build-competent-play":
        raise AdapterReject("signed_B_authority")
    policies = ident.get("policies")
    if not isinstance(policies, dict) or set(policies) != set(PANELS):
        raise AdapterReject("policy_identity")
    seen = set()
    for panel, arms in policies.items():
        if set(arms) != set(ARMS):
            raise AdapterReject("policy_identity")
        for arm, digest in arms.items():
            _hash64(digest)
            if digest in seen:
                raise AdapterReject("policy_identity")
            seen.add(digest)
    disagreement = packet.get("panel_disagreement")
    if not isinstance(disagreement, dict):
        raise AdapterReject("panel_disagreement")
    if disagreement.get("decision_A") == disagreement.get("decision_B"):
        raise AdapterReject("panel_disagreement")
    if not disagreement.get("decision_A") or not disagreement.get("decision_B"):
        raise AdapterReject("panel_disagreement")
    if disagreement.get("state") is None:
        raise AdapterReject("panel_disagreement")


def _check_cost(packet):
    # GUARD:cost_envelope
    cost = packet.get("cost")
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


def _check_features(packet):
    # GUARD:leaked_features
    features = packet.get("features")
    if not isinstance(features, dict):
        raise AdapterReject("features")
    names = features.get("names")
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


def _check_allocation(packet):
    # GUARD:allocation_zero_spend
    alloc = packet.get("allocation")
    if not isinstance(alloc, dict):
        raise AdapterReject("allocation")
    if alloc.get("schema") != "D547-PC1-ALLOCATION-1":
        raise AdapterReject("allocation")
    if alloc.get("epoch") != EPOCH:
        raise AdapterReject("allocation")
    hist = alloc.get("historical_accounts") or {}
    if hist.get("status") != "UNKNOWN_WHERE_UNRECOVERED":
        raise AdapterReject("historical_unknown")
    if hist.get("spent") not in (None,):
        raise AdapterReject("historical_unknown")
    if hist.get("remaining") not in (None,):
        raise AdapterReject("historical_credit")
    attempts = alloc.get("candidate_attempts") or {}
    if attempts.get("used") != 0:
        raise AdapterReject("candidate_attempt_spent")
    if attempts.get("maximum") != 1:
        raise AdapterReject("allocation")
    if attempts.get("consume_at") != "first new candidate-native invocation":
        raise AdapterReject("allocation")
    alpha = alloc.get("alpha") or {}
    if alpha.get("total_new_cap") != 0.05:
        raise AdapterReject("alpha")
    if (alpha.get("542") or {}).get("cap") != 0.025:
        raise AdapterReject("alpha")
    if (alpha.get("548") or {}).get("spendable") not in (0, 0.0):
        raise AdapterReject("alpha_548_borrow")
    usage = alloc.get("usage") or {}
    for key in ("cpu_seconds", "active_elapsed_seconds", "raw_emitted_bytes_cumulative"):
        if usage.get(key) not in (0, 0.0):
            raise AdapterReject("allocation_spend")
    starts = alloc.get("native_starts") or {}
    for stage, cap in kernel.CAPS.items():
        row = starts.get(stage) or {}
        if row.get("used") != 0 or row.get("cap") != cap:
            raise AdapterReject("allocation")
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


def _check_roots(packet):
    # GUARD:exposed_protected
    exposed = packet.get("exposed_seeds")
    protected = packet.get("protected_seeds")
    if exposed is None or protected is None:
        raise AdapterReject("missing_exposure_authority")
    exposed_set = {kernel.effective_seed(x) for x in exposed}
    protected_set = {kernel.effective_seed(x) for x in protected}
    if not PROTECTED <= protected_set:
        raise AdapterReject("protected_seeds")
    roots = packet.get("roots")
    if not isinstance(roots, dict):
        raise AdapterReject("roots")
    expected_strata = {f"{panel}/v{vow}" for panel in PANELS for vow in VOWS}
    if set(roots) != expected_strata:
        raise AdapterReject("roots")
    all_effective = []
    for stratum, arms in roots.items():
        try:
            kernel.validate_roots(arms, exposed_set, protected_set)
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
        for arm_roots in arms.values():
            all_effective.extend(kernel.effective_seed(x) for x in arm_roots)
    # GUARD:dev_confirm_overlap
    development = packet.get("development_roots") or []
    dev_eff = {kernel.effective_seed(x) for x in development}
    if dev_eff & set(all_effective):
        raise AdapterReject("dev_confirm_overlap")
    # panels must not reuse roots
    by_panel = {}
    for stratum, arms in roots.items():
        panel = stratum.split("/")[0]
        by_panel.setdefault(panel, set()).update(
            kernel.effective_seed(x) for x in arms["R"]
        )
    if by_panel.get("A") and by_panel.get("B") and by_panel["A"] & by_panel["B"]:
        raise AdapterReject("panel_root_overlap")


def _rows_map(rows):
    out = {}
    for row in rows:
        out[row["key"]] = row
    return out


def _check_counts(packet):
    # GUARD:registry_complete
    rows = packet.get("rows")
    if not isinstance(rows, list):
        raise AdapterReject("rows")
    try:
        kernel.validate_counts(rows)
    except ValueError as exc:
        text = str(exc)
        if "duplicate" in text or "undeclared" in text or "foreign" in text:
            raise AdapterReject("undeclared_or_duplicate_metric") from exc
        if "incomplete" in text:
            raise AdapterReject("incomplete_registry") from exc
        raise AdapterReject("sample_size") from exc
    mapped = _rows_map(rows)
    # GUARD:win_enact_order
    for panel in PANELS:
        for vow in VOWS:
            for k in PACKAGES:
                prefix = f"{panel}/v{vow}/K{k}/"
                acquire = mapped[prefix + "acquire"]["successes"]
                enact = mapped[prefix + "enact"]["successes"]
                win_enact = mapped[prefix + "win_enact"]["successes"]
                if not (0 <= win_enact <= enact <= acquire):
                    raise AdapterReject("win_enact_order")
                g = mapped[prefix + "K_R.gain"]["successes"]
                loss = mapped[prefix + "K_R.loss"]["successes"]
                if g + loss > kernel.N:
                    raise AdapterReject("discordance")
            g = mapped[f"{panel}/v{vow}/R_B.gain"]["successes"]
            loss = mapped[f"{panel}/v{vow}/R_B.loss"]["successes"]
            if g + loss > kernel.N:
                raise AdapterReject("discordance")
    refs = packet.get("trace_refs")
    if not isinstance(refs, dict):
        raise AdapterReject("trace_refs")
    for panel in PANELS:
        for vow in VOWS:
            for k in PACKAGES:
                for kind in ("acquire", "enact"):
                    key = f"{panel}/v{vow}/K{k}/{kind}"
                    loc = refs.get(key)
                    if not isinstance(loc, str) or not loc.startswith("native://"):
                        raise AdapterReject("trace_refs")


def _check_source_raw(packet):
    # GUARD:source_raw
    if packet.get("source_raw_complete") is not True:
        raise AdapterReject("missing_source_raw")
    if packet.get("changed_rule_after_exposure"):
        raise AdapterReject("changed_rule_after_exposure")


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


def evaluate_packet(packet):
    """Shipped admission entry. Does not read role/id/expected reason."""
    if not isinstance(packet, dict):
        return _reason_result("packet")
    try:
        _require_no_labels(packet)
        _check_mode(packet)
        _check_binding(packet)
        _check_identities(packet)
        _check_cost(packet)
        _check_features(packet)
        _check_allocation(packet)
        _check_roots(packet)
        _check_counts(packet)
        _check_source_raw(packet)
        if packet.get("full_equals_blind"):
            raise AdapterReject("full_equals_blind")
        if packet.get("identical_traces_renamed"):
            raise AdapterReject("identical_traces_renamed")
        if packet.get("invalid_ground_truth"):
            raise AdapterReject("invalid_ground_truth")
        if packet.get("all_abstain"):
            raise AdapterReject("all_abstain")
        if packet.get("foreign_detector_metric"):
            raise AdapterReject("undeclared_or_duplicate_metric")
        if packet.get("game_outcome_rows"):
            raise AdapterReject("game_outcomes")
        predicates = _predicates(packet["rows"])
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


def _digest(label):
    return hashlib.sha256(label.encode()).hexdigest()


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


def good_packet():
    """Complete synthetic packet. No role/id/expected fields."""
    roots = {}
    for i, panel in enumerate(PANELS):
        for vow in VOWS:
            base = 10_000_000 + i * 1_000_000 + vow * 10_000
            seq = [base + j for j in range(kernel.N)]
            roots[f"{panel}/v{vow}"] = {arm: seq[:] for arm in ARMS}
    policies = {}
    n = 0
    for panel in PANELS:
        policies[panel] = {}
        for arm in ARMS:
            n += 1
            policies[panel][arm] = _digest(f"policy-{panel}-{arm}-{n}")
    refs = {}
    for panel in PANELS:
        for vow in VOWS:
            for k in PACKAGES:
                for kind in ("acquire", "enact"):
                    refs[f"{panel}/v{vow}/K{k}/{kind}"] = (
                        f"native://{panel}/v{vow}/K{k}/{kind}#0"
                    )
    return {
        "mode": "synthetic",
        "trusted_verifier": TEST_VERIFIER,
        "authority": "D547-PC1",
        "epoch": EPOCH,
        "identities": {
            "product": _digest("product"),
            "content": _digest("content"),
            "native_oracle": _digest("oracle"),
            "profile": {"0": _digest("profile-0"), "5": _digest("profile-5")},
            "policies": policies,
            "signed_B_authority": "landscape-arm2-random-build-competent-play",
        },
        "panel_disagreement": {
            "state": {"hand": ["chisel"], "energy": 3},
            "decision_A": "play:chisel",
            "decision_B": "play:heavyBlow",
        },
        "cost": {
            arm: {
                "forward_evals_per_decision": 128,
                "hidden_rng": False,
                "privileged": False,
            }
            for arm in ("R", "K1", "K2", "K3")
        },
        "features": {
            "names": [f"public_qty_{i}" for i in range(8)],
            "includes_win_label": False,
        },
        "allocation": load_allocation(),
        "exposed_seeds": [],
        "protected_seeds": list(PROTECTED),
        "development_roots": [90_000_000 + i for i in range(64)],
        "roots": roots,
        "rows": passing_rows(),
        "trace_refs": refs,
        "source_raw_complete": True,
        "bound": False,
        "approved": False,
        "binding_receipt": None,
        "certificate": False,
    }


def with_fault(packet, path, value):
    out = copy.deepcopy(packet)
    cursor = out
    *parents, leaf = path
    for key in parents:
        cursor = cursor[key]
    cursor[leaf] = value
    return out
