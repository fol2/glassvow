import json
from pathlib import Path
import tempfile
import unittest
import resume_support as r

class ResumeTests(unittest.TestCase):
    def test_absent_configs_only(self):
        with tempfile.TemporaryDirectory() as d:
            cfg=[{'id':'p0'},{'id':'p1'}];p=Path(d)/'p0';p.mkdir()
            (p/'CELL.json').write_text('{}');(p/'EXECUTION.json').write_text('{"status":"COMPLETE"}')
            self.assertEqual(r.plan(d,cfg),([cfg[0]],[cfg[1]]))
    def test_partial_not_overwritten(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d)/'p0').mkdir()
            with self.assertRaisesRegex(ValueError,'PARTIAL_POLICY'):r.plan(d,[{'id':'p0'}])
    def test_failed_requires_named_repair(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'p0';p.mkdir();(p/'CELL.json').write_text('{}')
            (p/'EXECUTION.json').write_text('{"status":"INCONCLUSIVE_CAPTURE"}')
            with self.assertRaisesRegex(ValueError,'REQUIRES_REPAIR'):r.plan(d,[{'id':'p0'}])
    def test_unknown_directory_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d)/'unassigned').mkdir()
            with self.assertRaisesRegex(ValueError,'UNASSIGNED'):r.plan(d,[{'id':'p0'}])
    def test_absent_stage_does_not_invent_results(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(r.plan(Path(d)/'absent',[{'id':'p0'}]),([],[{'id':'p0'}]))
    def test_existing_pass_or_fail_not_reexecuted(self):
        for status in (r.PASS,r.FAIL):
            with tempfile.TemporaryDirectory() as d:
                x={'status':status,'packages_admitted':0,'p9_certified':False}
                (Path(d)/'TERMINAL.json').write_text(json.dumps(x))
                self.assertEqual(r.existing_terminal(d),x)
    def test_inconclusive_does_not_authorize_blind_retry(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d)/'TERMINAL.json').write_text('{"status":"INCONCLUSIVE"}')
            with self.assertRaisesRegex(ValueError,'DIAGNOSIS'):r.existing_terminal(d)
    def test_no_support_certificate_upgrade(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d)/'TERMINAL.json').write_text(json.dumps({'status':r.PASS,'packages_admitted':1,'p9_certified':False}))
            with self.assertRaisesRegex(ValueError,'NOT_ADMISSION'):r.existing_terminal(d)

if __name__=='__main__':unittest.main()
