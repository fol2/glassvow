"""Bounded negative tests for the existing source-only dispatch closure."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('hand_finalize', Path(__file__).with_name('finalize.py'))
F = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(F)


def fixture(folder, changes=None):
    sources = {
        'lab_policy.gd': 'extends "res://rollout_policy.gd"\nfunc terminal(g):\n return Cloner.clone_public(g,0)\n',
        'rollout_policy.gd': 'extends RefCounted\nconst Cloner: GDScript = preload("res://public_rollout.gd")\nfunc rollout(g):\n return Cloner.clone_public(g,1)\n',
        'public_rollout.gd': 'extends RefCounted\nconst Base: GDScript = preload("res://public_rollout_base.gd")\nconst SWITCHES = ["hand_preparation_enabled","hand_surge_enabled","hand_phantom_enabled"]\nstatic func clone_public(g,s):\n var out=Base.clone_public(g,s)\n for prop: Dictionary in g.rules.get_property_list():\n  var key=str(prop.name)\n  if key in SWITCHES:out.rules.set(key,g.rules.get(key))\n return out\n',
        'public_rollout_base.gd': 'extends RefCounted\nstatic func clone_public(g,s):\n return g\n',
    }
    sources.update(changes or {})
    manifest = {}
    with tarfile.open(folder / 'runtime-source.tar.xz', 'w:xz') as archive:
        for name, text in sources.items():
            data = text.encode()
            member = tarfile.TarInfo('qualified/' + name)
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
            manifest[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    (folder / 'SOURCE-MANIFEST.json').write_text(json.dumps({'qualified': manifest}))


class DispatchTests(unittest.TestCase):
    def check_binding(self, changes=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixture(root, changes)
            return F.source_binding(root)

    def test_reads_inherited_policy_not_just_leaf(self):
        result = self.check_binding()
        self.assertEqual(result['inheritance_chain'], ['lab_policy.gd', 'rollout_policy.gd'])
        self.assertEqual(result['clone_call_sites'], 2)

    def test_missing_hand_mask_rejected(self):
        with self.assertRaisesRegex(ValueError, 'MISSING_HAND_FLAG'):
            self.check_binding({'public_rollout.gd': 'const Base = preload("res://public_rollout_base.gd")\n'})

    def test_parent_cloner_bypass_rejected(self):
        bad = 'extends RefCounted\nconst Cloner = preload("res://public_rollout_base.gd")\nfunc rollout(g):\n return Cloner.clone_public(g,0)\n'
        with self.assertRaisesRegex(ValueError, 'ACTUAL_CLONER_BINDING'):
            self.check_binding({'rollout_policy.gd': bad})

    def test_direct_model_allocation_rejected(self):
        bad = 'extends "res://rollout_policy.gd"\nfunc terminal(g):\n return GlassvowGame.new(g.content,g.run)\n'
        with self.assertRaisesRegex(ValueError, 'UNREVIEWED_MODEL_ALLOCATION'):
            self.check_binding({'lab_policy.gd': bad})

    def test_inheritance_cycle_rejected(self):
        with self.assertRaisesRegex(ValueError, 'INHERITANCE_CYCLE_OR_LIMIT'):
            self.check_binding({'rollout_policy.gd': 'extends "res://lab_policy.gd"\n'})

    def test_missing_parent_manifest_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SOURCE_PATH'):
            self.check_binding({'lab_policy.gd': 'extends "res://missing.gd"\n'})

    def test_hash_drift_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixture(root)
            path = root / 'SOURCE-MANIFEST.json'
            manifest = json.loads(path.read_text())
            manifest['qualified']['rollout_policy.gd']['sha256'] = '0' * 64
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'SOURCE_IDENTITY'):
                F.source_binding(root)


if __name__ == '__main__':
    unittest.main()
