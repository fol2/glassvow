"""Bounded .import value/lineage checks, not an importer or Godot interpreter.

Authored values retain their exact lexical spelling, including interior
whitespace. No inferred defaults or post-result normalization is permitted.
Unsupported syntax/options fail closed. Producer qualification is separate;
a final matching document cannot authenticate how a resource was generated.
"""
import hashlib
import json
import re
import dd1_reservations as r

LIMIT = 65536
EXTENSIONS = frozenset(('.png', '.jpg', '.jpeg', '.webp', '.svg', '.ttf', '.otf',
    '.woff', '.woff2', '.wav', '.ogg', '.mp3', '.glb', '.gltf', '.obj', '.fbx', '.csv'))


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def _read_value(first, remaining):
    """Linear, bounded multiline delimiter scan; never evaluates a Variant.

    Godot texture metadata is commonly a multiline dictionary. Interior bytes
    remain significant, including whitespace: this is not default insertion or
    a normalization permission. The whole document already has a 64-KiB cap.
    """
    chunks, stack, quoted, escaped = [], [], False, False
    line = first.strip()
    while True:
        chunks.append(line)
        for ch in line:
            if quoted:
                if escaped:
                    escaped = False
                elif ch == '\\':
                    escaped = True
                elif ch == '"':
                    quoted = False
                elif ord(ch) < 32:
                    raise r.ReservationError('control character in import string')
            elif ch == '"':
                quoted = True
            elif ch in '([{':
                stack.append(ch)
                r.need(len(stack) <= 16, 'import value nesting')
            elif ch in ')]}':
                r.need(stack and stack.pop() == {')': '(', ']': '[', '}': '{'}[ch], 'import value delimiters')
            else:
                r.need(ch not in ';#\x00', 'ambiguous import value/comment')
        r.need(not quoted, 'incomplete import string')
        if not stack:
            value = '\n'.join(chunks).strip()
            r.need(value, 'incomplete import value')
            return value
        try:
            line = next(remaining)
        except StopIteration as exc:
            raise r.ReservationError('incomplete import value') from exc


def tokens(value):
    lines = iter(value.splitlines())
    try:
        result = _read_value(next(lines), lines)
    except StopIteration as exc:
        raise r.ReservationError('incomplete import value') from exc
    r.need(not any(line.strip() for line in lines), 'trailing import value')
    return result


def document(raw):
    r.need(isinstance(raw, bytes) and 0 < len(raw) <= LIMIT and b'\0' not in raw,
           'import document bound')
    text = raw.decode('utf-8')
    rows, section = {}, None
    lines = iter(text.splitlines())
    for line in lines:
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1]
            r.need(section in ('remap', 'deps', 'params') and section not in rows,
                   'duplicate/unknown import section')
            rows[section] = {}
            continue
        r.need(section is not None and '=' in line, 'invalid import assignment')
        key, value = line.split('=', 1); key = key.strip()
        r.need(re.fullmatch(r'[A-Za-z0-9_./-]{1,160}', key) and key not in rows[section],
               'duplicate/invalid import key')
        rows[section][key] = _read_value(value, lines)
    r.need(set(rows) == {'remap', 'deps', 'params'}, 'incomplete import sections')
    return rows


def string(value):
    try:
        result = json.loads(value)
    except (ValueError, TypeError) as exc:
        raise r.ReservationError('literal import string required') from exc
    r.need(isinstance(result, str), 'literal import string required')
    return result


def paths(doc):
    remap, deps = doc['remap'], doc['deps']
    names = [string(v) for k, v in remap.items() if k == 'path' or k.startswith('path.')]
    try:
        targets = json.loads(deps.get('dest_files', 'null'))
    except ValueError as exc:
        raise r.ReservationError('literal generated dependency list required') from exc
    r.need(isinstance(targets, list) and targets and len(targets) <= 128 and
           all(isinstance(x, str) for x in targets) and len(set(targets)) == len(targets),
           'invalid generated dependency list')
    r.need(names and set(names) <= set(targets), 'resource/dependency paths disagree')
    return targets


def validate_seed(slot, source, generated_paths, inert=False):
    from pathlib import PurePosixPath
    from dd1_preparation import path_name
    seed = slot['seed']; name = 'res://' + slot['path']
    keys = {'git_blob', 'sha256', 'asset', 'asset_sha256'}
    r.need(isinstance(seed, dict) and set(seed) == keys and slot['kind'] == 'file' and
           slot['path'].endswith('.import') and set(slot['files']) == {''}, 'seeded sidecar schema')
    raw = source.get(name)
    r.need(isinstance(raw, bytes) and seed['sha256'] == r.digest(raw) and seed['git_blob'] == blob(raw),
           'wrong tracked sidecar seed identity')
    asset = seed['asset']
    r.need(isinstance(asset, str) and asset.startswith('res://') and name == asset + '.import',
           'seed asset path mismatch')
    path_name(asset[6:])
    r.need(PurePosixPath(asset).suffix.lower() in EXTENSIONS or
           (inert and PurePosixPath(asset).suffix == '.bin'), 'not an eligible imported asset')
    r.need(asset in source and seed['asset_sha256'] == r.digest(source[asset]), 'seed asset identity')
    doc = document(raw)
    importer = string(doc['remap'].get('importer', 'null'))
    uid = string(doc['remap'].get('uid', 'null'))
    r.need(importer not in ('', 'keep', 'skip') and (importer != 'dd1_inert' or inert), 'ineligible seed importer')
    r.need(re.fullmatch(r'uid://[a-z0-9]+', uid) is not None and
           bool(string(doc['remap'].get('type', 'null'))), 'seed UID/type')
    r.need(string(doc['deps'].get('source_file', 'null')) == asset, 'sidecar source identity')
    r.need(doc['remap'].get('valid', 'true') == 'true', 'invalid sidecar seed')
    for target in paths(doc):
        r.need(target.startswith('res://.godot/') and target in generated_paths,
               'sidecar dependency outside declared generated inventory')
        path_name(target[6:])
    return doc


def validate_result(slot, source, derived):
    name = 'res://' + slot['path']
    before, after = document(source[name]), document(derived[name])
    r.need(after['remap'].get('valid', 'true') == 'true', 'invalid generated sidecar')
    # No caller-supplied whitelist of changed options. A later supported importer
    # normalization requires a separately source-explained implementation change.
    r.need(before == after, 'sidecar UID/parameter/source/type/options drift')
    targets = paths(after)
    r.need(all(isinstance(derived.get(p), bytes) and derived[p] for p in targets),
           'missing generated resource dependency')
    return {'seed_git_blob': slot['seed']['git_blob'], 'seed_sha256': r.digest(source[name]),
            'generated_sha256': r.digest(derived[name]), 'asset': slot['seed']['asset'],
            'asset_sha256': slot['seed']['asset_sha256'],
            'semantic_sha256': r.digest(r.encode(after)),
            'resources': {p: {'sha256': r.digest(derived[p]), 'bytes': len(derived[p])} for p in targets},
            'normalizations': [], 'claim': 'AUTHORED_VALUES_PRESERVED; producer history separately qualified'}
