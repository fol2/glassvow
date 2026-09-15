"""R2/R3 byte-binding, scope, sampler, schema and chronology regressions."""
import unittest
import synthetic_records as s
import evidence_boundary as b
from synthetic_controls import run, mutate


class BoundaryRecordTests(unittest.TestCase):
    def test_every_role_is_pinned_not_a_locator_assertion(self):
        p,c=s.good_bundle()
        for role,loc in b.flatten(p['evidence']).items():
            with self.subTest(role=role):
                bad=c.copy(); bad.store[loc]=bad.store[loc]+b' '
                result=run(p,bad,'digest-'+role)
                self.assertEqual(result['integrity'],'REJECT')
                self.assertIn('role_digest:',result['reason'])
        self.assertEqual(run(p,c,'all-role-bytes-restored')['statistical'],'PASS')

    def test_missing_source_and_wrong_locator(self):
        p,c=s.good_bundle();c.store.pop(p['evidence']['factual']['A/v0'])
        self.assertIn('missing_source_raw',run(p,c,'missing-raw')['reason'])
        p,c=s.good_bundle();p['evidence']['factual']['A/v0']='native://unknown'
        self.assertIn('role_locator',run(p,c,'wrong-locator')['reason'])

    def test_sampler_content_after_explicit_synthetic_repin(self):
        edits=[('method',lambda d:d.update(method='choose_winning_roots')),
               ('missing-method',lambda d:d.pop('method')),
               ('manifest',lambda d:d.update(manifest={'A/v0':[3000]})),
               ('frame',lambda d:d['frame'].update(domain=[1,9999])),
               ('exclusions',lambda d:d.update(forbidden=[])),
               ('permutation',lambda d:d['measurement_orders']['A/v0/K1'].reverse()),
               ('joint-draw',lambda d:d.update(draw_scope=['A/v0']))]
        for name,edit in edits:
            with self.subTest(name=name):
                p,c=mutate('sampler_manifest',lambda d:(edit(d),None)[1])
                self.assertEqual(run(p,c,'sampler-'+name)['integrity'],'REJECT')

    def test_development_exposure_protection_and_namespace(self):
        edits=[('development_manifest',lambda d:d['roots'].update({'A/v0':[3000]})),
               ('development_manifest',lambda d:d['roots'].__setitem__('A/v0',d['roots']['B/v5'])),
               ('exposure_manifest',lambda d:d.update(protected=[])),
               ('exposure_manifest',lambda d:d.update(namespaces={})),
               ('exposure_manifest',lambda d:d.update(status='UNKNOWN'))]
        for role,edit in edits:
            with self.subTest(role=role):
                p,c=mutate(role,lambda d:(edit(d),None)[1])
                self.assertEqual(run(p,c,'root-authority-'+role)['integrity'],'REJECT')

    def test_crn_missing_reordered_and_alias_duplicates(self):
        def missing(d): del d['crn_roots']
        def reversed_leg(d): d['crn_roots']['K1'].reverse()
        def alias(d): d['crn_roots']['K1'][0]=d['crn_roots']['K1'][1]+2**32
        def boolean(d): d['roots'][0]=True
        for name,edit in [('missing',missing),('reorder',reversed_leg),('alias',alias),('bool',boolean)]:
            p,c=mutate('factual/A/v0',edit)
            self.assertEqual(run(p,c,'crn-'+name)['integrity'],'REJECT')

    def test_cross_vow_and_cross_panel_roots_never_independent(self):
        for key in ('A/v5','B/v0'):
            p,c=s.good_bundle();source=s.load_json(c,p['evidence']['factual']['A/v0'])
            loc=p['evidence']['factual'][key];target=s.load_json(c,loc)
            target['roots']=source['roots'];target['crn_roots']=source['crn_roots'];s.store_json(c,loc,target)
            sampler=s.load_json(c,'synth://sampler');sampler['manifest'][key]=source['roots']
            for n in (1,2,3):sampler['measurement_orders'][key+f'/K{n}']=source['roots']
            s.store_json(c,'synth://sampler',sampler);s.repin(p,c)
            self.assertIn('root_collision',run(p,c,'cross-stratum-'+key)['reason'])

    def test_missing_native_rows_and_schema_arrays(self):
        p,c=mutate('native_export/A/v0',lambda d:(d['arms']['R'].pop(),None)[1])
        self.assertIn('native_row_completeness',run(p,c,'missing-native-row')['reason'])
        for role in ('model','factual/A/v0','measurement/A/v0/K1','development_manifest','cost'):
            p,c=mutate(role,lambda d:[]);r=run(p,c,'array-schema-'+role)
            self.assertEqual(r['integrity'],'REJECT');self.assertNotIn('AttributeError',r.get('detail',''))

    def test_stage_chronology(self):
        for role,change in [('measurement/A/v0/K1',{'timestamp':0}),('model',{'timestamp':39}),
                            ('factual/A/v0',{'started_at':59}),('development_manifest',{'started_at':19}),
                            ('peer/A/v0',{'timestamp':102})]:
            p,c=mutate(role,lambda d:d.update(change))
            self.assertEqual(run(p,c,'chronology-'+role)['integrity'],'REJECT')

    def test_preflight_state_actions_and_native_transition_links(self):
        def missing(d): del d[0]['state']
        def null_action(d): d[1]['action_A']=None;d[1]['action_B']={'not':'action'}
        def illegal(d): d[1]['action_B']={'command':'choose','arguments':{'index':999}}
        def wrong_transition(d): d[1]['transition_B']['next_state_ref']='invented'
        def no_disagreement(d): d[1]['action_B']=d[1]['action_A']
        for name,edit in [('missing-state',missing),('null-actions',null_action),('illegal-action',illegal),
                          ('transition',wrong_transition),('same-action',no_disagreement)]:
            p,c=mutate('preflight',edit)
            self.assertEqual(run(p,c,'preflight-'+name)['integrity'],'REJECT')

    def test_effective_alias_is_not_an_extra_root(self):
        p,c=mutate('native_export/A/v0',lambda d:d['arms']['R'][0].update(root=d['arms']['R'][0]['root']+2**32))
        r=run(p,c,'single-native-root-alias');self.assertEqual(r['statistical'],'PASS',r.get('reason'))


