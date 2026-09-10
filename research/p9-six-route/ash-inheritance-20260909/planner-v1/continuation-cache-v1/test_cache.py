import copy,io,json,lzma,tarfile,tempfile,unittest
from pathlib import Path
import benchmark as b

class CacheTests(unittest.TestCase):
    def test_only_factory_changed(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);old='const Greedy: GDScript=preload("res://greedy_policy.gd")\n# scoring stays\n'
            (p/'rollout_policy.gd').write_text(old)
            b.patch(p,Path(__file__).with_name('continuation_cache.gd'))
            self.assertEqual((p/'rollout_policy.gd').read_text().replace('continuation_cache.gd','greedy_policy.gd'),old)
    def test_missing_factory_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);(p/'rollout_policy.gd').write_text('wrong')
            with self.assertRaises(ValueError):b.patch(p,Path(__file__).with_name('continuation_cache.gd'))
    def test_only_timing_erased(self):
        rows=[{'kind':'header','probe_sha256':'exact'}, {'kind':'outcome','run_usec':1,'query_usec':2,'score':0.12,'action':7}, {'kind':'terminal','rows':1}]
        data=lambda r:('\n'.join(map(json.dumps,r))+'\n').encode()
        r=copy.deepcopy(rows);r[1]['run_usec']=999
        self.assertEqual(b.canonical(data(rows)),b.canonical(data(r)))
        for key in ('score','action','extra_game_field'):
            r=copy.deepcopy(rows);r[1][key]=98
            self.assertNotEqual(b.canonical(data(rows)),b.canonical(data(r)))
        r=copy.deepcopy(rows);r[0]['probe_sha256']='unbound'
        self.assertNotEqual(b.canonical(data(rows)),b.canonical(data(r)))
    def test_missing_timing_cannot_hide_bad_record(self):
        with self.assertRaises(ValueError):b.canonical(b'{"kind":"header"}\n{"kind":"outcome"}\n{"kind":"terminal"}\n')
    def test_cache_cannot_span_decisions(self):
        s=Path(__file__).with_name('continuation_cache.gd').read_text()
        self.assertEqual(s.count(' _memo.clear()'),2)
        self.assertIn('_memo_game = null\n _memo.clear()\n return answer',s)
        self.assertIn('g if not random_play else null',s)
        self.assertNotIn('.apply(',s)
        self.assertNotIn('.rng',s)
    def test_duplicate_archive_paths_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);p=root/'a.tar.xz'
            with tarfile.open(p,'w:xz') as tf:
                x=tarfile.TarInfo('same');x.size=1;tf.addfile(x,io.BytesIO(b'x'))
            with self.assertRaises(ValueError):b.unpack(p,root/'out',[{'path':'same'},{'path':'same'}],b.sha(p.read_bytes()))
    def test_archive_tamper_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'bad';p.write_bytes(b'changed')
            with self.assertRaises(ValueError):b.unpack(p,Path(tmp)/'out',[],'no')

if __name__=='__main__':unittest.main()
