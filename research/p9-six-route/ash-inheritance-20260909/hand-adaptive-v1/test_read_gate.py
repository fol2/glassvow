"""Synthetic reader regressions only, never native observation evidence."""
import copy
from itertools import product
import json
from pathlib import Path
import tempfile
import unittest
import read_gate as r


def synthetic(source, up, aspect, vow, context, mask, case):
    flags=[bool(mask & (1 << i)) for i in range(3)]
    energy=(2 if up else 1) if source=='surge' else 0
    draw=(2 if source=='preparation' else 1) if flags[0 if source=='preparation' else 1] else 0
    exhaust=source=='surge' or not up
    drawn=(draw+int(context=='branch' and exhaust)) if context!='empty' else 0
    effects=([{'kind':'energy','n':energy}] if energy else [])+([{'kind':'draw','n':draw}] if draw else [])
    n=(4 if up else 3) if flags[2] else 0
    loss=n*(1+drawn)+2
    before={'combat':{'player':{'hp':60}}}
    prefix={'combat':{'player':{'hp':60,'energy':1+energy},'hand':[{'uid':i} for i in [10002,10003]+list(range(10100,10100+drawn))],'exhaust':[{}] if exhaust else []}}
    after={'combat':{'player':{'energy':energy},'enemies':[{'hp':1000-loss}]},'return':True}
    return {'case':case,'source':source,'up':up,'aspect':aspect,'vow':vow,'context':context,'mask':mask,
            'flags':flags,'exact_flags':flags[:],'public_flags':flags[:],'readonly':True,'catalogue_unchanged':True,
            'source_data':{'cost':0,'effects':effects,'exhaust':exhaust},
            'consumer_data':{'cost':1,'effects':[{'kind':'special','id':'phantom','n':n}]},
            'before':before,'source_after':prefix,'after':after,'exact_after':copy.deepcopy(after),
            'public_after':copy.deepcopy(after),'events':[],'exact_events':[],'source_ret':True,'query':{}}


class ReaderTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.data={k:[] for k in ('reference','qualified','public-mutant','exact-mutant')}
        for values in product(('preparation','surge'),(False,True),(0,1),(0,5),('plain','empty','branch')):
            for mask in range(8):
                row=synthetic(*values,mask,len(self.data['qualified']));self.data['qualified'].append(row)
                if mask==7:
                    b=copy.deepcopy(row);b['case']=len(self.data['reference']);self.data['reference'].append(b)
                if mask==0:
                    for name,flag in [('public-mutant','public_flags'),('exact-mutant','exact_flags')]:
                        b=copy.deepcopy(row);b['case']=len(self.data[name]);b[flag]=[True]*3;self.data[name].append(b)
    def tearDown(self): self.temp.cleanup()
    def run_reader(self):
        for name, rows in self.data.items():
            b=rows+[{'kind':'terminal','cases':len(rows)}]
            (self.root/(name+'.jsonl')).write_text(''.join(json.dumps(x)+'\n' for x in b))
        return r.check(self.root)
    def test_synthetic_positive(self): self.assertEqual(self.run_reader()['qualified_cases'],384)
    def test_missing_case(self):
        self.data['qualified'].pop()
        with self.assertRaisesRegex(ValueError,'COMPLETE_CAPTURE'): self.run_reader()
    def test_lost_public_mask(self):
        self.data['qualified'][0]['public_flags']=[True]*3
        with self.assertRaisesRegex(ValueError,'CLONE_FLAG_RETENTION'): self.run_reader()
    def test_wrong_drawn_uid(self):
        self.data['qualified'][1]['source_after']['combat']['hand'][-1]['uid']=900
        with self.assertRaisesRegex(ValueError,'DRAW_INSTANCE_PROVENANCE'): self.run_reader()
    def test_energy_loss(self):
        self.data['qualified'][0]['source_after']['combat']['player']['energy']=0
        with self.assertRaisesRegex(ValueError,'BASE_ENERGY_AND_PAYMENT'): self.run_reader()
    def test_generic_strength_erased(self):
        self.data['qualified'][0]['after']['combat']['enemies'][0]['hp']=1000
        with self.assertRaisesRegex(ValueError,'NATIVE_HAND_PAYOFF'): self.run_reader()
    def test_catalogue_mutation(self):
        self.data['qualified'][0]['catalogue_unchanged']=False
        with self.assertRaisesRegex(ValueError,'LIVE_OR_CATALOGUE_MUTATION'): self.run_reader()
    def test_changed_default_query(self):
        self.data['qualified'][7]['query']={'not':'reference'}
        with self.assertRaisesRegex(ValueError,'DEFAULT_ON_FULL_QUERY_AND_STATE_PARITY'): self.run_reader()
    def test_mutant_not_detected(self):
        self.data['public-mutant'][0]['public_flags']=[False]*3
        with self.assertRaisesRegex(ValueError,'NAMED_FLAG_MUTANT'): self.run_reader()


if __name__=='__main__': unittest.main(verbosity=2)
