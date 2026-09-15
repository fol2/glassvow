"""Label-blind D547-PC1 synthetic controls. Drive the shipped entry point."""
from __future__ import annotations

import copy
import io
import os
import unittest

import prospective_admission as admission
import reference_kernel as kernel
import synthetic_evidence as se

HERE = os.path.dirname(os.path.abspath(__file__))
N = kernel.N
N_MEAS = kernel.N_MEAS


def run(packet, ctx):
    return admission.evaluate_packet(packet, ctx)


def good():
    return se.good_bundle()


def drop_rows(packet):
    packet.pop("rows", None)
    return packet


class KernelTests(unittest.TestCase):
    def test_sixteen_reference_methods(self):
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(kernel.DesignTests)
        result = unittest.TextTestRunner(stream=io.StringIO(), verbosity=2).run(suite)
        self.assertTrue(result.wasSuccessful())
        self.assertEqual(result.testsRun, 16)

    def test_registry_204(self):
        self.assertEqual(len(kernel.registry()), 204)
        kernel.validate_counts(admission.passing_rows())


class AuthorGateTests(unittest.TestCase):
    """These tests must fail if evaluate_packet is replaced by a role-label rule."""

    def test_good_packet_passes_without_labels(self):
        packet, ctx = good()
        self.assertNotIn("role", packet)
        self.assertNotIn("id", packet)
        self.assertNotIn("trusted_verifier", packet)
        result = run(packet, ctx)
        self.assertEqual(result["reason"], "SYNTHETIC_PACKET_WELL_FORMED", result)
        self.assertEqual(result["integrity"], "PASS")
        self.assertEqual(len(result["predicates"]), 152)
        self.assertTrue(all(v == "PASS" for v in result["predicates"].values()))
        self.assertFalse(result["certificate"])
        self.assertEqual(result["game_outcome_rows"], 0)
        self.assertEqual(result["native_invocations"], 0)

    def test_single_fault_and_repair(self):
        packet, ctx = good()
        baseline = run(packet, ctx)
        self.assertEqual(baseline["integrity"], "PASS")
        for name, make, reason in _packet_faults():
            with self.subTest(name=name):
                bad_packet, bad_ctx = make()
                result = run(bad_packet, bad_ctx)
                self.assertEqual(result["reason"], reason, (name, result))
                self.assertEqual(result["integrity"], "REJECT")
                self.assertFalse(result["certificate"])
                repaired_p, repaired_c = good()
                repaired = run(repaired_p, repaired_c)
                self.assertEqual(repaired["integrity"], "PASS", name)

    def test_role_injection_does_not_rescue_fault(self):
        packet, ctx = good()
        labelled = {**copy.deepcopy(packet), "role": "form_ok"}
        self.assertEqual(run(labelled, ctx)["reason"], "label_in_decision_input")
        bad = {**copy.deepcopy(packet), "bound": True}
        self.assertEqual(run(bad, ctx)["reason"], "fabricated_binding")


