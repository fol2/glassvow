"""R3 synthetic event/account reconciliation at the public admission entry."""
import copy
import unittest
import allocation_events as events
import reference_kernel as kernel
import evidence_boundary as b
import synthetic_records as s
from synthetic_controls import run


def transition(identifier, before, after, timestamp):
    return {'kind':'transition','event_id':identifier,'epoch':kernel.EPOCH,
            'from':before,'to':after,'timestamp':timestamp}


def execution(identifier='e1', offset=0):
    return {'kind':'execution','event_id':identifier,'invocation_id':identifier,
            'epoch':kernel.EPOCH,'timestamp':8+offset,'registered_at':5+offset,
            'started_at':6+offset,'finished_at':7+offset,'candidate':s.CANDIDATE,
            'stage':'preflight','count':1,'assignment_id':'assignment-one','result_sha256':'1'*64,
            'cpu':1.0,'elapsed':2.0+offset,'raw':4}


def bundle(log=None):
    p,c=s.good_bundle()
    alloc=p['allocation']
    log=log if log is not None else [execution()]
    alloc['event_log']=[transition('bound',events.INITIAL,'SPEC_BOUND',3),
        transition('preflight','SPEC_BOUND','CANDIDATE_PREFLIGHT',4)]+copy.deepcopy(log)
    receipts={name:b.loads(raw,name) for name,raw in c.receipts.items()}
    folded=events.fold(alloc,c.expected_identities['provenance'],receipts)
    ledger=folded['ledger']
    alloc.update(status=folded['state'],candidate=s.CANDIDATE if folded['attempts'] else None,
        binding_receipt=b.digest(c.receipts['binding']),independent_review=b.digest(c.receipts['independent_review']))
    alloc['candidate_attempts']['used']=folded['attempts']
    if folded['alpha']:
        alloc['alpha']['542'].update(committed=.025,status='COMMITTED')
        alloc['exposure_frame_manifest']=c.expected_identities['provenance']['roles']['sampler_manifest']['sha256']
    for stage in kernel.CAPS:alloc['native_starts'][stage]['used']=ledger.spent[stage]
    alloc['usage']={'cpu_seconds':ledger.cpu,'active_elapsed_seconds':ledger.elapsed,
                    'raw_emitted_bytes_cumulative':ledger.raw}
    sync(p,c)
    return p,c


def sync(p,c):
    s.store_json(c,'synth://allocation',p['allocation']);s.repin(p,c)


