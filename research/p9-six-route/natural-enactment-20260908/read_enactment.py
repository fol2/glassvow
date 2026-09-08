"""Read the frozen nine-run enactment replay, not a population/admission test."""
from pathlib import Path
import collections
import hashlib
import io
import tarfile
import json
import sys
R = Path(__file__).resolve().parent
sys.path.insert(0, str(R.parent/'source-package-audit-20260908'))
from read_followup import unpack, sha


def analyze(files, audit):
    p = json.loads(files['source/PROTOCOL.json'])
    cfg = json.loads(files['source/ASSIGNMENT.json'])
    receipt = json.loads(files['evidence/receipt.json'])
    assert receipt['returncode'] == 0 and receipt['error'] is None
    assert 0 <= receipt['elapsed_seconds'] < p['watchdog_seconds']
    assert receipt['post_run_source_equal']
    assert receipt['protocol_sha256'] == sha(files['source/PROTOCOL.json'])
    assert receipt['engine_sha256'] == p['engine_sha256']
    assert sha(files['source/ASSIGNMENT.json']) == p['assignment_sha256']
    assert sha(files['source/SOURCE-MANIFEST.json']) == p['source_manifest_sha256']
    assert sha(files['source/enactment_game.gd']) == p['observer_sha256']
    assert sha(files['source/run_enactment.gd']) == p['runner_sha256']
    for name, entry in receipt['files'].items():
        data = files['evidence/'+name]
        assert len(data) == entry['bytes'] and sha(data) == entry['sha256']
        if name.endswith('.log'):
            assert not any(e in data for e in (b'SCRIPT ERROR', b'Parse Error', b'ERROR:'))
    rows = [json.loads(line) for line in files['evidence/native.ndjson'].splitlines()]
    header = rows[0]
    assert header['kind'] == 'manifest' and header['engine'] == '4.7.2-stable (official)'
    assert header['content_sha256'] == p['content_sha256']
    assert header['config_sha256'] == p['assignment_sha256']
    assert header['observer_sha256'] == p['observer_sha256']
    assert header['runner_sha256'] == p['runner_sha256']
    runs = [r for r in rows if r['kind'] == 'run']
    witnesses = [r for r in rows if r['kind'] == 'witness']
    assert len(rows) == 1+len(runs)+len(witnesses)
    assert len(runs) == p['runs'] == len(cfg['specs']) == 9
    assert [r['spec'] for r in runs] == cfg['specs']
    assert len({r['spec']['row_file'] for r in runs}) == 9
    wanted = {(s['aspect'],s['vow'],s['seed'],route) for s in cfg['specs'] for route in s['routes']}
    assert len(wanted) == p['requested_contexts'] == 12
    ix = {}
    for w in witnesses:
        key = tuple(w[k] for k in ('aspect','vow','seed','route'))
        assert key in wanted and key not in ix; ix[key] = w
        assert w['factual_equal']
        assert [(a['m'],a['c']) for a in w['arms']] == [(0,0),(0,1),(1,0),(1,1)]
        assert all(a['ret'] is True for a in w['arms'])
        # Consumer-off is an exact dormant null on the SAME manipulated state.
        a,b = w['arms'][:2]
        assert a['after'] == b['after'] and a['events'] == b['events']
        producer = w['producer']; entry = w['commands'][producer['command_index']]
        assert entry['cmd'] == producer['cmd'] and entry['card'] == producer['card'] and entry['ret'] is True
        assert w['commands'][0]['cmd']['t'] == 'startCombat'
        assert producer['command_index'] < len(w['commands'])
        if w['route'] == 'cycle':assert producer['uid'] == w['cmd']['uid']
        if w['route'] in ('facet','smolder'):assert producer['cmd']['target'] == w['cmd']['target']
        if w['route'] == 'facet':
            assert any(e['t']=='shatter' and e['idx']==w['cmd']['target'] for e in producer['events'])
        if w['route'] in ('hand','fervor'):
            assert producer['card'] == {'hand':'nightSight','fervor':'empower'}[w['route']]
    summaries = []
    for run in runs:
        s = run['spec']; raw = audit[s['row_file']]
        assert sha(raw) == s['expected_row_sha256']
        assert run['original_row_equal'] and run['row'] == json.loads(raw)
        assert run['row']['outcome'] in ('win','loss') and run['row']['error']==''
        for route in s['routes']:
            key = (s['aspect'],s['vow'],s['seed'],route)
            seen = key in ix
            assert seen == bool(run['sampled'].get(route,False))
            counts = run['counts'][route]
            assert counts['consumer_plays'] >= counts['positive_mediator_plays'] >= counts['producer_linked_positive'] >= 0
            assert seen == (counts['producer_linked_positive'] > 0)
            result = {'aspect':s['aspect'],'vow':int(s['vow']),'seed':int(s['seed']),'route':route,'temporal_witness':seen,'counts':counts}
            if seen:
                w = ix[key]
                for dim in ('hp_removed','nominal_damage','poison_added'):
                    y = [a[dim] for a in w['arms']]
                    result[dim] = {'arms':y,'interaction':y[3]-y[2]-y[1]+y[0]}
                result['factual_equal'] = True
                result['dormant_exact_null'] = True
                result['producer_card'] = w['producer']['card']
                result['battle'] = w['battle']; result['turn'] = w['turn']
            summaries.append(result)
    return {'status':'NINE_PRESERVED_RUN_ENACTMENT_REPLAY_COMPLETE_NOT_P9',
        'protocol_sha256':sha(files['source/PROTOCOL.json']),
        'native_sha256':sha(files['evidence/native.ndjson']),
        'runs_reproduced':9,'requested_contexts':12,'temporal_witnesses':len(witnesses),
        'factual_matches':len(witnesses),'counterfactual_actions':4*len(witnesses),
        'dormant_exact_null_pairs':len(witnesses),'new_independent_samples':0,
        'contexts':summaries,'limits':p['limits'] + [
        'Absence in a selected witness is not population impossibility or evidence that a competent route policy cannot enact it.',
        'Nominal damage can increase without extra health removed; poison is a separate deferred quantity.',
        'The historical 518348-byte raw archive is not claimed wholly remotely preserved.']}


def read(root=R):
    files, _ = unpack(root, 'RAW-MANIFEST.json', 'raw.parts')
    folder = root.parent/'source-package-audit-20260908'
    manifest = json.loads((folder/'ACQUISITION-WITNESSES.json').read_bytes())
    archive = b''.join((folder/'acquisition.parts'/p['file']).read_bytes() for p in manifest['parts'])
    assert len(archive) == manifest['archive_bytes'] and sha(archive) == manifest['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:xz') as tf:
        assert all(m.isfile() for m in tf.getmembers())
        audit = {m.name:tf.extractfile(m).read() for m in tf.getmembers()}
    assert sha(audit['INDEX.json']) == manifest['index_sha256']
    result = analyze(files, audit)
    return result


if __name__ == '__main__':
    result = read(); data = json.dumps(result, indent=2)+'\n'; path = R/'RESULTS.json'
    if path.exists():assert path.read_text()==data, 'Existing publication differs'
    else:path.write_text(data)
    print(result['status'], result['runs_reproduced'], result['temporal_witnesses'])
