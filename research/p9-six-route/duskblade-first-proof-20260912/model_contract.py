"""Frozen feature declarations, finite development selection and model fitting.

Training is reconstructed only from the externally pinned development export.
The extractor/guardrail receipt owns native semantics and information legality.
"""
from __future__ import annotations

import re
import frozen_models as models
import reference_kernel as kernel
from evidence_boundary import BoundaryError, obj, integer, text
from record_io import STRATA, PACKAGES, PAIRS, array
from observation_records import normalize, label

LEAK_TOKENS = ('win', 'seed', 'policy', 'package', 'card', 'arm', 'filename',
               'trace', 'intervention', 'timing', 'future', 'identifier')


def names(values):
    if (not isinstance(values, list) or not 1 <= len(values) <= 32 or
            any(not isinstance(x, str) or not x for x in values) or len(set(values)) != len(values)):
        raise BoundaryError('feature_declaration')
    if any(token in value.lower() for value in values for token in LEAK_TOKENS):
        raise BoundaryError('leaked_features')
    return values


def declaration(features):
    full, peer = names(features.get('full_features')), names(features.get('peer_features'))
    removed = features.get('blind_removed')
    if not isinstance(removed, list) or not removed or not set(removed) < set(full) or len(set(removed)) != len(removed):
        raise BoundaryError('blind_feature_removal')
    blind = [name for name in full if name not in removed]
    semantics = obj(features.get('feature_semantics'), 'feature semantics')
    if set(semantics) != set(full) | set(peer):
        raise BoundaryError('feature_semantics')
    for name, meaning in semantics.items():
        if meaning not in ('public_state', 'public_behaviour', 'mediator', 'consumer_eligibility', 'chain_history'):
            raise BoundaryError('feature_semantics')
        if (meaning in ('mediator', 'consumer_eligibility', 'chain_history')) != (name in removed):
            raise BoundaryError('blind_semantic_removal')
    packages = obj(features.get('packages'), 'package definitions')
    if set(packages) != {'K1', 'K2', 'K3'}:
        raise BoundaryError('package_set')
    for definition in packages.values():
        obj(definition, 'package definition')
        components = definition.get('components')
        if not isinstance(components, list) or not components or any(not isinstance(x, str) or not x for x in components):
            raise BoundaryError('package_components')
        if len(set(components)) != len(components):
            raise BoundaryError('package_components')
        for key, value in obj(definition.get('resources'), 'required resources').items():
            text(key, 'resource'); integer(value, 'resource minimum')
        masks = definition.get('masks')
        if not isinstance(masks, list) or not 2 <= len(masks) <= 8 or any(not isinstance(m, str) for m in masks):
            raise BoundaryError('native_mask_declaration')
        if len(set(masks)) != len(masks) or definition.get('full_mask') not in masks or definition.get('disabled_mask') not in masks:
            raise BoundaryError('native_mask_declaration')
        if definition['full_mask'] == definition['disabled_mask']:
            raise BoundaryError('native_mask_declaration')
        text(definition.get('mec_reference'), 'frozen MEC reference')
    return full, blind, peer


