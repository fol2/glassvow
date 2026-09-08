import copy
import json
from pathlib import Path
import unittest
import review_capture as review
R=Path(__file__).parent
class CaptureReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records=[json.loads(s) for s in (R/'raw.ndjson').read_bytes().splitlines()]
        cls.protocol=json.loads((R/'PROTOCOL.json').read_bytes())
    def mutate(self, fn, reason):
        data=copy.deepcopy(self.records);fn(data)
        with self.assertRaisesRegex(ValueError,reason):review.verify_records(data,self.protocol)
    def test_whole_capture(self):self.assertGreater(review.verify_records(self.records,self.protocol),128)
    def test_mismatched_probe(self):self.mutate(lambda d:d[0].update(probe_sha256='x'),'HEADER_SOURCE')
    def test_mismatched_engine(self):self.mutate(lambda d:d[0]['engine'].update(hash='x'),'HEADER_ENGINE')
    def test_view_not_derived_from_raw(self):self.mutate(lambda d:d[1]['steps'][0]['view'].update(hp=0),'VIEW_REFLECTION')
    def test_rng_view_mismatch(self):self.mutate(lambda d:d[1]['steps'][0]['view'].update(rng=0),'VIEW_REFLECTION')
    def test_return_mismatch(self):self.mutate(lambda d:d[1]['steps'][0].update(ret=False),'RETURN_REFLECTION')
if __name__=='__main__':unittest.main()
