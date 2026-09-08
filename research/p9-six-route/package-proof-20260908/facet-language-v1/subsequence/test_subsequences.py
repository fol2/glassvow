import copy
import unittest
from read_subsequences import derive

A={'t':'playCard','uid':1,'target':0}
B={'t':'endTurn'}
C={'t':'playCard','uid':1000,'target':0}

def graph():
    return {
        'root': {'edges':[{'cmd':A,'state':'a'},{'cmd':B,'state':'b'}], 'terminal':{}},
        'a': {'edges':[{'cmd':B,'state':'ab'}], 'terminal':{}},
        'b': {'edges':[], 'terminal':{}},
        'ab': {'edges':[], 'terminal':{'cmd':C,'extra_hp':1}}}

class SubwordTests(unittest.TestCase):
    def test_complete_coverage(self):
        result=derive(graph(),'root',[A,B,C])
        self.assertEqual(result['positional_proper_subsets'],3)
        self.assertEqual(result['distinct_retained_prefix_words'],3)
        self.assertTrue(result['all_retained_consumer_proper_subwords_fail_specified_goal'])

    def test_missing_expanded_state_is_not_negative(self):
        g=graph();g.pop('a')
        with self.assertRaisesRegex(ValueError,'MISSING_EXPANDED'):
            derive(g,'root',[A,B,C])

    def test_positive_subset_rejected(self):
        g=graph();g['a']['terminal']={'cmd':C,'extra_hp':1}
        with self.assertRaisesRegex(ValueError,'POSITIVE_PROPER'):
            derive(g,'root',[A,B,C])

    def test_illegal_prefix_is_reported(self):
        g=graph();g['root']['edges']=[{'cmd':A,'state':'a'}]
        result=derive(g,'root',[A,B,C])
        self.assertEqual(result['outcomes']['ILLEGAL_PREFIX'],1)

    def test_duplicate_edge_rejected(self):
        g=graph();g['root']['edges'].append(copy.deepcopy(g['root']['edges'][0]))
        with self.assertRaisesRegex(ValueError,'DUPLICATE_COMMAND'):
            derive(g,'root',[A,B,C])

    def test_zero_contribution_recorded(self):
        g=graph();g['a']['terminal']={'cmd':C,'extra_hp':0}
        result=derive(g,'root',[A,B,C])
        self.assertEqual(result['outcomes']['NO_POSITIVE_SAME_STATE_ECHO_CONTRIBUTION'],1)

    def test_different_consumer_rejected(self):
        g=graph();g['a']['terminal']={'cmd':A,'extra_hp':0}
        with self.assertRaisesRegex(ValueError,'DIFFERENT_CONSUMER'):
            derive(g,'root',[A,B,C])

    def test_positional_duplicates_not_independent(self):
        g={'root':{'edges':[{'cmd':B,'state':'b'}],'terminal':{}},
           'b':{'edges':[{'cmd':B,'state':'bb'}],'terminal':{}},
           'bb':{'edges':[],'terminal':{'cmd':C,'extra_hp':1}}}
        result=derive(g,'root',[B,B,C])
        self.assertEqual(result['positional_proper_subsets'],3)
        self.assertEqual(result['distinct_retained_prefix_words'],2)

if __name__=='__main__': unittest.main()
