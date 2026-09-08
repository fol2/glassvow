"""Adversarial post-capture reader review; not independent or new game rows."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import read_native as reader

RAW=Path(__file__).with_name('raw.ndjson')

class ReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.rows=[json.loads(x) for x in RAW.read_bytes().splitlines()]
    def changed(self, edit, pattern):
        rows=copy.deepcopy(self.rows);edit(rows)
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'raw';p.write_text(''.join(json.dumps(x)+'\n' for x in rows))
            with self.assertRaisesRegex((ValueError, KeyError),pattern):reader.read(p)
    def test_complete_capture(self):
        result=reader.read(RAW)
        self.assertEqual(result['cycle_full_trace_equalities'],40)
        self.assertEqual(result['packages_admitted'],0)
    def test_missing_row(self):self.changed(lambda rs:rs.pop(5),'ROW_COUNT')
    def test_duplicate_identity(self):self.changed(lambda rs:rs.__setitem__(2,copy.deepcopy(rs[1])),'DUPLICATE')
    def test_false_terminal(self):self.changed(lambda rs:rs[-1].update(failed=True),'TERMINAL')
    def test_initial_state_not_ignored(self):
        self.changed(lambda rs:rs[2]['steps'][0]['before']['future'][0].update(mutant=1),'UNEQUAL_INITIAL_STATE')
    def test_stagger_discriminator_not_names(self):
        def edit(rs):
            row=next(r for r in rs if r.get('kind')=='facet' and r['spec']['aspect']==0 and r['spec']['environment']=='two_short' and r['producer']==0)
            row['steps'][0]['view']['staggered']=False
        self.changed(edit,'NO_STAGGER_DISTINGUISHER')
    def test_rng_difference_not_erased(self):
        def edit(rs):
            row=next(r for r in rs if r.get('kind')=='cycle' and r['expanded'])
            row['steps'][0]['after']['future'][0]['rng_state_mutation']=123
        self.changed(edit,'HIDDEN_STATE_CHANGE|UNROLL_CHANGED_FULL_TRACE')
    def test_event_loss_not_ignored(self):
        self.changed(lambda rs:rs[1]['steps'][0]['events'].pop(),'QUEUE_CONSERVATION')
    def test_illegal_consumer(self):
        self.changed(lambda rs:rs[1]['steps'][1].update(ret=False),'ILLEGAL_COMMAND')
    def test_intercommand_mutation(self):
        self.changed(lambda rs:rs[1]['steps'][1]['before']['future'][0].update(mutant=1),'HIDDEN_STATE_CHANGE')
    def test_other_aspect_stun(self):
        def edit(rs):
            row=next(r for r in rs if r.get('kind')=='facet' and r['spec']['aspect']==1)
            row['steps'][0]['view']['staggered']=True
        self.changed(edit,'ASH_STUN')

if __name__=='__main__':unittest.main()