class AllocationRecordTests(unittest.TestCase):
    def test_template_remains_unbound_zero_spend(self):
        alloc=s.load_allocation()
        self.assertEqual(alloc['status'],events.INITIAL)
        self.assertEqual(alloc['candidate_attempts']['used'],0)
        self.assertIsNone(alloc['historical_accounts']['spent'])
        self.assertIsNone(alloc['historical_accounts']['remaining'])
        self.assertFalse(alloc['event_log'])

    def test_one_invocation_requires_one_candidate_attempt(self):
        for used in (0,999,True):
            p,c=bundle();p['allocation']['candidate_attempts']['used']=used;sync(p,c)
            self.assertEqual(run(p,c,'attempt-used-'+str(used))['integrity'],'REJECT')
        p,c=bundle();r=run(p,c,'attempt-reconciled')
        self.assertEqual(r['statistical'],'PASS',r.get('reason'))
        self.assertEqual(r['allocation']['candidate_attempts'],1)
        self.assertEqual(r['native_invocations'],0)

    def test_identical_readback_is_idempotent_distinct_retry_is_not(self):
        e=execution();p,c=bundle([e,copy.deepcopy(e)])
        r=run(p,c,'identical-event-readback');self.assertEqual(r['statistical'],'PASS')
        self.assertEqual(r['allocation']['native_starts']['preflight'],1)
        p,c=bundle([e,execution('e2',2)])
        r=run(p,c,'distinct-retry-reconciled');self.assertEqual(r['statistical'],'PASS')
        self.assertEqual(r['allocation']['native_starts']['preflight'],2)
        p['allocation']['native_starts']['preflight']['used']=1;sync(p,c)
        self.assertIn('allocation_native_reconciliation',run(p,c,'distinct-retry-underreported')['reason'])

    def test_conflicting_readback_assignment_and_renamed_execution(self):
        for field,value in [('cpu',2),('result_sha256','2'*64),('invocation_id','e1')]:
            p,c=bundle()
            e=execution('e2',2)
            if field=='cpu':e['event_id']='e1'
            e[field]=value;p['allocation']['event_log'].append(e);sync(p,c)
            self.assertEqual(run(p,c,'event-conflict-'+field)['integrity'],'REJECT')

    def test_event_stage_candidate_caps_clock_and_schema(self):
        faults={'candidate':'second-candidate','stage':'counterfactual','count':-1,'raw':kernel.RAW_CAP+1,
                'cpu':301,'elapsed':kernel.ELAPSED_CAP+1,'started_at':1,'registered_at':8,
                'finished_at':6,'epoch':'OTHER','timestamp':0,'invocation_id':None}
        for field,value in faults.items():
            p,c=bundle();p['allocation']['event_log'][-1][field]=value;sync(p,c)
            self.assertEqual(run(p,c,'event-'+field)['integrity'],'REJECT')

    def test_resource_reports_reconcile_not_merely_under_caps(self):
        for field in ('cpu_seconds','active_elapsed_seconds','raw_emitted_bytes_cumulative'):
            p,c=bundle();p['allocation']['usage'][field]=0;sync(p,c)
            self.assertIn('allocation_usage_reconciliation',run(p,c,'usage-'+field)['reason'])
        p,c=bundle();p['allocation']['status']='APPROVED';sync(p,c)
        self.assertIn('allocation_status_reconciliation',run(p,c,'status-mismatch')['reason'])

    def test_immutable_caps_alpha_history_and_scope(self):
        faults=[lambda d:d['limits'].update(cpu_seconds=10**15),
            lambda d:d['historical_accounts'].update(remaining=100),
            lambda d:d['alpha']['548'].update(spendable=.025),
            lambda d:d['alpha'].update(interval_slots_542=128),
            lambda d:d['alpha'].update(refund_or_transfer_allowed=True),
            lambda d:d['candidate_attempts'].update(maximum=2),
            lambda d:d['alpha']['542'].update(committed=.025),
            lambda d:d.update(binding_receipt='fabricated')]
        for i,edit in enumerate(faults):
            p,c=bundle();edit(p['allocation']);sync(p,c)
            self.assertEqual(run(p,c,'allocation-immutable-'+str(i))['integrity'],'REJECT')

    def test_confirmation_freeze_commits_alpha_no_refund(self):
        log=[execution(),transition('dev','CANDIDATE_PREFLIGHT','DEVELOPMENT',40),
             transition('ref','DEVELOPMENT','REFERENCE_CONFIRMATION',60)]
        p,c=bundle(log);r=run(p,c,'alpha-committed-at-freeze')
        self.assertEqual(r['statistical'],'PASS',r.get('reason'))
        p['allocation']['alpha']['542'].update(committed=0,status='NOT_COMMITTED');sync(p,c)
        self.assertIn('allocation_alpha_reconciliation',run(p,c,'alpha-refund-rejected')['reason'])

    def test_no_status_jump_or_concurrency_above_two(self):
        p,c=bundle();p['allocation']['event_log'].append(transition('jump','CANDIDATE_PREFLIGHT','ROUTE_CONFIRMATION',10));sync(p,c)
        self.assertIn('allocation_transition',run(p,c,'status-jump')['reason'])
        p,c=bundle();p['allocation']['event_log'] += [execution('e2'),execution('e3')];sync(p,c)
        self.assertIn('concurrency_cap',run(p,c,'concurrency-three')['reason'])

    def test_real_file_still_zero_after_all_test_ledgers(self):
        self.assertEqual(s.load_allocation()['native_starts']['preflight']['used'],0)
        self.assertIsNone(s.load_allocation()['binding_receipt'])
