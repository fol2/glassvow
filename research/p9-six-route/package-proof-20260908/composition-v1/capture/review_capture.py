"""Post-capture binding and reflection review, separate from the frozen reader.

This cannot add or retune native observations. It checks the immutable capture,
its source/header identities and every convenience view against retained state.
"""
from pathlib import Path
import hashlib
import json
import sys


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise ValueError(reason)


def verify_records(records: list[dict], protocol: dict) -> int:
    head = records[0]
    for emitted, source in [('probe_sha256','probe.gd'),('expanded_sha256','expanded_rules.gd')]:
        require(head[emitted] == protocol['source_sha256'][source], 'HEADER_SOURCE:'+source)
    require(head['content_sha256'] == protocol['candidate_sha256'], 'HEADER_CONTENT')
    require(head['engine']['hash'] == 'ed1daf0bf001b61586d9930840f2f1394092c079'
            and head['engine']['string'] == '4.7.2-stable (official)', 'HEADER_ENGINE')
    count = 0
    for row in records[1:-1]:
        for step in row['steps']:
            future = step['after']['future']
            run, cb, ret = future
            # Native reflection preserves object references. Resolve them from
            # the whole snapshot before comparing a convenience view.
            objects = {}
            def index(value):
                if isinstance(value, dict):
                    if 'object' in value:
                        require(value['object'] not in objects, 'DUPLICATE_OBJECT')
                        objects[value['object']] = value
                    for v in value.values(): index(v)
                elif isinstance(value, list):
                    for v in value: index(v)
            index(future)
            def resolve(value):
                return objects[value['ref']] if isinstance(value,dict) and set(value)=={'ref'} else value
            run, cb = resolve(run), resolve(cb)
            e, p = resolve(cb['enemies'][0]), resolve(cb['player'])
            expected = {k:e[k] for k in ['hp','block','chips','facet_max','staggered']}
            expected.update(cracked=e['statuses'].get('vulnerable',0),weak=e['statuses'].get('weak',0),
                            energy=p['energy'],over=cb['over'],hand=[resolve(c)['uid'] for c in cb['hand']],
                            rng=run['rng']['rng_state'])
            require(expected == step['view'], 'VIEW_REFLECTION_MISMATCH')
            require(ret == step['ret'], 'RETURN_REFLECTION_MISMATCH')
            count += 1
    return count


def main(root: Path) -> dict:
    protocol = json.loads((root/'PROTOCOL.json').read_bytes())
    for name, wanted in protocol['source_sha256'].items():
        require(hashlib.sha256((root/name).read_bytes()).hexdigest()==wanted, 'SOURCE:'+name)
    data = (root/'raw.ndjson').read_bytes()
    require(hashlib.sha256(data).hexdigest()=='70176a36ba032b4434bb4baee35e3963112c63d8b42f7aa96b74de1f12a59b09','RAW_IDENTITY')
    records = [json.loads(line) for line in data.splitlines()]
    count = verify_records(records, protocol)
    return {'status':'CAPTURE_BINDINGS_AND_ALL_VIEWS_MATCH','review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
            'review_timing':'Post-capture; frozen reader, probe, protocol and raw unchanged',
            'checked_step_views':count,'new_native_runs':0,'new_independent_samples':0,
            'p9_certified':False,'packages_admitted':0,
            'limit':'This checks retained byte/field consistency, not trusted runtime provenance or population validity.'}

if __name__=='__main__':
    print(json.dumps(main(Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).parent),indent=2))
