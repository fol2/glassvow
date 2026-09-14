"""D547-PC1 dry-run validator. Synthetic fixtures only; no game outcomes."""

NECESSARY_SCREEN_CUTOFFS = frozenset({"32/32/16", "32/16/16", "32/16/8"})
UNKNOWN_MISLABELS = frozenset({"available", "exhausted", "zero"})
FORM_ENDPOINT = "whole_run_enacted_at_vow"
ACQ_EVENTS = ("offered", "acquired", "enacted")
MEAS_FIELDS = (
    "ground_truth_source",
    "abstention_policy",
    "held_out_split_id",
    "estimator_name",
)


def _reject(case, code):
    return {
        "id": case.get("id"),
        "verdict": "REJECT",
        "reason": code,
        "certificate": False,
        "game_outcome_rows": 0,
        "godot_runs": 0,
    }


def _form_pass(case):
    return {
        "id": case.get("id"),
        "verdict": "FORM_PASS",
        "reason": "WELL_FORMED",
        "certificate": False,
        "game_outcome_rows": 0,
        "godot_runs": 0,
    }


def validate(case, ledger):
    """Admission entry: raw case dict plus ledger. Never issues CERTIFICATE."""
    if not isinstance(case, dict):
        return _reject({"id": None}, "MISSING_FIELD")

    if case.get("claim_certificate"):
        return _reject(case, "CERTIFICATE_FORBIDDEN")

    authority = (case.get("authority") or "").strip()
    if not authority:
        return _reject(case, "MISSING_AUTHORITY")

    budget_status = case.get("budget_status") or "UNKNOWN"
    treat = case.get("treat_unknown_as")
    if budget_status == "UNKNOWN" and treat in UNKNOWN_MISLABELS:
        return _reject(case, "UNKNOWN_BUDGET_MISLABEL")

    if case.get("certificate_from_necessary_screen"):
        return _reject(case, "SCOPE_LIMITED_COUNTS_AS_CERTIFICATE")
    if case.get("sufficient_cutoff") in NECESSARY_SCREEN_CUTOFFS:
        return _reject(case, "SCOPE_LIMITED_COUNTS_AS_CERTIFICATE")
    if case.get("witness_kind") == "necessary_screen_count":
        return _reject(case, "SCOPE_LIMITED_COUNTS_AS_CERTIFICATE")

    if case.get("identity_only"):
        return _reject(case, "IDENTITY_ONLY_DESCRIPTOR")
    if case.get("detector_threshold_transfer"):
        return _reject(case, "DETECTOR_THRESHOLD_TRANSFER")

    if case.get("unqualified"):
        return _reject(case, "UNQUALIFIED_POLICY")
    if case.get("privileged"):
        return _reject(case, "PRIVILEGED_POLICY")

    search = case.get("search_cost_class") or ""
    ref_search = case.get("reference_search_cost_class") or ""
    runtime = case.get("runtime_cost_class") or ""
    ref_runtime = case.get("reference_runtime_cost_class") or ""
    if (search or ref_search or runtime or ref_runtime) and (
        search != ref_search or runtime != ref_runtime
    ):
        return _reject(case, "COST_UNMATCHED_POLICY")

    if case.get("unit_exposure"):
        return _reject(case, "EXPOSED_UNIT_AS_FRESH")
    if case.get("unit_duplicate"):
        return _reject(case, "DUPLICATED_UNIT_AS_FRESH")

    if case.get("outcomes_required") and not case.get("outcomes_present"):
        return _reject(case, "MISSING_OUTCOMES")

    game_rows = int(case.get("game_outcome_rows") or 0)
    godot_runs = int(case.get("godot_runs") or 0)
    families = (ledger or {}).get("families") or {}
    obs = families.get("observation_compute_wall_time") or {}
    row_cap = int(obs.get("this_batch_authorised_game_outcome_rows") or 0)
    godot_cap = int(obs.get("this_batch_authorised_godot_runs") or 0)
    if game_rows > row_cap or godot_runs > godot_cap:
        return _reject(case, "EXCEEDED_CAP")

    receipt_id = case.get("receipt_id")
    spent = case.get("spent_receipts") or []
    if receipt_id and receipt_id in spent:
        return _reject(case, "REPEATED_RECEIPT")

    if case.get("winners_only") or case.get("quality_conditional_on_success"):
        return _reject(case, "WINNERS_ONLY_QUALITY")

    if case.get("r14_treated_as_admission"):
        return _reject(case, "R14_AS_ADMISSION")
    if case.get("dusk_v0_status") == "failed":
        return _reject(case, "V0_AS_FAILED")

    if case.get("reference_is_c2_arm2"):
        return _reject(case, "REFERENCE_IS_C2_ARM2")
    if case.get("require_route_removal_to_reduce_adaptive_wins"):
        return _reject(case, "ROUTE_ABLATION_REQUIRED")

    if not case.get("policy_family"):
        return _reject(case, "MISSING_FIELD")
    if not search or not runtime:
        return _reject(case, "MISSING_FIELD")
    if not case.get("competent_reference"):
        return _reject(case, "MISSING_FIELD")
    if case.get("endpoint") != FORM_ENDPOINT:
        return _reject(case, "BAD_ENDPOINT")

    if case.get("deterministic_reachability_proof"):
        pass
    else:
        events = case.get("events") or {}
        if any(k not in events for k in ACQ_EVENTS) or not case.get("population"):
            return _reject(case, "MISSING_FIELD")

    if any(not case.get(k) for k in MEAS_FIELDS):
        return _reject(case, "MISSING_FIELD")

    if case.get("role") == "known_bad":
        return _reject(case, "KNOWN_BAD_UNCAUGHT")

    return _form_pass(case)


def validate_batch(cases, ledger):
    return [validate(case, ledger) for case in cases]
