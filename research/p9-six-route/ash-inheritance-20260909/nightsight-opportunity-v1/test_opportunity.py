"""Tests for the new temporal upper bound, not simulated scientific evidence."""
import unittest
import opportunity as m
T={'TURN':'turn','DRAW':'draw','STATUS':'status'}


def command(events=(),card='',fight=0,ret=True,q=4):
    return {'fight':fight,'card':card,'ret':ret,'events':list(events),'command':{'uid':1},
            'before':{'hand':[{'uid':i+1} for i in range(q+1)]}}


def status(n=1,who='player'):
    return {'t':'status','id':'nightsight','who':who,'n':n}


def start(n,draw=True):
    return [{'t':'turn','n':n}]+([{'t':'draw','uid':99}] if draw else [])


class Temporal(unittest.TestCase):
    def setUp(self):self.x=m.Track(T);self.x.consume(command(start(1)))
    def source(self):self.x.consume(command([status()],card='nightSight'))
    def consumer(self,**kw):return self.x.consume(command(card='phantomBlades',**kw))
    def test_source_then_next_turn_then_consumer(self):
        self.source();self.x.consume(command(start(2)))
        self.assertTrue(self.consumer()['possible_persistent_source_path'])
        self.assertEqual(self.x.counts['source_applications'],1)
    def test_same_turn_does_not_count(self):
        self.source();self.assertFalse(self.consumer()['possible_persistent_source_path'])
    def test_empty_turn_packet_does_not_count(self):
        self.source();self.x.consume(command(start(2,False)))
        self.assertFalse(self.consumer()['possible_persistent_source_path'])
    def test_regular_draw_is_not_turn_start(self):
        self.source();self.x.consume(command([{'t':'draw','uid':99}],card='preparation'))
        self.assertFalse(self.consumer()['possible_persistent_source_path'])
    def test_old_fight_source_cannot_leak(self):
        self.source();self.x.consume(command(start(2)))
        self.x.consume(command(start(1),fight=1))
        self.assertFalse(self.consumer(fight=1)['possible_persistent_source_path'])
    def test_removed_status_no_later_path(self):
        self.source();self.x.consume(command([status(-1)]));self.x.consume(command(start(2)))
        self.assertFalse(self.consumer()['possible_persistent_source_path'])
    def test_source_loss_does_not_erase_current_turn_draw(self):
        self.source();self.x.consume(command(start(2)));self.x.consume(command([status(-1)]))
        self.assertTrue(self.consumer()['possible_persistent_source_path'])
        self.x.consume(command(start(3)));self.assertFalse(self.consumer()['possible_persistent_source_path'])
    def test_wrong_who_or_failed_source_is_not_named(self):
        self.x.consume(command([status(who=0)],card='nightSight'));self.x.consume(command(start(2)))
        self.assertFalse(self.consumer()['possible_persistent_source_path'])
        self.x.consume(command([status()],card='nightSight',ret=False));self.x.consume(command(start(3)))
        self.assertFalse(self.consumer()['possible_persistent_source_path'])
    def test_different_source_is_not_automatically_nightsight_card(self):
        self.x.consume(command([status()],card='other'));self.x.consume(command(start(2)))
        self.assertFalse(self.consumer()['possible_persistent_source_path'])
        self.assertEqual(self.x.counts['other_positive_status_applications'],1)
    def test_consumer_before_source_not_retroactive(self):
        before=self.consumer();self.source();self.x.consume(command(start(2)))
        self.assertFalse(before['possible_persistent_source_path']);self.assertTrue(self.consumer()['possible_persistent_source_path'])
    def test_duplicate_turn_rejected(self):
        with self.assertRaisesRegex(ValueError,'TURN_CONTINUITY'):self.x.consume(command(start(1)))
    def test_illegal_consumer_not_observed(self):
        self.source();self.x.consume(command(start(2)));self.assertIsNone(self.consumer(ret=False))
    def test_hand_extent_not_damage(self):
        self.source();self.x.consume(command(start(2)))
        self.assertFalse(self.consumer(q=4)['above_reserve']);self.assertTrue(self.consumer(q=5)['above_reserve'])
    def test_held_identity_required(self):
        x=command(card='phantomBlades');x['command']['uid']=999
        with self.assertRaisesRegex(ValueError,'HELD_CONSUMER'):self.x.consume(x)
    def test_fractional_status_rejected(self):
        with self.assertRaisesRegex(ValueError,'EVENT_INTEGER'):self.x.consume(command([status(.5)],card='nightSight'))
    def test_duplicate_draw_events_do_not_duplicate_turn_counter(self):
        self.source();self.x.consume(command(start(2)+[{'t':'draw','uid':100}]))
        self.assertEqual(self.x.counts['potential_source_turns_with_draw'],1)
        self.assertEqual(self.x.counts['draws_in_potential_source_turn_packet'],2)
    def test_repeated_source_and_multiple_fights_accounted(self):
        self.source();self.source();self.x.consume(command(start(2)));self.consumer()
        self.x.consume(command(start(1),fight=1));self.x.consume(command([status(2)],card='nightSight',fight=1))
        self.x.consume(command(start(2),fight=1));self.consumer(fight=1)
        self.assertEqual(self.x.counts['source_applications'],3);self.assertEqual(self.x.counts['possible_path_plays'],2)
    def test_aliases_come_from_bound_event_types(self):
        z=m.Track({'TURN':'T','DRAW':'D','STATUS':'S'})
        z.consume(command([{'t':'T','n':1}]))
        z.consume(command([{'t':'S','id':'nightsight','who':'player','n':1}],card='nightSight'))
        z.consume(command([{'t':'T','n':2},{'t':'D','uid':2}]))
        self.assertTrue(z.consume(command(card='phantomBlades'))['possible_persistent_source_path'])

if __name__=='__main__':unittest.main()
