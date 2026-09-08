"""Materialise the exact small fixture project from repository bytes; run nothing.

Usage: python assemble.py REPOSITORY FRESH_OUTPUT
Requires standard patch. Native engine stays separately pinned by PROTOCOL.json.
"""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys
R=Path(__file__).resolve().parent

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main(repo,out):
    assert not out.exists(),'Use a fresh directory; never overwrite a frozen study'
    assert sha(repo/'content/full-content.json')=='a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
    out.mkdir(parents=True)
    for name in ('domain','content'):
        shutil.copytree(repo/name,out/name,ignore=shutil.ignore_patterns('__pycache__'))
    (out/'tools').mkdir()
    shutil.copyfile(repo/'tools/vow_incentives.gd',out/'tools/vow_incentives.gd')
    assert sha(out/'tools/vow_incentives.gd')=='f83e9273798c87ed6675c609997e09ffea8a2a0d4f3a4ef2b95a4f8d2864098e'
    for name in ('observer.patch','candidate.patch'):
        subprocess.run(['patch','--batch','--fuzz=0','-p1','-i',str(R/name)],cwd=out,check=True,capture_output=True)
    frozen=json.loads((R/'PROTOCOL.json').read_text())
    assert sha(out/'content/full-content.json')==frozen['content_sha256']
    legacy=repo/'research/p9-six-route/natural-contribution-20260907/diagnostic_rules.gd'
    shutil.copyfile(legacy,out/'diagnostic_legacy.gd')
    for name in ('test_package_nulls.gd','selective_fervor.gd'):shutil.copyfile(R/name,out/name)
    for name,digest in frozen['source_sha256'].items():assert sha(out/name)==digest,name
    (out/'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 finite null audit"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    print('ASSEMBLED_FIXED_SOURCES',out)
if __name__=='__main__':
    assert len(sys.argv)==3,__doc__
    main(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve())