def _packet_faults():
    def bind():
        p, c = good()
        p["bound"] = True
        return p, c

    def approved():
        p, c = good()
        p["approved"] = True
        return p, c

    def identity():
        p, c = good()
        p["identities"]["product"] = "not-a-hash"
        return p, c

    def exposed():
        p, c = good()
        root = se.load_json(c, "synth://factual/A/v0")["roots"][0]
        p["exposed_seeds"] = [root]
        exp = se.load_json(c, "synth://exposure")
        exp["exposed"] = [root]
        se.store_json(c, "synth://exposure", exp)
        return drop_rows(p), c

    def leaked():
        p, c = good()
        feat = se.load_json(c, "synth://features")
        feat["names"] = ["win_rate", "seed_id"]
        se.store_json(c, "synth://features", feat)
        model = se.load_json(c, "synth://model")
        model["full_features"] = feat["names"]
        model["blind_features"] = ["seed_id"]
        se.store_json(c, "synth://model", model)
        return drop_rows(p), c

    def unmatched_cost():
        p, c = good()
        cost = se.load_json(c, "synth://cost")
        cost["K1"]["forward_evals_per_decision"] = 64
        se.store_json(c, "synth://cost", cost)
        return drop_rows(p), c

    def privileged():
        p, c = good()
        cost = se.load_json(c, "synth://cost")
        cost["R"]["hidden_rng"] = True
        se.store_json(c, "synth://cost", cost)
        return drop_rows(p), c

    def credit():
        p, c = good()
        p["credit_from_history"] = True
        return p, c

    def borrow():
        p, c = good()
        p["borrow_548"] = True
        return p, c

    def second():
        p, c = good()
        p["second_candidate"] = True
        return p, c

    def top():
        p, c = good()
        p["top_up"] = True
        return p, c

    def label():
        p, c = good()
        p["role"] = "form_ok"
        return p, c

    def outcomes():
        p, c = good()
        p["game_outcome_rows"] = 1
        return p, c

    def spent():
        p, c = good()
        p["allocation"]["candidate_attempts"]["used"] = 1
        se.store_json(c, "synth://allocation", p["allocation"])
        return p, c

    def win_enact():
        p, c = good()
        se.mutate_factual_bits(c, "A", 0, "K1/win_enact", se.ones(N, 1000))
        return drop_rows(p), c

    return [
        ("fabricated_binding", bind, "fabricated_binding"),
        ("approved_flag", approved, "fabricated_binding"),
        ("identity_hash", identity, "product_identity"),
        ("exposed_root", exposed, "exposed_protected_root"),
        ("leaked_features", leaked, "leaked_features"),
        ("cost_unmatched", unmatched_cost, "cost_unmatched"),
        ("privileged_information", privileged, "privileged_information"),
        ("historical_credit", credit, "historical_credit"),
        ("alpha_548_borrow", borrow, "alpha_548_borrow"),
        ("second_candidate", second, "second_candidate"),
        ("top_up", top, "top_up"),
        ("label_in_input", label, "label_in_decision_input"),
        ("game_outcomes", outcomes, "game_outcomes"),
        ("attempt_spent", spent, "candidate_attempt_spent"),
        ("win_enact_order", win_enact, "win_enact_order"),
    ]


def _author_gate_suite():
    return unittest.defaultTestLoader.loadTestsFromTestCase(AuthorGateTests)


class LabelOnlySensitivityTests(unittest.TestCase):
    def test_label_only_replacement_fails_author_gate(self):
        original = admission.evaluate_packet

        def label_only(packet, context=None):
            if packet.get("role") == "known_bad":
                return admission._reason_result("LABEL_ONLY")
            return admission._pass_result({})

        admission.evaluate_packet = label_only
        try:
            result = unittest.TextTestRunner(stream=io.StringIO(), verbosity=0).run(
                _author_gate_suite()
            )
            self.assertFalse(result.wasSuccessful())
            self.assertGreater(len(result.failures) + len(result.errors), 0)
        finally:
            admission.evaluate_packet = original


