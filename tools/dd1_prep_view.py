"""DD1-PREP-1 original -> preparation -> sealed-runtime projection.

This module creates no authority. Native use additionally requires H-bound
PREP-1 disposition and closed-producer evidence; synthetic records cannot fill
those roles. Generated sidecars are mutable state, never immutable originals.
"""
import json
from pathlib import Path
import struct
import dd1_reservations as r
import dd1_import_semantics as semantics

SCHEMA = 'DD1-PREPARATION-3'
SELECTION = 5753240365
PROJECT = 'res://project.godot'
PROJECT_BLOB = '319cdc9006d3579ff2abb567830e204a8ff86d9c'
FUNPLAY = b'"res://addons/funplay_mcp/plugin.cfg", '
PLUGIN_LINE = (b'enabled=PackedStringArray(' + FUNPLAY +
    b'"res://addons/glassvow_web_export/plugin.cfg", "res://addons/glassvow_ios_export/plugin.cfg")')
ENGINE_REF = 'ed1daf0bf001b61586d9930840f2f1394092c079'
PLUGIN_TREES = {
    'addons/funplay_mcp': 'e37a0d78a51a17aba550e6469bbf160290eae7b9',
    'addons/glassvow_ios_export': '2073e862ab8ccf45782263c3c5ac5f8dc8f323e6',
    'addons/glassvow_web_export': '3c355e0ae02dda675439bdaebde9a1f58f5f2ec4'}


def require_plugin_inputs(source):
    """Reconstruct frozen Git trees: omitted plugin files do not disappear.

    These fixed plugin trees contain regular non-executable inputs. Unsupported
    file modes cannot match the pinned tree; no caller manifest is trusted.
    """
    import hashlib
    def tree(entries):
        leaves, children = {}, {}
        for name, raw in entries.items():
            first, sep, rest = name.partition('/')
            if sep:
                children.setdefault(first, {})[rest] = raw
            else:
                leaves[first] = semantics.blob(raw)
        r.need(not leaves.keys() & children.keys(), 'plugin file/directory alias')
        rows = [(n, b'100644 ' + n.encode() + b'\0' + bytes.fromhex(h)) for n,h in leaves.items()]
        rows += [(n+'/', b'40000 ' + n.encode() + b'\0' + bytes.fromhex(tree(v))) for n,v in children.items()]
        body = b''.join(b for _,b in sorted(rows))
        return hashlib.sha1(b'tree ' + str(len(body)).encode() + b'\0' + body).hexdigest()
    for prefix, wanted in PLUGIN_TREES.items():
        key = 'res://' + prefix + '/'
        entries = {n[len(key):]: raw for n,raw in source.items() if n.startswith(key)}
        r.need(entries and tree(entries) == wanted, 'missing/altered original plugin inventory:' + prefix)
# Replaced only when the exact harmless producer build changes, never by a unit.
INERT_PRODUCER = 'e50ce1698220a9cd2c2ac27f848b7a2e34fd29a6f683b7cf3432e17e0a749b13'


def selected(recipe):
    return isinstance(recipe, dict) and recipe.get('schema') == SCHEMA


def transform(original):
    r.need(semantics.blob(original) == PROJECT_BLOB and original.count(PLUGIN_LINE) == 1,
           'unexpected/ambiguous original project configuration')
    return original.replace(PLUGIN_LINE, PLUGIN_LINE.replace(FUNPLAY, b'', 1), 1)


def describe(source):
    """Deterministic data, not a launch record or authentication."""
    raw = source[PROJECT]; derived = transform(raw)
    initial = {name: r.digest(b) for name, b in source.items()}
    initial[PROJECT] = r.digest(derived)
    return dict(id='DD1-PREP-1-VIEW-1', owner_selection=SELECTION,
        original_project_git_blob=PROJECT_BLOB, original_project_sha256=r.digest(raw),
        preparation_project_sha256=r.digest(derived), runtime_project_sha256=r.digest(raw),
        delta='REMOVE_ONLY_FUNPLAY_EDITOR_ACTIVATION',
        promotion='RESTORE_ORIGINAL_PROJECT_USE_VALIDATED_SIDECARS', execution_files=initial)


def seeded(recipe):
    return {'res://' + s['path']: s for s in recipe['slots'] if 'seed' in s}


