import copy
import json
from pathlib import Path
import tempfile
import unittest
import restore_packet as r


class RestoreTests(unittest.TestCase):
    def nodes(self):
        return [['v', 'int', n] for n in range(8621)]

    def test_missing_node_rejected(self):
        with self.assertRaisesRegex(ValueError, 'COMPLETE_NODE_TABLE'):
            r.decode_nodes(self.nodes()[:-1])

    def test_type_confusion_rejected(self):
        n = self.nodes(); n[0] = ['v', 'int', True]
        with self.assertRaisesRegex(ValueError, 'VALUE_TYPE'): r.decode_nodes(n)

    def test_forward_reference_rejected(self):
        n = self.nodes(); n[0] = ['a', [0]]
        with self.assertRaisesRegex(ValueError, 'FORWARD_REFERENCE'): r.decode_nodes(n)

    def test_duplicate_dictionary_keys_rejected(self):
        n = self.nodes(); n[0] = ['v', 'str', 'key']; n[2] = ['d', [[0, 1], [0, 1]]]
        with self.assertRaisesRegex(ValueError, 'DICT_KEYS'): r.decode_nodes(n)

    def test_path_boundaries(self):
        for path in ('../a', '/a', 'a/../b', 'a//b', '', None):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'UNSAFE_PATH'):
                r.safe_path(path)
        self.assertEqual(r.safe_path('execution-1/raw.xz'), Path('execution-1/raw.xz'))

    def test_wrong_supplement_fails_before_output(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / 'output'
            with self.assertRaisesRegex(ValueError, 'SUPPLEMENT_IDENTITY'):
                r.restore([], b'wrong', Path(d), out)
            self.assertFalse(out.exists())

    def test_existing_output_not_overwritten(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(ValueError, 'OUTPUT_EXISTS'):
                r.restore([], b'wrong', Path(d), Path(d))

    def test_retained_prefix_hash_checked(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d); (p/'part-000.xzpart').write_text('invalid\n')
            with self.assertRaisesRegex(ValueError, 'PREFIX_BLOB:0'): r.retained_nodes(p)

    def test_typed_value_and_collection(self):
        n=self.nodes();n[0]=['v','str','key'];n[1]=['v','float',1.0];n[2]=['d',[[0,1]]];n[3]=['a',[2]]
        self.assertEqual(r.decode_nodes(n)[3],[{'key':1.0}])


if __name__=='__main__': unittest.main(verbosity=2)