class GuardDeletionTests(unittest.TestCase):
    CALLS = {
        "fabricated_binding": "        _check_binding(packet)\n",
        "ingest": "        records = _ingest_resolved_records(packet, context)\n",
        "derive": "        counts = _derive_counts(records)\n",
        "consistency": "        _check_count_consistency(counts)\n",
        "allocation": "        _check_allocation(packet, context)\n",
        "labels": "        _require_no_labels(packet)\n",
    }

    def _mutant_evaluate(self, call):
        path = os.path.join(HERE, "prospective_admission.py")
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        self.assertEqual(text.count(call), 1, call)
        ns = {}
        exec(compile(text.replace(call, "        pass\n"), "<mutant>", "exec"), ns)
        return ns["evaluate_packet"]

    def _call_mutant(self, mutant, packet, ctx):
        try:
            return mutant(copy.deepcopy(packet), ctx)
        except Exception as exc:
            return {"integrity": "ERROR", "reason": type(exc).__name__, "predicates": {}}

    def test_each_material_guard_is_load_bearing(self):
        packet, ctx = good()
        self.assertEqual(run(packet, ctx)["integrity"], "PASS")
        bound_p, bound_c = good()
        bound_p["bound"] = True
        labelled_p, labelled_c = good()
        labelled_p["role"] = "form_ok"
        cons_p, cons_c = good()
        se.mutate_peer_bits(cons_c, "A", 0, "pair12/exclusive_k", se.ones(N, 1500))
        drop_rows(cons_p)
        cap_p, cap_c = good()
        cap_p["allocation"]["limits"]["cpu_seconds"] = 10**15
        se.store_json(cap_c, "synth://allocation", cap_p["allocation"])
        probes = {
            "fabricated_binding": (bound_p, bound_c, "fabricated_binding"),
            "labels": (labelled_p, labelled_c, "label_in_decision_input"),
            "consistency": (cons_p, cons_c, "exclusive_exceeds_enact"),
            "allocation": (cap_p, cap_c, "allocation_template"),
            "ingest": (packet, ctx, None),
            "derive": (packet, ctx, None),
        }
        for guard, (p, c, expected) in probes.items():
            with self.subTest(guard=guard):
                mutant = self._mutant_evaluate(self.CALLS[guard])
                mutant_result = self._call_mutant(mutant, p, c)
                if expected is not None:
                    real = run(copy.deepcopy(p), c)
                    self.assertEqual(real["reason"], expected)
                    self.assertNotEqual(mutant_result.get("reason"), expected, guard)
                else:
                    ok = (
                        mutant_result.get("integrity") == "PASS"
                        and len(mutant_result.get("predicates") or {}) == 152
                        and all(v == "PASS" for v in mutant_result["predicates"].values())
                    )
                    self.assertFalse(ok, guard)


class AllocationTemplateTests(unittest.TestCase):
    def test_unbound_zero_spend_unknown_history(self):
        alloc = admission.load_allocation()
        self.assertEqual(alloc["candidate_attempts"]["used"], 0)
        self.assertEqual(
            alloc["candidate_attempts"]["consume_at"],
            "first new candidate-native invocation",
        )
        self.assertIsNone(alloc["historical_accounts"]["spent"])
        self.assertIsNone(alloc["historical_accounts"]["remaining"])
        self.assertEqual(alloc["historical_accounts"]["status"], "UNKNOWN_WHERE_UNRECOVERED")
        self.assertEqual(alloc["new_game_outcomes_in_this_planner_pass"], 0)
        self.assertIsNone(alloc["binding_receipt"])


class EmpiricalGateTests(unittest.TestCase):
    def test_empirical_cannot_select_synthetic_context(self):
        packet, ctx = good()
        packet["mode"] = "empirical"
        result = run(packet, ctx)
        self.assertEqual(result["integrity"], "BLOCKED")
        self.assertEqual(result["reason"], "empirical_cannot_select_synthetic_context")
        self.assertFalse(result["certificate"])

    def test_empirical_without_receipts_blocked(self):
        packet, ctx = se.build_bundle(context_kind="empirical")
        self.assertEqual(ctx.kind, "empirical")
        self.assertFalse(ctx.has_required_empirical_receipts())
        result = run(packet, ctx)
        self.assertEqual(result["integrity"], "BLOCKED")
        self.assertEqual(result["reason"], "empirical_missing_binding_freeze_receipts")
        self.assertFalse(result["certificate"])
        self.assertEqual(result["game_outcome_rows"], 0)

    def test_missing_context_blocked(self):
        packet, _ = good()
        result = admission.evaluate_packet(packet)
        self.assertEqual(result["integrity"], "BLOCKED")
        self.assertEqual(result["reason"], "missing_trusted_context")


class IdentityRuleTests(unittest.TestCase):
    def test_same_signed_B_across_panels_passes(self):
        packet, ctx = good()
        a_b = packet["identities"]["policies"]["A"]["B"]
        b_b = packet["identities"]["policies"]["B"]["B"]
        self.assertEqual(a_b, b_b)
        self.assertEqual(a_b, packet["identities"]["signed_B"])
        result = run(packet, ctx)
        self.assertEqual(result["integrity"], "PASS", result)

    def test_k_disagreement_requires_legal_action_difference(self):
        packet, ctx = good()
        pre = se.load_json(ctx, "synth://preflight")
        for row in pre:
            row["action_B"] = row["action_A"]
        se.store_json(ctx, "synth://preflight", pre)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "panel_disagreement")
        packet2, ctx2 = good()
        self.assertEqual(run(packet2, ctx2)["integrity"], "PASS")

    def test_k_hash_difference_without_action_difference_fails(self):
        packet, ctx = good()
        self.assertNotEqual(
            packet["identities"]["policies"]["A"]["K1"],
            packet["identities"]["policies"]["B"]["K1"],
        )
        pre = se.load_json(ctx, "synth://preflight")
        for row in pre:
            if row["arm"] == "K1":
                row["action_B"] = row["action_A"]
        se.store_json(ctx, "synth://preflight", pre)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "panel_disagreement")


