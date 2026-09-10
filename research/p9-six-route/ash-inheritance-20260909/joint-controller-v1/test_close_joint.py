import copy
import unittest
import tempfile
import json
from pathlib import Path
import close_joint as c


def support(bf, hand, shared):
    return {'bloodfire': {'active': bf, 'inactive': 128-bf, 'reachable': max(bf, 40), 'exclusive': bf-shared},
            'hand': {'active': hand, 'inactive': 128-hand, 'reachable': max(hand, 50), 'exclusive': hand-shared}}


def fixture(vow=5, win_loss=False):
    stage = {'vow': vow, 'stock_support': support(20, 40, 10), 'aware_support': support(40, 40, 20),
             'activation_old': 20, 'activation_new': 40, 'gained_policies': 20, 'lost_policies': 0,
             'stock_outcomes': {'win': 300, 'loss': 212},
             'aware_outcomes': {'win': 299 if win_loss else 310, 'loss': 213 if win_loss else 202},
             'one_sided_exact_sign_p': 1/2**20, 'paired_activation_difference': 20/128,
             'win_difference': (-1 if win_loss else 10)/512,
             'policy_cluster_bootstrap_interval': [-.02, .04],
             'gates': {'paired_activation_gain': True, 'paired_activation_sign_test': True,
                       'win_point_not_worse': not win_loss, 'win_noninferiority_lower_bound': True,
                       'inherited_pair_support': True},
             'costs': {'stock': {'process_cpu_seconds': 2200}, 'aware': {'process_cpu_seconds': 2300}},
             'resource_pass': True, 'pass': not win_loss}
    return stage


def inputs(positive=False):
    t = {'status': c.SUCCESS if positive else c.NEGATIVE, 'stages': {'5': fixture(win_loss=not positive)},
         'packages_admitted': 0, 'p9_certified': False, 'last_vow': 5, 'v0_skipped': True}
    if positive:
        t['stages']['0'] = fixture(0); t['last_vow'] = 0; t['v0_skipped'] = False
    rb = {'kind': 'COMPLETE_JOINT_COMPOSITION_COLD_READBACK', 'all_bytes_equal': True,
          'scientific_status': t['status'], 'reproduced_stages': list(t['stages']), 'files': 100,
          'packages_admitted': 0, 'p9_certified': False}
    p = {'support_bounds': copy.deepcopy(c.BOUNDS), 'containment': {'cpu_seconds_per_method_per_vow': 3600},
         'value_bounds': {'minimum_activation_gain': .05, 'one_sided_alpha_per_vow': .025, 'win_noninferiority_margin': .05}}
    return t, rb, p


