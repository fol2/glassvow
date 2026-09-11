"""Adversarial checker tests; synthetic states never become native evidence."""
import copy
import json
import lzma
import os
from pathlib import Path
import unittest
import check as C


def state(cards, turn=1, hp=100):
    return {'combat': {'hand': [{'uid': u, 'id': name} for u, name in cards],
                       'turn': turn, 'enemies': [{'idx': 0, 'hp': hp}]}}


def step(before, after, uid, events, ret=True):
    return {'command': {'t': 'playCard', 'uid': uid, 'target': 0},
            'before': before, 'after': after, 'events': events, 'ret': ret}


def sample():
    initial = state([(900, 'preparation'), (901, 'phantomBlades'), (902, 'phantomBlades')])
    drawn = state([(901, 'phantomBlades'), (902, 'phantomBlades'), (950, 'defend'), (951, 'defend')])
    source = step(initial, drawn, 900, [{'t': 'play', 'uid': 900},
                 {'t': 'draw', 'uid': 950}, {'t': 'draw', 'uid': 951}])
    after_first = state([(902, 'phantomBlades'), (950, 'defend'), (951, 'defend')], hp=91)
    first = step(drawn, after_first, 901, [{'t': 'play', 'uid': 901}])
    after_second = state([(950, 'defend'), (951, 'defend')], hp=85)
    second = step(after_first, after_second, 902, [{'t': 'play', 'uid': 902}])
    return [source, first, second]


class AttributionTests(unittest.TestCase):
    def test_read_does_not_consume_other_cards(self):
        d = C.descriptor(sample())
        self.assertEqual([x['surviving_source_uids'] for x in d], [[950, 951], [950, 951]])
        self.assertEqual([x['hand_units_read'] for x in d], [3, 2])
        self.assertEqual([x['useful_hp_removed'] for x in d], [9, 6])

    def test_spent_card_loses_credit(self):
        s = sample(); before = s[0]['after']
        after = state([(901, 'phantomBlades'), (902, 'phantomBlades'), (951, 'defend')])
        spent = step(before, after, 950, [{'t': 'play', 'uid': 950}])
        consumer = step(after, state([(902, 'phantomBlades'), (951, 'defend')], hp=94),
                        901, [{'t': 'play', 'uid': 901}])
        self.assertEqual(C.descriptor([s[0], spent, consumer])[0]['surviving_source_uids'], [951])

    def test_old_uid_redrawn_by_other_card_does_not_revive(self):
        s = sample(); before = s[0]['after']
        # An emitted discard then redraw within one command still expires old occurrence.
        after = copy.deepcopy(before)
        transit = {'command': {'t': 'synthetic'}, 'before': before, 'after': after,
                   'events': [{'t': 'toDiscard', 'uid': 950}, {'t': 'draw', 'uid': 950}], 'ret': None}
        self.assertEqual(C.descriptor([s[0], transit, s[1]])[0]['surviving_source_uids'], [951])

    def test_end_turn_expires_credit_even_when_same_uids_return(self):
        s = sample(); before = s[0]['after']; after = copy.deepcopy(before)
        after['combat']['turn'] = 2
        transit = {'command': {'t': 'endTurn'}, 'before': before, 'after': after,
                   'events': [{'t': 'discardHand'}, {'t': 'draw', 'uid': 950}], 'ret': None}
        consumer = copy.deepcopy(s[1]); consumer['before'] = after
        self.assertEqual(C.descriptor([s[0], transit, consumer])[0]['surviving_source_uids'], [])

    def test_epoch_change_without_endturn_event_fails_safe_credit(self):
        s = sample(); s[0]['after']['combat']['turn'] = 2
        self.assertEqual(C.descriptor(s)[0]['surviving_source_uids'], [])

    def test_consumer_itself_is_not_a_hand_unit(self):
        before = state([(900, 'surge')]); after = state([(901, 'phantomBlades'), (950, 'defend')])
        source = step(before, after, 900, [{'t': 'draw', 'uid': 901}, {'t': 'draw', 'uid': 950}])
        consumer = step(after, state([(950, 'defend')], hp=97), 901, [{'t': 'play', 'uid': 901}])
        d = C.descriptor([source, consumer])[0]
        self.assertEqual(d['surviving_source_uids'], [950]); self.assertTrue(d['consumer_was_source_drawn'])

    def test_rejected_action_is_not_zero_payoff(self):
        s = sample(); s[1]['ret'] = False
        with self.assertRaisesRegex(ValueError, 'REJECTED'): C.descriptor(s)

    def test_absent_action_is_not_zero_payoff(self):
        s = sample(); s[1]['command']['uid'] = 999
        with self.assertRaisesRegex(ValueError, 'ABSENT'): C.descriptor(s)

    def test_duplicate_hand_uid_rejected(self):
        s = sample(); s[0]['before']['combat']['hand'].append({'uid':900,'id':'surge'})
        with self.assertRaisesRegex(ValueError, 'DUPLICATE'): C.descriptor(s)

    def test_duplicate_draw_occurrence_rejected(self):
        s = sample(); s[0]['events'].append({'t':'draw','uid':950})
        with self.assertRaisesRegex(ValueError, 'DUPLICATE'): C.descriptor(s)

    def test_boolean_is_not_uid(self):
        with self.assertRaisesRegex(ValueError, 'INTEGER'): C.integer(True)

    def test_float_is_not_uid(self):
        with self.assertRaisesRegex(ValueError, 'INTEGER'): C.integer(900.0)

    def test_capped_hp_not_raw_hit(self):
        s=sample()[1];s['before']['combat']['enemies'][0]['hp']=2;s['after']['combat']['enemies'][0]['hp']=-7
        s['events'].append({'t':'hitEnemy','idx':0,'amount':999})
        self.assertEqual(C.useful_hp(s),2)

    def test_wrong_target_rejected(self):
        s=sample()[1];s['command']['target']=1
        with self.assertRaisesRegex(ValueError, 'TARGET'):C.useful_hp(s)

    def test_assignment_is_finite_and_has_no_surged_duplicate(self):
        a=C.assignment();self.assertEqual(len(a),72)
        self.assertFalse(any(s=='surge' and q=='spend_all' for s,_,_,_,q in a))

    def test_off_world_never_issues_drawn_card_command(self):
        r=dict(source='preparation',aspect=1,vow=5,up=False,scenario='spend_all',arm=0)
        self.assertEqual([x.get('uid') for x in C.expected_commands(r)[0]],[900,901])

    def test_reference_adapts_same_as_all_on(self):
        r=dict(source='preparation',aspect=1,vow=5,up=False,scenario='spend_all',arm=-1)
        a=C.expected_commands(r);r['arm']=3;self.assertEqual(a,C.expected_commands(r))

    def test_missing_world_is_not_pass(self):
        with self.assertRaisesRegex(ValueError, 'COVERAGE'):C.group({})