class RootManifestTests(unittest.TestCase):
    def test_missing_development_manifest(self):
        packet, ctx = good()
        del packet["evidence"]["development_manifest"]
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "missing_development_manifest")

    def test_same_roots_across_vows(self):
        packet, ctx = good()
        a0 = se.load_json(ctx, "synth://factual/A/v0")
        a5 = se.load_json(ctx, "synth://factual/A/v5")
        a5["roots"] = a0["roots"][:]
        a5["crn_roots"] = {arm: a0["roots"][:] for arm in admission.ARMS}
        se.store_json(ctx, "synth://factual/A/v5", a5)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "root_collision")

    def test_panel_root_overlap(self):
        packet, ctx = good()
        a0 = se.load_json(ctx, "synth://factual/A/v0")
        b0 = se.load_json(ctx, "synth://factual/B/v0")
        b0["roots"] = a0["roots"][:]
        b0["crn_roots"] = {arm: a0["roots"][:] for arm in admission.ARMS}
        se.store_json(ctx, "synth://factual/B/v0", b0)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "panel_root_overlap")

    def test_dev_confirm_overlap(self):
        packet, ctx = good()
        fac = se.load_json(ctx, "synth://factual/A/v0")
        dev = se.load_json(ctx, "synth://development")
        dev["roots"]["A/v0"] = [fac["roots"][0]]
        se.store_json(ctx, "synth://development", dev)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "dev_confirm_overlap")


class ProvenanceRecordTests(unittest.TestCase):
    def test_nonexistent_locators(self):
        packet, ctx = good()
        for key in list(packet["evidence"]["factual"]):
            packet["evidence"]["factual"][key] = "native://does-not-exist#999999"
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "missing_source_raw")
        self.assertEqual(result["integrity"], "REJECT")

    def test_wrong_product_bytes(self):
        packet, ctx = good()
        ctx.store["synth://product"] = se.dumps({"label": "other-product"})
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "product_identity")

    def test_packet_well_formed_hash_does_not_replace_bytes(self):
        packet, ctx = good()
        packet["identities"]["product"] = "f" * 64
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "product_identity")

    def test_missing_authority(self):
        packet, ctx = good()
        del packet["authority"]
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "missing_authority")

    def test_wrong_epoch(self):
        packet, ctx = good()
        packet["epoch"] = "OTHER-EPOCH"
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "epoch_mismatch")

    def test_repair_product_bytes(self):
        packet, ctx = good()
        original = ctx.store["synth://product"]
        ctx.store["synth://product"] = se.dumps({"label": "other-product"})
        self.assertEqual(run(drop_rows(copy.deepcopy(packet)), ctx)["reason"], "product_identity")
        ctx.store["synth://product"] = original
        self.assertEqual(run(packet, ctx)["integrity"], "PASS")


