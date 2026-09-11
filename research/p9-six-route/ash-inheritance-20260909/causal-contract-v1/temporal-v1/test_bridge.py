"""Synthetic API/mutation tests. Native and archived diagnostic checks are separate."""
import copy
import unittest
from bridge import Tracker


def card(uid, name='defend'):
    return {'uid':uid, 'id':name, 'up':False}


def fields(cards, uid, coefficient, origins):
    return {'held':[c['uid'] for c in cards if c['uid'] != uid],
            'coefficient':coefficient, 'origins':dict(origins)}


def row(seq, before, after, cmd, events=(), name='', ret=None, fight=0, key='diagnostic'):
    return {'row_key':key, 'sequence':seq, 'fight':fight, 'card':name,
            'command':cmd, 'events':list(events), 'ret':ret,
            'before':{'hand':before}, 'after':{'hand':after}}


class Tests(unittest.TestCase):
    def start(self, drawn=2, background=False):
        t=Tracker()
        before=[card(900,'preparation'),card(901,'phantomBlades'),card(902,'phantomBlades')]
        after=before[1:]+[card(10+i) for i in range(drawn)]
        events=[{'t':'play','uid':900}]+([{'t':'exhaust','uid':900}] if background else [])
        events += [{'t':'draw','uid':10+i} for i in range(drawn)]
        r=row(0,before,after,{'t':'playCard','uid':900},events,'preparation',True)
        t.take(r,3,fields)
        return t,after

    def consume(self,t,held,seq=1,uid=901):
        after=[c for c in held if c['uid']!=uid]
        r=row(seq,held,after,{'t':'playCard','uid':uid},[{'t':'play','uid':uid}],'phantomBlades',True)
        return t.take(r,3,fields),after

    def test_birth_binds_actual_source_instance(self):
        t,h=self.start();out,_=self.consume(t,h)
        self.assertEqual({x['producer_uid'] for x in out['retained_producer_occurrences']},{900})
        self.assertEqual({x['birth_sequence'] for x in out['retained_producer_occurrences']},{0})
        self.assertEqual(len(out['retained_producer_occurrences']),2)

    def test_repeat_consumer_does_not_spend_other_cards(self):
        t,h=self.start();a,h=self.consume(t,h);b,_=self.consume(t,h,2,902)
        self.assertEqual(a['retained_producer_occurrences'],b['retained_producer_occurrences'])

    def test_spent_draw_is_not_retained(self):
        t,h=self.start();after=[c for c in h if c['uid']!=10]
        t.take(row(1,h,after,{'t':'playCard','uid':10},[{'t':'play','uid':10}],'defend',True),3,fields)
        out,_=self.consume(t,after,2)
        self.assertEqual([x['held_uid'] for x in out['retained_producer_occurrences']],[11])

    def test_exhaust_hook_draw_is_background(self):
        t,h=self.start(background=True);out,_=self.consume(t,h)
        self.assertEqual(out['retained_producer_occurrences'],[])

    def test_turn_reset_same_uid_does_not_revive_old_origin(self):
        t,h=self.start();after=[card(901,'phantomBlades'),card(10)]
        t.take(row(1,h,after,{'t':'endTurn'},[{'t':'discardHand'},{'t':'draw','uid':901},{'t':'draw','uid':10}]),3,fields)
        out,_=self.consume(t,after,2)
        self.assertEqual(out['retained_producer_occurrences'],[])
        self.assertEqual(out['consumer_draw_occurrence']['source_card'],'background')

    def test_same_id_distinct_source_instances_are_not_collapsed(self):
        t,h=self.start();h=h+[card(903,'preparation')];t.prior=[c['uid'] for c in h]
        after=[c for c in h if c['uid']!=903]+[card(12)]
        t.take(row(1,h,after,{'t':'playCard','uid':903},[{'t':'play','uid':903},{'t':'draw','uid':12}],'preparation',True),3,fields)
        out,_=self.consume(t,after,2)
        self.assertEqual({x['producer_uid'] for x in out['retained_producer_occurrences']},{900,903})

    def test_drawn_consumer_access_is_separate(self):
        t=Tracker();before=[card(900,'surge')];after=[card(901,'phantomBlades')]
        t.take(row(0,before,after,{'t':'playCard','uid':900},[{'t':'play','uid':900},{'t':'draw','uid':901}],'surge',True),3,fields)
        out,_=self.consume(t,after)
        self.assertEqual(out['retained_producer_occurrences'],[])
        self.assertEqual(out['consumer_draw_occurrence']['producer_uid'],900)

    def test_duplicate_uid_rejected(self):
        with self.assertRaisesRegex(ValueError,'DUPLICATE_HAND'):
            Tracker().take(row(0,[card(1),card(1)],[],{'t':'endTurn'}),3,fields)

    def test_bool_uid_rejected(self):
        with self.assertRaisesRegex(ValueError,'INTEGER_REQUIRED'):
            Tracker().take(row(0,[card(True)],[],{'t':'endTurn'}),3,fields)

    def test_wrong_played_id_rejected(self):
        with self.assertRaisesRegex(ValueError,'PLAY_IDENTITY'):
            Tracker().take(row(0,[card(1,'surge')],[],{'t':'playCard','uid':1},name='preparation',ret=True),3,fields)

    def test_illegal_action_not_zero(self):
        with self.assertRaisesRegex(ValueError,'REJECTED_ACTION_NOT_ZERO'):
            Tracker().take(row(0,[card(1)],[],{'t':'playCard','uid':1},name='defend',ret=False),3,fields)

    def test_missing_sequence_rejected(self):
        with self.assertRaisesRegex(ValueError,'SEQUENCE'):
            Tracker().take(row(1,[],[],{'t':'endTurn'}),3,fields)

    def test_state_discontinuity_rejected(self):
        t,h=self.start()
        with self.assertRaisesRegex(ValueError,'HAND_CONTINUITY'):
            t.take(row(1,[],[],{'t':'endTurn'}),3,fields)

    def test_two_runs_cannot_share_tracker(self):
        t,h=self.start()
        with self.assertRaisesRegex(ValueError,'ONE_COMPLETE_RUN'):
            t.take(row(1,h,[],{'t':'endTurn'},key='different'),3,fields)

    def test_input_is_read_only(self):
        t,h=self.start();r=row(1,h,h,{'t':'useArt'});prior=copy.deepcopy(r)
        t.take(r,3,fields);self.assertEqual(r,prior)

    def test_output_metadata_does_not_alias_internal_state(self):
        t,h=self.start();out,_=self.consume(t,h)
        out['retained_producer_occurrences'][0]['source_card']='tampered'
        self.assertEqual(t.origins[10]['source_card'],'preparation')

    def test_negative_coefficient_rejected(self):
        with self.assertRaisesRegex(ValueError,'NEGATIVE_COEFFICIENT'):
            Tracker().take(row(0,[],[],{'t':'endTurn'}),-1,fields)

    def test_bool_coefficient_rejected(self):
        with self.assertRaisesRegex(ValueError,'INTEGER_REQUIRED'):
            Tracker().take(row(0,[],[],{'t':'endTurn'}),True,fields)

if __name__=='__main__':
    unittest.main(verbosity=2)
