"""Deterministic synthetic evidence bundle for D547-PC1 adapter tests.

Generates runner-owned store bytes and a claim packet. Not empirical, not a
certificate, and not a live receipt. Python 3 stdlib only.
"""
from __future__ import annotations

import copy
import hashlib
import json

import prospective_admission as admission
import reference_kernel as kernel

N = kernel.N
N_MEAS = kernel.N_MEAS
PANELS = admission.PANELS
VOWS = admission.VOWS
PACKAGES = admission.PACKAGES
PAIRS = admission.PAIRS
ARMS = admission.ARMS
PROTECTED = admission.PROTECTED
STRATA = admission.STRATA


def dumps(obj):
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")


def digest(data):
    if isinstance(data, str):
        data = data.encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def ones(n, k):
    k = max(0, min(n, int(k)))
    return [1] * k + [0] * (n - k)


def k_defaults():
    return {
        "acquire": 1024,
        "enact": 900,
        "win_enact": 600,
        "K_R.gain": 205,
        "K_R.loss": 205,
        "on.correct": 250,
        "off.correct": 254,
        "natural_negative.not_negative": 0,
        "blind_on.gain": 128,
        "blind_on.loss": 0,
        "blind_off.gain": 128,
        "blind_off.loss": 0,
        "correct": 1850,
        "exclusive": {1: 500, 2: 500, 3: 500},
    }


def stratum_defaults():
    return {
        "B.win": 512,
        "R_B.gain": 1150,
        "R_B.loss": 40,
        "K": {k: k_defaults() for k in PACKAGES},
    }


def _merge(base, override):
    if not override:
        return copy.deepcopy(base)
    out = copy.deepcopy(base)
    for key, value in override.items():
        if key == "K" and isinstance(value, dict):
            for kk, kv in value.items():
                out["K"].setdefault(int(kk), k_defaults()).update(kv)
        else:
            out[key] = value
    return out


def _meas_bits(tgt):
    on_c = tgt["on.correct"]
    off_c = tgt["off.correct"]
    nn = tgt["natural_negative.not_negative"]
    bits = {
        "on.correct": ones(N_MEAS, on_c),
        "off.correct": ones(N_MEAS, off_c),
        "natural_negative.not_negative": ones(N_MEAS, nn),
        "blind_on.gain": ones(N_MEAS, tgt["blind_on.gain"]),
        "blind_on.loss": ones(N_MEAS, tgt["blind_on.loss"]),
        "blind_off.gain": ones(N_MEAS, tgt["blind_off.gain"]),
        "blind_off.loss": ones(N_MEAS, tgt["blind_off.loss"]),
    }
    on_pred = [1] * on_c + [-1] * (N_MEAS - on_c)
    off_pred = [0] * off_c + [-1] * (N_MEAS - off_c)
    natural_pred = [0] * (N_MEAS - nn) + [-1] * nn
    return bits, on_pred, off_pred, natural_pred


