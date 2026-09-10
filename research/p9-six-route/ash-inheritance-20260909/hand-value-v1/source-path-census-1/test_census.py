import copy
import unittest
import census as c


def frame(key='5:0:73625100', seq=0, card='', before=(), after=(), events=(), ret=True, uid=1, fight=0):
    return {'row_key': key, 'kind': 'command', 'sequence': seq, 'original_untouched_by_clones': True,
            'before': {'hand': [{'uid': x} for x in before]}, 'after': {'hand': [{'uid': x} for x in after]},
            'card': card, 'ret': ret, 'command': {'uid': uid}, 'events': list(events), 'fight': fight}


class Tests(unittest.TestCase):
    def test_direct_draw_exhaust_background_separated(self):
        origins = {}
        n = c.update_origins([{'t':'draw','uid':2},{'t':'exhaust'},{'t':'draw','uid':3}], 'preparation', True, origins)
        self.assertEqual(n, 1)
        self.assertEqual(origins, {2:'preparation',3:'background'})

    def test_illegal_or_ordinary_source_is_not_direct(self):
        for card, legal in (('surge',False),('other',True)):
            origins = {}
            self.assertEqual(c.update_origins([{'t':'draw','uid':2}],card,legal,origins),0)
            self.assertEqual(origins,{2:'background'})

    def test_source_drew_consumer_is_not_other_held_card(self):
        t = c.Tracker('11', {'5:0:73625100'})
        t.feed(frame(card='surge',before=[1,9],after=[2,9],events=[{'t':'draw','uid':2}]))
        t.feed(frame(seq=1,card='phantomBlades',before=[2,9],after=[9],uid=2))
        r=t.finish()['5:0:73625100']
        self.assertEqual((r['source_access_plays'],r['retained_source_plays']),(1,0))

    def test_other_drawn_card_is_retained_path(self):
        t=c.Tracker('11', {'5:0:73625100'})
        t.feed(frame(card='preparation',before=[1,9],after=[2,9],events=[{'t':'draw','uid':2}]))
        t.feed(frame(seq=1,card='phantomBlades',before=[2,9],after=[2],uid=9))
        self.assertEqual(t.finish()['5:0:73625100']['retained_source_plays'],1)

    def test_both_paths_count_once_in_union(self):
        t=c.Tracker('11', {'5:0:73625100'})
        t.feed(frame(card='preparation',before=[1],after=[2,3],events=[{'t':'draw','uid':2},{'t':'draw','uid':3}]))
        t.feed(frame(seq=1,card='phantomBlades',before=[2,3],after=[3],uid=2))
        r=t.finish()['5:0:73625100']
        self.assertEqual((r['source_access_plays'],r['retained_source_plays'],r['either_source_path_plays']),(1,1,1))

    def test_source_off_leak_is_failure(self):
        t=c.Tracker('01', {'5:0:73625100'})
        with self.assertRaisesRegex(ValueError,'DIRECT_DRAW_LEAK'):
            t.feed(frame(card='surge',before=[1],after=[2],events=[{'t':'draw','uid':2}]))

    def test_source_off_background_draw_is_allowed(self):
        t=c.Tracker('01', {'5:0:73625100'})
        t.feed(frame(card='preparation',before=[1],after=[2],events=[{'t':'exhaust'},{'t':'draw','uid':2}]))
        t.feed(frame(seq=1,card='phantomBlades',before=[2],after=[],uid=2))
        self.assertEqual(t.finish()['5:0:73625100']['either_source_path_plays'],0)

    def test_disabled_consumer_can_have_other_hit_effects(self):
        t=c.Tracker('00', {'5:0:73625100'})
        t.feed(frame(card='phantomBlades',before=[1],after=[],events=[{'t':'hitEnemy','amount':7}]))
        self.assertEqual(t.finish()['5:0:73625100']['phantom_plays'],1)
        self.assertFalse(t.fields[0]['consumer_factor_assigned'])

    def test_played_card_provenance_does_not_survive_redraw(self):
        t=c.Tracker('11', {'5:0:73625100'})
        t.feed(frame(card='preparation',before=[1],after=[2],events=[{'t':'draw','uid':2}]))
        t.feed(frame(seq=1,card='other',before=[2],after=[],uid=2))
        t.feed(frame(seq=2,before=[],after=[2],events=[{'t':'draw','uid':2}]))
        t.feed(frame(seq=3,card='phantomBlades',before=[2],after=[],uid=2))
        self.assertEqual(t.finish()['5:0:73625100']['source_access_plays'],0)

    def test_new_fight_does_not_reuse_origins(self):
        t=c.Tracker('11', {'5:0:73625100'})
        t.feed(frame(card='surge',before=[1],after=[2],events=[{'t':'draw','uid':2}]))
        t.feed(frame(seq=1,card='phantomBlades',before=[2],after=[],uid=2,fight=1))
        self.assertEqual(t.finish()['5:0:73625100']['source_access_plays'],0)

    def test_sequence_or_continuity_corruption(self):
        for record, expected in ((frame(seq=1),'COMMAND_IDENTITY'),(frame(before=[1,1]),'HELD_IDENTITIES')):
            t=c.Tracker('11', {'5:0:73625100'})
            with self.assertRaisesRegex(ValueError,expected):t.feed(record)
        t=c.Tracker('11', {'5:0:73625100'});t.feed(frame(after=[1]))
        with self.assertRaisesRegex(ValueError,'HAND_CONTINUITY'):t.feed(frame(seq=1,before=[2]))

    def test_full_coverage_required(self):
        t=c.Tracker('11', {'5:0:73625100','5:1:73625100'})
        t.feed(frame())
        with self.assertRaisesRegex(ValueError,'INCOMPLETE_ASSIGNMENT'):t.finish()

    def test_illegal_phantom_not_counted(self):
        t=c.Tracker('11', {'5:0:73625100'})
        t.feed(frame(card='phantomBlades',before=[1],after=[1],ret=False))
        self.assertEqual(t.finish()['5:0:73625100']['phantom_plays'],0)

    def test_actual_response_arithmetic(self):
        patterns={'0000':163,'0001':5,'0010':4,'0011':33,'0100':2,'0101':10,'0111':6,'1010':6,'1011':6,'1100':12,'1101':4,'1110':3,'1111':258}
        # These are known aggregate numbers, not manufactured real row assignments.
        keys=iter(sorted(c.keyset())); rows={w:{} for w in c.WORLDS}
        for p,n in patterns.items():
            for _ in range(n):
                k=next(keys)
                for w,b in zip(c.WORLDS,p):rows[w][k]=int(b)
        r=c.response_patterns(rows)
        self.assertEqual(r['wins'],{'00':289,'01':295,'10':316,'11':322})
        self.assertEqual(r['paired_response_distributions']['interaction'],{'-1':15,'0':482,'1':15})
        self.assertEqual(r['paired_response_distributions']['consumer'],{'-1':13,'0':480,'1':19})

    def test_interaction_need_not_be_zero_or_one(self):
        rows={w:{k:int(w in ('00','11')) for k in c.keyset()} for w in c.WORLDS}
        self.assertEqual(c.response_patterns(rows)['paired_response_distributions']['interaction'],{'2':512})
        rows={w:{k:int(w in ('01','10')) for k in c.keyset()} for w in c.WORLDS}
        self.assertEqual(c.response_patterns(rows)['paired_response_distributions']['interaction'],{'-2':512})

    def test_paths(self):
        for x in ('','../x','/etc/passwd','a/../b','a//b','a\\b','.'):
            with self.assertRaisesRegex(ValueError,'PATH'):c.path_safe(x)

if __name__=='__main__':unittest.main()
