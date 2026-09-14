"""Label-blind D547-PC1 synthetic controls. Drive the shipped entry point."""
from __future__ import annotations

import copy
import io
import os
import unittest

import prospective_admission as admission
import reference_kernel as kernel

HERE = os.path.dirname(os.path.abspath(__file__))


def _set_row(packet, key, successes=None, n=None, new_key=None):
    out = copy.deepcopy(packet)
    for row in out["rows"]:
        if row["key"] == key:
            if successes is not None:
                row["successes"] = successes
            if n is not None:
                row["n"] = n
            if new_key is not None:
                row["key"] = new_key
            return out
    raise AssertionError(key)


def _faults():
    """Mutators and expected reasons live here, not inside evaluate_packet input."""
    good = admission.good_packet()
    exposed = good["roots"]["A/v0"]["R"][0]
    alias = copy.deepcopy(good)
    alias["roots"]["A/v0"]["K1"][0] = alias["roots"]["A/v0"]["K1"][1] + 2**32
    crn = copy.deepcopy(good)
    crn["roots"]["A/v0"]["K1"][0] = 99_999_999
    missing = copy.deepcopy(good)
    missing["rows"].pop()
    overlap = copy.deepcopy(good)
    overlap["development_roots"] = [good["roots"]["A/v0"]["R"][0]]
    panel_overlap = copy.deepcopy(good)
    panel_overlap["roots"]["B/v0"]["R"] = good["roots"]["A/v0"]["R"][:]
    panel_overlap["roots"]["B/v0"]["B"] = good["roots"]["A/v0"]["B"][:]
    panel_overlap["roots"]["B/v0"]["K1"] = good["roots"]["A/v0"]["K1"][:]
    panel_overlap["roots"]["B/v0"]["K2"] = good["roots"]["A/v0"]["K2"][:]
    panel_overlap["roots"]["B/v0"]["K3"] = good["roots"]["A/v0"]["K3"][:]
    return [
        ("fabricated_binding", {**copy.deepcopy(good), "bound": True}, "fabricated_binding"),
        ("approved_flag", {**copy.deepcopy(good), "approved": True}, "fabricated_binding"),
        ("empirical_test_verifier", {**copy.deepcopy(good), "mode": "empirical"}, "empirical_test_verifier"),
        ("identity_hash", admission.with_fault(good, ("identities", "product"), "not-a-hash"), "identity_hash"),
        ("exposed_root", {**copy.deepcopy(good), "exposed_seeds": [exposed]}, "exposed_protected_root"),
        ("protected_root", {**copy.deepcopy(good), "roots": _inject_protected(good)}, "exposed_protected_root"),
        ("seed_alias", alias, "root_duplicates"),
        ("crn_mismatch", crn, "crn_mismatch"),
        ("win_enact_order", _set_row(good, "A/v0/K1/win_enact", successes=1000), "win_enact_order"),
        ("incomplete_registry", missing, "incomplete_registry"),
        ("foreign_metric", _set_row(good, "A/v0/B.win", new_key="detector/accuracy"), "undeclared_or_duplicate_metric"),
        ("historical_credit", {**copy.deepcopy(good), "credit_from_history": True}, "historical_credit"),
        ("alpha_548_borrow", {**copy.deepcopy(good), "borrow_548": True}, "alpha_548_borrow"),
        ("second_candidate", {**copy.deepcopy(good), "second_candidate": True}, "second_candidate"),
        ("top_up", {**copy.deepcopy(good), "top_up": True}, "top_up"),
        ("leaked_features", admission.with_fault(good, ("features", "names"), ["win_rate", "seed_id"]), "leaked_features"),
        ("cost_unmatched", _unmatched_cost(good), "cost_unmatched"),
        ("privileged_information", _privileged(good), "privileged_information"),
        ("missing_source_raw", {**copy.deepcopy(good), "source_raw_complete": False}, "missing_source_raw"),
        ("panel_disagreement", admission.with_fault(good, ("panel_disagreement", "decision_B"), "play:chisel"), "panel_disagreement"),
        ("dev_confirm_overlap", overlap, "dev_confirm_overlap"),
        ("panel_root_overlap", panel_overlap, "panel_root_overlap"),
        ("missing_exposure", {**copy.deepcopy(good), "exposed_seeds": None}, "missing_exposure_authority"),
        ("game_outcomes", {**copy.deepcopy(good), "game_outcome_rows": 1}, "game_outcomes"),
        ("label_in_input", {**copy.deepcopy(good), "role": "form_ok"}, "label_in_decision_input"),
        ("identical_traces_renamed", {**copy.deepcopy(good), "identical_traces_renamed": True}, "identical_traces_renamed"),
        ("invalid_ground_truth", {**copy.deepcopy(good), "invalid_ground_truth": True}, "invalid_ground_truth"),
        ("all_abstain", {**copy.deepcopy(good), "all_abstain": True}, "all_abstain"),
        ("full_equals_blind", {**copy.deepcopy(good), "full_equals_blind": True}, "full_equals_blind"),
        ("weak_B_ceiling", _set_row(good, "A/v0/B.win", successes=1300), "PREDICATE_NOT_PASS"),
        ("quality_fail", _set_row(good, "A/v0/K1/K_R.gain", successes=50), "PREDICATE_NOT_PASS"),
        ("attempt_spent", _spent_attempt(good), "candidate_attempt_spent"),
        ("bool_count", _set_row(good, "A/v0/B.win", successes=True), "sample_size"),
    ]


def _inject_protected(good):
    roots = copy.deepcopy(good["roots"])
    roots["A/v0"]["R"][0] = 3000
    return roots


