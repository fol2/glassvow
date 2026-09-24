"""Focused bridge falsifiers. Synthetic transport fixtures NEVER confer authority.

Real accepted H and reservation source are used. Transaction tests run harmless
in-process functions at the existing internal inert-test seam, not an OS sandbox
or native positive. Unchanged FIT OS controls retain their recorded provenance.
"""
from copy import deepcopy
from datetime import datetime, timezone, timedelta
import base64
import inspect
import json
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'research/p9-six-route/duskblade-first-proof-20260912'))
import dd1_host_channel as c
import dd1_host_custody as k
import dd1_host_bridge as b
import dd1_reservations as r

RECORDS = []
HEAD = '2fcfbfced835eb4c4e61a19abbb25dcc4c4a6122'


def synthetic_account():
    return dict(schema='DD1-N0-RECOVERY-1-ACCOUNT-1', synthetic=True,
        historical=dict(starts_used=1277, starts_cap=8192, starts_remaining_arithmetic=6915,
            spendable=False, attempt='1/1 consumed', cpu_seconds='UNKNOWN', elapsed_seconds='UNKNOWN', raw_bytes='UNKNOWN'),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139, raw_bytes_cap=r.RAW_CAP,
            executors=1, per_invocation_cpu_seconds=300, first_engine_launch_utc=r.FIRST,
            deadline_utc=r.DEADLINE, events=[]))


def comment_fixture(body='source/inert fixture only'):
    prefix = 'https://api.github.com/repos/fol2/glassvow'
    return dict(id=c.SELECTION, url=prefix+'/issues/comments/'+str(c.SELECTION), issue_url=prefix+'/issues/421',
        user=dict(login='fol2', id=105634418), author_association='OWNER', body=body,
        created_at='2026-09-24T12:00:00Z', updated_at='2026-09-24T12:00:00Z')


