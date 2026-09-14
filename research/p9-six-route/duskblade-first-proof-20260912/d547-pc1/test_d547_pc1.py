"""Drive the shipped D547-PC1 validator on shipped fixtures. Not game outcomes."""
import json
import os
import unittest

import validator

HERE = os.path.dirname(os.path.abspath(__file__))

REQUIRED_BAD = frozenset(
    {
        "NC-MISSING-AUTHORITY",
        "NC-UNKNOWN-BUDGET-AS-AVAILABLE",
        "NC-UNKNOWN-BUDGET-AS-EXHAUSTED",
        "NC-SCOPE-LIMITED-COUNTS-AS-CERTIFICATE",
        "NC-HAND-COUNTS-AS-CERTIFICATE",
        "NC-POST-V38-COUNTS-AS-CERTIFICATE",
        "NC-IDENTITY-ONLY-DESCRIPTOR",
        "NC-UNQUALIFIED-POLICY",
        "NC-PRIVILEGED-POLICY",
        "NC-COST-UNMATCHED-POLICY",
        "NC-EXPOSED-UNIT-AS-FRESH",
        "NC-DUPLICATED-UNIT-AS-FRESH",
        "NC-MISSING-OUTCOMES",
        "NC-EXCEEDED-CAPS",
        "NC-REPEATED-RECEIPT",
        "NC-548-THRESHOLD-TRANSFER",
        "NC-WINNERS-ONLY-QUALITY",
        "NC-R14-AS-ADMISSION",
        "NC-V0-AS-FAILED",
    }
)


def _load():
    with open(os.path.join(HERE, "negative_control.json"), encoding="utf-8") as handle:
        batch = json.load(handle)
    with open(os.path.join(HERE, "ledger.json"), encoding="utf-8") as handle:
        ledger = json.load(handle)
    return batch, ledger


class D547PC1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.batch, cls.ledger = _load()
        cls.results = {
            case["id"]: validator.validate(case, cls.ledger)
            for case in cls.batch["cases"]
        }

    def test_required_known_bad_ids_present(self):
        ids = {case["id"] for case in self.batch["cases"] if case["role"] == "known_bad"}
        self.assertTrue(REQUIRED_BAD <= ids, REQUIRED_BAD - ids)

    def test_known_bad_rejected_not_admitted(self):
        for case in self.batch["cases"]:
            if case["role"] != "known_bad":
                continue
            result = self.results[case["id"]]
            self.assertEqual(result["verdict"], "REJECT", case["id"])
            self.assertNotIn(result["verdict"], ("PASS", "ADMITTED", "CERTIFICATE"))
            self.assertFalse(result["certificate"])
            self.assertEqual(result["game_outcome_rows"], 0)

    def test_form_ok_is_not_certificate(self):
        result = self.results["NC-FORM-OK"]
        self.assertEqual(result["verdict"], "FORM_PASS")
        self.assertFalse(result["certificate"])
        self.assertEqual(result["game_outcome_rows"], 0)
        self.assertNotIn(result["verdict"], ("PASS", "ADMITTED", "CERTIFICATE"))

    def test_no_game_outcome_rows(self):
        for result in self.results.values():
            self.assertEqual(result["game_outcome_rows"], 0)
            self.assertEqual(result["godot_runs"], 0)

    def test_ledger_unknown_not_zero_historical(self):
        for family in self.ledger["families"].values():
            self.assertEqual(family["historical_balance"], "UNKNOWN")
        self.assertTrue(self.ledger["new_not_inherited"])
        obs = self.ledger["families"]["observation_compute_wall_time"]
        self.assertEqual(obs["this_batch_authorised_game_outcome_rows"], 0)


if __name__ == "__main__":
    unittest.main()
