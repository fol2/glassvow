"""Assemble existing controller and new observer; never simulate during assembly."""
from pathlib import Path
import hashlib,io,json,lzma,shutil,subprocess,sys,tarfile
R=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main(base,hand,out):
    assert not out.exists()
    subprocess.run([sys.executable,str(base/'research/p9-six-route/source-package-audit-20260908/assemble.py'),str(base),str(out)],check=True)
    manifest=json.loads((R/'CONTROLLER-MANIFEST.json').read_bytes());blob=(R/'retained-controller.tar.xz').read_bytes()
    assert len(blob)==manifest['archive_bytes'] and sha(blob)==manifest['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(blob),mode='r:xz') as tf:
        members=tf.getmembers();assert {m.name for m in members}==set(manifest['files'])
        for m in members:
            assert m.isfile() and Path(m.name).name==m.name
            b=tf.extractfile(m).read();assert sha(b)==manifest['files'][m.name]['sha256']
            (out/m.name).write_bytes(b)
    files={
      'greedy_policy.gd':'v19/fuel/recovery/greedy_policy.gd', 'greedy_stock.gd':'v19/recovery/greedy_stock.gd',
      'additive_policy.gd':'v18/project/greedy_policy.gd','policy_buggy_v9.gd':'v9/project/lab_policy.gd',
      'policy_v8.gd':'v8/project/lab_policy.gd','public_rollout.gd':'v15/public_rollout.gd',
      'causal_probe.gd':'natural-contribution-20260907/causal_probe.gd',
      'diagnostic_rules.gd':'natural-contribution-20260907/diagnostic_rules.gd',
      'health_accounting.gd':'v16/recovery/health_accounting.gd'}
    for name,path in files.items():shutil.copyfile(base/'research/p9-six-route'/path,out/name)
    source=(out/'lab_runner.gd').read_text()
    needle='var g: GlassvowGame=GlassvowGame.new(db,run)'
    assert source.count(needle)==1
    source=source.replace('extends SceneTree\n','extends SceneTree\nconst RecordedGame=preload("res://hand_game.gd")\n',1)
    source=source.replace(needle,'var g: GlassvowGame=RecordedGame.new(db,run) if cfg.get("hand_observer",true) else GlassvowGame.new(db,run)')
    (out/'support_base_runner.gd').write_text(source)
    for name in ('hand_rules.gd',):shutil.copyfile(hand/name,out/name)
    for name in ('support_runner.gd','hand_game.gd'):shutil.copyfile(R/name,out/name)
    shutil.copyfile(base/'tools/check_scripts.sh',out/'tools/check_scripts.sh')
    print('SUPPORT_ASSEMBLED',out)
if __name__=='__main__':main(*map(lambda p:Path(p).resolve(),sys.argv[1:]))
