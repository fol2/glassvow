"""Synthetic tests only: assignment, contrasts, gates, preservation and scope."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import readout as r
import campaign as c


def rows(vow=5, pattern=None):
    result = {w:[] for w in r.WORLDS}
    for first in range(0,128,2):
        for index in (first,first+1):
            for seed in r.config(first,vow)['seeds']:
                bits = pattern if pattern is not None else f'{index%16:04b}'
                for world, bit in zip(r.WORLDS,bits):
                    result[world].append({'index':index,'seed':seed,'vow':vow,
                        'policy':{'id':index},'row':{'outcome':'win' if bit=='1' else 'loss'}})
    return result


def contract():
    return {'assignment':{'policy_root':r.ROOT,'policies':128,'policies_per_cell':2,'seeds_per_cell':4,
        'seed_base':r.SEED_BASE,'seed_vow_stride':1000,'qualification_seed':r.QUALIFICATION_SEED,
        'vows':[5,0],'worlds':list(r.WORLDS)},'candidate_content_sha256':c.CONTENT,
        'primary':{'outcome':'native_win','contrasts':['11-01','11-10','11-10-01+00'],'bootstrap_samples':10000,
        'bootstrap_seed':421,'lower_quantile':.05/6,'upper_quantile':1-.05/6,'positive_lower_bounds_required':3},
        'limits':{'cpu_seconds_per_world_per_vow':3600,'seconds_per_invocation':240,'raw_bytes_per_stream':536870912,'max_workers':4},
        'packages_admitted':0,'p9_certified':False}


class Assignment(unittest.TestCase):
    def test_exact_block_and_policy_coverage(self):
        b,w,p = r.paired(rows(),5)
        self.assertEqual(len(b),256)
        self.assertEqual(w,{x:256 for x in r.WORLDS})
        self.assertEqual(p,{f'{i:04b}':32 for i in range(16)})
        self.assertEqual([sum(x[k] for x in b) for k in range(3)],[0.,0.,0.])
    def test_vow_assignments_are_disjoint_and_not_old_cohort(self):
        a={s for i in range(0,128,2) for s in r.config(i,0)['seeds']}
        b={s for i in range(0,128,2) for s in r.config(i,5)['seeds']}
        self.assertEqual(len(a),256);self.assertEqual(len(b),256)
        self.assertFalse(a&b);self.assertFalse(any(5000<=s<=5199 for s in a|b))
        self.assertFalse(any(73620100<=s<=73625355 for s in a|b))
        self.assertNotIn(r.QUALIFICATION_SEED,a|b)
    def test_duplicate_row(self):
        data=rows();data['11'][-1]=data['11'][0]
        with self.assertRaisesRegex(ValueError,'ASSIGNMENT_OR_DUPLICATE'):r.paired(data,5)
    def test_wrong_seed(self):
        data=rows();data['10'][0]['seed']-=200000
        with self.assertRaisesRegex(ValueError,'ASSIGNMENT_OR_DUPLICATE'):r.paired(data,5)
    def test_missing_row(self):
        data=rows();data['00'].pop()
        with self.assertRaisesRegex(ValueError,'ROW_COUNT'):r.paired(data,5)
    def test_float_and_bool_identity(self):
        for bad in (0.,False):
            data=rows();data['01'][0]['index']=bad
            with self.assertRaisesRegex(ValueError,'ROW_IDENTITY'):r.paired(data,5)
    def test_policy_drift(self):
        data=rows();data['00'][0]['policy']={'id':900}
        with self.assertRaisesRegex(ValueError,'WITHIN_POLICY_DRIFT'):r.paired(data,5)
    def test_cross_world_policy(self):
        data=rows()
        for row in data['10']:row['policy']['offset']=1
        with self.assertRaisesRegex(ValueError,'CROSS_WORLD_POLICY_DRIFT'):r.paired(data,5)
    def test_duplicate_policy_identity(self):
        data=rows()
        for world in data:
            for row in data[world]:row['policy']={'id':0}
        with self.assertRaisesRegex(ValueError,'RECTANGLE'):r.paired(data,5)
    def test_error_is_not_loss(self):
        data=rows();data['11'][0]['row']['error']='turnCeiling'
        with self.assertRaisesRegex(ValueError,'FAULT_NOT_LOSS'):r.paired(data,5)
    def test_unsupported_context(self):
        with self.assertRaisesRegex(ValueError,'ROW_IDENTITY'):r.paired(rows(0),5)
        for first in (-2,1,128,False):
            with self.assertRaisesRegex(ValueError,'CONFIG_INDEX'):r.config(first,5)


class Decisions(unittest.TestCase):
    def test_full_chain_only(self):
        result=r.primary(rows(pattern='0001'),5,lambda b:[[.8,1.]]*3)
        self.assertTrue(result['primary_pass'])
        self.assertTrue(all(x['point']==1. for x in result['contrasts'].values()))
    def test_source_only_is_not_complementarity(self):
        result=r.primary(rows(pattern='0011'),5,lambda b:[[.8,1.],[0.,0.],[0.,0.]])
        self.assertFalse(result['primary_pass'])
        self.assertEqual(result['contrasts']['source_group']['point'],1.)
        self.assertEqual(result['contrasts']['interaction']['point'],0.)
    def test_zero_bound_does_not_pass(self):
        result=r.primary(rows(pattern='0001'),5,lambda b:[[0.,1.]]*3)
        self.assertFalse(result['primary_pass'])
    def test_all_three_bounds_required(self):
        for k in range(3):
            intervals=[[.1,.9] for _ in range(3)];intervals[k]=[-.1,.9]
            self.assertFalse(r.primary(rows(),5,lambda b:intervals)['primary_pass'])
    def test_invalid_interval(self):
        for intervals in ([[0,1]],[[float('nan'),1]]*3,[[1,-1]]*3):
            with self.assertRaisesRegex(ValueError,'INTERVAL'):r.primary(rows(),5,lambda b:intervals)
    def test_same_blocks_sent_to_preserved_bootstrap(self):
        data=rows();expected=r.paired(data,5)[0]
        seen=[]
        def function(b):seen.append(b);return [[-.1,.1]]*3
        r.primary(data,5,function);self.assertEqual(seen,[expected])
    def test_cost_exact_boundary_and_invalid(self):
        costs={w:3600. for w in r.WORLDS};self.assertTrue(r.resource_ok(costs))
        for bad in (3600.000000001,-1.,float('nan'),True):
            trial=costs.copy();trial['11']=bad;self.assertFalse(r.resource_ok(trial))
        self.assertFalse(r.resource_ok({'11':1}))
    def test_conditional_stage_transitions(self):
        positive={'resource_pass':True,'pass_all':True,'primary_pass':True}
        self.assertEqual(r.next_stage(positive,5),'OPEN_FIXED_V0')
        self.assertEqual(r.next_stage(positive,0),'CLOSE_SUPPORTED_NOT_CERTIFICATE')
        negative={'resource_pass':True,'pass_all':False,'primary_pass':False}
        self.assertEqual(r.next_stage(negative,5),'CLOSE_NOT_ESTABLISHED')
        with self.assertRaisesRegex(ValueError,'RESOURCE_INCONCLUSIVE'):
            r.next_stage(dict(positive,resource_pass=False),5)
        with self.assertRaisesRegex(ValueError,'CONJUNCTION'):
            r.next_stage(dict(negative,pass_all=True),5)


class Binding(unittest.TestCase):
    def test_contract(self):c.validate_contract(contract())
    def test_assignment_primary_and_cost_are_not_mutable(self):
        for section,key,bad in [('assignment','policies',64),('assignment','seed_base',123),
             ('primary','positive_lower_bounds_required',1),('primary','lower_quantile',.05),
             ('limits','cpu_seconds_per_world_per_vow',7200)]:
            data=contract();data[section][key]=bad
            with self.assertRaisesRegex(ValueError,'FROZEN_'):c.validate_contract(data)
    def test_no_content_drift_or_certificate(self):
        data=contract();data['candidate_content_sha256']='wrong'
        with self.assertRaisesRegex(ValueError,'CANDIDATE'):c.validate_contract(data)
        data=contract();data['p9_certified']=True
        with self.assertRaisesRegex(ValueError,'NO_ADMISSION'):c.validate_contract(data)
    def test_unsafe_paths(self):
        for value in ('','.', '../raw', '/etc/passwd','x/../y','x\\y','x//y'):
            with self.assertRaisesRegex(ValueError,'PATH'):c.relative(value)
        self.assertEqual(c.relative('v5/00/raw.xz'),Path('v5/00/raw.xz'))
    def test_git_blob_identity(self):
        self.assertEqual(c.blob(b''),'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391')
    def test_manifest_indexes_complete_raw_without_itself(self):
        with tempfile.TemporaryDirectory() as d:
            out=Path(d);(out/'x').mkdir();(out/'x/raw').write_bytes(b'raw')
            c.save(out/'TERMINAL.json',{'status':'INCONCLUSIVE'})
            c.index(out);first=(out/'FILES.json').read_bytes();c.index(out)
            self.assertEqual(first,(out/'FILES.json').read_bytes())
            self.assertEqual({x['path'] for x in c.load(out/'FILES.json')},{'x/raw','TERMINAL.json'})
    def test_current_scope_blocks_product_mutation(self):
        with tempfile.TemporaryDirectory() as d:
            repo=Path(d)
            def fake(repo,*a):
                if a[0]=='rev-parse':return 'head'
                if a[0]=='ls-remote':return 'head\tref'
                if a[0]=='diff':return ''
                return ''
            with patch.object(c,'git',fake):
                with self.assertRaisesRegex(ValueError,'WRITE_SCOPE'):
                    c.publish(repo,'head',[repo/'domain/rules/combat.gd'],'not allowed')
    def test_concurrent_writer_stops_before_staging(self):
        calls=[]
        def fake(repo,*a):
            calls.append(a)
            return 'head' if a[0]=='rev-parse' else 'other\tref'
        with patch.object(c,'git',fake):
            with self.assertRaisesRegex(ValueError,'CONCURRENT_WRITER'):
                c.publish(Path('/test'),'head',[Path('/test')/c.HERE/'file'],'message')
        self.assertFalse(any(x[0]=='add' for x in calls))


if __name__=='__main__':unittest.main()
