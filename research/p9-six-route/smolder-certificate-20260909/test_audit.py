"""Adversarial tests for source relations and fail-closed trace attribution."""
import copy, json, lzma, tempfile, unittest
from pathlib import Path
from trace_audit import Lineage, read_trace, summarize
from source_relation import catalyst_relation

NATIVE='\t\t"catalyst":\n\t\t\tvar poison: int = _sget(target.statuses, "poison")\n\t\t\tif poison > 0:\n\t\t\t\tadd_status_enemy(cb, target, "poison", poison * (_ji(fx["n"]) - 1), run)\n'
OLD=NATIVE.replace('\t\t\t\tadd_status_enemy', '\t\t\t\tvar multiplier: int = _ji(fx["n"])\n\t\t\t\tif run.aspect == 1 and _sget(target.statuses, "mistbound") > 0:\n\t\t\t\t\tmultiplier += _ji(fx.get("mistboundBonus", 0))\n\t\t\t\t\tadd_status_enemy(cb, target, "mistbound", -1, run)\n\t\t\t\tadd_status_enemy').replace('poison * (_ji(fx["n"]) - 1)','poison * (multiplier - 1)')


def item(seq, card='', before=(0,0), after=(0,0), events=None, target=0, typ='playCard', up=False, ret=True):
    deck=[{'uid':1,'id':'venomStrike','up':False},{'uid':2,'id':'catalyst','up':up}]
    view=lambda vals:{'deck':deck,'enemies':[{'idx':i,'hp':40,'poison':n} for i,n in enumerate(vals)]}
    return {'kind':'command','row_key':'0:73209100','sequence':seq,'fight':0,
            'command':{'t':typ,'target':target,'uid':2 if card=='catalyst' else 1},
            'card':card,'before':view(before),'after':view(after),'events':events or [],'ret':ret}

def poison(who,n):return {'t':'status','id':'poison','who':who,'n':n}
def begin():
    x=Lineage();x.command(item(0,typ='startCombat'));return x

def source(x,seq=1):x.command(item(seq,'venomStrike',after=(4,0),events=[poison(0,4)]))
def consumer(x,seq=2,stock=4,target=0,up=False):
    before=[0,0];before[target]=stock;after=before.copy();after[target]*=3 if up else 2
    x.command(item(seq,'catalyst',before=before,after=after,target=target,up=up,events=[poison(target,stock*(2 if up else 1))]))