def _build_stratum(panel, vow, roots, identities, tgt):
    b, g, loss = tgt["B.win"], tgt["R_B.gain"], tgt["R_B.loss"]
    bits = {
        "B.win": ones(N, b),
        "R_B.gain": ones(N, g),
        "R_B.loss": ones(N, loss),
    }
    for k in PACKAGES:
        kd = tgt["K"][k]
        bits[f"K{k}/acquire"] = ones(N, kd["acquire"])
        bits[f"K{k}/enact"] = ones(N, kd["enact"])
        bits[f"K{k}/win_enact"] = ones(N, kd["win_enact"])
        bits[f"K{k}/K_R.gain"] = ones(N, kd["K_R.gain"])
        bits[f"K{k}/K_R.loss"] = ones(N, kd["K_R.loss"])
    behavior = {
        f"K{k}": [((i + 1) * (k + 3) + k + vow + (0 if panel == "A" else 17)) % 10**9 for i in range(N)]
        for k in PACKAGES
    }
    factual = {
        "panel": panel,
        "vow": vow,
        "roots": roots,
        "crn_roots": {arm: roots[:] for arm in ARMS},
        "bits": bits,
        "behavior": behavior,
        "product": identities["product"],
        "profile": identities["profile"][str(vow)],
        "control": identities["signed_B"],
        "freeze_id": "freeze-1",
        "sampler_id": "sampler-1",
        "frame_id": "frame-1",
        "timestamp": 3000,
    }
    measurement = {}
    for k in PACKAGES:
        kd = tgt["K"][k]
        enact = bits[f"K{k}/enact"]
        selected = [roots[i] for i, flag in enumerate(enact) if flag][:N_MEAS]
        mb, on_pred, off_pred, natural_pred = _meas_bits(kd)
        measurement[k] = {
            "panel": panel,
            "vow": vow,
            "k": k,
            "roots": selected,
            "bits": mb,
            "on_gt": [1] * N_MEAS,
            "on_native": [1] * N_MEAS,
            "off_gt": [0] * N_MEAS,
            "off_native": [0] * N_MEAS,
            "on_pred": on_pred,
            "off_pred": off_pred,
            "natural_pred": natural_pred,
            "timestamp": 3000,
        }
    peer_bits = {}
    for k, ell in PAIRS:
        kd = tgt["K"][k]
        ld = tgt["K"][ell]
        ek = kd["exclusive"].get(ell, 500)
        el_ = ld["exclusive"].get(k, 500)
        peer_bits[f"pair{k}{ell}/correct_k"] = ones(N, kd["correct"])
        peer_bits[f"pair{k}{ell}/correct_l"] = ones(N, ld["correct"])
        peer_bits[f"pair{k}{ell}/exclusive_k"] = ones(N, ek)
        peer_bits[f"pair{k}{ell}/exclusive_l"] = ones(N, el_)
    peer = {"panel": panel, "vow": vow, "bits": peer_bits}
    return factual, measurement, peer


SIGNED_B_RAW = dumps({"implementation": "landscape-arm2-random-build-competent-play"})


def _policy_bytes(panel, arm, identities):
    if arm == "B":
        return SIGNED_B_RAW
    return dumps({"policy": f"{panel}/{arm}"})