class Tests(unittest.TestCase):
    def refused(self, name, fn, reason, error=ValueError):
        with self.assertRaises(error) as caught:
            fn()
        self.assertIn(reason, str(caught.exception))
        RECORDS.append(dict(name=name, result='PASS', reason=str(caught.exception), synthetic=True))

    def test_owner_schema_and_splices(self):
        doc = comment_fixture()
        self.assertEqual(c.owner_comment(doc,c.SELECTION,421),doc['body'])
        RECORDS.append(dict(name='owner-comment-shape', result='PASS', synthetic=True, authenticated=False))
        mutations = {
            'wrong-issuer-name': lambda d:d['user'].update(login='other'),
            'wrong-issuer-id': lambda d:d['user'].update(id=1),
            'wrong-association': lambda d:d.update(author_association='MEMBER'),
            'wrong-repository': lambda d:d.update(issue_url='https://api.github.com/repos/elsewhere/repo/issues/421'),
            'wrong-issue': lambda d:d.update(issue_url=d['issue_url'].replace('421','542')),
            'wrong-comment': lambda d:d.update(id=1),
            'invalid-time': lambda d:d.update(updated_at='not-a-time')}
        for name, change in mutations.items():
            altered=deepcopy(doc);change(altered)
            self.refused(name,lambda d=altered:c.owner_comment(d,c.SELECTION,421),
                'issuer' if 'issuer' in name or 'association' in name else 'timestamp' if 'time' in name else 'scope')
        for name, raw in [('duplicate-json',b'{"a":1,"a":2}'),('nonfinite-json',b'{"a":NaN}')]:
            self.refused(name,lambda raw=raw:c.decode(raw),'duplicate' if 'duplicate' in name else 'nonfinite')

    def test_transport_never_redirects_or_leaks_token(self):
        doc=comment_fixture()
        class Response:
            status=200
            def getheader(self,*_):return 'application/json'
            def read(self,n):return c.canonical(doc)
        class Connection:
            requests=[]
            def __init__(self,host,**kw):
                assert host=='api.github.com' and kw['context'].check_hostname
            def request(self,method,path,headers):
                self.requests.append((method,path,headers.copy()))
            def getresponse(self):return Response()
            def close(self):pass
        with patch.dict(os.environ, {'GH_TOKEN':'SYNTHETIC_TOKEN_NOT_A_CREDENTIAL'}), \
             patch.object(c.http.client,'HTTPSConnection',Connection):
            api=c.GitHubReadOnly(); record=api.comment(c.SELECTION,421)
            self.assertEqual(record.body,doc['body'])
            self.assertNotIn('SYNTHETIC_TOKEN',json.dumps(api.observations))
            self.assertEqual(Connection.requests[-1][0],'GET')
            Response.status=302
            self.refused('redirect-denied',lambda:api.comment(c.SELECTION,421),'status 302')
            api.close();self.assertIsNone(api._token)
        RECORDS.append(dict(name='fixed-TLS-origin-GET-token-redaction', result='PASS', synthetic_transport=True,
                            actual_GitHub_authentication=False))
        self.refused('path-traversal',lambda:c.GitHubReadOnly().file(HEAD,'../secrets'),'unsafe repository')
        self.refused('nonexact-head',lambda:c.commit('main'),'exact commit')

    def test_file_transport_hashes(self):
        raw=b'SYNTHETIC_SOURCE\n'
        doc=dict(type='file',path='test.py',encoding='base64',size=len(raw),sha=c.git_blob(raw),
                 content=base64.b64encode(raw).decode())
        with patch.object(c.GitHubReadOnly,'_get',return_value=(doc,'2026-09-24T12:00:00Z')):
            api=c.GitHubReadOnly();self.assertEqual(api.file(HEAD,'test.py'),raw)
            doc['sha']='0'*40
            self.refused('changed-file-bytes',lambda:api.file(HEAD,'test.py'),'identity mismatch')
        RECORDS.append(dict(name='repository-byte-decode', result='PASS', synthetic_transport=True))

    def test_readonly_custody_and_aliases(self):
        with tempfile.TemporaryDirectory(prefix='dd1-bridge-synthetic-custody-') as name:
            root=Path(name);path=root/k.ACCOUNT_REL;path.parent.mkdir(parents=True)
            raw=c.canonical(synthetic_account());path.write_bytes(raw)
            observed=k.observe(root)
            self.assertEqual(observed['generation'],c.sha(raw));self.assertTrue(observed['synthetic'])
            self.assertEqual(path.read_bytes(),raw);self.assertFalse(Path(str(path)+'.lock').exists())
            self.assertFalse(observed['authoritative'])
            RECORDS.append(dict(name='read-only-synthetic-custody',result='PASS',observation=observed,
                                account_before_hex=raw.hex(),account_after_hex=path.read_bytes().hex()))
            alias=root/'alias';alias.symlink_to(path)
            self.refused('custody-symlink',lambda:k.read_existing(alias),'',error=OSError)
            hard=root/'hard';os.link(path,hard)
            self.refused('custody-hardlink',lambda:k.read_existing(path),'linked')

    def test_custody_conflicts(self):
        host={'fixture':'SYNTHETIC_HOST'};root=Path('/synthetic-only')
        executor=dict(host=host,uid=os.geteuid(),root=str(root))
        obs=dict(account={'sha256':'a'*64,'uid':os.geteuid(),'mode':0o600},generation='a'*64,history_sha256='b'*64,
                 synthetic=False,errors=[],pending=[])
        reg=dict(schema='DD1-HOST-CUSTODY-REGISTRATION-1',repository=c.REPOSITORY,operation=b.OPERATION,
                 status='REGISTERED',scope='ENGINEERING_ONLY',actual_custodian='SYNTHETIC_CUSTODIAN',artifact_head=HEAD,deadline_utc=k.DEADLINE,
                 account_relative_path=k.ACCOUNT_REL,lease_relative_path=k.ACCOUNT_REL+'.lock',
                 executor_identity=executor,live_account_identity=obs['account'],current_generation='a'*64,
                 reservation_history_sha256='b'*64,custody_mode='EXISTING_SAME_EXECUTOR',
                 previous_executor_identity=executor,original_custodian_confirmation=1)
        unit={'account_sha256':'a'*64}
        self.assertEqual(k.reasons(reg,obs,host,root,HEAD,unit),[])
        RECORDS.append(dict(name='custody-structure-only',result='PASS',synthetic_dictionary=True,
                            registered_account=False,native_positive=False))
        for name,key,value,reason in [
            ('custody-other-host','executor_identity',{},'owning executor'),
            ('custody-no-custodian','actual_custodian',None,'custodian identity'),
            ('custody-stale-generation','current_generation','c'*64,'stale ledger'),
            ('custody-history-splice','reservation_history_sha256','c'*64,'history'),
            ('custody-wrong-head','artifact_head','c'*40,'exact head'),
            ('custody-transfer','custody_mode','NEW_EXECUTOR','transfer'),
            ('custody-extend','deadline_utc','2026-09-25T00:00:00Z','extend')]:
            changed=deepcopy(reg);changed[key]=value
            errors=k.reasons(changed,obs,host,root,HEAD,unit)
            self.assertTrue(any(reason in x for x in errors),(name,errors))
            RECORDS.append(dict(name=name,result='PASS',reasons=errors,synthetic_dictionary=True))
        for name,key,value in [('pending-reservation','pending',['interrupted']),('synthetic-not-live','synthetic',True)]:
            changed=deepcopy(obs);changed[key]=value
            errors=k.reasons(reg,changed,host,root,HEAD,unit);self.assertTrue(errors)
            RECORDS.append(dict(name=name,result='PASS',reasons=errors,synthetic_dictionary=True))

    def test_no_fabricated_native_context(self):
        unit=dict(mode='inert_control',wall_seconds=12)
        self.refused('synthetic-native-entry',lambda:b.commission(unit,HEAD),'rejects synthetic')
        with self.assertRaises(TypeError):b.commission(unit,HEAD,trusted_context={'kind':'empirical'})
        with self.assertRaises(TypeError):b.commission(unit,HEAD,authority_check=lambda _:True)
        RECORDS.append(dict(name='no-context-or-callback-API',result='PASS',native_positive=False))
        self.refused('native-in-inert-entry',lambda:b.inert({'mode':'engineering'},account_path='/absent',
            receipt_path='/absent',output='/absent',head=HEAD,repo='/not-used'),'rejects native')
        self.refused('live-path-in-inert-entry',lambda:b.inert({'mode':'inert_control'},account_path=ROOT/'account',
            receipt_path='/absent',output='/absent',head=HEAD,repo=ROOT),'outside repository')
        deadline=c.stamp(k.DEADLINE)
        self.assertIn('original recovery window expired',b.window_reasons(unit,deadline))
        self.assertTrue(b.window_reasons(unit,deadline-timedelta(seconds=3)))
        RECORDS.append(dict(name='deadline-and-cleanup-headroom',result='PASS',synthetic_clock_in_pure_function=True))
        self.assertTrue(b.deployment_reasons({}, {}, {}, {}, unit, {},HEAD))
        self.refused('invented-issuer-compose',lambda:b._compose_verified(
            {name:c.canonical({'authority':'synthetic:fake'}) for name in b.BASE_ROLES},
            {'overlay_head':HEAD,'unit_id':'fake'},None),'undesignated producer')

    def test_useful_path_pricing(self):
        now=c.stamp('2026-09-24T12:00:00Z')
        unit=dict(stage='identity',cpu_seconds=16,raw_bytes=1000000,wall_seconds=12,contained_starts=0)
        def planned(stage,script=None):
            row=dict(unit,stage=stage,contained_starts=2 if stage=='fixture' else 0,input_contract_sha256='a'*64)
            if script:row['script']=script
            return row
        cost=dict(current_unit_sha256=c.sha(c.canonical(unit)),unpriced_terms=[],source_witnesses=['SYNTHETIC_ONLY'],
            prior_unledgered_cpu_ns=1,prior_unledgered_raw_bytes=7,
            remaining_units=[planned('identity'),planned('preparation'),planned('parse','res://tests/a.gd'),planned('fixture')],
            remaining_required_parsers=['res://tests/a.gd'],endpoint='res://tests/test_dd1_source_repair.gd')
        total=b.price_plan(cost,unit,now)
        self.assertEqual(total,dict(starts=6,cpu_ns=64000000001,raw_bytes=4000007,wall_seconds=48))
        RECORDS.append(dict(name='complete-path-pricing',result='PASS',synthetic_arithmetic=True,totals=total))
        for name,change,reason in [
            ('price-unknown',lambda d:d.update(prior_unledgered_raw_bytes=None),'natural'),
            ('price-missing-term',lambda d:d.update(unpriced_terms=['compiler']),'unpriced'),
            ('price-wrong-unit',lambda d:d.update(current_unit_sha256='b'*64),'identity'),
            ('price-unbound-output',lambda d:d['remaining_units'][1].update(input_contract_sha256='z'*64),'input/output'),
            ('price-omitted-parser',lambda d:d.update(remaining_required_parsers=['res://tests/missing.gd']),'parser set'),
            ('price-missing-endpoint',lambda d:d['remaining_units'].pop(),'useful endpoint'),
            ('price-duplicate-preparation',lambda d:d['remaining_units'].insert(2,planned('preparation')),'ordering'),
            ('price-uncontained',lambda d:d['remaining_units'][0].update(contained_starts=1),'contained-start')]:
            altered=deepcopy(cost);change(altered)
            self.refused(name,lambda d=altered:b.price_plan(d,unit,now),reason)
        self.refused('price-whole-deadline',lambda:b.price_plan(cost,unit,c.stamp(k.DEADLINE)-timedelta(seconds=47)),
                     'whole useful path')

    def test_real_H_binding_only(self):
        for name,pin in c.H_PINS.items():
            self.assertEqual(c.git_blob((ROOT/c.H_ROOT/name).read_bytes()),pin)
        import evidence_boundary as h
        self.assertEqual(Path(h.__file__).resolve(),ROOT/c.H_ROOT/'evidence_boundary.py')
        # No empirical context/disposition is made. Real H checks the bridge's
        # actual prospective role names in an explicitly synthetic host context.
        store={role:c.canonical({'schema':'SYNTHETIC_ONLY','role':role}) for role in sorted(b.BASE_ROLES|b.PREP_ROLES)}
        expected,packet=b._binding_shape(store,dict(overlay_head=HEAD,unit_id='BRIDGE-SYNTHETIC'),h,'synthetic')
        roles=expected['roles']
        context=SimpleNamespace(kind='synthetic',expected_identities={'provenance':expected},resolve=store.get,receipts={})
        packet=dict(evidence={role:role for role in roles})
        self.assertEqual(h.verify_bindings(packet,context),expected)
        RECORDS.append(dict(name='real-H-prospective-roles',result='PASS',roles=sorted(roles),H=c.H,
                            H_blobs=c.H_PINS,H_mocked=False,environment='synthetic',native_positive=False))
        for role in roles:
            old=store[role];store[role]=b'changed'
            self.refused('H-changed-'+role,lambda:h.verify_bindings(packet,context),'role_digest:'+role)
            store[role]=old
        packet['evidence'].pop('runtime_fit_thread_bound')
        self.refused('H-missing-thread-bound',lambda:h.verify_bindings(packet,context),'external_role_set')

    def test_inert_wrapper_call_through(self):
        # Only the delegate is spied. This proves NEW argument wiring, not the
        # unchanged Linux backend's behavior. No empirical context is assembled.
        with tempfile.TemporaryDirectory(prefix='dd1-bridge-call-through-') as name:
            root=Path(name);repo=root/'repo';repo.mkdir();ap=root/'synthetic.json'
            before=c.canonical(synthetic_account());ap.write_bytes(before)
            captured={}
            def delegate(command,**kwargs):
                captured.update(command=command,**kwargs)
                return {'marker':'SYNTHETIC_DELEGATE_ONLY'}
            with patch.dict(sys.modules,{'dd1_meter_entry':SimpleNamespace(_run_inert_unit=delegate)}):
                unit={'mode':'inert_control','argv':['/workload','positive']}
                z=b.inert(unit,account_path=ap,receipt_path=root/'receipt',output=root/'out',head=HEAD,repo=repo)
            self.assertEqual(z,{'marker':'SYNTHETIC_DELEGATE_ONLY'})
            self.assertEqual(captured,dict(command=unit['argv'],unit=unit,account_path=ap,
                receipt_path=root/'receipt',output=root/'out',head=HEAD,repo=repo))
            self.assertEqual(ap.read_bytes(),before);self.assertFalse((root/'out').exists())
            RECORDS.append(dict(name='inert-delegate-argument-wiring',result='PASS',delegate_spied=True,
                native_positive=False,OS_execution=False,fields=sorted(captured)))

    def test_deployment_scope_separation(self):
        host={'fixture':'SYNTHETIC_ONLY'};unit={'stage':'identity'}
        base=dict(repository=c.REPOSITORY,operation=b.OPERATION,artifact_head=HEAD)
        reg=dict(actual_custodian='SYNTHETIC_CUSTODIAN',executor_identity=host,current_generation='a'*64,reservation_history_sha256='b'*64)
        d=dict(base,schema='DD1-HOST-BRIDGE-DEPLOYMENT-1',scope='ENGINEERING_ONLY',launch_selected=True,
            selection_comment=c.SELECTION,deadline_utc=k.DEADLINE,stage='identity',host=host,qualification_sha256='c'*64)
        review=dict(base,schema='DD1-HOST-BRIDGE-REVIEW-1',scope='HOST_BRIDGE_AND_QUALIFICATION',verdict='APPROVE',
            author_session='synthetic-author',reviewer_session='synthetic-reviewer',qualification_sha256='c'*64)
        confirm=dict(base,schema='DD1-HOST-CUSTODIAN-CONFIRMATION-1',custodian='SYNTHETIC_CUSTODIAN',executor_identity=host,generation='a'*64,
            reservation_history_sha256='b'*64,same_existing_custodian=True,other_executors_retired=True,unresolved_history=[])
        self.assertEqual(b.deployment_reasons(d,review,confirm,reg,unit,host,HEAD),[])
        RECORDS.append(dict(name='deployment-structure-only',result='PASS',synthetic_dictionary=True,
                            authenticated=False,native_positive=False))
        for name,target,key,value,reason in [
            ('deploy-source-only',0,'scope','SOURCE_INERT_ONLY','native deployment'),
            ('deploy-host',0,'host',{},'stage/host'),
            ('deploy-stage',0,'stage','preparation','stage/host'),
            ('deploy-head',0,'artifact_head','0'*40,'artifact'),
            ('deploy-repo',0,'repository','fol2/other','repository'),
            ('review-self',1,'reviewer_session','synthetic-author','distinct'),
            ('review-qualification',1,'qualification_sha256','d'*64,'qualification'),
            ('custodian-retirement',2,'other_executors_retired',False,'reconciled'),
            ('custodian-history',2,'unresolved_history',['unknown'],'reconciled')]:
            docs=deepcopy([d,review,confirm]);docs[target][key]=value
            errors=b.deployment_reasons(*docs,reg,unit,host,HEAD)
            self.assertTrue(any(reason in x for x in errors),(name,errors))
            RECORDS.append(dict(name=name,result='PASS',reasons=errors,synthetic_dictionary=True))

    def test_qualification_correspondence(self):
        unit=dict(overlay_head=HEAD,unit_id='SYNTHETIC_SHAPE',stage='identity',account_sha256='a'*64,
                  compatibility={'synthetic':True},runtime_fit={'host':{'fixture':True}},
                  execution_modes={},mode_projection={})
        values={name:c.canonical({'scope':'SYNTHETIC_ONLY'}) for name in b.BASE_ROLES}
        values['execution_demand']=c.canonical(unit)
        for name,key in [('compatibility_profile','compatibility'),('runtime_fit_profile','runtime_fit'),
                         ('runtime_fit_modes','execution_modes'),('runtime_fit_projection','mode_projection')]:
            values[name]=c.canonical(unit[key])
        q=dict(schema='DD1-HOST-QUALIFICATION-1',repository=c.REPOSITORY,operation=b.OPERATION,
               artifact_head=HEAD,stage='identity',host=unit['runtime_fit']['host'],account_sha256='a'*64,
               records_ref=HEAD,roles={n:dict(path=n,git_blob=c.git_blob(raw),sha256=c.sha(raw)) for n,raw in values.items()})
        class SyntheticFiles:
            def file(self,ref,path,blob):
                self_test.assertEqual(ref,HEAD)
                raw=values[path];self_test.assertEqual(c.git_blob(raw),blob)
                return raw
        self_test=self;api=SyntheticFiles()
        self.assertEqual(b.read_roles(api,q,unit,HEAD),values)
        RECORDS.append(dict(name='qualification-byte-correspondence',result='PASS',synthetic_transport=True,
                            authenticated=False,native_positive=False))
        for name,change,reason in [
            ('qualification-head',lambda d:d.update(artifact_head='0'*40),'artifact'),
            ('qualification-host',lambda d:d.update(host={}), 'host'),
            ('qualification-ledger',lambda d:d.update(account_sha256='b'*64),'generation'),
            ('qualification-stage',lambda d:d.update(stage='fixture'),'stage'),
            ('qualification-role-omission',lambda d:d['roles'].pop('runtime_fit_thread_bound'),'roles'),
            ('qualification-changed-bytes',lambda d:d['roles']['execution_demand'].update(sha256='b'*64),'changed')]:
            altered=deepcopy(q);change(altered)
            self.refused(name,lambda d=altered:b.read_roles(api,d,unit,HEAD),reason)
        # Invalid credential bytes must fail without printing them or connecting.
        with patch.dict(os.environ,{'GH_TOKEN':'SYNTHETIC\nSECRET'}):
            api=c.GitHubReadOnly()
            self.refused('credential-header-refusal',lambda:api.comment(c.SELECTION,421),'invalid header')
            self.assertNotIn('SECRET',json.dumps(api.observations))

    def test_selection_and_all_record_revalidation(self):
        original = c.LiveRecord(123,421,'SYNTHETIC_ONLY','a'*64,
                                '2026-09-24T12:00:00Z','2026-09-24T13:00:00Z')
        with patch.object(c.GitHubReadOnly,'comment',return_value=original):
            api=c.GitHubReadOnly()
            self.refused('selection-keywords-not-authority',lambda:api.selection(),'scope changed')
            b.recheck_records(api,[original])
        for field,value in [('body_sha256','b'*64),('updated_at','2026-09-24T12:01:00Z')]:
            from dataclasses import replace
            changed=replace(original,**{field:value})
            with patch.object(c.GitHubReadOnly,'comment',return_value=changed):
                self.refused('authority-revalidation-'+field,
                             lambda:b.recheck_records(c.GitHubReadOnly(),[original]),'record changed')
        RECORDS.append(dict(name='all-authority-revalidation-shape',result='PASS',synthetic_transport=True,
                            authenticated=False,native_positive=False))

    def test_existing_inert_transaction_seam(self):
        # This is intentionally NOT evidence of OS confinement or of a newly
        # executed FIT workload. New wrapper call-through proof remains distinct.
        for interrupt in (False,True):
            with tempfile.TemporaryDirectory(prefix='dd1-bridge-synthetic-transaction-') as name:
                root=Path(name);ap=root/'account.json';ap.write_bytes(r.encode(synthetic_account()))
                before=ap.read_bytes();out=root/'out';source=b'INERT_BRIDGE_TRANSACTION\n'
                unit=dict(schema='DD1-COMPLETE-UNIT-DEMAND-2',operation=r.OPERATION,scientific_m=r.M,
                    overlay_head=HEAD,receipt_sha256='r'*64,account_sha256=r.digest(before),unit_id='bridge-transaction',
                    argv=['in-process-inert-only'],mode='inert_control',contained_starts=0,cpu_seconds=11,
                    wall_seconds=10,raw_bytes=2**20,source_files={'res://inert.txt':r.digest(source)})
                def task(grant,dest):
                    live=r.read(ap)['recovery']['unit_reservations_v2'][-1]
                    self.assertEqual(live['state'],'RESERVED')
                    self.assertEqual(live['cpu_ns'],11*10**9)
                    if interrupt:raise KeyboardInterrupt('synthetic interruption before task write')
                    (dest/'harmless.txt').write_bytes(source)
                    return dict(success=True,cleanup_confirmed=True)
                result=r.reserve_and_run(ap,unit,command=unit['argv'],head=HEAD,receipt_sha='r'*64,
                    source_reader=lambda _:source,authority_check=lambda a:self.assertTrue(a['synthetic']),
                    output=out,runner=task,now=c.stamp('2026-09-24T12:00:00Z'))
                self.assertEqual(result['charged']['state'],'INTERRUPTED' if interrupt else 'COMPLETE')
                after=ap.read_bytes()
                self.refused('transaction-replay-'+str(interrupt),lambda:r.reserve_and_run(ap,unit,
                    command=unit['argv'],head=HEAD,receipt_sha='r'*64,source_reader=lambda _:source,
                    authority_check=lambda a:None,output=out,runner=task,now=c.stamp('2026-09-24T12:00:00Z')),'stale receipt/account',r.ReservationError)
                self.assertEqual(after,ap.read_bytes())
                RECORDS.append(dict(name='existing-inert-transaction-'+str(interrupt),result='PASS',
                    route='dd1_reservations.reserve_and_run internal inert-test seam; NOT Linux native entry',
                    account_before_hex=before.hex(),account_after_hex=after.hex(),observation=result,
                    emitted={p.name:p.read_bytes().hex() for p in out.iterdir() if p.is_file()},engine_runs=0,
                    clock_scope='fixed synthetic timestamp at internal transaction seam only'))


if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Tests))
    target=os.environ.get('DD1_BRIDGE_TEST_REPORT')
    if target:Path(target).write_bytes(c.canonical(dict(schema='DD1-HOST-BRIDGE-TESTS-1',passed=result.wasSuccessful(),
        records=RECORDS,H=c.H,H_blobs=c.H_PINS,engine_runs=0,live_account_writes=0,native_positive=False)))
    raise SystemExit(0 if result.wasSuccessful() else 1)
