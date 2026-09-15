"""R1-R3 adversarial checks through the actual shipped entry, no game runs."""
import copy
import json
import unittest
from unittest.mock import patch

import prospective_admission as a
import admission_pipeline as pipeline
import synthetic_records as s
import evidence_boundary as b
import reference_kernel as k
import frozen_models as models

RESULTS = []


def run(packet, context, name='probe'):
    result = a.evaluate_packet(packet, context)
    RESULTS.append({'case': name, 'integrity': result['integrity'], 'reason': result['reason'],
                    'statistical': result.get('statistical'), 'predicates': result['predicates'],
                    'certificate': result['certificate']})
    return result


def mutate(role, edit, repin=True, packet_edit=None):
    p, c = s.good_bundle()
    loc = b.flatten(p['evidence'])[role]
    value = s.load_json(c, loc)
    replacement = edit(value)
    if replacement is not None:
        value = replacement
    s.store_json(c, loc, value)
    if packet_edit:
        packet_edit(p, c)
    if repin:
        s.repin(p, c)
    return p, c


class EntryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p, cls.c = s.good_bundle()
        cls.positive = run(cls.p, cls.c, 'coherent-positive-without-summaries')

    def test_positive_204_counts_152_predicates(self):
        r = self.positive
        self.assertEqual(r['integrity'], 'PASS', r.get('reason'))
        self.assertEqual(r['statistical'], 'PASS')
        self.assertEqual(len(r['rows']), 204)
        self.assertEqual(len(r['predicates']), 152)
        self.assertEqual(set(r['predicates'].values()), {'PASS'})
        self.assertEqual(r['root_checks'], {'factual_records': 40960, 'paired_overlap': 0})
        self.assertFalse(r['certificate']); self.assertFalse(r['empirical_certificate'])
        self.assertEqual((r['game_outcome_rows'], r['native_invocations']), (0, 0))
        self.assertNotIn('rows', self.p)
        self.assertEqual(self.p['identities']['policies']['A']['R'], self.p['identities']['policies']['B']['R'])
        self.assertEqual(self.p['identities']['policies']['A']['B'], self.p['identities']['signed_B'])
        counts = {x['key']: x['successes'] for x in r['rows']}
        for panel, vow in a.STRATA:
            q = f'{panel}/v{vow}'
            self.assertEqual([counts[q+'/'+m] for m in ('B.win','R_B.gain','R_B.loss')], [400,1200,0])
            for route in ('K1','K2','K3'):
                self.assertEqual([counts[q+'/'+route+'/'+m] for m in ('acquire','enact','win_enact','K_R.gain','K_R.loss')], [1200,1000,1000,0,0])
                self.assertEqual(counts[q+'/'+route+'/on.correct'], 256)
                self.assertEqual(counts[q+'/'+route+'/off.correct'], 256)
                self.assertEqual(counts[q+'/'+route+'/natural_negative.not_negative'], 0)
            # K1/K2 each enact on 1,000 roots in their own arms. Comparing the two
            # arms would give zero exclusive use. Same-trajectory reduction does not.
            self.assertEqual(counts[q+'/pair12/exclusive_k'], 700)
            self.assertEqual(counts[q+'/pair12/exclusive_l'], 1000)

    def test_unchanged_kernel_16_methods(self):
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(k.DesignTests)
        import io
        result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
        self.assertTrue(result.wasSuccessful())
        self.assertEqual(result.testsRun, 16)

    def test_packet_authority_faults_and_repair(self):
        faults = {'bound': True, 'approved': True, 'certificate': True, 'role': 'form_ok',
            'trusted_verifier': True, 'game_outcome_rows': 1, 'borrow_548': True,
            'credit_from_history': True, 'top_up': True, 'second_candidate': True,
            'epoch': 'OTHER', 'authority': 'OTHER'}
        for field, value in faults.items():
            with self.subTest(field=field):
                p = copy.deepcopy(self.p); p[field] = value
                result = run(p, self.c, 'packet-' + field)
                self.assertEqual(result['integrity'], 'REJECT', result)
                self.assertFalse(result['certificate'])
        self.assertEqual(run(self.p, self.c, 'packet-repaired')['statistical'], 'PASS')

    def test_summary_crosscheck_not_input(self):
        p = copy.deepcopy(self.p); p['rows'] = copy.deepcopy(self.positive['rows'])
        self.assertEqual(run(p, self.c, 'matching-summaries')['statistical'], 'PASS')
        p['rows'][0]['successes'] += 1
        self.assertEqual(run(p, self.c, 'changed-summary')['reason'], 'summary_mismatch')
        for kind in ('missing','duplicate','extended','foreign','bool'):
            p = copy.deepcopy(self.p); p['rows'] = copy.deepcopy(self.positive['rows'])
            if kind == 'missing': p['rows'].pop()
            if kind == 'duplicate': p['rows'].append(p['rows'][0])
            if kind == 'extended': p['rows'][0]['n'] += 1
            if kind == 'foreign': p['rows'][0]['key'] = 'detector/accuracy'
            if kind == 'bool': p['rows'][0]['successes'] = True
            self.assertEqual(run(p, self.c, 'summary-'+kind)['integrity'], 'REJECT')

    def test_label_only_or_unconditional_pass_is_detected(self):
        good = {'integrity':'PASS','reason':'SYNTHETIC_PACKET_WELL_FORMED',
                'statistical':'PASS','certificate':False,'predicates':{}}
        p = copy.deepcopy(self.p); p['bound'] = True
        with patch.object(a, 'evaluate_packet', return_value=good):
            self.assertNotEqual(run(p, self.c)['integrity'], 'REJECT')
        self.assertEqual(run(p, self.c, 'load-bearing-packet-guard')['integrity'], 'REJECT')


