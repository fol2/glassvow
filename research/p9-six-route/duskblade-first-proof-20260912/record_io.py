"""Load only externally digest-bound records and resolve typed record references."""
from __future__ import annotations

from evidence_boundary import BoundaryError, obj, loads, flatten, text, integer

ARMS = ("R", "B", "K1", "K2", "K3")
STRATA = tuple((p, v) for p in ("A", "B") for v in (0, 5))
PACKAGES = (1, 2, 3)
PAIRS = ((1, 2), (1, 3), (2, 3))


def reference(documents, ref):
    ref = obj(ref, "record reference")
    if set(ref) != {"role", "path"}:
        raise BoundaryError("record_reference_schema")
    role = text(ref["role"], "reference role")
    if role not in documents or not isinstance(ref["path"], list):
        raise BoundaryError("unresolved_record_reference")
    value = documents[role]
    for key in ref["path"]:
        if isinstance(value, list):
            integer(key, "reference index")
            if key >= len(value):
                raise BoundaryError("unresolved_record_reference")
        elif isinstance(value, dict):
            text(key, "reference key")
            if key not in value:
                raise BoundaryError("unresolved_record_reference")
        else:
            raise BoundaryError("unresolved_record_reference")
        value = value[key]
    return value


def child(ref, *path):
    return {"role": ref["role"], "path": ref["path"] + list(path)}


def ingest(packet, context):
    flat = flatten(packet["evidence"])
    documents, raw = {}, {}
    for role, locator in flat.items():
        raw[role] = context.resolve(locator)
        if role == "extractor_source" or role.startswith("policies/"):
            continue
        documents[role] = loads(raw[role], role)
    aliases = {"development": "development_manifest", "sampler": "sampler_manifest",
               "exposure": "exposure_manifest"}
    result = {name: obj(documents[aliases.get(name, name)], name) for name in
              ("product", "content", "native_oracle", "profile_0", "profile_5", "signed_B",
               "development", "sampler", "exposure", "features", "model", "freeze", "cost", "allocation")}
    result.update(documents=documents, raw=raw, preflight=documents["preflight"])
    result["factual"], result["measurement"], result["peer"] = {}, {}, {}
    for panel, vow in STRATA:
        key = f"{panel}/v{vow}"
        for group in ("factual", "peer"):
            record = obj(documents[f"{group}/{key}"], group)
            if record.get("panel") != panel or type(record.get("vow")) is not int or record["vow"] != vow:
                raise BoundaryError("stratum_key_mismatch")
            result[group][(panel, vow)] = record
        for k in PACKAGES:
            record = obj(documents[f"measurement/{key}/K{k}"], "measurement")
            if (record.get("panel"), record.get("vow"), record.get("k")) != (panel, vow, k):
                raise BoundaryError("stratum_key_mismatch")
            if type(record["vow"]) is not int or type(record["k"]) is not int:
                raise BoundaryError("stratum_key_mismatch")
            result["measurement"][(panel, vow, k)] = record
    return result


def bit(value, reason="binary observation"):
    if type(value) is not int or value not in (0, 1):
        raise BoundaryError("schema:" + reason)
    return value


def array(value, n, reason):
    if not isinstance(value, list) or len(value) != n:
        raise BoundaryError(reason)
    return value


def crosscheck(record, field, actual):
    if field in record:
        # Canonical JSON comparison prevents bool/int equality hiding bad caches.
        from evidence_boundary import canonical
        if canonical(record[field]) != canonical(actual):
            raise BoundaryError("derived_crosscheck:" + field)