def development_models(records, expected, check_published=True):
    """Return the specified fitted models, never a confirmation-trained fit."""
    feat, dev = records['features'], records['development']
    full_names, blind_names, peer_names = declaration(feat)
    if (dev.get('schema') != 'D547-DEVELOPMENT-2' or
            dev.get('producer_sha256') != expected['roles']['extractor_source']['sha256']):
        raise BoundaryError('development_producer')
    rosters = obj(feat.get('rosters'), 'predeclared rosters')
    evaluations = obj(dev.get('evaluations'), 'development evaluations')
    keys = {f'{p}/v{v}' for p, v in STRATA}
    if set(rosters) != keys or set(evaluations) != keys:
        raise BoundaryError('development_strata')
    fitted = {}
    for panel, vow in STRATA:
        prefix = f'{panel}/v{vow}'
        roster = obj(rosters[prefix], 'role rosters')
        evaluated = obj(evaluations[prefix], 'role evaluations')
        roles = {'R', 'K1', 'K2', 'K3'}
        if set(roster) != roles or set(evaluated) != roles:
            raise BoundaryError('development_roles')
        selected = {}
        for arm in sorted(roles):
            configurations = roster[arm]
            if (not isinstance(configurations, list) or not 1 <= len(configurations) <= 8 or
                    any(not isinstance(x, str) or not re.fullmatch('[0-9a-f]{64}', x) for x in configurations) or
                    len(set(configurations)) != len(configurations)):
                raise BoundaryError('development_roster_size')
            runs = array(evaluated[arm], len(configurations), 'development_roster_coverage')
            candidates, seen = [], set()
            for entry in runs:
                entry = obj(entry, 'configuration evaluation')
                policy = entry.get('policy_sha256')
                if policy not in configurations or policy in seen:
                    raise BoundaryError('development_configuration')
                seen.add(policy)
                rows = array(entry.get('rows'), 64, 'development_size')
                normalized = [normalize(row, kernel.effective_seed(root),
                    {'role': 'development_manifest', 'path': []}, feat['packages'], records['identities']['native_oracle'])
                    for row, root in zip(rows, dev['roots'][prefix])]
                if arm != 'R' and sum(row['routes'][arm]['enact'] for row in normalized) < 16:
                    continue
                candidates.append((sum(row['win'] for row in normalized), policy, normalized))
            if not candidates:
                raise BoundaryError('development_qualification:' + prefix + '/' + arm)
            winner = min(candidates, key=lambda item: (-item[0], item[1]))
            if winner[1] != records['policies'][(panel, arm)]:
                raise BoundaryError('development_selection:' + prefix + '/' + arm)
            selected[arm] = winner[2]
        fitted[prefix] = {}
        for k in PACKAGES:
            arm = f'K{k}'
            definition, cases_full, cases_blind = feat['packages'][arm], [], []
            for row in selected[arm]:
                route = row['routes'][arm]
                if route['first_enact'] is None:
                    continue
                views = route['decisions'][route['first_enact']]['views']
                for mask, target in ((definition['full_mask'], 1), (definition['disabled_mask'], 0)):
                    view = obj(views.get(mask), 'development native view')
                    if label(view['native']) != target:
                        raise BoundaryError('development_manipulation')
                    cases_full.append({'x': models.features(view['public'], full_names), 'label': target})
                    cases_blind.append({'x': models.features(view['public'], blind_names), 'label': target})
            fitted[prefix][arm] = {'full': models.fit(cases_full, full_names, (0, 1)),
                                   'blind': models.fit(cases_blind, blind_names, (0, 1))}
        for k, ell in PAIRS:
            cases = [{'x': models.features(row['fingerprint'], peer_names), 'label': a}
                     for a in (k, ell) for row in selected[f'K{a}']]
            fitted[prefix][f'pair{k}{ell}'] = models.fit(cases, peer_names, (k, ell))
    if check_published:
        model = obj(records['model'], 'frozen model')
        if model.get('fitted_on') != 'development':
            raise BoundaryError('fitted_on_confirmation')
        declared = obj(model.get('strata'), 'frozen model strata')
        if set(declared) != set(fitted):
            raise BoundaryError('model_strata')
        for prefix, estimators in fitted.items():
            supplied = obj(declared[prefix], 'frozen estimators')
            if set(supplied) != set(estimators):
                raise BoundaryError('model_estimator_set')
            for name, wanted in estimators.items():
                variants = ('full', 'blind') if name.startswith('K') else (None,)
                for variant in variants:
                    actual = obj(supplied[name], 'model variant')[variant] if variant else supplied[name]
                    expected_model = wanted[variant] if variant else wanted
                    models.validate(actual, names=expected_model['features'], classes=expected_model['classes'])
                    if actual != expected_model:
                        raise BoundaryError('model_not_frozen_development_fit:' + prefix + '/' + name)
    return fitted


def cost_envelope(records):
    """Reconcile per-arm reports to per-invocation typed source work records."""
    import math
    from record_io import ARMS, crosscheck
    cost, declared_cap, cpu_by_arm = records['cost'], None, {}
    frozen_caps = obj(records['features'].get('policy_cost_caps'), 'frozen policy cost caps')
    if set(frozen_caps) != set(ARMS):
        raise BoundaryError('frozen_cost_arm_set')
    if set(cost) != set(ARMS):
        raise BoundaryError('cost_arm_set')
    for arm in ARMS:
        report = obj(cost[arm], 'cost arm')
        if report.get('hidden_rng') is not False or report.get('privileged') is not False:
            raise BoundaryError('privileged_information')
        cap = integer(report.get('forward_evals_per_decision'), 'available decision cap')
        if cap != integer(frozen_caps[arm], 'frozen available decision cap'):
            raise BoundaryError('cost_envelope_not_frozen')
        if not 1 <= cap <= 128:
            raise BoundaryError('cost_envelope')
        if arm != 'B':
            if declared_cap is not None and cap != declared_cap:
                raise BoundaryError('cost_unmatched')
            declared_cap = cap
        observed = []
        if arm != 'B':
            for panel, vow in STRATA:
                entries = records['development']['evaluations'][f'{panel}/v{vow}'][arm]
                for entry in entries:
                    observed.extend(array(obj(entry, 'cost configuration')['rows'], 64, 'development_size'))
        for panel, vow in STRATA:
            observed.extend(array(records['documents'][f'native_export/{panel}/v{vow}']['arms'][arm], kernel.N, 'native_row_completeness'))
        evaluations, cpus = [], []
        for native in observed:
            work = obj(obj(native, 'cost native row').get('work'), 'native work accounting')
            values = work.get('forward_evaluations')
            if not isinstance(values, list) or not values:
                raise BoundaryError('unknown_cost')
            for value in values:
                if integer(value, 'actual evaluations') > cap:
                    raise BoundaryError('decision_cost_overrun')
            cpu = work.get('cpu_seconds')
            if type(cpu) not in (int, float) or not math.isfinite(cpu) or not 0 <= cpu <= 300:
                raise BoundaryError('native_cpu_cost')
            cpus.append(cpu); evaluations.extend(values)
        crosscheck(report, 'actual_evaluations', evaluations)
        ordered = sorted(evaluations)
        statistics = {'total': sum(evaluations), 'p50': ordered[math.ceil(len(ordered)*.50)-1],
                      'p95': ordered[math.ceil(len(ordered)*.95)-1], 'invocations': len(observed)}
        if obj(report.get('statistics'), 'cost statistics') != statistics:
            raise BoundaryError('cost_statistics')
        cpu_by_arm[arm] = math.fsum(cpus)
        if report.get('cpu_seconds') != cpu_by_arm[arm]:
            raise BoundaryError('cost_cpu_reconciliation')
    return cpu_by_arm