class ReceiptTests(unittest.TestCase):
    def test_missing_context_and_receipts_fail_closed(self):
        from prospective_admission import evaluate_packet
        p,c=s.good_bundle();self.assertEqual(evaluate_packet(p)['integrity'],'BLOCKED')
        p['mode']='empirical';self.assertEqual(run(p,c,'packet-cannot-select-context')['integrity'],'BLOCKED')
        c.kind='empirical';c.expected_identities['provenance']['environment']='empirical';c.receipts={}
        self.assertEqual(run(p,c,'empirical-missing-authority')['integrity'],'BLOCKED')

    def test_garbage_receipt_bytes_even_when_expected_digest_matches(self):
        p,c=s.good_bundle()
        for role in b.SCOPES:
            c.receipts[role]=b'not-json-not-a-binding'
            c.expected_identities['provenance']['receipt_authorities'][role]['sha256']=b.digest(c.receipts[role])
        self.assertEqual(run(p,c,'garbage-receipts')['integrity'],'REJECT')

    def test_real_shaped_wrong_receipt_fields(self):
        faults=[('independent_review','artifact_head','f'*40),('independent_review','verdict','REQUEST_CHANGES'),
            ('binding','scope','unrelated-task'),('binding','review_sha256','f'*64),('freeze','epoch','OTHER'),
            ('freeze','candidate','OTHER'),('freeze','inputs_sha256','f'*64),('freeze','timestamp',0),
            ('extraction','evidence_sha256','f'*64),('extraction','producer_sha256','f'*64),
            ('extraction','supported_semantics',[]),('guardrails','checks',{}),
            ('independent_review','authority','other-issuer')]
        for role,field,value in faults:
            with self.subTest(role=role,field=field):
                p,c=s.good_bundle();receipt=b.loads(c.receipts[role],role);receipt[field]=value
                c.receipts[role]=b.canonical(receipt)
                c.expected_identities['provenance']['receipt_authorities'][role]['sha256']=b.digest(c.receipts[role])
                self.assertEqual(run(p,c,'receipt-'+role+'-'+field)['integrity'],'REJECT')
        p,c=s.good_bundle();self.assertEqual(run(p,c,'receipts-restored')['statistical'],'PASS')

    def test_synthetic_receipts_cannot_become_empirical_authority(self):
        p,c=s.good_bundle();p['mode']='empirical';c.kind='empirical'
        c.expected_identities['provenance']['environment']='empirical'
        for role in b.SCOPES:
            receipt=b.loads(c.receipts[role],role);receipt['environment']='empirical'
            c.receipts[role]=b.canonical(receipt)
            c.expected_identities['provenance']['receipt_authorities'][role]['sha256']=b.digest(c.receipts[role])
        self.assertIn('synthetic_issuer',run(p,c,'synthetic-issuer-empirical')['reason'])
        with self.assertRaises(ValueError):s.repin(p,c)