class ClosureTests(unittest.TestCase):
    def test_positive_still_not_package(self):
        r = c.summarize(*inputs(True))
        self.assertTrue(r['controller_and_necessary_pair_support_pass'])
        self.assertEqual(r['packages_admitted'], 0)
        self.assertFalse(r['p9_certified'])

    def test_one_lost_win_stays_negative(self):
        r = c.summarize(*inputs())
        self.assertEqual(r['stages']['5']['failed_gates'], ['win_point_not_worse'])
        self.assertFalse(r['v0_opened'])

    def test_green_reader_without_readback_rejected(self):
        t, rb, p = inputs(); rb['all_bytes_equal'] = False
        with self.assertRaisesRegex(ValueError, 'COLD_READBACK'): c.summarize(t, rb, p)

    def test_cost_overrun_not_rounded(self):
        t, rb, p = inputs(); t['stages']['5']['costs']['aware']['process_cpu_seconds'] = 3600.01
        with self.assertRaisesRegex(ValueError, 'RESOURCE_RECONSTRUCTION'): c.summarize(t, rb, p)

    def test_nonfinite_cost_rejected(self):
        t, rb, p = inputs(); t['stages']['5']['costs']['aware']['process_cpu_seconds'] = float('nan')
        with self.assertRaisesRegex(ValueError, 'ACTUAL_COST'): c.summarize(t, rb, p)

    def test_missing_arm_cost_rejected(self):
        t, rb, p = inputs(); del t['stages']['5']['costs']['aware']
        with self.assertRaisesRegex(ValueError, 'COST_METHODS'): c.summarize(t, rb, p)

    def test_unwaived_support(self):
        t, rb, p = inputs(); p['support_bounds']['active'] = 26
        with self.assertRaisesRegex(ValueError, 'SUPPORT_BOUNDS'): c.summarize(t, rb, p)

    def test_false_success_without_v0(self):
        t, rb, p = inputs(True); del t['stages']['0']; rb['reproduced_stages'] = ['5']
        with self.assertRaisesRegex(ValueError, 'FALSE_SUCCESS'): c.summarize(t, rb, p)

    def test_v0_after_negative_rejected(self):
        t, rb, p = inputs(); t['stages']['0'] = fixture(0); rb['reproduced_stages'].append('0')
        with self.assertRaisesRegex(ValueError, 'V0_WITHOUT_V5'): c.summarize(t, rb, p)

    def test_false_support_green_rejected(self):
        t, rb, p = inputs(); t['stages']['5']['aware_support'] = support(40, 31, 20)
        with self.assertRaisesRegex(ValueError, 'GATE_RECONSTRUCTION'): c.summarize(t, rb, p)

    def test_duplicate_policy_partition_rejected(self):
        t, rb, p = inputs(); t['stages']['5']['aware_support']['bloodfire']['inactive'] = 90
        with self.assertRaisesRegex(ValueError, 'POLICY_PARTITION'): c.summarize(t, rb, p)

    def test_shared_active_identity_rejected(self):
        t, rb, p = inputs(); t['stages']['5']['aware_support']['hand']['exclusive'] += 1
        with self.assertRaisesRegex(ValueError, 'COMMON_ACTIVE'): c.summarize(t, rb, p)

    def test_false_effect_count_rejected(self):
        t, rb, p = inputs(); t['stages']['5']['gained_policies'] += 1
        with self.assertRaisesRegex(ValueError, 'PAIRED_ACTIVATION'): c.summarize(t, rb, p)

    def test_incomplete_outcomes_rejected(self):
        t, rb, p = inputs(); t['stages']['5']['aware_outcomes']['loss'] -= 1
        with self.assertRaisesRegex(ValueError, 'COMPLETE_OUTCOMES'): c.summarize(t, rb, p)

    def test_numeric_true_is_not_boolean(self):
        t, rb, p = inputs(); t['stages']['5']['gates']['inherited_pair_support'] = 1
        with self.assertRaisesRegex(ValueError, 'GATE_RECONSTRUCTION'): c.summarize(t, rb, p)

    def test_p9_cannot_be_promoted(self):
        t, rb, p = inputs(True); t['p9_certified'] = True
        with self.assertRaisesRegex(ValueError, 'PREMATURE_PACKAGE'): c.summarize(t, rb, p)


class CapsuleTests(unittest.TestCase):
    def test_historical_dependencies_remain_unchanged(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp); root = repo / c.ROOT
            (root / 'package-disposition-20260908').mkdir(parents=True)
            old = {'product_reference': '2ed6cdb0302ba3aab5845a18d862841165e8aaf7',
                   'original_arms': {'raw_archive_remote_complete': False},
                   'descriptor_sha256': 'frozen', 'validation': {'rerun_or_refit': False},
                   'status': 'OLD_RESOURCE_FAILURE'}
            c.save(root / 'SESSION-STATE.json', old)
            c.sync_capsule(repo, c.summarize(*inputs()), 'Preserve the fixed negative and inspect only the unanswered complete package obligation before another nomination.')
            new = c.load(root / 'SESSION-STATE.json')
            for key in ('original_arms', 'descriptor_sha256', 'validation', 'product_reference'):
                self.assertEqual(new[key], old[key])
            self.assertEqual(new['packages_admitted'], 0)
            self.assertNotIn('OLD_RESOURCE_FAILURE', (root / 'SESSION-HANDOFF.md').read_text())
            self.assertIn(c.NEGATIVE, (root / 'package-disposition-20260908/ROADMAP.md').read_text())

    def test_cannot_sync_a_changed_product(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp); (repo / c.ROOT).mkdir(parents=True)
            c.save(repo / c.ROOT / 'SESSION-STATE.json', {'product_reference': 'changed'})
            with self.assertRaisesRegex(ValueError, 'PRODUCT_REFERENCE'):
                c.sync_capsule(repo, c.summarize(*inputs()), 'Preserve the original evidence and perform only the specifically bound next action.')

    def test_no_unspecified_next_action(self):
        with self.assertRaisesRegex(ValueError, 'SPECIFIC_NEXT_ACTION'):
            c.sync_capsule(Path('.'), c.summarize(*inputs()), '')

    def test_support_true_is_not_an_integer_count(self):
        rows = support(40, 40, 20); rows['bloodfire']['active'] = True
        with self.assertRaisesRegex(ValueError, 'SUPPORT_COUNTS'): c.support_valid(rows)