def producer_contract(unit, recipe):
    return dict(id='DD1-PREP-1-PRODUCER-1', engine_source=ENGINE_REF,
        executable_sha256=recipe['engine_sha256'],
        source_manifest_sha256=recipe['source_manifest_sha256'],
        runtime_sha256=r.digest(r.encode(unit['linux']['runtime'])),
        argv_sha256=r.digest(r.encode(unit['argv'])),
        seeds_sha256=r.digest(r.encode({k: v['seed'] for k, v in seeded(recipe).items()})),
        claim='PINNED_READER_BEFORE_FINAL_WRITE; CLOSED_WRITERS_REQUIRED',
        scope='INERT_ONLY' if unit['mode'] == 'inert_control' else 'HOST_QUALIFICATION_REQUIRED')


def validate(unit, source):
    recipe = unit['preparation']
    expected_keys = {'schema', 'source_head', 'source_manifest_sha256', 'engine_sha256', 'slots', 'view', 'producer'}
    r.need(set(recipe) == expected_keys, 'PREP-1 recipe schema')
    r.need(recipe['view'] == describe(source), 'wrong original/derived/runtime view binding')
    r.need(unit.get('execution_files') == recipe['view']['execution_files'], 'wrong bound preparation execution view')
    r.need(recipe['producer'] == producer_contract(unit, recipe), 'wrong producer/recipe binding')
    if unit['mode'] == 'inert_control':
        r.need(recipe['engine_sha256'] == INERT_PRODUCER, 'not the pinned harmless preparation producer')
    else:
        from dd1_compatibility import ENGINE
        r.need(recipe['engine_sha256'] == ENGINE, 'PREP-1 fixed engine identity')
        require_plugin_inputs(source)
    seeds = seeded(recipe)
    r.need(seeds and len(seeds) <= 64, 'bounded explicit seeded sidecars required')
    generated = {'res://' + s['path'] + ('/' + rel if rel else '')
                 for s in recipe['slots'] for rel in s['files']}
    for slot in seeds.values():
        semantics.validate_seed(slot, source, generated, unit['mode'] == 'inert_control')
    return seeds


def execution_files(recipe, source):
    """Immutable execution config + immutable archive, before any release."""
    if not selected(recipe):
        return {}, {}
    raw = source[PROJECT]
    overrides = {PROJECT: transform(raw)}
    originals = {k: source[k] for k in (PROJECT, *seeded(recipe))}
    return overrides, originals


class SealedInputs(dict):
    """Only constructed after receipt, account and exact payload verification.

    This type is an internal transport, not a caller-provided authority token.
    Public native entry always obtains it by load_sealed, never from arguments.
    """
    def __init__(self, values, originals, recipe):
        super().__init__(values)
        self.originals = originals
        self.recipe = recipe
        self.seeded_paths = frozenset(seeded(recipe))


def seed_audit(recipe, path_map, journal):
    """Bounded inotify ordering evidence, not call-origin authentication.

    Combined with code-pinned immutable producer/writer closure. Inotify can
    coalesce identical adjacent events; this is NOT an adversarial general read
    trace and is never used in place of native closed-producer qualification.
    """
    states = {str(i): dict(access_before_write=False, writing=False, closes=0, modified=False)
              for i, slot in enumerate(recipe['slots']) if 'seed' in slot}
    errors = []
    at = 0
    while at < len(journal):
        r.need(at + 16 <= len(journal), 'truncated seed audit')
        wd, mask, cookie, size = struct.unpack_from('iIII', journal, at)
        r.need(at + 16 + size <= len(journal), 'truncated seed audit name')
        name = path_map.get(wd)
        if name in states:
            s = states[name]
            if mask & 1:  # IN_ACCESS
                if not s['modified']:
                    s['access_before_write'] = True
                if s['writing']:
                    errors.append('seed read while rewrite is open:' + name)
            if mask & 2:  # IN_MODIFY
                if not s['access_before_write']:
                    errors.append('seed rewritten without prior observed read:' + name)
                s['writing'] = True; s['modified'] = True
            if mask & 8:  # IN_CLOSE_WRITE
                s['closes'] += 1; s['writing'] = False
    
        at += 16 + size
    for name, s in states.items():
        if not s['access_before_write'] or not s['modified'] or s['writing'] or s['closes'] != 1:
            errors.append('unqualified seed read/rewrite history:' + name)
    return dict(ok=not errors, states=states, errors=errors,
                claim='SUPPORTING_KERNEL_ORDERING; NOT COMPLETE READ/CALL TRACE')


def semantic_results(recipe, source, derived):
    return {name: semantics.validate_result(slot, source, derived)
            for name, slot in seeded(recipe).items()}