class PrimitiveTests(unittest.TestCase):
    def reject(self, role, edit, needle=None):
        p,c = mutate(role, edit)
        result = run(p,c, role+'-'+(needle or 'malformed'))
        self.assertEqual(result['integrity'], 'REJECT', result.get('reason'))
        if needle: self.assertIn(needle, result['reason'])
        return result

    def test_impossible_per_root_bits_even_with_unchanged_totals(self):
        def bad(doc):
            gains = [0]*400+[1]*1200+[0]*448
            losses = [0]*2048
            # A false gain at a B-win root replaces a true gain, preserving its total.
            gains[0], gains[400] = 1, 0
            doc['bits'] = {'R_B.gain': gains, 'R_B.loss': losses}
        self.reject('factual/A/v0', bad, 'derived_crosscheck')

    def test_enactment_requires_same_root_prior_acquisition(self):
        self.reject('native_export/A/v0', lambda d: d['arms']['K1'][0]['snapshots'][0].update(components=[]), 'enactment_without_acquisition')

    def test_all_memberships_and_terminal_are_required(self):
        self.reject('native_export/A/v0', lambda d: (d['arms']['K1'][0]['decisions'].pop('K2'), None)[1], 'missing_route_membership')
        self.reject('native_export/A/v0', lambda d: d['arms']['B'][0]['terminal'].update(outcome='UNKNOWN'), 'missing_or_invalid_terminal')

    def test_native_source_view_root_and_illegal_prefix(self):
        edits = [
            ('native_reader_identity', lambda d: d['arms']['K1'][0]['decisions']['K1'][1]['native'].update(reader_sha256='f'*64)),
            ('view_origin', lambda d: d['arms']['K1'][0]['decisions']['K1'][1]['views']['111'].update(root=1)),
            ('illegal_prefix_tail_not_unknown', lambda d: d['arms']['K1'][0]['decisions']['K1'][0]['native'].update(unavailable_tail=0)),
            ('missing_native_resource_observation', lambda d: d['arms']['K1'][0]['snapshots'][0].update(resources={})),
        ]
        for reason, edit in edits:
            with self.subTest(reason=reason): self.reject('native_export/A/v0', edit, reason)

    def test_wrong_cached_predictions_reject_without_summary_rows(self):
        for field, values in (('on_pred',[0]*256), ('off_pred',[1]*256), ('natural_pred',[None]*256)):
            with self.subTest(field=field):
                self.reject('measurement/A/v0/K1', lambda d: d.update({field:values}), 'derived_crosscheck')

    def test_wrong_native_ground_truth_rejects(self):
        def edit(doc):
            for row in doc['arms']['K1'][:256]:
                row['decisions']['K1'][1]['views']['101']['native'] = {'eligible':1,'payoff':1}
        self.reject('native_export/A/v0', edit, 'invalid_manipulation_ground_truth')

    def test_resolved_reference_cannot_point_to_another_root(self):
        def edit(doc): doc['cases'][0]['views']['111']['path'][2] = 1
        self.reject('measurement/A/v0/K1', edit, 'measurement_native_reference')

    def test_first_enactment_natural_first_and_masks(self):
        def later(doc): doc['roots'] = doc['roots'][1:]+[doc['roots'][0]]
        self.reject('measurement/A/v0/K1', later, 'measurement_selection')
        def negative(doc): doc['natural_cases'][0]['view']['path'][5] = 1
        self.reject('measurement/A/v0/K1', negative, 'natural_negative_reference')
        def mask(doc): del doc['cases'][0]['views']['000']
        self.reject('measurement/A/v0/K1', mask, 'measurement_mask_set')

    def test_supplied_peer_correctness_and_exclusive_are_only_crosschecks(self):
        for key in ('pair12/correct_k','pair12/exclusive_k'):
            self.reject('peer/A/v0', lambda d: d.update(bits={key:([0]+[1]*2047 if key.endswith('correct_k') else [1]*2048)}), 'derived_crosscheck')