class DescriptiveTests(unittest.TestCase):
    def reports(self):
        return {m: {'row_results': [{'row_key': f'5:{i}:{seed}', 'index': i, 'seed': seed,
                  'outcome': 'win' if m == 'aware' else 'loss', 'bloodfire': i % 2 == 0, 'hand': i % 3 == 0}
                 for i in range(128) for seed in range(4)]} for m in ('stock', 'aware')}

    def test_all_rows_and_configurations_remain(self):
        result = c.describe_complete_pairs(self.reports())
        self.assertEqual(result['outcome_pairs']['aware_only_win'], 512)
        self.assertEqual(sum(x['configurations'] for x in result['methods']['aware']['policy_membership_groups'].values()), 128)
        self.assertFalse(result['admission_or_new_stage_opened'])

    def test_no_selected_success_subset(self):
        q = self.reports(); q['aware']['row_results'].pop()
        with self.assertRaisesRegex(ValueError, 'RECTANGLE'): c.describe_complete_pairs(q)

    def test_duplicate_cannot_replace_a_seed(self):
        q = self.reports(); q['aware']['row_results'][0] = copy.deepcopy(q['aware']['row_results'][1])
        with self.assertRaisesRegex(ValueError, 'RECTANGLE'): c.describe_complete_pairs(q)

    def test_same_key_cannot_hide_changed_policy(self):
        q = self.reports(); q['aware']['row_results'][0]['index'] = 1
        with self.assertRaisesRegex(ValueError, 'CLUSTERS'): c.describe_complete_pairs(q)


class LedgerTests(unittest.TestCase):
    def row(self, sequence, before, after, card='', events=None, command='playCard'):
        return {'kind': 'command', 'row_key': '5:0:1', 'sequence': sequence,
                'before': {'bloodfire': before, 'hp': 20}, 'after': {'bloodfire': after, 'hp': 17},
                'command': {'t': command}, 'card': card, 'events': events or [], 'ret': True}
    def test_paid_then_consumed_conserves(self):
        rows = [self.row(0, 0, 1, 'bloodRite', [{'t':'status','id':'bloodfire','n':1}]),
                self.row(1, 1, 0, 'leechBlade', [{'t':'status','id':'bloodfire','n':-1}])]
        r = c.trace_ledger(rows)['5:0:1']
        self.assertTrue(r['conserved_without_unobserved_sources'])
        self.assertEqual((r['applied'], r['consumed'], r['unconsumed_decreases']), (1,1,0))
    def test_expiry_is_not_a_consumer(self):
        rows = [self.row(0, 0, 1, 'bloodRite', [{'t':'status','id':'bloodfire','n':1}]),
                self.row(1, 1, 0, command='endTurn')]
        r = c.trace_ledger(rows)['5:0:1']
        self.assertEqual(r['decreases_by_command'], {'endTurn':1})
        self.assertEqual(r['consumed'], 0)
    def test_hidden_increase_cannot_be_called_conservation(self):
        r = c.trace_ledger([self.row(0, 0, 1)])['5:0:1']
        self.assertFalse(r['conserved_without_unobserved_sources'])
    def test_between_command_mutation_is_visible(self):
        r = c.trace_ledger([self.row(0, 0, 0), self.row(1, 1, 1)])['5:0:1']
        self.assertEqual(r['continuity_breaks'], 1)
    def test_unbound_producer_event_rejected(self):
        with self.assertRaisesRegex(ValueError, 'LEDGER_PRODUCER'):
            c.trace_ledger([self.row(0, 0, 1, 'strike', [{'t':'status','id':'bloodfire','n':1}])])


if __name__ == '__main__': unittest.main(verbosity=2)