def build_bundle(
    stratum_overrides=None,
    context_kind="synthetic",
    ledger_bound=False,
    events=None,
    usage=None,
    native_used=None,
    allocation_mutator=None,
    include_rows=True,
    extra_packet=None,
):
    product_raw = dumps({"label": "D547-PC1-synthetic-product"})
    content_raw = dumps({"label": "D547-PC1-synthetic-content"})
    oracle_raw = dumps({"label": "D547-PC1-synthetic-oracle"})
    signed_raw = SIGNED_B_RAW
    profile_raw = {0: dumps({"vow": 0}), 5: dumps({"vow": 5})}
    identities = {
        "product": digest(product_raw),
        "content": digest(content_raw),
        "native_oracle": digest(oracle_raw),
        "signed_B": digest(signed_raw),
        "profile": {str(v): digest(profile_raw[v]) for v in VOWS},
        "epoch": kernel.EPOCH,
        "policies": {},
    }
    policy_raw = {}
    for panel in PANELS:
        identities["policies"][panel] = {}
        for arm in ARMS:
            raw = _policy_bytes(panel, arm, identities)
            policy_raw[(panel, arm)] = raw
            identities["policies"][panel][arm] = digest(raw)

    store = {
        "synth://product": product_raw,
        "synth://content": content_raw,
        "synth://oracle": oracle_raw,
        "synth://signed_B": signed_raw,
        "synth://profile/0": profile_raw[0],
        "synth://profile/5": profile_raw[5],
    }
    for panel in PANELS:
        for arm in ARMS:
            store[f"synth://policy/{panel}/{arm}"] = policy_raw[(panel, arm)]

    names = [f"public_qty_{i}" for i in range(8)]
    store["synth://features"] = dumps({"names": names, "includes_win_label": False})
    store["synth://model"] = dumps({
        "fitted_on": "development",
        "full_features": names,
        "blind_features": names[:6],
        "centroids": {"on": [0.0] * 8, "off": [1.0] * 8},
    })
    store["synth://cost"] = dumps({
        arm: {"forward_evals_per_decision": 128, "hidden_rng": False, "privileged": False}
        for arm in ("R", "K1", "K2", "K3")
    })
    store["synth://freeze"] = dumps({
        "id": "freeze-1",
        "epoch": kernel.EPOCH,
        "timestamp": 1000,
        "product": identities["product"],
        "packages": ["K1", "K2", "K3"],
    })

    overrides = stratum_overrides or {}
    development_roots = {}
    sampler_manifest = {}
    for i, (panel, vow) in enumerate(STRATA):
        base = 10_000_000 + i * 1_000_000 + vow * 10_000
        roots = [base + j for j in range(N)]
        sampler_manifest[f"{panel}/v{vow}"] = roots
        development_roots[f"{panel}/v{vow}"] = [90_000_000 + i * 1000 + j for j in range(64)]
        tgt = _merge(stratum_defaults(), overrides.get((panel, vow)))
        factual, measurement, peer = _build_stratum(panel, vow, roots, identities, tgt)
        store[f"synth://factual/{panel}/v{vow}"] = dumps(factual)
        store[f"synth://peer/{panel}/v{vow}"] = dumps(peer)
        for k in PACKAGES:
            store[f"synth://meas/{panel}/v{vow}/K{k}"] = dumps(measurement[k])

    store["synth://development"] = dumps({"roots": development_roots})
    store["synth://sampler"] = dumps({
        "id": "sampler-1",
        "frame_id": "frame-1",
        "method": "uniform-without-replacement",
        "timestamp": 1500,
        "forbidden": sorted(PROTECTED),
        "manifest": sampler_manifest,
    })
    store["synth://exposure"] = dumps({
        "exposed": [],
        "protected": list(PROTECTED),
        "authority": "synthetic-exposure",
    })
    preflight = []
    for arm in ("R", "K1", "K2", "K3"):
        preflight.append({
            "arm": arm,
            "legal": True,
            "state": {"hand": ["chisel"], "energy": 3},
            "action_A": f"play:{arm}:A",
            "action_B": f"play:{arm}:B",
            "policy_A": identities["policies"]["A"][arm],
            "policy_B": identities["policies"]["B"][arm],
        })
    store["synth://preflight"] = dumps(preflight)

    allocation = admission.load_allocation()
    if events:
        allocation = copy.deepcopy(allocation)
        allocation["event_log"] = events
        if usage is not None:
            allocation["usage"] = usage
        if native_used is not None:
            for stage, used in native_used.items():
                allocation["native_starts"][stage]["used"] = used
    if allocation_mutator:
        allocation = copy.deepcopy(allocation)
        allocation_mutator(allocation)
    store["synth://allocation"] = dumps(allocation)

    evidence = {
        "product": "synth://product",
        "content": "synth://content",
        "native_oracle": "synth://oracle",
        "profile_0": "synth://profile/0",
        "profile_5": "synth://profile/5",
        "signed_B": "synth://signed_B",
        "preflight": "synth://preflight",
        "development_manifest": "synth://development",
        "sampler_manifest": "synth://sampler",
        "freeze": "synth://freeze",
        "exposure_manifest": "synth://exposure",
        "features": "synth://features",
        "model": "synth://model",
        "cost": "synth://cost",
        "allocation": "synth://allocation",
        "policies": {
            panel: {arm: f"synth://policy/{panel}/{arm}" for arm in ARMS}
            for panel in PANELS
        },
        "factual": {f"{p}/v{v}": f"synth://factual/{p}/v{v}" for p, v in STRATA},
        "measurement": {
            f"{p}/v{v}/K{k}": f"synth://meas/{p}/v{v}/K{k}"
            for p, v in STRATA for k in PACKAGES
        },
        "peer": {f"{p}/v{v}": f"synth://peer/{p}/v{v}" for p, v in STRATA},
    }
    packet = {
        "mode": "synthetic" if context_kind == "synthetic" else "empirical",
        "authority": "D547-PC1",
        "epoch": kernel.EPOCH,
        "identities": {
            "product": identities["product"],
            "content": identities["content"],
            "native_oracle": identities["native_oracle"],
            "profile": identities["profile"],
            "policies": identities["policies"],
            "signed_B": identities["signed_B"],
            "signed_B_authority": "landscape-arm2-random-build-competent-play",
        },
        "evidence": evidence,
        "allocation": allocation,
        "exposed_seeds": [],
        "protected_seeds": list(PROTECTED),
        "bound": False,
        "approved": False,
        "binding_receipt": None,
        "certificate": False,
    }
    if include_rows:
        packet["rows"] = _rows_for_overrides(overrides) if overrides else admission.passing_rows()
    if extra_packet:
        packet.update(extra_packet)

    context = admission.TrustedContext(
        kind=context_kind,
        expected_identities=identities,
        expected_allocation=admission.load_allocation(),
        store=store,
        receipts={},
        expected_authority="D547-PC1",
        synthetic_ledger_bound=ledger_bound,
    )
    return packet, context


