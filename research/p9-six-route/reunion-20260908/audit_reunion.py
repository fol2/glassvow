"""One-off reconciliation, not a scientific gate or an experiment runner.
Run at repository root. Writes only this reconciliation directory. Never pushes.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess

ROOT = Path('research/p9-six-route')
OUT = ROOT / 'reunion-20260908'
BASE = '0726f9e4eecd84ede09ae587befd1d216c038ab1'
MAIN = '2ed6cdb0302ba3aab5845a18d862841165e8aaf7'
KNOWN = [
 '42ead732e32e8dda5d043927c42fbc50bd75886d',
 '08d50ecd', '1526ab75597e956e2847231cfd0ce74300c4730d',
 '7c3d09fd8fd2fd1bba5081ca15e51e33059c6c0b',
 '8d13baf53f742c75487c7f0f4fcd416fb72158a0',
 'a7791720ec51a01f89ae24e32e6290bf25431bd4',
 'f3e6fe20fc1ff18b25e4c6c100be611f2d5adf06',
 '5991d81f9f32a67d6a66e05a6928d2e1e573e881',
 '46401783b39ada692ce9b990f9deda342b79e7dd',
 'b14d61435dd272f2b24a9f799617e6aad7ce22bc',
 '7b39ebd148bdc7ee23c7e3a4abff4cab79040d71',
 '41e1a1ae532844550c31750700cb8936a035f98f',
 '58e8a73b6679516c6166bb85e16c9446230f9fe5',
 'dada9b6b4a069b6478362e104cb0701ff11aecd1',
 '4777533740c9cb2ebbe98cddb9fa2e230d212e4d',
 '1c29bb1feadd677089e93bc50b434b698a86af88',
 'a5392f0454206f8d1d759c04ef6b72290c7a129e',
 'd364e49d310ebcb354d808ea952fab283c165a53',
 '9be033490c4f4b7ac6ccdcf466571289c2cf31f6',
 'a9bda8e938c011a36e254ca7b8198bdfeed8988d',
 'a0e15b238ea21002d208b63aecebd7f95fc6dc31',
 'f36d1428e595711aa997fd3ff8cea633c4df319a',
 '6c008ad0c5e63da495aa45520bdd08837cbc4cbd',
 '93ddad1b770f57e968d3897cd8d36b5ab15d2a37', BASE]


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(['git', *args], check=check, capture_output=True, timeout=90)


def identity(data: bytes) -> dict:
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'git_blob': hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()}


def safe_path(path: str) -> Path:
    p = PurePosixPath(path)
    if p.is_absolute() or '..' in p.parts or not p.parts:
        raise ValueError('Unsafe archive path')
    if not (path.startswith(str(ROOT)+'/') or path == '.github/workflows/p9-research-runtime-bundle.yml'):
        raise ValueError('Outside owned recovery scope: '+path)
    return Path(*p.parts)


def entries(ref: str, path: str) -> dict[str, str]:
    records = git('ls-tree', '-r', '-z', ref, '--', path).stdout.split(b'\0')
    out = {}
    for record in records:
        if not record:
            continue
        meta, name = record.split(b'\t', 1)
        mode, kind, blob = meta.decode().split()
        if kind != 'blob' or mode not in ('100644', '100755'):
            raise ValueError('Unexpected file type: '+name.decode())
        out[name.decode()] = blob
    return out


def classify_blob(blob: str, current: str | None, historical: set[str]) -> str:
    if blob == current:
        return 'EXACT_CURRENT'
    if blob in historical:
        return 'PRESERVED_IN_REACHABLE_HISTORY'
    return 'PRESERVE_DIVERGENT_BYTES'


def main() -> None:
    OUT.mkdir(exist_ok=True)
    if (OUT/'RESULTS.json').exists():
        raise ValueError('Reunion already recorded; inspect a delta instead of repeating it')
    head = git('rev-parse', 'HEAD').stdout.decode().strip()
    if git('merge-base', '--is-ancestor', BASE, head, check=False).returncode:
        raise ValueError('Checkout does not include the observed frontier')
    current = entries(head, str(ROOT))
    current.update(entries(head, '.github/workflows/p9-research-runtime-bundle.yml'))
    current_receipt = []
    for path, blob in sorted(current.items()):
        data = Path(path).read_bytes()
        actual = identity(data)
        if actual['git_blob'] != blob:
            raise ValueError('Cold checkout byte mismatch: '+path)
        current_receipt.append({'path': path, **actual})
    ancestors = set(git('rev-list', head).stdout.decode().splitlines())
    historical = {line.split(' ', 1)[0] for line in
                  git('rev-list', '--objects', head, '--', str(ROOT),
                      '.github/workflows/p9-research-runtime-bundle.yml').stdout.decode().splitlines()}
    lineage = []
    saved = []
    for supplied in KNOWN:
        resolved = git('rev-parse', '--verify', supplied+'^{commit}', check=False)
        if resolved.returncode and len(supplied) == 40:
            git('fetch', '--no-tags', '--filter=blob:none', '--depth=1', 'origin', supplied, check=False)
            resolved = git('rev-parse', '--verify', supplied+'^{commit}', check=False)
        if resolved.returncode:
            lineage.append({'supplied': supplied, 'status': 'REFERENCE_UNRESOLVED'})
            continue
        sha = resolved.stdout.decode().strip()
        subject = git('show', '-s', '--format=%s', sha).stdout.decode().strip()
        if sha in ancestors:
            lineage.append({'supplied': supplied, 'sha': sha, 'status': 'ANCESTOR', 'subject': subject})
            continue
        parents = git('show', '-s', '--format=%P', sha).stdout.decode().split()
        if not parents:
            git('fetch', '--no-tags', '--filter=blob:none', '--depth=2', 'origin', sha, check=False)
            parents = git('show', '-s', '--format=%P', sha).stdout.decode().split()
        if not parents:
            raise ValueError('Missing divergent parent: '+sha)
        paths = git('diff', '--name-only', '-z', parents[0], sha).stdout.split(b'\0')
        changes = []
        tree = entries(sha, str(ROOT))
        tree.update(entries(sha, '.github/workflows/p9-research-runtime-bundle.yml'))
        for raw_path in paths:
            if not raw_path:
                continue
            path = raw_path.decode()
            safe_path(path)
            blob = tree.get(path)
            if blob is None:
                changes.append({'path': path, 'status': 'HISTORICAL_DELETION_NOT_APPLIED'})
                continue
            verdict = classify_blob(blob, current.get(path), historical)
            row = {'path': path, 'git_blob': blob, 'status': verdict}
            if verdict == 'PRESERVE_DIVERGENT_BYTES':
                data = git('cat-file', 'blob', blob).stdout
                if identity(data)['git_blob'] != blob:
                    raise ValueError('Divergent byte mismatch')
                target = OUT / 'divergent' / sha / safe_path(path)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                row.update({'archived_path': str(target), **identity(data)})
                saved.append(row)
            changes.append(row)
        lineage.append({'supplied': supplied, 'sha': sha, 'status': 'DIVERGENT_CONTENT_RECONCILED',
                        'subject': subject, 'changes': changes})
    state = json.loads((ROOT/'SESSION-STATE.json').read_bytes())
    receipts = []
    def visit(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key in ('receipt', 'readback', 'record', 'exact_closure_scope') and isinstance(child, str):
                    p = ROOT/child
                    if not p.is_file():
                        raise ValueError('Missing active evidence reference: '+str(p))
                    receipts.append({'path': str(p), **identity(p.read_bytes())})
                else:
                    visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
    visit(state)
    production_delta = git('diff', '--name-only', MAIN, head, '--', 'domain', 'content', 'project.godot').stdout.decode().splitlines()
    output = {
        'kind': 'REUNION_LINEAGE_AND_COLD_BYTE_AUDIT_NOT_NEW_RESEARCH',
        'observed_scientific_frontier': BASE, 'verified_checkout': head,
        'scope': 'Known checkpoints in this conversation and mounted recovery inventory; not every unobserved conversation or machine.',
        'known_checkpoint_count': len(KNOWN),
        'ancestor_count': sum(x['status'] == 'ANCESTOR' for x in lineage),
        'unresolved_references': [x['supplied'] for x in lineage if x['status'] == 'REFERENCE_UNRESOLVED'],
        'lineage': lineage, 'divergent_files_preserved': saved,
        'cold_checkout_file_count': len(current_receipt),
        'cold_checkout_manifest': current_receipt,
        'active_evidence_receipts': receipts,
        'product_domain_content_diff_from_main': production_delta,
        'scientific_state_sha256': identity((ROOT/'SESSION-STATE.json').read_bytes())['sha256'],
        'raw_gap_not_repaired': state['original_arms'],
        'packages_admitted': state['packages_admitted'], 'p9_certified': state['p9_certified'],
        'new_native_runs': 0, 'new_independent_samples': 0,
        'scientific_readers_rerun': False,
        'decision': 'Keep newest accumulated scientific state. Archive divergent bytes without applying obsolete handoff/workflow instructions. No destructive rebase or product merge.'}
    data = (json.dumps(output, indent=2)+'\n').encode()
    (OUT/'RESULTS.json').write_bytes(data)
    summary = {k:v for k,v in output.items() if k not in ('cold_checkout_manifest','lineage','active_evidence_receipts')}
    summary['result_identity'] = identity(data)
    (OUT/'SUMMARY.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary, sort_keys=True))

if __name__ == '__main__':
    main()