class AuditTests(unittest.TestCase):
    def test_direct_complete_stock_chain(self):
        x=begin();source(x);consumer(x);self.assertEqual(len(x.witnesses),1);self.assertEqual(x.witnesses[0]['amplifier_added_stock'],4)
    def test_unrelated_source_not_venom(self):
        x=begin();x.command(item(1,'toxicMist',after=(3,3),events=[poison(0,3),poison(1,3)]));consumer(x,stock=3)
        self.assertFalse(x.possible_consumers);self.assertFalse(x.witnesses)
    def test_retarget_not_a_direct_chain(self):
        x=begin();source(x);x.command(item(2,'other',before=(4,0),after=(4,5),events=[poison(1,5)]));consumer(x,3,5,1)
        self.assertFalse(x.possible_consumers);self.assertFalse(x.witnesses)
    def test_conservative_transfer_keeps_possible(self):
        x=begin();source(x);x.command(item(2,'other',before=(4,0),after=(0,4),events=[{'t':'shatter','idx':0},poison(1,4),{'t':'smolderJump','from':0,'to':1,'n':4}]))
        consumer(x,3,4,1);self.assertEqual(len(x.possible_consumers),1);self.assertFalse(x.witnesses)
    def test_decay_is_not_direct_attribution(self):
        x=begin();source(x);x.command(item(2,typ='endTurn',before=(4,0),after=(3,0)));consumer(x,3,3)
        self.assertTrue(x.possible_consumers);self.assertFalse(x.witnesses)
    def test_zero_total_clears_provenance(self):
        x=begin();source(x);x.command(item(2,typ='endTurn',before=(4,0),after=(0,0)));x.command(item(3,'other',after=(3,0),events=[poison(0,3)]));consumer(x,4,3)
        self.assertFalse(x.possible_consumers)
    def test_other_poison_removes_clean_only(self):
        x=begin();source(x);x.command(item(2,'other',before=(4,0),after=(7,0),events=[poison(0,3)]));consumer(x,3,7)
        self.assertTrue(x.possible_consumers);self.assertFalse(x.witnesses)
    def test_failed_source_not_counted(self):
        x=begin();z=item(1,'venomStrike',after=(4,0),events=[poison(0,4)],ret=False);x.command(z);consumer(x)
        self.assertFalse(x.possible_consumers)
    def test_generated_source_is_only_possible(self):
        x=begin();z=item(1,'venomStrike',after=(4,0),events=[poison(0,4)]);z['before']['deck']=[];x.command(z);consumer(x)
        self.assertTrue(x.possible_consumers);self.assertFalse(x.witnesses)
    def test_extra_venomous_prevents_clean(self):
        x=begin();x.command(item(1,'venomStrike',after=(8,0),events=[poison(0,4),poison(0,4)]));consumer(x,stock=8)
        self.assertTrue(x.possible_consumers);self.assertFalse(x.witnesses)
    def test_upgraded_amplifier(self):
        x=begin();source(x);consumer(x,up=True);self.assertEqual(x.witnesses[0]['multiplier'],3)
    def test_upgrade_mismatch_rejected(self):
        x=begin();source(x);z=item(2,'catalyst',before=(4,0),after=(12,0),events=[poison(0,8)])
        with self.assertRaisesRegex(ValueError,'UPGRADE'):x.command(z)
    def test_bad_amp_amount_rejected(self):
        x=begin();source(x)
        with self.assertRaisesRegex(ValueError,'AMPLIFIER'):x.command(item(2,'catalyst',before=(4,0),after=(9,0),events=[poison(0,5)]))
    def test_empty_mediator_not_positive(self):
        x=begin();x.command(item(1,'catalyst'));self.assertFalse(x.witnesses);self.assertFalse(x.possible_consumers)
    def test_positive_amp_at_zero_rejected(self):
        x=begin()
        with self.assertRaisesRegex(ValueError,'EMPTY'):x.command(item(1,'catalyst',after=(1,0),events=[poison(0,1)]))
    def test_new_fight_clears_all(self):
        x=begin();source(x);z=item(2,typ='startCombat',after=(3,0));z['fight']=1;x.command(z)
        self.assertFalse(x.possible);self.assertFalse(x.clean)
    def test_source_after_consumer_not_retroactive(self):
        x=begin();consumer(x,1,3);source(x,2);self.assertFalse(x.possible_consumers)
    def test_non_poison_command_preserves_clean(self):
        x=begin();source(x);x.command(item(2,'defend',before=(4,0),after=(4,0)));consumer(x,3);self.assertEqual(len(x.witnesses),1)
    def test_lethal_source_does_not_add(self):
        x=begin();z=item(1,'venomStrike',events=[{'t':'die','idx':0}]);z['after']['enemies'][0]['hp']=0;x.command(z);self.assertFalse(x.possible)
    def test_source_and_immediate_jump(self):
        x=begin();x.command(item(1,'venomStrike',after=(0,4),events=[poison(0,4),{'t':'shatter','idx':0},poison(1,4)]));consumer(x,2,4,1)
        self.assertTrue(x.possible_consumers);self.assertFalse(x.witnesses)
    def test_mutated_after_stock_never_clean(self):
        x=begin();source(x);x.command(item(2,'catalyst',before=(4,0),after=(99,0),events=[poison(0,4)]))
        self.assertFalse(x.witnesses)
    def test_duplicate_enemy_identity_fails_closed(self):
        x=begin();z=item(1);z['before']['enemies'][1]['idx']=0
        with self.assertRaisesRegex(ValueError,'DUPLICATE_ENEMY'):x.command(z)
    def test_missing_trace_row_fails(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'trace.xz';p.write_bytes(lzma.compress(b''))
            with self.assertRaisesRegex(ValueError,'MISSING_TRACE_ROW'):read_trace(p,{'0:73209100':{}})
    def test_duplicate_row_end_fails(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'trace.xz';entry={'kind':'row_end','row_key':'0:73209100','commands':0}
            p.write_bytes(lzma.compress(((json.dumps(entry)+'\n')*2).encode()))
            with self.assertRaisesRegex(ValueError,'TRACE_CLOSURE'):read_trace(p,{'0:73209100':{'potential_chain':False}})
    def test_command_sequence_fails(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'trace.xz';p.write_bytes(lzma.compress((json.dumps(item(1,typ='startCombat'))+'\n').encode()))
            with self.assertRaisesRegex(ValueError,'COMMAND_SEQUENCE'):read_trace(p,{'0:73209100':{}})
    def test_unassigned_trace_fails(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'trace.xz';p.write_bytes(lzma.compress((json.dumps(item(0))+'\n').encode()))
            with self.assertRaisesRegex(ValueError,'UNASSIGNED_TRACE'):read_trace(p,{})
    def test_exact_source_case_mutation_fails(self):
        with self.assertRaisesRegex(ValueError,'RESIDUAL'):catalyst_relation(NATIVE,OLD.replace('poison > 0','poison >= 0'))
    def test_residual_source_exact(self):self.assertTrue(catalyst_relation(NATIVE,OLD)['same_residual_kernel'])
    def test_status_mutation_rejected(self):
        with self.assertRaisesRegex(ValueError,'RESIDUAL'):catalyst_relation(NATIVE.replace('"poison", poison','"burn", poison'),OLD)
    def test_historical_consumption_mutation_rejected(self):
        with self.assertRaisesRegex(ValueError,'EXTENSION'):catalyst_relation(NATIVE,OLD.replace('"mistbound", -1','"mistbound", -2'))
    def test_duplicate_case_rejected(self):
        with self.assertRaisesRegex(ValueError,'CASE'):catalyst_relation(NATIVE+NATIVE,OLD)
    def test_complete_policy_not_row_count(self):
        rows=[{'policy_index':i,'seed':s,'potential_chain':True,'source_attributed_possible':i<31,'clean_direct_stock_witness':False,'witnesses':[], 'outcome':'win'} for i in range(128) for s in range(73209100,73209104)]
        r=summarize(rows,5);self.assertIn('INSUFFICIENT',r['status']);self.assertEqual(len(r['source_attributed_possible_policies']),31);self.assertFalse(r['p9_certified'])
    def test_missing_seed_rejected(self):
        rows=[{'policy_index':i,'seed':s} for i in range(128) for s in range(73209100,73209104)];rows[0]['seed']+=1
        with self.assertRaisesRegex(ValueError,'SEEDS'):summarize(rows,5)
    def test_short_rectangle_rejected(self):
        with self.assertRaisesRegex(ValueError,'RECTANGLE'):summarize([],5)

if __name__=='__main__':unittest.main(verbosity=2)