def seal_fields(unit, pinned, derived, output):
    recipe = pinned['preparation']; source = pinned['source']
    r.need(pinned['files']['/source/project.godot'][0] == transform(source[PROJECT]),
           'executed preparation configuration drift')
    audit = pinned.get('seed_audit', {})
    r.need(audit.get('ok') is True, 'missing/failed seed-history audit')
    semantics_out = semantic_results(recipe, source, derived)
    originals = {k: source[k] for k in (PROJECT, *seeded(recipe))}
    return dict(recipe=recipe, original_files={k: r.digest(v) for k, v in source.items()},
        original_archive={k: {'sha256': r.digest(v), 'bytes': len(v)} for k, v in originals.items()},
        execution_view=recipe['view'], seeded_semantics=semantics_out,
        seed_history=audit, semantic_scope=recipe['producer']['scope']), originals


def verify_seal(receipt, unit, raw_originals, derived):
    recipe = receipt['recipe']
    if unit['mode'] != 'inert_control':
        require_plugin_inputs(raw_originals)
    r.need(unit.get('execution_files') == {n: x['sha256'] for n,x in receipt['files'].items()},
           'wrong bound sealed execution view')
    r.need(selected(recipe) and receipt['recipe_sha256'] == r.digest(r.encode(recipe)) and
           receipt['original_files'] == unit['source_files'], 'sealed projection/original lineage')
    r.need(receipt['execution_view'] == describe(raw_originals) == recipe['view'], 'sealed configuration projection')
    r.need(receipt['execution_view']['runtime_project_sha256'] == r.digest(raw_originals[PROJECT]),
           'runtime configuration not restored')
    r.need(receipt['seed_history'].get('ok') is True and
           receipt['seeded_semantics'] == semantic_results(recipe, raw_originals, derived),
           'sealed semantic/history splice')
    return SealedInputs(derived, {k: raw_originals[k] for k in (PROJECT, *seeded(recipe))}, recipe)


def native_bindings(unit, expected, context):
    """Use H's existing trusted-host roles. No issuer/context is built here."""
    from dd1_compatibility import bound_role
    recipe = unit.get('preparation')
    if not selected(recipe):
        return
    bound_role(expected, context, 'preparation_projection', r.encode(recipe['view']))
    bound_role(expected, context, 'preparation_producer', r.encode(recipe['producer']))
    role = expected['roles'].get('preparation_disposition', {})
    raw = context.resolve(role.get('locator'))
    r.need(isinstance(raw, bytes) and r.digest(raw) == role.get('sha256'), 'missing PREP-1 disposition')
    d = json.loads(raw)
    authority = expected.get('receipt_authorities', {}).get('preparation_disposition', {})
    issuer = authority.get('authority')
    r.need(isinstance(issuer, str) and issuer and not issuer.startswith('synthetic:') and
           authority.get('sha256') == r.digest(raw) and d.get('authority') == issuer and
           context.receipts.get('preparation_disposition') == raw, 'unauthenticated PREP-1 issuer')
    r.need(d.get('schema') == 'DD1-PREP-1-DISPOSITION-1' and d.get('owner_selection') == SELECTION and
           d.get('operation') == 'DD1-LINUX-ENTRY-1' and d.get('source_head') == unit['overlay_head'] and
           d.get('stage') == 'preparation' and d.get('recipe_sha256') == r.digest(r.encode(recipe)) and
           d.get('independent_review') == 'APPROVE' and d.get('planner_acceptance') == 'ACCEPTED' and
           d.get('launch_admitted') is True, 'unadmitted PREP-1 preparation')
    # This is a *host-authenticated proof input*, not facts asserted by a unit.
    # No default future qualification is generated by source/inert tests.
    proof_role = expected['roles'].get('preparation_writer_closure', {})
    proof_raw = context.resolve(proof_role.get('locator'))
    r.need(isinstance(proof_raw, bytes) and proof_role.get('sha256') == r.digest(proof_raw) and
           d.get('writer_closure_sha256') == r.digest(proof_raw), 'missing bound preparation writer closure')
    proof = json.loads(proof_raw)
    r.need(proof.get('source_manifest_sha256') == recipe['source_manifest_sha256'] and
           proof.get('producer_sha256') == r.digest(r.encode(recipe['producer'])) and
           proof.get('engine_source') == ENGINE_REF and
           proof.get('all_reachable_writers_qualified') is True and
           proof.get('seed_paths') == sorted(seeded(recipe)) and
           isinstance(proof.get('source_witnesses'), list) and proof['source_witnesses'],
           'unqualified preparation writer/seed lineage')
