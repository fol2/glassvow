"""Restore exact local evidence from retained complete DAG nodes and missing recipes.
No engine invocation. Partial transport is not trusted: all 55 original file
identities, runtime members, raw streams, readout and audit must reproduce.
"""
from __future__ import annotations
import argparse
import base64
import codecs
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import sys
import tempfile

SUBTREE = 'research/p9-six-route/ash-inheritance-20260909/causal-contract-v1'
SUPPLEMENT_SHA256 = 'e2c75beafaee29241c94bdc8a44eadb97c6c377fe69801af5f56f8759f4da70d'
MANIFEST_SHA256 = '79a23738fce726368bd6c3a1aabbd4d378016d6a2a16ef263376cb6494174e8e'
PART_BLOBS = ('be051195e62289252b149e98076725891552b7e3',
              '7d1619834208d68e0712ddddaf8f54f66a530dc0',
              '022b26e31fef7cfa3f980410123a5e489617d023',
              '5171c138eed893983f437aee52ff010a3083055c',
              '1caf2966b7592357f7e2c130d6fc72d3fa50656d',
              '1524817b8cc77359a8252d0f334c47b7624ca821')


def require(value, reason):
    if not value:
        raise ValueError(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def pretty(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def safe_path(name):
    require(isinstance(name, str) and bool(name), 'UNSAFE_PATH')
    path = Path(name)
    require(not path.is_absolute()
            and '..' not in path.parts and str(path) == name, 'UNSAFE_PATH')
    return path


def decode_nodes(nodes):
    require(len(nodes) == 8621, 'COMPLETE_NODE_TABLE')
    values = []
    for node in nodes:
        require(isinstance(node, list) and node, 'NODE_GRAMMAR')
        if node[0] == 'v':
            require(len(node) == 3 and type(node[2]).__name__ == node[1], 'VALUE_TYPE')
            value = node[2]
        else:
            require(len(node) == 2 and node[0] in ('a', 'd'), 'NODE_TAG')
            refs = node[1] if node[0] == 'a' else [i for p in node[1] for i in p]
            require(all(type(i) is int and 0 <= i < len(values) for i in refs), 'FORWARD_REFERENCE')
            if node[0] == 'a':
                value = [values[i] for i in node[1]]
            else:
                keys = [values[k] for k, _ in node[1]]
                require(all(isinstance(k, str) for k in keys) and len(set(keys)) == len(keys), 'DICT_KEYS')
                value = {values[k]: values[i] for k, i in node[1]}
        values.append(value)
    return values


def retained_nodes(folder):
    decoder = lzma.LZMADecompressor()
    chunks = []
    for i, expected in enumerate(PART_BLOBS):
        data = (folder / f'part-{i:03d}.xzpart').read_bytes()
        require(blob(data) == expected, 'PREFIX_BLOB:' + str(i))
        chunks.append(decoder.decompress(base64.b64decode(data.strip(), validate=True)))
    text = codecs.getincrementaldecoder('utf-8')().decode(b''.join(chunks), final=False)
    start = text.index('"nodes":[') + len('"nodes":')
    nodes, end = json.JSONDecoder().raw_decode(text, start)
    require(text[end:end + 9] == ',"files":', 'COMPLETE_ARRAY_BOUNDARY')
    return nodes


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def restore(nodes, supplement_bytes, product, output):
    require(not output.exists(), 'OUTPUT_EXISTS')
    require(sha(supplement_bytes) == SUPPLEMENT_SHA256, 'SUPPLEMENT_IDENTITY')
    p = json.loads(lzma.decompress(supplement_bytes))
    require(p['version'] == 2 and p['subtree'] == SUBTREE and p['packet_manifest_sha256'] == MANIFEST_SHA256, 'PACKET_BINDING')
    values = decode_nodes(nodes)
    specs = {f['path']: f for f in p['files']}
    require(len(specs) == len(p['files']) == 55, 'FILE_COVERAGE')
    for name in specs:
        safe_path(name)
    json_cache = {}
    required_json = {f['sha256'] for f in specs.values() if f['kind'] == 'json'}
    for v in values:
        if isinstance(v, (dict, list)):
            b = pretty(v)
            h = sha(b)
            if h in required_json:
                json_cache[h] = b
    require(set(json_cache) == required_json, 'JSON_NODE_RECOVERY')
    output.mkdir(parents=True)

    def put(name, data):
        f = specs[name]
        require(len(data) == f['bytes'] and sha(data) == f['sha256'], 'ORIGINAL_BYTE_IDENTITY:' + name)
        target = output / safe_path(name)
        require(not target.exists(), 'DUPLICATE_OUTPUT:' + name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    for name, f in specs.items():
        if f['kind'] == 'text':
            put(name, p['texts'][name].encode())
        elif f['kind'] == 'json':
            put(name, json_cache[f['sha256']])
        elif f['kind'] == 'raw':
            source = f['source']
            headers = [v for v in values if isinstance(v, dict) and v.get('kind') == 'header' and v.get('source') == source]
            rows = [v for v in values if isinstance(v, dict) and v.get('kind') == 'sequence' and v.get('source') == source]
            require(len(headers) == 1 and len(rows) == 576, 'RAW_RECORD_COVERAGE:' + source)
            rows = headers + rows + [{'kind': 'terminal', 'rows': 576}]
            raw = b''.join((json.dumps(v, ensure_ascii=False, separators=(',', ':')) + '\n').encode() for v in rows)
            require(sha(raw) == f['raw_sha256'], 'RAW_IDENTITY:' + source)
            put(name, lzma.compress(raw))

    assembler = module('preserved_assembler', output / 'assemble.py')
    segments = []
    require(len(p['tar_gaps']) == len(p['tar_members']) + 1, 'TAR_COVERAGE')
    for i, m in enumerate(p['tar_members']):
        rel = safe_path(m['name'])
        segments.append(base64.b64decode(p['tar_gaps'][i], validate=True))
        if str(rel) in ('causal_probe.gd', 'causal_rules.gd'):
            b = (output / rel).read_bytes()
        elif str(rel) == 'content/full-content.json':
            b = assembler.candidate_content((product / rel).read_bytes())
        elif str(rel) == 'domain/rules/combat.gd':
            b = assembler.candidate_combat((product / rel).read_bytes())
        elif str(rel) == 'project.godot':
            b = b'config_version=5\n[application]\nconfig/name="P9 source utility mediation proof"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        else:
            b = (product / rel).read_bytes()
        require(len(b) == m['bytes'] and sha(b) == m['sha256'], 'ARCHIVED_MEMBER:' + str(rel))
        segments.append(b)
    segments.append(base64.b64decode(p['tar_gaps'][-1], validate=True))
    archive = b''.join(segments)
    require(sha(archive) == p['tar_raw_sha256'], 'TAR_RAW_IDENTITY')
    put('execution-1/runtime-source.tar.xz', lzma.compress(archive))

    sys.path.insert(0, str(output))
    reader = module('read', output / 'read.py')
    sys.modules['read'] = reader
    frozen = json.loads((output / 'FREEZE.json').read_bytes())
    result = reader.read(output / 'execution-1', frozen['source_sha256'])
    put('execution-1/RESULTS.json', pretty(result))
    audit = module('audit_capture', output / 'audit_capture.py')
    sys.modules['audit_capture'] = audit
    with tempfile.TemporaryDirectory(prefix='preserved-audit-') as d:
        target = Path(d) / 'audit'
        audit.audit(output, target)
        for name in ('REVIEW.json', 'CAUSAL-FIELDS.json'):
            put('review-1/' + name, (target / name).read_bytes())
        put('review-1/AUDIT.stdout', (target / 'REVIEW.json').read_bytes())
    found = {str(f.relative_to(output)) for f in output.rglob('*') if f.is_file() and '__pycache__' not in f.parts}
    require(found == set(specs), 'EXACT_RESTORED_FILE_SET')
    require(sha((output / 'PACKET-MANIFEST.json').read_bytes()) == MANIFEST_SHA256, 'ORIGINAL_MANIFEST')
    return {'files': len(specs), 'all_original_bytes_equal': True,
            'raw_records': 1728, 'raw_uncompressed_bytes': 39273762,
            'complete_original_transport_recovered': False,
            'reconstruction': 'Complete retained DAG plus independently hash-bound original text and archive recipes; each original file must match the uploaded checkpoint.',
            'new_native_runs': 0, 'packages_admitted': 0, 'p9_certified': False}


if __name__ == '__main__':
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument('transport', type=Path)
    a.add_argument('product', type=Path)
    a.add_argument('output', type=Path)
    a.add_argument('receipt', type=Path)
    a.add_argument('--nodes-file', type=Path)
    args = a.parse_args()
    nodes = json.loads(args.nodes_file.read_bytes()) if args.nodes_file else retained_nodes(args.transport)
    encoded = b''.join((args.transport / f'supplement-{i:02d}.b64').read_bytes().strip() for i in range(4))
    packed = base64.b64decode(encoded, validate=True)
    report = restore(nodes, packed, args.product, args.output)
    args.receipt.write_bytes(pretty(report))
    print(json.dumps(report, indent=2))