class NumericalEntryTests(unittest.TestCase):
    def result(self, edit):
        p,c = mutate('native_export/A/v0', edit)
        return run(p,c, self._testMethodName)

    def test_weak_reference_fixed_failure(self):
        def edit(doc):
            for i,row in enumerate(doc['arms']['R']): row['terminal']['outcome'] = 'win' if i<700 else 'loss'
        r=self.result(edit); self.assertEqual(r['integrity'],'PASS'); self.assertEqual(r['predicates']['A/v0/R_minus_B'],'FAIL')

    def test_reference_interval_straddles_actual_entry(self):
        def edit(doc):
            for i,row in enumerate(doc['arms']['R']): row['terminal']['outcome'] = 'win' if i<1117 else 'loss'
        r=self.result(edit); self.assertEqual(r['integrity'],'PASS'); self.assertEqual(r['predicates']['A/v0/R_minus_B'],'INCONCLUSIVE')

    def test_bad_route_quality_and_activation_without_wins(self):
        def edit(doc):
            for row in doc['arms']['K1']: row['terminal']['outcome'] = 'loss'
        r=self.result(edit); self.assertEqual(r['integrity'],'PASS')
        self.assertEqual(r['predicates']['A/v0/K1/quality'],'FAIL')
        self.assertEqual(r['predicates']['A/v0/K1/win_enact'],'FAIL')
        self.assertEqual(r['predicates']['A/v0/K1/enact'],'PASS')

    def test_fallback_only_success_insufficient_measurement(self):
        def edit(doc):
            for row in doc['arms']['K1']:
                row['decisions']['K1'] = row['decisions']['K1'][:1]
        r=self.result(edit); self.assertEqual(r['integrity'],'INCONCLUSIVE'); self.assertNotEqual(r.get('statistical'),'PASS')

    def test_low_support_but_complete_fixed_measurement(self):
        def edit(doc):
            for row in doc['arms']['K1'][256:]:
                row['decisions'] = {'K1':row['decisions']['K1'][:1],'K2':[],'K3':[]}
                row['snapshots'][0]['components'] = []
        r=self.result(edit); self.assertEqual(r['integrity'],'PASS')
        self.assertEqual(r['predicates']['A/v0/K1/acquire'],'FAIL')
        self.assertEqual(r['predicates']['A/v0/K1/enact'],'FAIL')

    def test_recomputed_predictions_change_decisions_without_cached_bits(self):
        def edit(doc):
            for row in doc['arms']['K1'][:256]:
                row['decisions']['K1'][1]['views']['111']['public']['chain_signal']=0
                row['decisions']['K1'][1]['views']['101']['public']['chain_signal']=1
                row['decisions']['K1'][0]['views']['111']['public']['chain_signal']=1
        r=self.result(edit); self.assertEqual(r['integrity'],'PASS')
        for key in ('on','off','natural_null'):
            self.assertEqual(r['predicates']['A/v0/K1/'+key],'FAIL')

    def test_recomputed_abstentions_are_wrong(self):
        def edit(doc):
            for row in doc['arms']['K1'][:256]:
                row['decisions']['K1'][1]['views']['111']['public']['chain_signal']=.5
                row['decisions']['K1'][0]['views']['111']['public']['chain_signal']=.5
        r=self.result(edit); self.assertEqual(r['integrity'],'PASS')
        self.assertEqual(r['predictions']['A/v0/K1']['on_pred'],[None]*256)
        self.assertEqual(r['predicates']['A/v0/K1/on'],'FAIL')
        self.assertEqual(r['predicates']['A/v0/K1/natural_null'],'FAIL')

    def test_identical_peer_fingerprints_not_rescued_by_arm_names(self):
        def edit(doc):
            for row in doc['arms']['K2']: row['public_fingerprint']={'tempo':6,'guarding':1}
        r=self.result(edit); self.assertEqual(r['integrity'],'PASS')
        self.assertEqual(r['predicates']['A/v0/pair12/correct_l'],'FAIL')