def _unmatched_cost(good):
    packet = copy.deepcopy(good)
    packet["cost"]["K1"]["forward_evals_per_decision"] = 64
    return packet


def _privileged(good):
    packet = copy.deepcopy(good)
    packet["cost"]["R"]["hidden_rng"] = True
    return packet


def _spent_attempt(good):
    packet = copy.deepcopy(good)
    packet["allocation"]["candidate_attempts"]["used"] = 1
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
        packet = admission.good_packet()
        self.assertNotIn("role", packet)
        self.assertNotIn("id", packet)
        result = admission.evaluate_packet(packet)
        self.assertEqual(result["reason"], "SYNTHETIC_PACKET_WELL_FORMED", result)
        self.assertEqual(result["integrity"], "PASS")
        self.assertTrue(result["predicates"])
        self.assertTrue(all(v == "PASS" for v in result["predicates"].values()))
        self.assertFalse(result["certificate"])
        self.assertEqual(result["game_outcome_rows"], 0)
        self.assertEqual(len(result["predicates"]), 152)

    def test_single_fault_and_repair(self):
        good = admission.good_packet()
        baseline = admission.evaluate_packet(good)
        self.assertEqual(baseline["integrity"], "PASS")
        for name, packet, reason in _faults():
            with self.subTest(name=name):
                result = admission.evaluate_packet(packet)
                self.assertEqual(result["reason"], reason, (name, result))
                if reason == "PREDICATE_NOT_PASS":
                    self.assertEqual(result["integrity"], "PASS")
                    self.assertTrue(result["failed_predicates"])
                else:
                    self.assertEqual(result["integrity"], "REJECT")
                self.assertFalse(result["certificate"])
                self.assertEqual(result["game_outcome_rows"], 0)
                repaired = admission.evaluate_packet(copy.deepcopy(good))
                self.assertEqual(repaired["integrity"], "PASS", name)
                self.assertNotIn("failed_predicates", repaired)

    def test_role_injection_does_not_rescue_fault(self):
        good = admission.good_packet()
        labelled = {**copy.deepcopy(good), "role": "form_ok"}
        self.assertEqual(admission.evaluate_packet(labelled)["reason"], "label_in_decision_input")
        bad = {**copy.deepcopy(good), "bound": True}
        self.assertEqual(admission.evaluate_packet(bad)["reason"], "fabricated_binding")


def _author_gate_suite():
    return unittest.defaultTestLoader.loadTestsFromTestCase(AuthorGateTests)


class LabelOnlySensitivityTests(unittest.TestCase):
    def test_label_only_replacement_fails_author_gate(self):
        original = admission.evaluate_packet

        def label_only(packet):
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
        "exposed_protected_root": "        _check_roots(packet)\n",
        "win_enact_order": "        _check_counts(packet)\n",
        "leaked_features": "        _check_features(packet)\n",
        "cost_unmatched": "        _check_cost(packet)\n",
        "missing_source_raw": "        _check_source_raw(packet)\n",
        "historical_credit": "        _check_allocation(packet)\n",
        "label_in_decision_input": "        _require_no_labels(packet)\n",
    }

    def _mutant_evaluate(self, call):
        path = os.path.join(HERE, "prospective_admission.py")
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        self.assertEqual(text.count(call), 1, call)
        ns = {}
        exec(compile(text.replace(call, "        pass\n"), "<mutant>", "exec"), ns)
        return ns["evaluate_packet"], ns["good_packet"]

    def test_each_material_guard_is_load_bearing(self):
        mapping = {name: packet for name, packet, reason in _faults()}
        reasons = {name: reason for name, packet, reason in _faults()}
        probes = {
            "fabricated_binding": mapping["fabricated_binding"],
            "exposed_protected_root": mapping["exposed_root"],
            "win_enact_order": mapping["win_enact_order"],
            "leaked_features": mapping["leaked_features"],
            "cost_unmatched": mapping["cost_unmatched"],
            "missing_source_raw": mapping["missing_source_raw"],
            "historical_credit": mapping["historical_credit"],
            "label_in_decision_input": mapping["label_in_input"],
        }
        for guard, packet in probes.items():
            with self.subTest(guard=guard):
                real = admission.evaluate_packet(copy.deepcopy(packet))
                expected = reasons[
                    {
                        "exposed_protected_root": "exposed_root",
                        "label_in_decision_input": "label_in_input",
                    }.get(guard, guard)
                ]
                if guard == "exposed_protected_root":
                    expected = "exposed_protected_root"
                if guard == "label_in_decision_input":
                    expected = "label_in_decision_input"
                self.assertEqual(real["reason"], expected)
                mutant_eval, _ = self._mutant_evaluate(self.CALLS[guard])
                mutant = mutant_eval(copy.deepcopy(packet))
                self.assertNotEqual(mutant["reason"], expected, guard)


class AllocationTemplateTests(unittest.TestCase):
    def test_unbound_zero_spend_unknown_history(self):
        alloc = admission.load_allocation()
        self.assertEqual(alloc["candidate_attempts"]["used"], 0)
        self.assertEqual(alloc["candidate_attempts"]["consume_at"], "first new candidate-native invocation")
        self.assertIsNone(alloc["historical_accounts"]["spent"])
        self.assertIsNone(alloc["historical_accounts"]["remaining"])
        self.assertEqual(alloc["historical_accounts"]["status"], "UNKNOWN_WHERE_UNRECOVERED")
        self.assertEqual(alloc["new_game_outcomes_in_this_planner_pass"], 0)
        self.assertIsNone(alloc["binding_receipt"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
