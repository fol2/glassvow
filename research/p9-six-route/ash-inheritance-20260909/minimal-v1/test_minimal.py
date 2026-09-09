"""Focused author-review regressions, not independent scientific confirmation."""
import ast
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
import build

spec = importlib.util.spec_from_file_location('proof_read', Path(__file__).with_name('read.py'))
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


class Contracts(unittest.TestCase):
    def test_wrong_content_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, 'BASE_CONTENT'):
            build.candidate_content(b'{}', {})

    def test_wrong_combat_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, 'BASE_COMBAT'):
            build.patch_combat(b'extends RefCounted')

    def test_duplicate_anchor_fails(self):
        with self.assertRaisesRegex(ValueError, 'PATCH_ANCHOR'):
            build.once('aa', 'a', 'b')

    def test_missing_anchor_fails(self):
        with self.assertRaisesRegex(ValueError, 'PATCH_ANCHOR'):
            build.once('b', 'a', 'c')

    def test_patch_exactly_once(self):
        self.assertEqual(build.once('abc', 'b', 'x'), 'axc')

    def test_missing_matrix_not_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError):
                r.analyse(Path(tmp))

    def test_header_only_not_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / 'raw'
            folder.mkdir()
            (folder.parent / 'ASSEMBLY.json').write_text('{}')
            (folder / 'baseline.jsonl').write_text(json.dumps({'kind': 'manifest', 'mode': 'baseline'}) + '\n')
            with self.assertRaisesRegex(ValueError, 'INCOMPLETE_STREAM'):
                r.analyse(folder)

    def test_wrong_engine_not_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / 'raw'
            folder.mkdir()
            (folder.parent / 'ASSEMBLY.json').write_text('{}')
            rows = [{'kind': 'manifest', 'mode': 'baseline', 'engine': 'unqualified'},
                    {'kind': 'terminal', 'cases': 60}]
            (folder / 'baseline.jsonl').write_text('\n'.join(map(json.dumps, rows)) + '\n')
            with self.assertRaisesRegex(ValueError, 'ENGINE'):
                r.analyse(folder)

    def test_stock_absence_is_zero(self):
        self.assertEqual(r.stock({'combat': {'player': {'statuses': {}}}}), 0)

    def test_hit_only_not_status(self):
        self.assertEqual(r.hits({'events': [{'t': 'status', 'n': 2}]}), [])

    def test_seed_scope_not_protected(self):
        protocol = json.loads(Path(__file__).with_name('PROTOCOL.json').read_bytes())
        self.assertGreater(protocol['fixture_seed'], 5399)
        self.assertEqual(protocol['cases'], 360)

    def test_original_command_and_turn_envelopes_not_replaced(self):
        code = Path(build.__file__).read_text()
        self.assertNotIn('func play_card', code)
        self.assertNotIn('func end_turn', code)
        self.assertNotIn('func _shatter_enemy', code)

    def test_selected_hash_is_not_harness_hash(self):
        self.assertNotEqual(build.SELECTED, 'e475482c76a405814dba4638860bb799f610a220fcde5d931c78d1a447e18f48')

    def test_no_history_exec(self):
        tree = ast.parse(Path(build.__file__).read_text())
        calls = [node.func.id for node in ast.walk(tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)]
        self.assertNotIn('exec', calls)
        self.assertNotIn('eval', calls)

    def test_precise_matrix_not_policy_population(self):
        self.assertEqual(len(r.MODES), 6)
        self.assertEqual(len(set(r.MODES)), 6)
        self.assertEqual(len(r.CONTEXTS), 6)
        self.assertIn('source_lethal', r.CONTEXTS)


if __name__ == '__main__':
    unittest.main()
