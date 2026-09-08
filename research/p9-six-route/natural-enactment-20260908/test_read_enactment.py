"""Tamper tests bypass envelope hashes to exercise semantic reconciliation."""
import copy
import io
import json
import tarfile
import unittest
import read_enactment as reader

class ReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files,_ = reader.unpack(reader.R,'RAW-MANIFEST.json','raw.parts')
        folder=reader.R.parent/'source-package-audit-20260908'
        m=json.loads((folder/'ACQUISITION-WITNESSES.json').read_bytes())
        archive=b''.join((folder/'acquisition.parts'/p['file']).read_bytes() for p in m['parts'])
        with tarfile.open(fileobj=io.BytesIO(archive),mode='r:xz') as tf:
            cls.audit={m.name:tf.extractfile(m).read() for m in tf.getmembers()}
    def reject(self, change):
        files=copy.deepcopy(self.files)
        rows=[json.loads(x) for x in files['evidence/native.ndjson'].splitlines()]
        change(rows)
        data=('\n'.join(json.dumps(r) for r in rows)+'\n').encode()
        files['evidence/native.ndjson']=data
        receipt=json.loads(files['evidence/receipt.json'])
        receipt['files']['native.ndjson']={'bytes':len(data),'sha256':reader.sha(data)}
        files['evidence/receipt.json']=json.dumps(receipt).encode()
        with self.assertRaises((AssertionError,KeyError,ValueError)):
            reader.analyze(files,self.audit)
    def test_complete(self):
        r=reader.analyze(self.files,self.audit)
        self.assertEqual((r['runs_reproduced'],r['requested_contexts'],r['temporal_witnesses']),(9,12,10))
    def test_drop_absent_run(self):
        self.reject(lambda r:r.remove(next(x for x in r if x['kind']=='run' and not x['sampled'])))
    def test_duplicate_witness(self):
        self.reject(lambda r:r.append(copy.deepcopy(next(x for x in r if x['kind']=='witness'))))
    def test_factual_false(self):
        self.reject(lambda r:next(x for x in r if x['kind']=='witness').update(factual_equal=False))
    def test_null_state_corruption(self):
        self.reject(lambda r:next(x for x in r if x['kind']=='witness')['arms'][0].update(after=[]))
    def test_fake_original_outcome(self):
        self.reject(lambda r:next(x for x in r if x['kind']=='run')['row'].update(outcome='invented'))
    def test_foreign_seed(self):
        self.reject(lambda r:next(x for x in r if x['kind']=='witness').update(seed=999))
    def test_false_absence(self):
        self.reject(lambda r:next(x for x in r if x['kind']=='run' and x['sampled']).update(sampled={}))
    def test_wrong_instance(self):
        self.reject(lambda r:next(x for x in r if x['kind']=='witness' and x['route']=='cycle')['producer'].update(uid=-1))

if __name__=='__main__':unittest.main()
