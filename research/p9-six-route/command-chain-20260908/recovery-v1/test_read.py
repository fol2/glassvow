import copy,json,os,unittest
from pathlib import Path
import read
class ReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records=read.load(os.environ['P9_CAPTURE']);cls.protocol=json.loads((Path(__file__).parent/'PROTOCOL.json').read_text())
    def reject(self,edit,reason):
        r=copy.deepcopy(self.records);edit(r)
        with self.assertRaisesRegex(ValueError,reason):read.analyze(r,self.protocol)
    def test_complete_read(self):self.assertEqual(read.analyze(self.records,self.protocol)['rows'],672)
    def test_missing_row(self):self.reject(lambda r:r.remove(next(x for x in r if x['kind']=='row')),'INCOMPLETE_ASSIGNMENT')
    def test_duplicate_row(self):self.reject(lambda r:r.insert(-1,next(x for x in r if x['kind']=='row')),'DUPLICATE_ROW')
    def test_metric(self):
        def edit(r):next(x for x in r if x['kind']=='row')['metrics']['hp_removed']+=1
        self.reject(edit,'METRIC_RECOMPUTE')
    def test_command(self):
        def edit(r):next(x for x in r if x['kind']=='row' and x['steps'])['steps'][0]['cmd']['t']='fake'
        self.reject(edit,'COMMAND_ASSIGNMENT')
    def test_source(self):self.reject(lambda r:r[0].update(probe_sha256='0'*64),'PROBE')
    def test_state(self):
        def edit(r):next(x for x in r if x['kind']=='state')['serialized']+=' '
        self.reject(edit,'STATE_HASH_OR_DUPLICATE')
    def test_identity(self):
        def edit(r):
            row=next(x for x in r if x['kind']=='row' and any(e.get('t')=='play' for s in x['steps'] for e in s['events']))
            next(e for s in row['steps'] for e in s['events'] if e.get('t')=='play')['id']='invented'
        self.reject(edit,'PLAY_ID')
    def test_legal(self):
        def edit(r):next(s for x in r if x['kind']=='row' for s in x['steps'] if s['cmd']['t']=='playCard')['ret']=False
        self.reject(edit,'ILLEGAL_CARD')
class AccountingTests(unittest.TestCase):
    @staticmethod
    def state(n):return {'enemies':[{'idx':0,'hp':n}]}
    def test_overkill(self):self.assertEqual(read.fold(self.state(4),[{'t':'hitEnemy','idx':0,'amount':8,'hpAfter':0}],self.state(0)),(4,8))
    def test_heal(self):self.assertEqual(read.fold(self.state(4),[{'t':'heal','who':0,'n':2},{'t':'hitEnemy','idx':0,'amount':3,'hpAfter':3}],self.state(3)),(3,3))
    def test_bad_hp(self):
        with self.assertRaisesRegex(ValueError,'HIT_HP'):read.fold(self.state(4),[{'t':'hitEnemy','idx':0,'amount':1,'hpAfter':2}],self.state(2))
    def test_missing_damage(self):
        with self.assertRaisesRegex(ValueError,'FINAL_HP'):read.fold(self.state(4),[],self.state(2))
if __name__=='__main__':unittest.main()
