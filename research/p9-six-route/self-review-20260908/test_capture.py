"""Regressions re-seal the local envelope so checks reach semantic validation."""
import copy
import json
import unittest
import check_capture as checker

class CaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.audit = checker.load()

    def mutated(self, change):
        files = dict(self.files)
        rows = [json.loads(x) for x in files['evidence/native.ndjson'].splitlines()]
        change(rows)
        data = ('\n'.join(json.dumps(r) for r in rows) + '\n').encode()
        files['evidence/native.ndjson'] = data
        receipt = json.loads(files['evidence/receipt.json'])
        receipt['files']['native.ndjson'] = dict(bytes=len(data), sha256=checker.old.sha(data))
        files['evidence/receipt.json'] = json.dumps(receipt).encode()
        return files

    def reject(self, change, old_accepts=False):
        files = self.mutated(change)
        if old_accepts:
            checker.old.analyze(files, self.audit)
        with self.assertRaises((ValueError, AssertionError, KeyError)):
            checker.check(files, self.audit)

    @staticmethod
    def witness(rows, route='cycle'):
        return next(r for r in rows if r['kind'] == 'witness' and r['route'] == route)

    def test_untouched(self):
        result = checker.check(self.files, self.audit)
        self.assertEqual(result['arithmetic_recomputed_arms'], 40)
        self.assertEqual(result['new_independent_samples'], 0)

    def test_nominal_tamper(self):
        self.reject(lambda rows: self.witness(rows)['arms'][3].update(nominal_damage=999), True)

    def test_health_tamper(self):
        self.reject(lambda rows: self.witness(rows)['arms'][3].update(hp_removed=999), True)

    def test_poison_tamper(self):
        self.reject(lambda rows: self.witness(rows, 'smolder')['arms'][3].update(poison_added=999), True)

    def test_zero_mediator(self):
        def change(rows):
            w = self.witness(rows)
            _, cb, _, ix, _ = checker.state(w['before'])
            next(checker.resolve(c, ix) for c in cb['hand'] if checker.resolve(c, ix)['uid'] == w['cmd']['uid'])['bonus'] = 0
        self.reject(change, True)

    def test_consumer_uid(self):
        self.reject(lambda rows: self.witness(rows, 'fervor')['cmd'].update(uid=987654), True)

    def test_turn_context(self):
        self.reject(lambda rows: self.witness(rows).update(turn=999), True)

    def test_future_producer(self):
        self.reject(lambda rows: self.witness(rows)['producer'].update(turn=999), True)

    def test_producer_name(self):
        def change(rows):
            w = self.witness(rows)
            w['producer']['card'] = 'chisel'
            w['commands'][w['producer']['command_index']]['card'] = 'chisel'
        self.reject(change, True)

    def test_final_hp(self):
        def change(rows):
            arm = self.witness(rows)['arms'][3]
            _, _, _, _, enemies = checker.state(arm['after'])
            enemies[0]['hp'] += 1
        self.reject(change, True)

    def test_event_hp(self):
        def change(rows):
            arm = self.witness(rows)['arms'][3]
            next(e for e in arm['events'] if e['t'] == 'hitEnemy')['hpAfter'] += 1
        self.reject(change, True)

    def test_negative_event_damage(self):
        def change(rows):
            arm = self.witness(rows)['arms'][3]
            next(e for e in arm['events'] if e['t'] == 'hitEnemy')['amount'] = -1
        self.reject(change, True)

    def test_projected_return(self):
        self.reject(lambda rows: self.witness(rows)['arms'][3]['after'].__setitem__(2, False), True)

    def test_extra_battle_in_prefix(self):
        self.reject(lambda rows: self.witness(rows)['commands'].append(dict(cmd=dict(t='startCombat'), card='', ret=None)), True)

    def test_missing_receipt_log(self):
        files = dict(self.files)
        receipt = json.loads(files['evidence/receipt.json'])
        receipt['files'].pop('stderr.log')
        files['evidence/receipt.json'] = json.dumps(receipt).encode()
        checker.old.analyze(files, self.audit)
        with self.assertRaises(ValueError):
            checker.check(files, self.audit)

    def test_false_factual_flag(self):
        self.reject(lambda rows: self.witness(rows).update(factual_equal=False))

    def test_duplicate_witness(self):
        self.reject(lambda rows: rows.append(copy.deepcopy(self.witness(rows))))

if __name__ == '__main__':
    unittest.main()
