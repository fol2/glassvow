"""Post-observation regression tests using real preserved complete groups.
These tests are not new scientific observations or an independent review.
"""
import copy
from pathlib import Path
import tempfile
import unittest
import audit_capture as audit
import read

ROOT=Path(__file__).resolve().parent


class NativeCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases={(source,*key):rows for source,key,rows in audit.groups(ROOT/'execution-1')}

    def group(self,source='bloodRite',context='available'):
        return copy.deepcopy(self.cases[source,1,0,False,context])

    def check(self,rows,source='bloodRite',context='available'):
        return read.check_group(source,(1,0,False,context),rows)

    def test_all_192_complete_native_groups(self):
        self.assertEqual(len(self.cases),192)
        for key,rows in self.cases.items():
            audit.describe(key[0],key[1:],rows)

    def test_omitted_proper_subset_is_rejected(self):
        rows=self.group();del rows[6]
        with self.assertRaisesRegex(ValueError,'FACTORIAL'):self.check(rows)

    def test_same_outcome_does_not_rescue_mismatched_reference(self):
        rows=self.group();rows[-1]['end']['combat']['future_flag']=1
        with self.assertRaises(ValueError):self.check(rows)

    def test_source_mediator_cannot_change_original_energy(self):
        rows=self.group();rows[2]['steps'][0]['after']['combat']['player']['energy']+=1
        with self.assertRaises(ValueError):self.check(rows)

    def test_source_energy_cannot_erase_hp_cost(self):
        rows=self.group();rows[4]['steps'][0]['after']['combat']['player']['hp']+=3
        with self.assertRaises(ValueError):self.check(rows)

    def test_wrong_producer_uid_definition_rejected(self):
        rows=self.group()
        for r in rows.values():
            for snap in (r['start'],r['steps'][0]['before']):
                for card in snap['combat']['hand']:
                    if card['uid']==900:card['id']='preparation'
        with self.assertRaisesRegex(ValueError,'PRODUCER_INSTANCE'):
            audit.describe('bloodRite',(1,0,False,'available'),rows)

    def test_empty_draw_necessary_pattern_not_causal(self):
        for source in ('preparation','surge'):
            r=self.check(self.group(source,'empty_draw'),source,'empty_draw')
            self.assertTrue(r['necessary_activation_is_not_causal_witness'])
            self.assertEqual(r['utility_energy_enabled']['actual_hp_interaction'],0)
            self.assertGreater(r['all_on_consumer']['actual_hp_removed'],0)

    def test_illegal_consumer_is_not_imputed_zero(self):
        rows=self.group(context='no_energy')
        r=self.check(rows,context='no_energy')
        self.assertFalse(r['utility_energy_disabled']['identified_for_fixed_commands'])
        self.assertIsNone(r['utility_energy_disabled']['actual_hp_interaction'])
        self.assertTrue(r['utility_energy_enabled']['identified_for_fixed_commands'])

    def test_overkill_healing_is_not_erased_by_capped_damage(self):
        r=self.check(self.group(context='already_lethal'),context='already_lethal')
        self.assertEqual(r['utility_energy_enabled']['actual_hp_interaction'],0)
        self.assertEqual(r['utility_energy_enabled']['healing_interaction'],5)

    def test_native_reference_is_the_existing_candidate(self):
        r=self.check(self.group())
        self.assertEqual(r['all_on_consumer']['actual_hp_removed'],19)
        self.assertEqual(r['mediator_off_consumer']['actual_hp_removed'],9)

    def test_effect_draw_uid_is_not_a_label(self):
        rows=self.group('preparation')
        # Preserve all-on/reference equality and retrocausal pairs: the event itself
        # is then rejected against the actual source-produced inventory identities.
        for arm in (-1,2,3,6,7):
            for event in rows[arm]['steps'][0]['events']:
                if event.get('t')=='draw':event['uid']=99999
        with self.assertRaises(ValueError):
            audit.describe('preparation',(1,0,False,'available'),rows)

    def test_source_fatal_has_no_energy_or_charge(self):
        r=audit.describe('bloodRite',(1,0,False,'source_fatal'),self.group(context='source_fatal'))
        self.assertEqual(r['source_net_energy_delta'],0)
        self.assertEqual(r['source_bloodfire_created'],0)
        self.assertFalse(r['consumer_eligible'])

    def test_manifest_tamper_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'x').write_bytes(b'abc')
            with self.assertRaisesRegex(ValueError,'BYTE_IDENTITY'):
                audit.verify_files(p,[{'path':'x','bytes':3,'sha256':audit.sha(b'abd')}])

    def test_duplicate_manifest_entry_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'x').write_bytes(b'abc')
            entry={'path':'x','bytes':3,'sha256':audit.sha(b'abc')}
            with self.assertRaisesRegex(ValueError,'DUPLICATE_MANIFEST'):
                audit.verify_files(p,[entry,entry])

    def test_parent_manifest_path_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'UNSAFE_MANIFEST'):
            audit.verify_files(Path('.'),[{'path':'../private','bytes':0,'sha256':''}])


if __name__=='__main__':unittest.main(verbosity=2)
