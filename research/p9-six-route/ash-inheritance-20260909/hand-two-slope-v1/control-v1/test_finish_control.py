import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import finish_control as f


class Tests(unittest.TestCase):
    def test_known_integer_key_readout_fault_reproduced_and_resolved(self):
        actual={'paired_discordance':{0:127,-1:1},'difference':-.0078125}
        raw=f.wire(actual)
        self.assertNotEqual(actual,json.loads(raw))
        self.assertTrue(f.verify_wire(actual,raw))

    def test_changed_count_is_not_a_serialization_difference(self):
        actual={'paired_discordance':{0:127,-1:1}}
        saved={'paired_discordance':{0:128}}
        with self.assertRaisesRegex(ValueError,'EXACT_SERIALIZED_READOUT'):f.verify_wire(actual,f.wire(saved))

    def test_no_float_tolerance(self):
        with self.assertRaisesRegex(ValueError,'EXACT_SERIALIZED_READOUT'):f.verify_wire({'x':1e-9},f.wire({'x':0.}))

    def test_no_boolean_numeric_substitution(self):
        with self.assertRaisesRegex(ValueError,'EXACT_SERIALIZED_READOUT'):f.verify_wire({'gate':True},f.wire({'gate':1}))

    def test_string_mapping_is_already_equal(self):
        self.assertFalse(f.verify_wire({'x':{'0':3}},f.wire({'x':{'0':3}})))

    def test_unsafe_paths(self):
        for s in ('../outside','/etc/passwd','','a//b','a\\b'):
            with self.assertRaisesRegex(ValueError,'PATH'):f.path(s)

    def test_complete_capture_rejects_modified_or_extra_file(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);a=root/'a';b=root/'b';a.mkdir();b.mkdir()
            rel=Path('capture');(a/rel).mkdir();(b/rel).mkdir()
            data=b'original';record={'path':'raw','bytes':len(data),'sha256':f.sha(data)}
            for p in (a/rel,b/rel):
                (p/'raw').write_bytes(data);f.save(p/'FILES.json',[record])
            with patch.object(f,'git',return_value=f.blob(data)):
                self.assertEqual(f.checked_capture(a,b,rel),[record])
                (b/rel/'raw').write_bytes(b'changed')
                with self.assertRaisesRegex(ValueError,'COLD_BYTES'):f.checked_capture(a,b,rel)
                (b/rel/'raw').write_bytes(data);(b/rel/'extra').write_bytes(b'new')
                with self.assertRaisesRegex(ValueError,'FULL_CAPTURE'):f.checked_capture(a,b,rel)

if __name__=='__main__':unittest.main()