class ConsistencyTests(unittest.TestCase):
    def test_b_zero_wins_with_rb_losses(self):
        packet, ctx = good()
        se.mutate_factual_bits(ctx, "A", 0, "B.win", se.ones(N, 0))
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "rb_loss_exceeds_B_win")

    def test_implied_r_wins_via_gain(self):
        packet, ctx = good()
        se.mutate_factual_bits(ctx, "A", 0, "R_B.gain", se.ones(N, 2000))
        result = run(drop_rows(packet), ctx)
        self.assertIn(result["reason"], ("rb_gain_exceeds_B_loss", "implied_R_wins"))

    def test_exclusive_exceeds_enact(self):
        packet, ctx = good()
        se.mutate_peer_bits(ctx, "A", 0, "pair12/exclusive_k", se.ones(N, 1500))
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "exclusive_exceeds_enact")

    def test_blind_loss_exceeds_full_incorrect(self):
        packet, ctx = good()
        se.mutate_meas_bits(ctx, "A", 0, 1, "blind_on.loss", se.ones(N_MEAS, 20))
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "blind_loss_exceeds_full_incorrect")

    def test_summary_mismatch_is_not_provenance(self):
        packet, ctx = good()
        for row in packet["rows"]:
            if row["key"] == "A/v0/B.win":
                row["successes"] = 0
                break
        result = run(packet, ctx)
        self.assertEqual(result["reason"], "summary_mismatch")

    def test_repair_exclusive(self):
        packet, ctx = good()
        se.mutate_peer_bits(ctx, "A", 0, "pair12/exclusive_k", se.ones(N, 1500))
        self.assertEqual(run(drop_rows(copy.deepcopy(packet)), ctx)["reason"], "exclusive_exceeds_enact")
        packet2, ctx2 = good()
        self.assertEqual(run(packet2, ctx2)["integrity"], "PASS")


class MeasurementProvenanceTests(unittest.TestCase):
    def test_invalid_ground_truth_native_mismatch(self):
        packet, ctx = good()
        meas = se.load_json(ctx, "synth://meas/A/v0/K1")
        meas["on_native"][0] = 0
        se.store_json(ctx, "synth://meas/A/v0/K1", meas)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "invalid_ground_truth")

    def test_all_abstain_from_predictions(self):
        packet, ctx = good()
        meas = se.load_json(ctx, "synth://meas/A/v0/K1")
        meas["on_pred"] = [-1] * N_MEAS
        se.store_json(ctx, "synth://meas/A/v0/K1", meas)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "all_abstain")

    def test_selection_not_first_eligible(self):
        packet, ctx = good()
        meas = se.load_json(ctx, "synth://meas/A/v0/K1")
        fac = se.load_json(ctx, "synth://factual/A/v0")
        enact = fac["bits"]["K1/enact"]
        later = [fac["roots"][i] for i, flag in enumerate(enact) if flag][10:10 + N_MEAS]
        meas["roots"] = later
        se.store_json(ctx, "synth://meas/A/v0/K1", meas)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "measurement_selection")

    def test_full_equals_blind_from_model(self):
        packet, ctx = good()
        model = se.load_json(ctx, "synth://model")
        model["blind_features"] = list(model["full_features"])
        se.store_json(ctx, "synth://model", model)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "full_equals_blind")

    def test_identical_traces_renamed(self):
        packet, ctx = good()
        fac = se.load_json(ctx, "synth://factual/A/v0")
        fac["behavior"]["K2"] = list(fac["behavior"]["K1"])
        se.store_json(ctx, "synth://factual/A/v0", fac)
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "identical_traces_renamed")

    def test_stratum_key_swap(self):
        packet, ctx = good()
        packet["evidence"]["factual"]["A/v0"] = "synth://factual/B/v0"
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "stratum_key_mismatch")


