import unittest
import copy
import json
import lzma
from pathlib import Path
import tempfile
import read_control as r

class ControlTests(unittest.TestCase):
    def test_exact_tenth_boundary(self):
        x=r.arithmetic([True]*20+[False]*80,[True]*30+[False]*70)
        self.assertTrue(all(x['gates'].values()))
    def test_both_movement_directions(self):
        for a,b in ((20,31),(31,20)):
            x=r.arithmetic([True]*a+[False]*(100-a),[True]*b+[False]*(100-b))
            self.assertFalse(x['gates']['absolute_random_build_movement_at_most_tenth'])
    def test_ceiling_boundary(self):
        self.assertTrue(r.arithmetic([True]*50+[False]*50,[True]*50+[False]*50)['gates']['candidate_random_build_at_most_half'])
        self.assertFalse(r.arithmetic([True]*50+[False]*50,[True]*51+[False]*49)['gates']['candidate_random_build_at_most_half'])
    def test_incomplete_rejected(self):
        for a,b in (([],[]),([True],[True,False])):
            with self.assertRaises(ValueError):r.arithmetic(a,b)
    def test_counts_are_not_boolean_observations(self):
        with self.assertRaises(ValueError):r.arithmetic([1,0],[True,False])
    def test_matched_pairs_not_unpaired_counts(self):
        x=r.arithmetic([True,False],[False,True]);self.assertEqual(x['difference'],0)
        self.assertEqual(x['paired_discordance'],{-1:1,1:1})
    def test_interval_constant_zero(self):
        self.assertEqual(r.paired_interval([0]*128,100),[0,0])
    def test_fixed_complete_eight_contexts(self):
        p={'seed0':60909000,'seeds_per_grid':128};cfg=r.specifications(p)
        self.assertEqual(len(cfg),8);self.assertEqual(sum(x['runs'] for x in cfg),1024)
        self.assertEqual({x['arm'] for x in cfg},{2})

    @staticmethod
    def synthetic():
        p={'seed0':60909000,'seeds_per_grid':128,'content_sha256':{'baseline':'baseline','candidate':'candidate'},
           'combat_sha256':{'baseline':'base_combat','candidate':'candidate_combat'},
           'tool_sha256':{},'source_sha256':{'probe.gd':'probe'},
           'resolved_policy_sha256':r.sha(b'{}'),'containment':{'raw_bytes_per_cell':2000000}}
        cfg=r.specifications(p)[0]
        h={'kind':'header','config':cfg,'signed_arm':{'random_build':True,'random_play':False,'ban':[]},
           'engine':'4.7.2-stable (official)','content_sha256':'baseline','combat_sha256':'base_combat',
           'sources':{},'driver_sha256':'probe','policy':{}}
        rows=[{'seed':cfg['seed0']+i,'aspect':cfg['aspect'],'vow':cfg['vow'],'arm':2,
               'policy':{},'outcome':'loss','error':''} for i in range(128)]
        return p,cfg,[h]+rows
    def test_no_balanced_controller_substitution(self):
        p,cfg,rows=self.synthetic();rows[0]['signed_arm']['random_build']=False
        with self.assertRaisesRegex(ValueError,'SIGNED_ARM'):r.validate(rows,cfg,p)
    def test_policy_drift_even_when_all_rows_agree(self):
        p,cfg,rows=self.synthetic()
        for row in rows:row['policy']={'hidden_refit':True}
        with self.assertRaisesRegex(ValueError,'DEFAULT_SIGNED_POLICY'):r.validate(rows,cfg,p)
    def test_missing_or_replaced_seed_rejected(self):
        p,cfg,rows=self.synthetic()
        with self.assertRaisesRegex(ValueError,'COUNT'):r.validate(rows[:-1],cfg,p)
        rows[-1]['seed']+=1
        with self.assertRaisesRegex(ValueError,'SEED_ORDER'):r.validate(rows,cfg,p)
    def test_fabricated_win_rejected(self):
        p,cfg,rows=self.synthetic();rows[-1].update(outcome='win',hp=1,fights=[])
        with self.assertRaisesRegex(ValueError,'VALID_WIN'):r.validate(rows,cfg,p)
    def test_other_content_rejected(self):
        p,cfg,rows=self.synthetic();rows[0]['content_sha256']='wrong'
        with self.assertRaisesRegex(ValueError,'CONTENT'):r.validate(rows,cfg,p)
    def test_cold_compressed_readout_is_identical(self):
        # All rows here are explicitly synthetic reader fixtures, not native runs.
        p,_,_=self.synthetic()
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            for cfg in r.specifications(p):
                _,_,rows=self.synthetic();rows[0]['config']=cfg
                rows[0]['content_sha256']=p['content_sha256'][cfg['catalogue']]
                rows[0]['combat_sha256']=p['combat_sha256'][cfg['catalogue']]
                for row in rows[1:]:row.update(aspect=cfg['aspect'],vow=cfg['vow'])
                (root/(cfg['id']+'.ndjson')).write_text(''.join(json.dumps(x)+'\n' for x in rows))
            before=r.analyze(root,p)
            for path in root.glob('*.ndjson'):
                path.with_suffix('.ndjson.xz').write_bytes(lzma.compress(path.read_bytes()));path.unlink()
            self.assertEqual(before,r.analyze(root,p))

if __name__=='__main__':unittest.main()
