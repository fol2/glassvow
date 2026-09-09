"""Falsify unsafe source carry and label-only matching, without native runs."""
import unittest
import identity as m


class IdentityTests(unittest.TestCase):
    def setUp(self):
        self.package = {'p': {'id': 'p', 'aspects': ('ashwarden',),
             'nodes': ('venomStrike', 'toxicMist', 'catalyst'),
             'edges': ({'id': 'venomStrike->catalyst', 'producer': 'venomStrike', 'consumer': 'catalyst'},)}}

    def test_full_frame_identity(self):
        frame = {'combat': {'mode': '100644', 'git_blob': 'a'}, 'reward': {'mode': '100644', 'git_blob': 'b'}}
        self.assertEqual(m.same_frame(frame, dict(frame)), ['combat', 'reward'])

    def test_preview_change_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE_CHANGED'):
            m.same_frame({'combat': 'old'}, {'combat': 'new'})

    def test_reward_change_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE_CHANGED'):
            m.same_frame({'reward': 'old'}, {'reward': 'new'})

    def test_deleted_dependency_rejected(self):
        with self.assertRaisesRegex(ValueError, 'INVENTORY'):
            m.same_frame({'combat': 'a', 'state': 'b'}, {'combat': 'a'})

    def test_added_dependency_rejected(self):
        with self.assertRaisesRegex(ValueError, 'INVENTORY'):
            m.same_frame({'combat': 'a'}, {'combat': 'a', 'state': 'b'})

    def test_mode_change_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE_CHANGED'):
            m.same_frame({'x': ('100644', 'a')}, {'x': ('120000', 'a')})

    def test_empty_frame_rejected(self):
        with self.assertRaisesRegex(ValueError, 'EMPTY'):
            m.same_frame({}, {})

    def test_exact_edge_matches(self):
        _, edge = m.match_edge(self.package, 'p', 'venomStrike', 'catalyst', 'ashwarden')
        self.assertEqual(edge['id'], 'venomStrike->catalyst')

    def test_shared_consumer_is_not_identity(self):
        with self.assertRaisesRegex(ValueError, 'EXACT_REGISTERED'):
            m.match_edge(self.package, 'p', 'toxicMist', 'catalyst', 'ashwarden')

    def test_wrong_aspect_rejected(self):
        with self.assertRaisesRegex(ValueError, 'ASPECT'):
            m.match_edge(self.package, 'p', 'venomStrike', 'catalyst', 'duskblade')

    def test_archived_module_not_executed(self):
        data = b"raise RuntimeError('must not run')\nPACKAGES=({'id':'x','edges':()},)\n"
        self.assertIn('x', m.packages_from_source(data))

    def test_computed_registry_not_executed(self):
        with self.assertRaises(ValueError):
            m.packages_from_source(b"PACKAGES=__import__('os').system('false')\n")

    def test_duplicate_assignment_rejected(self):
        with self.assertRaisesRegex(ValueError, 'REGISTRATION_COUNT'):
            m.packages_from_source(b'PACKAGES=()\nPACKAGES=()\n')

    def test_duplicate_registration_rejected(self):
        with self.assertRaisesRegex(ValueError, 'DUPLICATE_PACKAGE'):
            m.packages_from_source(b"PACKAGES=({'id':'x'},{'id':'x'})\n")

    def test_static_load_must_be_bound(self):
        with self.assertRaisesRegex(ValueError, 'UNBOUND_STATIC_LOAD'):
            m.dependency_screen({'a.gd': b'const X=preload("res://unbound.gd")'}, [])

    def test_bound_static_load_recorded(self):
        r = m.dependency_screen({'a.gd': b'const X=preload("res://b.gd")', 'b.gd': b'pass'}, [])
        self.assertEqual(r, [('a.gd', 'b.gd')])

    def test_excluded_geometry_dependency_rejected(self):
        with self.assertRaisesRegex(ValueError, 'EXCLUDED_CLASS_REFERENCE'):
            m.dependency_screen({'a.gd': b'var x=MapLayoutInput.new()'}, ['MapLayoutInput'])

    def test_dynamic_external_lookup_rejected(self):
        with self.assertRaisesRegex(ValueError, 'DYNAMIC_EXTERNAL_LOOKUP'):
            m.dependency_screen({'a.gd': b'var x=ClassDB.instantiate(name)'}, [])

    def test_manifest_serialisation_stable(self):
        self.assertEqual(m.encode({'b': 2, 'a': 1}), m.encode({'a': 1, 'b': 2}))


if __name__ == '__main__':
    unittest.main()
