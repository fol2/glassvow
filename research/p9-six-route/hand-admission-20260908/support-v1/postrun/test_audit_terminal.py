"""Delivery audit tests. Synthetic bytes are never native evidence."""
import copy
import json
import lzma
from pathlib import Path
import tempfile
import unittest
from audit_terminal import PASS, FAIL, rendered, sha, terminal_rules, verify_child, activation_channels


class AuditTests(unittest.TestCase):
    def terminal(self, status=FAIL, vow=5):
        return {'status': status, 'last_completed_vow': vow,
                'packages_admitted': 0, 'p9_certified': False}

    def test_v5_negative_stays_negative(self):
        self.assertEqual(terminal_rules(self.terminal(), {5: {'status': FAIL}}, False), 5)

    def test_no_v0_after_negative(self):
        with self.assertRaises(ValueError):
            terminal_rules(self.terminal(), {5: {'status': FAIL}}, True)

    def test_v5_success_alone_not_final_success(self):
        with self.assertRaises(ValueError):
            terminal_rules(self.terminal(PASS), {5: {'status': PASS}}, False)

    def test_v0_negative_stays_negative(self):
        self.assertEqual(terminal_rules(self.terminal(FAIL, 0),
                         {5: {'status': PASS}, 0: {'status': FAIL}}, True), 0)

    def test_both_vows_are_required_for_full_support(self):
        self.assertEqual(terminal_rules(self.terminal(PASS, 0),
                         {5: {'status': PASS}, 0: {'status': PASS}}, True), 0)

    def test_no_package_admission_from_support(self):
        t = self.terminal()
        t['packages_admitted'] = 1
        with self.assertRaises(ValueError):
            terminal_rules(t, {5: {'status': FAIL}}, False)

    def test_inconclusive_is_not_failure(self):
        with self.assertRaises(ValueError):
            terminal_rules(self.terminal('INCONCLUSIVE'), {5: {'status': FAIL}}, False)

    def test_terminal_must_match_actual_stage(self):
        with self.assertRaises(ValueError):
            terminal_rules(self.terminal(PASS, 0),
                           {5: {'status': PASS}, 0: {'status': FAIL}}, True)

    def test_opportunity_is_not_reported_as_positive_health_interaction(self):
        row = {'final_pair': True, 'historical_chain_active': True,
               'consumers': [{'classification': 'SOURCE_REQUIRED_FOR_RECORDED_COMMAND_OPPORTUNITY'}]}
        r = activation_channels([{'policy_index': 7, 'runs': [row]}])
        self.assertEqual(r['opportunity_only_policy_indices'], [7])
        self.assertEqual(r['positive_health_interaction_policy_indices'], [])

    def test_alternative_positive_cannot_be_invented_as_historical_chain(self):
        row = {'final_pair': True, 'historical_chain_active': True,
               'consumers': [{'classification': 'NO_POSITIVE_COMPLETE_HISTORICAL_CHAIN'}]}
        with self.assertRaises(ValueError):
            activation_channels([{'policy_index': 0, 'runs': [row]}])

    def make_child(self, folder):
        cfg = {'id': 'p000-v5-o1-s58080100', 'policy_id': 'a' * 64,
               'policy_index': 0, 'seed0': 58080100, 'runs': 1, 'vow': 5, 'route': 'hand'}
        cell = {k: cfg[k] for k in ('policy_id', 'policy_index', 'vow')}
        cell.update(route_preference='hand', runs=[{'seed': cfg['seed0'], 'result': 'win',
            'historical_chain_active': True, 'positive_high_payoff': True,
            'final_pair': True, 'consumer_reached': True,
            'decision_trace_sha256': 'b' * 64}])
        (folder / 'CONFIG.json').write_bytes(rendered(cfg))
        (folder / 'CELL.json').write_bytes(rendered(cell))
        for name in ('stdout.log', 'stderr.log'):
            (folder / name).write_bytes(b'')
        raw = {}
        for name in ('endpoints.ndjson', 'trace.ndjson'):
            data = b'{"synthetic_test_not_native":true}\n'
            (folder / (name + '.xz')).write_bytes(lzma.compress(data))
            raw[name] = {'bytes': len(data), 'sha256': sha(data)}
        receipt = {'status': 'COMPLETE', 'failure': None, 'config_id': cfg['id'],
                   'returncode': 0, 'raw': raw, 'files':
                   {p.name: {'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
                    for p in folder.iterdir()}}
        (folder / 'EXECUTION.json').write_bytes(rendered(receipt))
        return cfg

    def test_every_compressed_and_expanded_byte_is_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp)
            cfg = self.make_child(f)
            seen = []
            _, r = verify_child(f, cfg, seen)
            self.assertEqual(r['seed'], cfg['seed0'])
            self.assertEqual(len(seen), 6)
            with (f / 'trace.ndjson.xz').open('ab') as stream:
                stream.write(b'x')
            with self.assertRaises(ValueError):
                verify_child(f, cfg, [])

    def test_index_is_bound_to_configuration(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp)
            cfg = self.make_child(f)
            other = dict(cfg, policy_index=1)
            with self.assertRaises(ValueError):
                verify_child(f, other, [])

    def test_expanded_hash_cannot_be_replaced_by_compressed_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp)
            cfg = self.make_child(f)
            receipt = json.loads((f / 'EXECUTION.json').read_bytes())
            receipt['raw']['trace.ndjson']['sha256'] = sha((f / 'trace.ndjson.xz').read_bytes())
            (f / 'EXECUTION.json').write_bytes(rendered(receipt))
            with self.assertRaises(ValueError):
                verify_child(f, cfg, [])

    def test_unfinished_child_not_reused(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp)
            cfg = self.make_child(f)
            receipt = json.loads((f / 'EXECUTION.json').read_bytes())
            receipt['status'] = 'INCONCLUSIVE_CAPTURE'
            (f / 'EXECUTION.json').write_bytes(rendered(receipt))
            with self.assertRaises(ValueError):
                verify_child(f, cfg, [])


if __name__ == '__main__':
    unittest.main()
