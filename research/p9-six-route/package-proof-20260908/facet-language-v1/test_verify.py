import copy,json,os,unittest
from pathlib import Path
import verify as v
class Rules(unittest.TestCase):
    def state(self):
        return [{'stats':{'shatters':1}},{'over':False,'turn':1,'player':{'energy':1},'hand':[{'id':'resonantLance','uid':1000},{'id':'defend','uid':1100},{'id':'chisel','uid':900}], 'enemies':[{'idx':0,'hp':100,'staggered':True,'statuses':{}}]},None]
    def test_exact_prefix(self):
        self.assertEqual(v.prefix(self.state(),0),[dict(t='playCard',uid=900,target=0),dict(t='playCard',uid=1100,target=None),dict(t='endTurn')])
    def test_no_energy(self):
        s=self.state();s[1]['player']['energy']=0;self.assertEqual(v.prefix(s,0),[dict(t='endTurn')]);self.assertFalse(v.enabled(s))
    def test_depth_and_turn_bounds(self):
        self.assertEqual(v.prefix(self.state(),9),[])
        s=self.state();s[1]['turn']=4;self.assertNotIn(dict(t='endTurn'),v.prefix(s,0))
    def test_gate_without_producer_is_not_enough(self):
        s=self.state();s[0]['stats']['shatters']=0;self.assertFalse(v.enabled(s))
    def test_shatter_after_consumer_is_not_before(self):
        s=self.state();s[1]['enemies'][0]['staggered']=False;self.assertFalse(v.enabled(s))
    def test_vulnerable_disjunction(self):
        s=self.state();s[1]['enemies'][0].update(staggered=False,statuses={'vulnerable':1});self.assertTrue(v.enabled(s))
    def test_actual_health_not_preblock_damage(self):
        s=self.state();after=copy.deepcopy(s);after[1]['enemies'][0]['hp']=96
        self.assertEqual(v.accounting(s,[dict(t='hitEnemy',idx=0,amount=4,blocked=10,hpAfter=96)],after),(4,4))
    def test_false_health_rejected(self):
        with self.assertRaises(ValueError):v.accounting(self.state(),[dict(t='hitEnemy',idx=0,amount=4,blocked=10,hpAfter=90)],self.state())
    def test_negative_damage_rejected(self):
        with self.assertRaises(ValueError):v.accounting(self.state(),[dict(t='hitEnemy',idx=0,amount=-1,hpAfter=101)],self.state())
class CaptureMutations(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        p=os.environ.get('P9_CAPTURE')
        if not p:raise unittest.SkipTest('Native capture has not been opened')
        cls.root=Path(p);cls.records=[json.loads(x) for x in (cls.root/'native.ndjson').read_bytes().splitlines()]
        cls.initials={(r['vow'],r['up']):r['initial'] for r in json.loads((cls.root/'OLD-INITIALS.json').read_text())}
        cls.script=v.sha((Path(__file__).parent/'search.gd').read_bytes())
    def reject(self,fn):
        data=copy.deepcopy(self.records);fn(data)
        with self.assertRaises((ValueError,KeyError,IndexError)):v.verify(data,self.initials,self.script)
    def test_clean(self):v.verify(self.records,self.initials,self.script)
    def test_missing_node(self):self.reject(lambda d:d.pop(next(i for i,r in enumerate(d) if r['kind']=='node')))
    def test_dropped_legal_edge(self):
        def edit(d):
            n=next(r for r in d if r['kind']=='node' and r['edges']);n['edges'].pop();n['commands'].pop()
        self.reject(edit)
    def test_fake_minimum(self):
        found=next((r for r in self.records if r['kind']=='result' and 'minimum_commands' in r),None)
        if found is None:self.skipTest('No minimum claim made')
        self.reject(lambda d:next(r for r in d if r['kind']=='result' and 'minimum_commands' in r).update(minimum_commands=1))
    def test_missing_terminal_comparator(self):
        found=next((r for r in self.records if r['kind']=='node' and r['terminal']),None)
        if found is None:self.skipTest('No eligible terminal')
        self.reject(lambda d:next(r for r in d if r['kind']=='node' and r['terminal']).update(terminal={}))
    def test_fictitious_extra_hp(self):
        found=next((r for r in self.records if r['kind']=='node' and r['terminal']),None)
        if found is None:self.skipTest('No eligible terminal')
        self.reject(lambda d:next(r for r in d if r['kind']=='node' and r['terminal'])['terminal'].update(extra_hp=999))
if __name__=='__main__':unittest.main()