class ModelTests(unittest.TestCase):
    def test_boolean_public_features_zero_variance_and_ties(self):
        m=models.fit([{'x':[0,1],'label':0},{'x':[1,1],'label':1}],['signal','constant'],(0,1))
        self.assertEqual(models.predict(m,models.features({'signal':True,'constant':1},m['features'])),1)
        self.assertIsNone(models.predict(m,[.5,1]))
        self.assertEqual(m['scale'][1],0)

    def test_model_mutations_and_development_selection(self):
        cases = [
            ('model',lambda d:d['strata']['A/v0']['K1']['full'].pop('centroids') and None),
            ('model',lambda d:d.update(fitted_on='confirmation')),
            ('model',lambda d:d['strata']['A/v0']['K1']['full'].update(mean=[99,99])),
            ('features',lambda d:d.update(blind_removed=[])),
            ('features',lambda d:d.update(peer_features=['seed_id'])),
            ('development_manifest',lambda d:d['evaluations']['A/v0']['K1'][0].update(policy_sha256='f'*64)),
            ('cost',lambda d:d['R'].update(hidden_rng=True)),
            ('cost',lambda d:d['K1'].update(forward_evals_per_decision=64)),
            ('cost',lambda d:d['R'].update(actual_evaluations=[129])),
        ]
        for role,edit in cases:
            with self.subTest(role=role):
                p,c=mutate(role,edit);r=run(p,c,'model-development-'+role)
                self.assertEqual(r['integrity'],'REJECT',r.get('reason'))

    def test_cost_caps_are_frozen_not_reporter_selected(self):
        def edit(doc):
            for arm in a.ARMS: doc[arm]['forward_evals_per_decision'] = 64
        p,c = mutate('cost', edit)
        self.assertEqual(run(p,c,'cost-cap-after-freeze')['reason'], 'cost_envelope_not_frozen')

    def test_native_work_and_cpu_are_observed_not_summary_assertions(self):
        cases = [
            ('decision_cost_overrun', lambda d: d['arms']['K1'][0]['work'].update(forward_evaluations=[129])),
            ('native_cpu_cost', lambda d: d['arms']['K1'][0]['work'].update(cpu_seconds=301)),
            ('cost_cpu_reconciliation', lambda d: d['arms']['K1'][0]['work'].update(cpu_seconds=.02)),
            ('unknown_cost', lambda d: d['arms']['K1'][0]['work'].update(forward_evaluations=[])),
        ]
        for reason,edit in cases:
            p,c=mutate('native_export/A/v0',edit)
            self.assertEqual(run(p,c,'native-work-'+reason)['reason'],reason)

    def test_no_qualified_development_configuration(self):
        def edit(d):
            for row in d['evaluations']['A/v0']['K1'][0]['rows']:
                row['decisions']['K1']=row['decisions']['K1'][:1]
        p,c=mutate('development_manifest',edit)
        self.assertIn('development_qualification',run(p,c,'no-dev-qualification')['reason'])


