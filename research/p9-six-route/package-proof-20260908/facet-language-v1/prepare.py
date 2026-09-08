"""Assemble one source-bound fixture-search project; do not simulate."""
import hashlib, importlib.util, json, shutil, sys
from pathlib import Path

def sha(b): return hashlib.sha256(b).hexdigest()
def prepare(repo: Path, out: Path, study: Path):
    if out.exists(): raise ValueError('FRESH_PROJECT_REQUIRED')
    audit = repo/'research/p9-six-route/source-package-audit-20260908'
    spec = importlib.util.spec_from_file_location('audit_assembly',audit/'assemble.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    module.main(repo,out)
    for name in ('causal_probe.gd','diagnostic_rules.gd'):
        shutil.copyfile(repo/'research/p9-six-route/natural-contribution-20260907'/name,out/name)
    shutil.copyfile(repo/'research/p9-six-route/v16/recovery/health_accounting.gd',out/'health_accounting.gd')
    shutil.copyfile(study/'search.gd',out/'facet_language.gd')
    expected=json.loads((study/'SOURCE-MANIFEST.json').read_text())
    actual={str(p.relative_to(out)):sha(p.read_bytes()) for p in out.rglob('*') if p.is_file() and '.godot' not in p.parts and p.suffix!='.uid'}
    if actual!=expected: raise ValueError('PROJECT_IDENTITY:'+str(set(actual.items()) ^ set(expected.items())))
    return actual
if __name__=='__main__':
    prepare(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve(),Path(__file__).resolve().parent)
