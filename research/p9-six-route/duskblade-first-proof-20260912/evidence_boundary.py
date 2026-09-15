"""External role bindings and authenticated-receipt content checks for D547-PC1.

The runner supplies expected SHA256s and authenticated issuer identities out of
band. This does NOT authenticate GitHub, signatures, or arbitrary JSON itself.
In particular a locator or a receipt in the submitted store is not an authority.
Synthetic issuers are usable only in a runner-created synthetic context.
"""
from __future__ import annotations

import hashlib
import json
import re

import reference_kernel as kernel

SEMANTICS = ["normal-terminal-win-v1", "mec-acquire-complete-chain-v1",
             "first-preconsumer-immediate-eligibility-payoff-v1",
             "public-feature-extraction-v1", "legal-public-policy-action-v1"]
SCOPES = {"independent_review": ("547-adapter", "APPROVE"),
          "binding": ("547-contract", "BOUND"),
          "freeze": ("542-candidate", "FROZEN"),
          "extraction": ("542-extraction", "VERIFIED"),
          "guardrails": ("542-invariants", "VERIFIED")}
GUARDS = ["mec-source-closure", "legal-profile-provenance", "signed-control",
          "policy-information-cost", "unchanged-invariants"]
INPUT_GROUPS = {"product", "content", "native_oracle", "profile_0", "profile_5",
                "signed_B", "policies", "preflight", "preflight_trace", "development_manifest",
                "sampler_manifest", "freeze", "exposure_manifest", "features",
                "model", "extractor_source"}


class BoundaryError(ValueError):
    pass


class MissingAuthority(BoundaryError):
    pass


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def obj(value, name):
    if not isinstance(value, dict):
        raise BoundaryError("schema:" + name)
    return value


def integer(value, name):
    if type(value) is not int or value < 0:
        raise BoundaryError("schema:" + name)
    return value


def text(value, name):
    if not isinstance(value, str) or not value:
        raise BoundaryError("schema:" + name)
    return value


def loads(raw, name):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise BoundaryError("duplicate JSON key:" + name)
            result[key] = value
        return result
    def constant(value):
        raise BoundaryError("nonfinite JSON:" + name)
    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_constant=constant)
    except (UnicodeError, json.JSONDecodeError, TypeError) as exc:
        raise BoundaryError("malformed JSON:" + name) from exc


def flatten(value, prefix=""):
    obj(value, "evidence map")
    out = {}
    for key, item in value.items():
        text(key, "role")
        role = prefix + key
        if isinstance(item, dict):
            nested = flatten(item, role + "/")
            if set(nested) & set(out):
                raise BoundaryError("ambiguous role map")
            out.update(nested)
        else:
            if role in out:
                raise BoundaryError("ambiguous role map")
            out[role] = text(item, "locator")
    return out


def manifest_digests(roles):
    complete = {r: b["sha256"] for r, b in roles.items()}
    inputs = {r: d for r, d in complete.items() if r.split("/")[0] in INPUT_GROUPS}
    return digest(canonical(inputs)), digest(canonical(complete))


def verify_bindings(packet, context):
    expected = context.expected_identities.get("provenance")
    if not isinstance(expected, dict):
        raise MissingAuthority("missing_external_manifest")
    if expected.get("environment") != context.kind:
        raise BoundaryError("manifest_environment")
    if expected.get("epoch") != kernel.EPOCH:
        raise BoundaryError("manifest_epoch")
    if not re.fullmatch(r"[0-9a-f]{40}", text(expected.get("artifact_head"), "artifact head")):
        raise BoundaryError("artifact_head")
    text(expected.get("candidate"), "candidate")
    roles = obj(expected.get("roles"), "external roles")
    submitted = flatten(packet.get("evidence"))
    if set(submitted) != set(roles):
        raise BoundaryError("external_role_set")
    for role, locator in submitted.items():
        binding = obj(roles[role], "role binding")
        if binding.get("locator") != locator:
            raise BoundaryError("role_locator:" + role)
        raw = context.resolve(locator)
        if raw is None:
            raise BoundaryError("missing_source_raw:" + role)
        if digest(raw) != binding.get("sha256"):
            raise BoundaryError("role_digest:" + role)
    inputs, evidence = manifest_digests(roles)
    if expected.get("inputs_sha256") != inputs or expected.get("evidence_sha256") != evidence:
        raise BoundaryError("external_manifest_digest")
    return expected


def receipts(context, expected):
    """Inspect content *after* comparison with runner-authenticated identities.

    Review and binding scope the artifact. Freeze scopes pre-output inputs.
    Extraction and guardrails scope the later complete evidence manifest, thus
    avoiding the impossible requirement to freeze future outcome bytes.
    """
    authorities = obj(expected.get("receipt_authorities", {}), "receipt authorities")
    if any(role not in context.receipts or role not in authorities for role in SCOPES):
        raise MissingAuthority("missing_binding_freeze_review_extraction_guardrails")
    result = {}
    for role, (scope, verdict) in SCOPES.items():
        raw = context.receipts[role]
        pinned = obj(authorities[role], "receipt authority")
        if not isinstance(raw, bytes) or digest(raw) != pinned.get("sha256"):
            raise BoundaryError("receipt_digest:" + role)
        record = obj(loads(raw, role), "receipt:" + role)
        matches = {"schema": "D547-RECEIPT-1", "environment": context.kind,
                   "epoch": kernel.EPOCH, "artifact_head": expected["artifact_head"],
                   "scope": scope, "verdict": verdict,
                   "authority": text(pinned.get("authority"), "authenticated issuer")}
        for field, value in matches.items():
            if record.get(field) != value:
                raise BoundaryError("receipt_" + field + ":" + role)
        if context.kind == "empirical" and record["authority"].startswith("synthetic:"):
            raise BoundaryError("synthetic_issuer_in_empirical_context")
        integer(record.get("timestamp"), "receipt timestamp")
        if role in ("freeze", "extraction", "guardrails"):
            for field in ("candidate", "inputs_sha256"):
                if record.get(field) != expected[field]:
                    raise BoundaryError("receipt_" + field + ":" + role)
        if role in ("extraction", "guardrails") and record.get("evidence_sha256") != expected["evidence_sha256"]:
            raise BoundaryError("receipt_evidence:" + role)
        result[role] = record
    order = [result[r]["timestamp"] for r in ("independent_review", "binding", "freeze", "extraction")]
    if order != sorted(order) or result["guardrails"]["timestamp"] < order[-1]:
        raise BoundaryError("receipt_chronology")
    if result["binding"].get("review_sha256") != authorities["independent_review"]["sha256"]:
        raise BoundaryError("binding_review_link")
    extraction = result["extraction"]
    if (extraction.get("producer_sha256") != expected["roles"]["extractor_source"]["sha256"] or
            extraction.get("supported_semantics") != SEMANTICS):
        raise BoundaryError("extractor_source_semantics")
    checks = obj(result["guardrails"].get("checks"), "invariant checks")
    if set(checks) != set(GUARDS) or any(value != "PASS" for value in checks.values()):
        raise BoundaryError("unresolved_invariant_guardrails")
    return result


def verify(packet, context):
    expected = verify_bindings(packet, context)
    return expected, receipts(context, expected)
