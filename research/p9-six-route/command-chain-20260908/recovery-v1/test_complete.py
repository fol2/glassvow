"""Tests for the committed finite archive and diagnostic; no engine or new samples."""
import copy,json,shutil,tempfile,unittest
from pathlib import Path
import complete
import pack_native
import read
ROOT=Path(__file__).resolve().parent
class ArchiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=complete.reconstruct(ROOT)
        cls.records=[json.loads(x) for x in cls.raw.splitlines()]
        cls.result=read.analyze(cls.records,json.loads((ROOT/'PROTOCOL.json').read_text()))
    def test_full_result_stays_negative(self):
        self.assertEqual((self.result['status'],self.result['failed_checks']),('COMMAND_CONTRACT_FAIL',64))
        self.assertEqual(complete.sha((json.dumps(self.result,indent=2)+'\n').encode()),'81f5261c118eced66482a78857e3d1335beed80abc5e83d97215c5b9e6289e8f')
    def test_all_vetoes_explained_not_admitted(self):
        d=complete.explain(self.records,self.result)
        self.assertEqual((d['facet_rows'],d['paired_subset_contrasts'],len(d['all_failed_checks'])),(384,192,64))
        self.assertFalse(d['p9_certified']);self.assertEqual(d['packages_admitted'],0)
    def test_post_consumer_shatter_is_not_prior_production(self):
        d=complete.explain(self.records,self.result)
        c=next(x for x in d['full_contexts'] if x['fixture']==['facet',0,5,False,False])
        self.assertEqual((c['producer_shatters_before_consumer'],c['shatters_after_consumer_hit']),(0,1))
        self.assertFalse(c['consumer_pre_echo_gate']);self.assertEqual(c['health_interaction'],1)
    def test_preexisting_gate_is_not_whole_chain_null(self):
        d=complete.explain(self.records,self.result)
        c=next(x for x in d['full_contexts'] if x['fixture']==['facet',0,0,False,True])
        self.assertTrue(c['consumer_pre_echo_gate'])
        self.assertEqual((c['health_interaction'],c['preblock_interaction'],c['blocked_interaction']),(10,0,-10))
    def test_saturation_is_rejected_before_accounting(self):
        records=copy.deepcopy(self.records)
        row=next(r for r in records if r['kind']=='row' and r['fixture']['role']=='facet' and any(e['t']=='hitEnemy' for s in r['steps'] for e in s['events']))
        next(e for s in row['steps'] for e in s['events'] if e['t']=='hitEnemy')['overkill']=1
        with self.assertRaisesRegex(ValueError,'SATURATION'):complete.explain(records,self.result)
    def mutate_archive(self,edit,reason):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t);shutil.copyfile(ROOT/'RAW-MANIFEST.json',root/'RAW-MANIFEST.json');shutil.copytree(ROOT/'raw.parts',root/'raw.parts')
            edit(root)
            with self.assertRaisesRegex(ValueError,reason):complete.reconstruct(root)
    def test_corrupted_part_rejected(self):
        def edit(r):
            p=r/'raw.parts/part-00.b64';b=p.read_bytes();p.write_bytes(b'!'+b[1:])
        self.mutate_archive(edit,'PART')
    def test_reordered_parts_rejected(self):
        def edit(r):
            p=r/'RAW-MANIFEST.json';m=json.loads(p.read_text());m['parts'][0],m['parts'][1]=m['parts'][1],m['parts'][0];p.write_text(json.dumps(m))
        self.mutate_archive(edit,'PACKED')
    def test_wrong_raw_hash_rejected(self):
        def edit(r):
            p=r/'RAW-MANIFEST.json';m=json.loads(p.read_text());m['raw_sha256']='0'*64;p.write_text(json.dumps(m))
        self.mutate_archive(edit,'RAW')
    def test_delta_codec_value_type_and_deletion_roundtrip(self):
        for a,b in [(None,{}),({'x':1},{'y':2}),([1,2],[1]),({'a':[True,2]},{'a':[1,2]})]:
            self.assertEqual(pack_native.canonical(pack_native.patch(a,pack_native.diff(a,b))),pack_native.canonical(b))
if __name__=='__main__':unittest.main()