@unittest.skipUnless(os.environ.get('P9_NATIVE_CAPTURE'), 'Native capture not yet opened')
class NativeMutationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw=lzma.decompress(Path(os.environ['P9_NATIVE_CAPTURE']).read_bytes())
        cls.rows=[json.loads(x) for x in raw.splitlines()][1:-1]
        cls.target={r['arm']:r for r in cls.rows if
                    (r['source'],r['aspect'],r['vow'],r['up'],r['scenario']) ==
                    ('preparation',1,0,False,'repeat_consumer')}

    def test_actual_positive_control(self):
        r=C.group(copy.deepcopy(self.target))
        self.assertEqual([x['interaction_useful_hp'] for x in r['contrasts']],[6,6])

    def test_missing_world_rejects(self):
        r=copy.deepcopy(self.target);r.pop(0)
        with self.assertRaisesRegex(ValueError,'COVERAGE'):C.group(r)

    def test_mismatched_initial_state_rejects(self):
        r=copy.deepcopy(self.target);r[0]['start']['combat']['player']['energy']+=1
        with self.assertRaisesRegex(ValueError,'MATCHED_INITIAL'):C.group(r)

    def test_false_native_reference_rejects(self):
        r=copy.deepcopy(self.target);r[-1]['end']['combat']['player']['energy']+=1
        with self.assertRaisesRegex(ValueError,'NATIVE_REFERENCE'):C.group(r)

    def test_rejected_consumer_rejects(self):
        r=copy.deepcopy(self.target);last=r[0]['steps'][-1]
        last['ret']=False;last['after']['return']=False;r[0]['end']['return']=False
        with self.assertRaisesRegex(ValueError,'REJECTED_ACTION'):C.group(r)

    def test_cross_pile_duplicate_rejects(self):
        r=copy.deepcopy(self.target);last=r[0]['steps'][-1]
        last['after']['combat']['draw'].append(copy.deepcopy(last['after']['combat']['draw'][0]))
        r[0]['end']=copy.deepcopy(last['after'])
        with self.assertRaisesRegex(ValueError,'CROSS_PILE_UID'):C.group(r)

    def test_event_deletion_rejects(self):
        r=copy.deepcopy(self.target);r[0]['steps'][-1]['events'].pop()
        with self.assertRaisesRegex(ValueError,'EVENT_BINDING'):C.group(r)

    def test_undeclared_replacement_action_rejects(self):
        r=copy.deepcopy(self.target);r[0]['steps'][-1]['command']['uid']=920
        with self.assertRaisesRegex(ValueError,'DECLARED_ADAPTIVE'):C.group(r)

    def test_consumer_retrocausality_rejects(self):
        r=copy.deepcopy(self.target);r[0]['steps'][0]['after']['combat']['player']['energy']+=1
        with self.assertRaisesRegex(ValueError,'RETROCAUSALITY'):C.group(r)

    def test_false_target_hp_contrast_rejects(self):
        r=copy.deepcopy(self.target);last=r[0]['steps'][-1]
        last['after']['combat']['enemies'][0]['hp']-=1;r[0]['end']=copy.deepcopy(last['after'])
        with self.assertRaisesRegex(ValueError,'PAYOFF_INTERACTION'):C.group(r)

if __name__=='__main__':unittest.main()
