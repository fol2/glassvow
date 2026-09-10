import copy
import json
from pathlib import Path
import unittest
import assemble
import read


def fake_group():
    def state():
        return {'run':{},'save':{},'return':None,'combat':{'player':{'hp':60,'energy':3,'statuses':{}},'enemies':[{'idx':0,'hp':100}], 'hand':[], 'queue':[], 'over':False}}
    rows = {}
    for arm in range(8):
        e,m,c = bool(arm&4),bool(arm&2),bool(arm&1)
        start = state();a = copy.deepcopy(start)
        a['return'] = True
        a['combat']['player']['hp'] -= 3
        a['combat']['player']['energy'] += 2*e
        ae=[]
        if e:ae.append({'t':'energy','n':5})
        if m:
            a['combat']['player']['statuses']['bloodfire'] = 1
            ae.append({'t':'status','id':'bloodfire','n':1})
        a['combat']['queue'] = ae
        b = copy.deepcopy(a);b['combat']['player']['energy'] -= 2
        amount = 9 + 10*(m and c)
        b['combat']['enemies'][0]['hp'] -= amount
        if m and c:b['combat']['player']['statuses'].pop('bloodfire')
        be=[{'t':'hitEnemy','idx':0,'amount':amount}]
        b['combat']['queue'] += be
        source_step={'command':{'t':'playCard','uid':900,'target':None},'before':start,'after':a,'events':ae,'ret':True}
        consumer_step={'command':{'t':'playCard','uid':901,'target':0},'before':a,'after':b,'events':be,'ret':True}
        rows[arm]={'kind':'sequence','source':'bloodRite','aspect':1,'vow':0,'up':False,'context':'available','arm':arm,'start':start,'steps':[source_step,consumer_step],'end':b}
    rows[-1]=copy.deepcopy(rows[7]);rows[-1]['arm']=-1
    return rows


class Tests(unittest.TestCase):
    def test_complete_factorial_interaction(self):
        r=read.check_group('bloodRite',(1,0,False,'available'),fake_group())
        self.assertEqual(r['utility_energy_enabled']['actual_hp_interaction'],10)
    def test_missing_subset_fails(self):
        rows=fake_group();del rows[2]
        with self.assertRaisesRegex(ValueError,'FACTORIAL'):read.check_group('bloodRite',(1,0,False,'available'),rows)
    def test_original_hp_utility_cannot_be_erased(self):
        rows=fake_group();rows[2]['steps'][0]['after']['combat']['player']['hp']=60
        with self.assertRaises(ValueError):read.check_group('bloodRite',(1,0,False,'available'),rows)
    def test_no_selected_success_reference(self):
        rows=fake_group();rows[-1]['end']['combat']['enemies'][0]['hp']=1
        with self.assertRaises(ValueError):read.check_group('bloodRite',(1,0,False,'available'),rows)
    def test_consumer_cannot_act_before_source(self):
        rows=fake_group();rows[1]['steps'][0]['after']['combat']['player']['hp']=56
        with self.assertRaises(ValueError):read.check_group('bloodRite',(1,0,False,'available'),rows)
    def test_unknown_state_field_not_projected_out(self):
        a=fake_group()[0]['start'];b=copy.deepcopy(a);b['combat']['future_unmeasured']=1
        self.assertNotEqual(read.snapshot_without_path(a,'bloodfire'),read.snapshot_without_path(b,'bloodfire'))
    def test_energy_does_not_erase_hp(self):
        a=fake_group()[0]['start'];b=copy.deepcopy(a);b['combat']['player']['hp']-=3
        self.assertNotEqual(read.snapshot_without_path(a,'energy'),read.snapshot_without_path(b,'energy'))
    def test_ineligible_is_not_zero(self):
        s=copy.deepcopy(fake_group()[0]['steps'][1]);s['ret']=False
        self.assertIsNone(read.payoff(s)['actual_hp_removed'])
    def test_ineligible_rectangle_is_undefined(self):
        rows=fake_group();rows[4]['steps'][1]['ret']=False
        r=read.interaction(rows,True)
        self.assertFalse(r['identified_for_fixed_commands']);self.assertIsNone(r['actual_hp_interaction'])
    def test_false_return_not_integer_zero(self):
        s=copy.deepcopy(fake_group()[0]['steps'][1]);s['ret']=0
        with self.assertRaises(ValueError):read.payoff(s)
    def test_capped_health_not_hit_amount(self):
        s=copy.deepcopy(fake_group()[7]['steps'][1]);s['before']['combat']['enemies'][0]['hp']=5;s['after']['combat']['enemies'][0]['hp']=-14
        self.assertEqual(read.payoff(s)['actual_hp_removed'],5)
        self.assertEqual(read.payoff(s)['native_hit_amount'],19)
    def test_hp_and_healing_are_separate(self):
        s=copy.deepcopy(fake_group()[7]['steps'][1]);s['events'].append({'t':'heal','who':'player','n':4})
        r=read.payoff(s);self.assertEqual(r['healing_events'],4);self.assertEqual(r['actual_hp_removed'],19)
    def test_exact_patch_anchor_is_required(self):
        with self.assertRaisesRegex(ValueError,'ANCHOR'):assemble.once('xx','x','y')
    def test_altered_content_cannot_enter(self):
        with self.assertRaisesRegex(ValueError,'BASE_CONTENT'):assemble.candidate_content(b'{}')
    def test_unchanged_native_fallback_present(self):
        t=(Path(__file__).parent/'causal_rules.gd').read_text()
        self.assertIn('super._apply_effect(run, cb, inst, d, fx, target, damage_mult)',t)
        self.assertNotIn('"loseHp"',t)
        self.assertNotIn('cb.player.energy =',t)
    def test_not_an_admission(self):
        p=json.loads((Path(__file__).parent/'PROTOCOL.json').read_bytes())
        self.assertEqual(p['records'],192*9);self.assertFalse(p['p9_certified']);self.assertEqual(p['packages_admitted'],0)

if __name__=='__main__':unittest.main(verbosity=2)
