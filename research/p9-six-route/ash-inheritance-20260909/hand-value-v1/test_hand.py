import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import read_hand as r
import run_hand as run


def rows(pattern='0001', vow=5):
    result={w:[] for w in r.WORLDS}
    for first in range(0,128,2):
        for index in (first,first+1):
            for seed in r.config(first,vow)['seeds']:
                for world,y in zip(r.WORLDS,pattern):
                    result[world].append({'index':index,'seed':seed,'vow':vow,'policy':{'index':index},'row':{'outcome':'win' if y=='1' else 'loss','error':False}})
    return result


class HandTests(unittest.TestCase):
    def test_complete_positive_interaction(self):
        blocks,wins,patterns=r.blocks_from_rows(rows(),5)
        self.assertEqual(len(blocks),256)
        self.assertTrue(all(b==[1.,1.,1.] for b in blocks))
        self.assertEqual(wins,{'00':0,'01':0,'10':0,'11':512})
        self.assertEqual(patterns,{'0001':512})

    def test_ordinary_source_value_not_complementarity(self):
        blocks,_,_=r.blocks_from_rows(rows('0011'),5)
        self.assertTrue(all(b==[1.,0.,0.] for b in blocks))

    def test_ordinary_consumer_value_not_complementarity(self):
        blocks,_,_=r.blocks_from_rows(rows('0101'),5)
        self.assertTrue(all(b==[0.,1.,0.] for b in blocks))

    def test_zero_contrast(self):
        blocks,_,_=r.blocks_from_rows(rows('1111'),5)
        self.assertTrue(all(b==[0.,0.,0.] for b in blocks))

    def test_missing_world_rejected(self):
        x=rows();del x['10']
        with self.assertRaisesRegex(ValueError,'FOUR_WORLDS'):r.blocks_from_rows(x,5)

    def test_missing_row_rejected(self):
        x=rows();x['11'].pop()
        with self.assertRaisesRegex(ValueError,'COMPLETE_RECTANGLE'):r.blocks_from_rows(x,5)

    def test_duplicate_rejected(self):
        x=rows();x['11'][-1]=copy.deepcopy(x['11'][0])
        with self.assertRaisesRegex(ValueError,'COMPLETE_RECTANGLE'):r.blocks_from_rows(x,5)

    def test_wrong_policy_rejected(self):
        x=rows();x['11'][0]['policy']={'index':999}
        with self.assertRaisesRegex(ValueError,'MATCHED_POLICY'):r.blocks_from_rows(x,5)

    def test_fault_not_loss(self):
        x=rows();x['00'][0]['row']['error']=True
        with self.assertRaisesRegex(ValueError,'FAULT_NOT_LOSS'):r.blocks_from_rows(x,5)

    def test_boolean_id_not_integer(self):
        x=rows();x['00'][0]['index']=False
        with self.assertRaisesRegex(ValueError,'INTEGER_IDENTITIES'):r.blocks_from_rows(x,5)

    def test_wrong_vow_rejected(self):
        x=rows();x['11'][0]['vow']=0
        with self.assertRaisesRegex(ValueError,'MATCHED_POLICY'):r.blocks_from_rows(x,5)

    def test_seed_blocks_hold_two_distinct_policies(self):
        x=rows();x['11'][0]['row']['outcome']='loss'
        blocks,_,_=r.blocks_from_rows(x,5)
        self.assertEqual(blocks[0],[.5,.5,.5])

    def test_no_bootstrap_positive_point_override(self):
        with patch.object(r,'bootstrap_function',return_value=lambda _: [[0.,1.]]*3):
            result=r.primary(rows(),5,Path('.'))
        self.assertFalse(result['primary_pass'])

    def test_resource_exact_boundary(self):
        self.assertTrue(r.resource_ok({w:3600 for w in r.WORLDS}))
        self.assertFalse(r.resource_ok({w:3600.00001 for w in r.WORLDS}))
        self.assertFalse(r.resource_ok({w:float('nan') for w in r.WORLDS}))
        self.assertFalse(r.resource_ok({'00':1}))

    def test_invalid_config(self):
        for i,v in ((1,5),(128,5),(True,5),(0,1),(0,False)):
            with self.assertRaises(ValueError):r.config(i,v)

    def test_source_world_initializes_group_not_new_card_effect(self):
        text='extends GlassvowGame\nconst F=["hand_preparation_enabled","hand_surge_enabled","hand_phantom_enabled"]\nfunc apply(cmd: Dictionary) -> Array[Dictionary]:\n\treturn super.apply(cmd)\n'
        for world in r.WORLDS:
            result=run.observer_world(text.encode(),world).decode()
            for flag,y in zip(run.FLAGS,(world[0],world[0],world[1])):
                self.assertIn('rules.set("'+flag+'", '+str(y=='1').lower()+')',result)
            self.assertIn('return super.apply(cmd)',result)
            self.assertNotIn('hand.clear',result)
            self.assertNotIn('energy =',result)
        with self.assertRaisesRegex(ValueError,'UNEXPECTED_INITIALIZER'):
            run.observer_world((text+'func _init():\n pass\n').encode(),'11')

    def test_contract_identity_and_no_relaxed_bar(self):
        contract=json.loads(Path(__file__).with_name('CONTRACT.json').read_text());run.validate_contract(contract)
        changed=copy.deepcopy(contract);changed['limits']['cpu_seconds_per_world_per_vow']=3601
        with self.assertRaisesRegex(ValueError,'FROZEN_CONTAINMENT'):run.validate_contract(changed)
        changed=copy.deepcopy(contract);changed['primary']['positive_lower_bounds_required']=1
        with self.assertRaisesRegex(ValueError,'FROZEN_READOUT'):run.validate_contract(changed)

    def test_entry_reader_rejects_missing_masks_and_mismatched_all_on(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for name in ('reference',*r.WORLDS):
                w='11' if name=='reference' else name
                row={'kind':'HAND_WORLD_ENTRY','masks':[w[0]=='1',w[0]=='1',w[1]=='1'],'clone_masks_preserved':True,'factual_untouched':True,'steps':[{'after':{'return':True}}]*3}
                (root/(name+'.json')).write_text(json.dumps(row));(root/(name+'.jsonl')).write_text('raw')
            self.assertEqual(run.entry_result(root)['status'],'HAND_WORLD_ENTRY_BINDING_PASS')
            (root/'11.jsonl').write_text('drift')
            with self.assertRaisesRegex(ValueError,'ALL_ON_ENTRY_PARITY'):run.entry_result(root)


if __name__=='__main__':unittest.main()