class LoadBearingTests(unittest.TestCase):
    def test_material_guard_deletion_exposes_false_acceptance(self):
        import record_io, record_contract, model_contract, observation_records, allocation_events
        p,c=s.good_bundle()
        positive=a.evaluate_packet(p,c)
        raw=record_io.ingest(p,c);pipeline.identities(p,raw,c)
        fitted=model_contract.development_models(raw,c.expected_identities['provenance'])
        counts={row['key']:row['successes'] for row in positive['rows']}
        scenarios=[
            ('authority',pipeline,'packet_guards',lambda *args:None,None,lambda d:None),
            ('sampler',record_contract,'validate',lambda *args:None,'sampler_manifest',lambda d:d.update(method='select_winners')),
            ('model',model_contract,'development_models',lambda *args:fitted,'model',lambda d:d['strata']['A/v0']['K1']['full'].update(mean=[99,99])),
            ('cost',model_contract,'cost_envelope',lambda *args:positive['cpu_by_arm'],'cost',lambda d:d['R'].update(hidden_rng=True)),
            ('allocation',allocation_events,'validate',lambda *args:positive['allocation'],'allocation',lambda d:d['limits'].update(cpu_seconds=10**15)),
            ('derive',observation_records,'derive',lambda *args:(counts,positive['predictions'],positive['root_checks']),
                'native_export/A/v0',lambda d:d['arms']['R'][0]['terminal'].update(outcome='UNKNOWN')),
        ]
        for name,module,method,replacement,role,edit in scenarios:
            with self.subTest(guard=name):
                if role:
                    badp,badc=mutate(role,edit)
                    if role=='allocation':
                        badp['allocation']=s.load_json(badc,'synth://allocation')
                else:
                    badp,badc=s.good_bundle();badp['bound']=True
                real=run(badp,badc,'guard-present-'+name)
                self.assertEqual(real['integrity'],'REJECT',real.get('reason'))
                with patch.object(module,method,side_effect=replacement):
                    exposed=run(badp,badc,'guard-deleted-'+name)
                self.assertEqual(exposed.get('statistical'),'PASS',exposed.get('reason'))
                self.assertEqual(run(badp,badc,'guard-restored-'+name)['integrity'],'REJECT')

    def test_digest_verifier_is_load_bearing(self):
        p,c=s.good_bundle();c.store[p['evidence']['factual']['A/v0']]+=b' '
        expected=c.expected_identities['provenance']
        receipts={name:b.loads(raw,name) for name,raw in c.receipts.items()}
        self.assertEqual(run(p,c,'digest-guard-present')['integrity'],'REJECT')
        with patch.object(b,'verify',return_value=(expected,receipts)):
            self.assertEqual(run(p,c,'digest-guard-deleted')['statistical'],'PASS')
        self.assertEqual(run(p,c,'digest-guard-restored')['integrity'],'REJECT')