def _rows_for_overrides(overrides):
    rows = admission.passing_rows()
    if not overrides:
        return rows
    mapped = {row["key"]: row for row in rows}
    for (panel, vow), tgt in overrides.items():
        merged = _merge(stratum_defaults(), tgt)
        p = f"{panel}/v{vow}"
        mapped[f"{p}/B.win"]["successes"] = merged["B.win"]
        mapped[f"{p}/R_B.gain"]["successes"] = merged["R_B.gain"]
        mapped[f"{p}/R_B.loss"]["successes"] = merged["R_B.loss"]
        for k in PACKAGES:
            kd = merged["K"][k]
            q = f"{p}/K{k}"
            for field in (
                "acquire", "enact", "win_enact", "K_R.gain", "K_R.loss",
                "on.correct", "off.correct", "natural_negative.not_negative",
                "blind_on.gain", "blind_on.loss", "blind_off.gain", "blind_off.loss",
            ):
                mapped[f"{q}/{field}"]["successes"] = kd[field]
            for ell in PACKAGES:
                if ell == k:
                    continue
                a, b = (k, ell) if k < ell else (ell, k)
                pair = f"{p}/pair{a}{b}"
                if k < ell:
                    mapped[f"{pair}/correct_k"]["successes"] = kd["correct"]
                    mapped[f"{pair}/exclusive_k"]["successes"] = kd["exclusive"].get(ell, 500)
                else:
                    mapped[f"{pair}/correct_l"]["successes"] = kd["correct"]
                    mapped[f"{pair}/exclusive_l"]["successes"] = kd["exclusive"].get(ell, 500)
    return rows


_GOOD = None


def good_bundle():
    global _GOOD
    if _GOOD is None:
        _GOOD = build_bundle()
    packet, ctx = _GOOD
    return copy.deepcopy(packet), ctx.copy()


def load_json(ctx, locator):
    return json.loads(ctx.store[locator].decode("utf-8"))


def store_json(ctx, locator, obj):
    ctx.store[locator] = dumps(obj)


def mutate_factual_bits(ctx, panel, vow, key, values):
    loc = f"synth://factual/{panel}/v{vow}"
    obj = load_json(ctx, loc)
    obj["bits"][key] = values
    store_json(ctx, loc, obj)


def mutate_meas_bits(ctx, panel, vow, k, key, values):
    loc = f"synth://meas/{panel}/v{vow}/K{k}"
    obj = load_json(ctx, loc)
    obj["bits"][key] = values
    store_json(ctx, loc, obj)


def mutate_peer_bits(ctx, panel, vow, key, values):
    loc = f"synth://peer/{panel}/v{vow}"
    obj = load_json(ctx, loc)
    obj["bits"][key] = values
    store_json(ctx, loc, obj)
