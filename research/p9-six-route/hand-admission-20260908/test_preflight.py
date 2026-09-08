import copy
import json
import os
from pathlib import Path
import unittest
from read_preflight import analyze,project_view
from review_preflight import review

class HandPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root=Path(os.environ.get('HAND_CAPTURE',Path(__file__).resolve().parent))
        cls.raw=(root/'raw.ndjson').read_bytes()
        cls.protocol=json.loads((Path(__file__).resolve().parent/'PROTOCOL.json').read_bytes())
        cls.records=[json.loads(x) for x in cls.raw.splitlines()]
    def altered(self, fn):
        records=copy.deepcopy(self.records);fn(records)
        return ('\n'.join(json.dumps(x) for x in records)+'\n').encode()
    def reject(self,fn):
        with self.assertRaises((ValueError,KeyError,TypeError)):
            review(self.altered(fn),self.protocol)
    @staticmethod
    def row(records,mask=0):
        return next(r for r in records if r['kind']=='row' and r['spec']['aspect']==1 and r['spec']['label']=='prep_stock' and r['mask']==mask)
    def test_complete_original(self):
        self.assertEqual(review(self.raw,self.protocol)['rows_bound'],1032)
    def test_truncation(self):self.reject(lambda r:r.pop())
    def test_missing_row(self):self.reject(lambda r:r.remove(self.row(r)))
    def test_duplicate_row(self):self.reject(lambda r:r.insert(-1,self.row(r)))
    def test_source_hash(self):self.reject(lambda r:r[0].update(probe_sha256='0'*64))
    def test_engine_identity(self):self.reject(lambda r:r[0]['engine'].update(string='wrong'))
    def test_state_corruption(self):self.reject(lambda r:next(x for x in r if x['kind']=='state').update(serialized='{}'))
    def test_unfaithful_view(self):self.reject(lambda r:self.row(r)['steps'][0]['after_view'].update(energy=99))
    def test_lost_events(self):self.reject(lambda r:self.row(r)['steps'][0].update(events=[]))
    def test_nominal_promoted_to_health(self):self.reject(lambda r:self.row(r)['steps'][1]['health'].update(removed=999))
    def test_bad_stock(self):
        self.reject(lambda r:next(o for o in self.row(r)['steps'][1]['observations'] if o['kind']=='phantom').update(q_after_removal=9))
    def test_unbound_fixture(self):self.reject(lambda r:self.row(r)['spec'].update(hand=99))
    def test_boolean_mask(self):self.reject(lambda r:self.row(r).update(mask=False))
    def test_intervention_initial_drift(self):self.reject(lambda r:self.row(r,1).update(initial=self.row(r,1)['steps'][0]['after']))
    def test_missing_consumer_observation(self):
        # Native/off parity alone does not establish sufficient telemetry.
        self.reject(lambda r:self.row(r)['steps'][1].update(observations=[]))
    def test_missing_supplier_observation(self):self.reject(lambda r:self.row(r)['steps'][0].update(observations=[]))
    def test_wrong_supplier_effect(self):self.reject(lambda r:self.row(r)['steps'][0]['observations'][0]['effect'].update(n=99))
    def test_target_binding(self):self.reject(lambda r:self.row(r)['steps'][1]['command'].update(target=1))

if __name__=='__main__':unittest.main()