class AllocationTests(unittest.TestCase):
    def _alloc(self, mutator):
        packet, ctx = good()
        mutator(packet["allocation"])
        se.store_json(ctx, "synth://allocation", packet["allocation"])
        return run(drop_rows(packet), ctx)

    def test_status_approved_rejected(self):
        result = self._alloc(lambda a: a.__setitem__("status", "APPROVED"))
        self.assertEqual(result["reason"], "allocation_template")

    def test_cpu_cap_inflated(self):
        result = self._alloc(lambda a: a["limits"].__setitem__("cpu_seconds", 10**15))
        self.assertEqual(result["reason"], "allocation_template")

    def test_alpha_committed_inflated(self):
        result = self._alloc(lambda a: a["alpha"]["542"].__setitem__("committed", 999))
        self.assertEqual(result["reason"], "allocation_alpha")

    def test_548_reserve_inflated(self):
        result = self._alloc(lambda a: a["alpha"]["548"].__setitem__("spendable", 0.025))
        self.assertIn(result["reason"], ("alpha_548_borrow", "allocation_template"))

    def test_interval_slots_changed(self):
        result = self._alloc(lambda a: a["alpha"].__setitem__("interval_slots_542", 128))
        self.assertEqual(result["reason"], "allocation_template")

    def test_fabricated_review_receipt(self):
        result = self._alloc(lambda a: a.__setitem__("binding_receipt", {"artifact": "other"}))
        self.assertEqual(result["reason"], "fabricated_binding")

    def test_negative_event(self):
        events = [{
            "event_id": "e1",
            "candidate": "cand-x",
            "stage": "preflight",
            "count": -1,
            "cpu": 0.0,
            "elapsed": 1.0,
            "raw": 0,
        }]
        packet, ctx = se.build_bundle(events=events, ledger_bound=True)
        result = run(drop_rows(packet), ctx)
        self.assertIn(result["reason"], ("allocation_event", "schema_integrity"))

    def test_event_fold_idempotent_readback(self):
        event = {
            "event_id": "e1",
            "candidate": "cand-x",
            "stage": "preflight",
            "count": 2,
            "cpu": 1.0,
            "elapsed": 5.0,
            "raw": 8,
        }
        usage = {
            "cpu_seconds": 1.0,
            "active_elapsed_seconds": 5.0,
            "raw_emitted_bytes_cumulative": 8,
        }
        native_used = {"preflight": 2, "development": 0, "confirmation": 0, "counterfactual": 0}
        packet, ctx = se.build_bundle(
            events=[event, copy.deepcopy(event)],
            ledger_bound=True,
            usage=usage,
            native_used=native_used,
        )
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["integrity"], "PASS", result)

    def test_distinct_execution_not_identical_readback(self):
        e1 = {
            "event_id": "e1",
            "candidate": "cand-x",
            "stage": "preflight",
            "count": 1,
            "cpu": 1.0,
            "elapsed": 5.0,
            "raw": 4,
        }
        e2 = {
            "event_id": "e2",
            "candidate": "cand-x",
            "stage": "preflight",
            "count": 1,
            "cpu": 1.0,
            "elapsed": 6.0,
            "raw": 4,
        }
        usage = {
            "cpu_seconds": 1.0,
            "active_elapsed_seconds": 5.0,
            "raw_emitted_bytes_cumulative": 4,
        }
        native_used = {"preflight": 1, "development": 0, "confirmation": 0, "counterfactual": 0}
        packet, ctx = se.build_bundle(
            events=[e1, e2],
            ledger_bound=True,
            usage=usage,
            native_used=native_used,
        )
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "allocation_event")

    def test_conflicting_receipt(self):
        e1 = {
            "event_id": "e1",
            "candidate": "cand-x",
            "stage": "preflight",
            "count": 1,
            "cpu": 0.0,
            "elapsed": 1.0,
            "raw": 0,
        }
        e1b = dict(e1)
        e1b["count"] = 2
        packet, ctx = se.build_bundle(
            events=[e1, e1b],
            ledger_bound=True,
            usage={"cpu_seconds": 0.0, "active_elapsed_seconds": 1.0, "raw_emitted_bytes_cumulative": 0},
            native_used={"preflight": 1, "development": 0, "confirmation": 0, "counterfactual": 0},
        )
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["reason"], "allocation_event")

    def test_malformed_row_missing_successes(self):
        packet, ctx = good()
        packet["rows"][0] = {"key": packet["rows"][0]["key"], "n": N}
        result = run(packet, ctx)
        self.assertEqual(result["integrity"], "REJECT")
        self.assertIn(result["reason"], ("schema_integrity", "sample_size"))
        self.assertNotIn("exception", result)

    def test_bool_in_exposed_seeds(self):
        packet, ctx = good()
        packet["exposed_seeds"] = [True]
        result = run(drop_rows(packet), ctx)
        self.assertEqual(result["integrity"], "REJECT")
        self.assertEqual(result["reason"], "schema_integrity")


