"""Negative fixtures for the existing followup reader, never native trials."""
import copy
import json
import unittest
from pathlib import Path
from unittest.mock import patch
import read_followup as reader


class FollowupReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, _ = reader.unpack(reader.R, 'FOLLOWUP-MANIFEST.json', 'followup.parts')
        cls.original, _ = reader.unpack(reader.R, 'NATIVE-MANIFEST.json', 'native.parts')

    def reject(self, name, change, lines=False):
        files = copy.deepcopy(self.files)
        obj = reader.rows(files[name]) if lines else json.loads(files[name])
        change(obj)
        files[name] = (('\n'.join(json.dumps(r) for r in obj)+'\n') if lines else json.dumps(obj)).encode()
        with self.assertRaises((AssertionError, KeyError, ValueError)):
            reader.analyze(files, self.original)

    def test_complete(self):
        result = reader.analyze(self.files, self.original)
        self.assertEqual(result['locality_cases'], 60)
        self.assertEqual(result['omitted_field_mutations_detected'], 17)
        self.assertEqual(result['new_population_or_protected_samples'], 0)

    def test_changed_payoff(self):
        self.reject('locality/full-native.ndjson', lambda r:r[1].update(hp_removed=999), True)

    def test_missing_row(self):
        self.reject('locality/full-native.ndjson', lambda r:r.pop(1), True)

    def test_duplicate_row(self):
        self.reject('locality/full-native.ndjson', lambda r:r.__setitem__(2, r[1]), True)

    def test_unobserved_stagger(self):
        self.reject('locality/full-native.ndjson', lambda r:r[1]['before_fields'][1]['enemies'][0].update(staggered=False), True)

    def test_engine_mismatch(self):
        self.reject('locality/receipt.json', lambda r:r.update(engine_sha256='0'*64))

    def test_timeout(self):
        self.reject('locality/full-receipt.json', lambda r:r.update(elapsed_seconds=120))

    def test_nonzero_exit(self):
        self.reject('locality/receipt.json', lambda r:r.update(returncode=3))

    def test_diagnostic(self):
        files = dict(self.files); files['locality/full-stderr.log'] += b'\nSCRIPT ERROR\n'
        with self.assertRaises(AssertionError):reader.analyze(files, self.original)

    def test_missing_coverage(self):
        self.reject('state-coverage/coverage.ndjson', lambda r:r.pop(2), True)

    def test_forged_reexam(self):
        self.reject('state-coverage/reexam.ndjson', lambda r:r[-1].update(checks=676), True)

    def test_corrupt_part(self):
        original = Path.read_bytes
        def corrupted(path):
            data = original(path)
            return data[:-1] + bytes([data[-1]^1]) if path.name=='000.part' and path.parent.name=='followup.parts' else data
        with patch.object(Path, 'read_bytes', corrupted):
            with self.assertRaises(AssertionError):reader.unpack(reader.R, 'FOLLOWUP-MANIFEST.json', 'followup.parts')


if __name__ == '__main__':
    unittest.main()
