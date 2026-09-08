"""Fail-closed tests of the derivative reader; never a native rerun."""
import copy
import json
from pathlib import Path
import unittest
import census as c
from read_packet import unpack

P = Path(__file__).parent
class CensusTests(unittest.TestCase):
    def setUp(self):
        self.p=unpack(P)
    def rejected(self, mutate):
        mutate(self.p)
        with self.assertRaises((ValueError,KeyError,TypeError)):
            c.read(self.p)
    def test_corrupted_part(self):
        import tempfile, shutil
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            for name in ['CENSUS-MANIFEST.json']+[f'CENSUS.part{i:02}' for i in range(4)]:
                shutil.copyfile(P/name,root/name)
            (root/'CENSUS.part00').write_bytes(b'corrupt')
            with self.assertRaises(ValueError):unpack(root)
    def test_complete_coverage(self):
        r=c.read(self.p)
        self.assertEqual((r['rows'],len(r['cells']),r['unique_base_policy_vectors']),(2048,96,1))
        self.assertTrue(all(x['temporal_chain_count'] is None for x in r['cells']))
    def test_missing_cell(self):self.rejected(lambda p:p['groups'].pop())
    def test_duplicate_cell(self):self.rejected(lambda p:p['groups'].__setitem__(1,p['groups'][0]))
    def test_bad_bitmap(self):self.rejected(lambda p:p['groups'][0].__setitem__(4,'G'*16))
    def test_changed_seed(self):self.rejected(lambda p:p.__setitem__('seed0',45010001))
    def test_changed_archive(self):self.rejected(lambda p:p.__setitem__('source_archive_sha256','0'*64))
    def test_missing_source(self):self.rejected(lambda p:p['source_files'].pop(next(iter(p['source_files']))))
    def test_fake_additional_policy(self):
        self.rejected(lambda p:p['base_policies'].__setitem__('0'*64,{}))
    def test_unbound_policy(self):
        self.rejected(lambda p:p['base_policy_per_cell'].__setitem__(next(iter(p['source_files'])),'0'*64))
    def test_changed_policy_value(self):
        self.rejected(lambda p:next(iter(p['base_policies'].values())).__setitem__('cardDecline',0))
    def test_changed_tool(self):self.rejected(lambda p:p['balance_sources'].__setitem__('balance_sim.gd','0'*64))
    def test_claimed_remote_raw(self):self.rejected(lambda p:p.__setitem__('source_archive_remote_complete',True))
    def test_route_missing(self):self.rejected(lambda p:p['groups'][0][5].pop())
    def test_coplay_requires_consumer(self):
        def change(p):
            p['groups'][0][5][0][4]='f'*16
            p['groups'][0][5][0][5]='0'*16
        self.rejected(change)
    def test_starter_offer_not_reachability(self):
        r=c.read(self.p)
        facet=next(x for x in r['cells'] if (x['catalogue'],x['aspect'],x['vow'],x['arm'],x['route'])==('candidate','duskblade',0,1,'facet'))
        self.assertEqual(facet['producer_offered'],0)
        self.assertEqual(facet['both_final_owned'],32)
    def test_cycle_count_not_repeat(self):
        r=c.read(self.p)
        for row in r['cells']:
            if row['route']=='cycle':
                self.assertEqual(row['both_played_anywhere'],row['consumer_played'])
                self.assertIsNone(row['temporal_chain_count'])
    def test_roundtrip_seed_bit_order(self):
        b=[i in (0,3,63) for i in range(64)]
        self.assertEqual(c.decode(c.encode(b)),b)
    def test_no_independent_sample_or_policy_replication_claim(self):
        r=c.read(self.p)
        self.assertEqual(r['new_independent_samples'],0)
        self.assertEqual(r['arm_modes'],4)
        self.assertTrue(all(row['independent_policy_count'] is None for row in r['cells']))
if __name__=='__main__':unittest.main()