class KernelWiringTests(unittest.TestCase):
    """Exact 152 keys plus fail/straddle against the restored numerical kernel."""

    def test_good_keys_match_kernel(self):
        packet, ctx = good()
        result = run(packet, ctx)
        self.assertEqual(len(result["predicates"]), 152)
        expected = admission._predicates(packet["rows"])
        self.assertEqual(result["predicates"], expected)

    def _override_result(self, overrides):
        packet, ctx = se.build_bundle(stratum_overrides=overrides)
        return run(packet, ctx), packet

    def test_b_ceiling_fail_matches_kernel(self):
        overrides = {("A", 0): {"B.win": 1300, "R_B.gain": 400, "R_B.loss": 40}}
        result, packet = self._override_result(overrides)
        expected = kernel.decide(kernel.interval(1300, N), 0.50, "<")
        self.assertEqual(result["predicates"]["A/v0/B_ceiling"], expected)
        self.assertEqual(result["reason"], "PREDICATE_NOT_PASS")
        self.assertIn("A/v0/B_ceiling", result["failed_predicates"])
        self.assertFalse(result["certificate"])

    def test_b_ceiling_straddle_matches_kernel(self):
        overrides = {("A", 0): {"B.win": 1000, "R_B.gain": 400, "R_B.loss": 40}}
        result, _ = self._override_result(overrides)
        expected = kernel.decide(kernel.interval(1000, N), 0.50, "<")
        self.assertEqual(result["predicates"]["A/v0/B_ceiling"], expected)

    def test_strict_b_boundary_not_pass_at_half(self):
        overrides = {("A", 0): {"B.win": 1024, "R_B.gain": 400, "R_B.loss": 40}}
        result, _ = self._override_result(overrides)
        expected = kernel.decide(kernel.interval(1024, N), 0.50, "<")
        self.assertEqual(result["predicates"]["A/v0/B_ceiling"], expected)
        self.assertNotEqual(expected, "PASS")

    def test_r_minus_b_fail_and_straddle(self):
        fail = {("A", 0): {"B.win": 512, "R_B.gain": 400, "R_B.loss": 100}}
        result, _ = self._override_result(fail)
        expected = kernel.decide(kernel.paired(400, 100, N), 0.35, ">=")
        self.assertEqual(result["predicates"]["A/v0/R_minus_B"], expected)
        straddle = {("A", 0): {"B.win": 512, "R_B.gain": 700, "R_B.loss": 50}}
        result, _ = self._override_result(straddle)
        expected = kernel.decide(kernel.paired(700, 50, N), 0.35, ">=")
        self.assertEqual(result["predicates"]["A/v0/R_minus_B"], expected)

    def test_quality_fail_and_straddle(self):
        fail = {("A", 0): {"K": {1: {"K_R.gain": 50, "K_R.loss": 600}}}}
        result, _ = self._override_result(fail)
        expected = kernel.decide(kernel.paired(50, 600, N), -0.10, ">=")
        self.assertEqual(result["predicates"]["A/v0/K1/quality"], expected)
        straddle = {("A", 0): {"K": {1: {"K_R.gain": 250, "K_R.loss": 400}}}}
        result, _ = self._override_result(straddle)
        expected = kernel.decide(kernel.paired(250, 400, N), -0.10, ">=")
        self.assertEqual(result["predicates"]["A/v0/K1/quality"], expected)

    def test_acquire_enact_win_enact_families(self):
        fail = {("A", 0): {"K": {1: {"acquire": 400, "enact": 400, "win_enact": 100, "exclusive": {2: 100, 3: 100}}}}}
        result, _ = self._override_result(fail)
        self.assertEqual(
            result["predicates"]["A/v0/K1/acquire"],
            kernel.decide(kernel.interval(400, N), 0.30, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/K1/win_enact"],
            kernel.decide(kernel.interval(100, N), 0.10, ">="),
        )
        straddle = {("A", 0): {"K": {1: {"acquire": 600, "enact": 512, "win_enact": 150}}}}
        result, _ = self._override_result(straddle)
        self.assertEqual(
            result["predicates"]["A/v0/K1/acquire"],
            kernel.decide(kernel.interval(600, N), 0.30, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/K1/enact"],
            kernel.decide(kernel.interval(512, N), 0.25, ">="),
        )

    def test_measurement_families(self):
        fail = {("A", 0): {"K": {1: {
            "on.correct": 100,
            "off.correct": 180,
            "natural_negative.not_negative": 40,
            "blind_on.gain": 0,
            "blind_on.loss": 0,
            "blind_off.gain": 0,
            "blind_off.loss": 0,
        }}}}
        result, _ = self._override_result(fail)
        self.assertEqual(
            result["predicates"]["A/v0/K1/on"],
            kernel.decide(kernel.interval(100, N_MEAS), 0.80, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/K1/blind_gain"],
            kernel.decide(kernel.balanced_gain(0, 0, 0, 0), 0.10, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/K1/off"],
            kernel.decide(kernel.interval(180, N_MEAS), 0.90, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/K1/natural_null"],
            kernel.decide(kernel.interval(40, N_MEAS), 0.05, "<="),
        )
        straddle = {("A", 0): {"K": {1: {
            "on.correct": 200,
            "off.correct": 230,
            "natural_negative.not_negative": 20,
            "blind_on.gain": 128,
            "blind_on.loss": 0,
        }}}}
        result, _ = self._override_result(straddle)
        self.assertEqual(
            result["predicates"]["A/v0/K1/on"],
            kernel.decide(kernel.interval(200, N_MEAS), 0.80, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/K1/off"],
            kernel.decide(kernel.interval(230, N_MEAS), 0.90, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/K1/natural_null"],
            kernel.decide(kernel.interval(20, N_MEAS), 0.05, "<="),
        )

    def test_peer_families(self):
        fail = {("A", 0): {"K": {1: {"correct": 1400, "exclusive": {2: 100, 3: 100}}}}}
        result, _ = self._override_result(fail)
        self.assertEqual(
            result["predicates"]["A/v0/pair12/correct_k"],
            kernel.decide(kernel.interval(1400, N), 0.75, ">="),
        )
        self.assertEqual(
            result["predicates"]["A/v0/pair12/exclusive_k"],
            kernel.decide(kernel.interval(100, N), 0.10, ">="),
        )
        straddle = {("A", 0): {"K": {1: {"correct": 1600, "exclusive": {2: 200, 3: 200}}}}}
        result, _ = self._override_result(straddle)
        self.assertEqual(
            result["predicates"]["A/v0/pair12/correct_k"],
            kernel.decide(kernel.interval(1600, N), 0.75, ">="),
        )

    def test_one_stratum_failure_is_not_averaged(self):
        overrides = {("B", 5): {"B.win": 1300, "R_B.gain": 400, "R_B.loss": 40}}
        result, _ = self._override_result(overrides)
        self.assertEqual(result["reason"], "PREDICATE_NOT_PASS")
        self.assertIn("B/v5/B_ceiling", result["failed_predicates"])
        self.assertEqual(result["predicates"]["A/v0/B_ceiling"], "PASS")
        self.assertEqual(
            result["predicates"]["B/v5/B_ceiling"],
            kernel.decide(kernel.interval(1300, N), 0.50, "<"),
        )


class NumericalMutantTests(unittest.TestCase):
    def test_constant_pass_predicates_fail_focused_suite(self):
        original = admission._predicates

        def fake_predicates(rows):
            names = tuple(original(rows))
            mapped = {row["key"]: row["successes"] for row in rows}
            fabricated = {key: "PASS" for key in names}
            if mapped.get("A/v0/B.win", 0) > 1000:
                fabricated["A/v0/B_ceiling"] = "FAIL"
            if mapped.get("A/v0/K1/K_R.gain", 0) < 100:
                fabricated["A/v0/K1/quality"] = "FAIL"
            return fabricated

        admission._predicates = fake_predicates
        try:
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(KernelWiringTests)
            result = unittest.TextTestRunner(stream=io.StringIO(), verbosity=0).run(suite)
            self.assertFalse(result.wasSuccessful())
            self.assertGreater(len(result.failures) + len(result.errors), 0)
        finally:
            admission._predicates = original


class CountDerivationTests(unittest.TestCase):
    def test_derived_counts_match_passing_rows(self):
        packet, ctx = good()
        records = admission._ingest_resolved_records(packet, ctx)
        counts = admission._derive_counts(records)
        expected = {row["key"]: row["successes"] for row in admission.passing_rows()}
        self.assertEqual(counts, expected)
        self.assertEqual(len(counts), 204)
