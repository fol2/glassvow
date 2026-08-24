# #456 host qualification — candidate loading, development seeds, compute hosts

Issue: [fol2/glassvow#456](https://github.com/fol2/glassvow/issues/456).
Engine pin: **4.7.2.stable**. Game-under-test remains H39
`content/full-content.json` file SHA
`a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1`.
Canonical packet: [`data/456/canonical-host.json`](data/456/canonical-host.json).

This ticket does not sit the frozen #215/#216 exam and does not edit live
content. Final production promotion still belongs to #421.

## 1. Alternate content path

`--content=PATH` is wired through `tools/balance_sim.gd`,
`tools/balance_sweep.gd` and `tools/balance_cem.gd` via
`tools/balance_catalogue.gd`. Default remains `res://content/full-content.json`.

An explicit path is read directly. The loader never replaces, checks out,
symlinks or edits `content/full-content.json`. Missing or invalid JSON fails
closed before any run row is written. Manifests bind:

- actual loaded **file SHA-256** (`contentFileSha256` / `contentSha256`);
- **semantic SHA-256** (Python canonical JSON, same definition as #455);
- source **commit**;
- **search-space SHA**;
- **driver SHA** of the balance CLI scripts.

Two candidate catalogues were run concurrently on this host; the live file SHA
did not move. Proof: `python3 -B tools/balance_host_qualify.py --self-test`.

## 2. Development-seed contract

Registry: [`421-content-search-seeds-v1.json`](421-content-search-seeds-v1.json).
Guard: `python3 -B tools/balance_seed_contract.py --self-test` (CI) and the
same rules inside `BalanceCatalogue.stage_error` when `--stage` is set.

| Band | Seeds | Root |
|---|---|---|
| Host fingerprint | 5600–5663 | default policy (not sampled) |
| F0 controls | 6000–6031 | **454** |
| F0 mini-landscape | 6100–6107 | **454** |
| F1 racing | 6200–6399 | **1454** |
| F1 mini-CEM train | 6400–6799 | **2454** |
| F1 mini-CEM validate | 6800–6999 | **2454** |
| Audit (sealed until finalist) | 8000–8199 | 454 / 1454 / 2454 |

`balance_cem.gd` still defaults `--holdoutSeed0=5000` / `--holdoutCount=200`
(the frozen exam acceptance band). `--stage=f1-mini-cem-train` must pass a
development holdout (`--holdoutSeed0=6800`) or use combined
`--stage=f1-mini-cem`; the default 5000–5199 fails closed. `--stage=audit`
is sealed until a finalist exists.

Frozen exam keeps roots **215 / 216**, layer-1 3000–3039, controls 4000–4199,
CEM train 4200–4999, acceptance **5000–5199**. Reserve **5200–5399** is still
untouched. Overlap with any of those from an F0/F1 `--stage` fails closed.

Mini-landscapes must pass `--frozen-axes` to `tools/balance_landscape.py` so
deck cuts (thinMax 25, midMax 35), aspect medians and shatter-then-smolder
tie order stay the #215 freeze.

## 3. Compute-host qualification

Fingerprint: seeds 5600–5663 × duskblade/ashwarden × vows 0/5 = **256** rows,
default policy, shipping mix, H39 content, Godot **4.7.2.stable**.

| Host | `godot --version` | Seed-1000 digest | 256-row hash | Stalls/errors | Verdict |
|---|---|---|---|---|---|
| **M4 Mac mini 16GB** | `4.7.2.stable.official.ed1daf0bf` | `b02bca98…` **PIN_MATCH** | `27a837c0481b368c5b789097e57415a07fb97e8db64a8924fbca58ac07b1d3c8` | 0 / 0 | **QUALIFIED** (canonical) |
| **M1 Max 64GB** | — | — | — | — | **PENDING** packet |
| **Linux/x86 cloud VM** | — | — | — | — | **NOT QUALIFIED** |

A fingerprint packet is **QUALIFIED** only when it matches
`docs/balance/data/456/canonical-host.json` (godot, content SHAs, search-space
SHA, driver SHA, seed-1000 digest, 256-row hash). `balance_host_qualify.py`
grades against that file by default; `--mint` writes a packet without grading.
Do not pool rows from a host that fails exact parity.

## 4. Throughput (zero fingerprint drift)

M4 Mac mini 16GB, Apple M4, arm64, Darwin:

| Workers | Wall (s) | Rows/s | Fingerprint |
|---:|---:|---:|---|
| 4 | 6.255 | 40.929 | `27a837c0…` |
| 6 | 5.483 | 46.690 | `27a837c0…` |
| 8 | 4.296 | **59.591** | `27a837c0…` |

Chosen on this host: **8 workers** (stable rows/s, zero drift). The M1 Max
must still measure 6 / 8 / 10 itself; do not copy the mini's count.

## Commands for the M1 Max (immutable packet only)

Run on the same branch/commit as this document. Return
`/tmp/glassvow-456-m1/host.json` and
`/tmp/glassvow-456-m1-bench/bench-summary.json`. Do not edit the repository.

```bash
godot --version   # must start with 4.7.2.stable

python3 -B tools/balance_host_qualify.py --jobs 8 \
  --compare docs/balance/data/456/canonical-host.json \
  --out /tmp/glassvow-456-m1

python3 -B tools/balance_host_qualify.py --bench --jobs 6,8,10 \
  --out /tmp/glassvow-456-m1-bench
```

A cloud VM may run the same fingerprint after `godot --version` shows
`4.7.2.stable…`. Until that packet matches the canonical hash, it stays
**NOT QUALIFIED** and its rows stay out of ranking.

## Replay

```bash
python3 -B tools/balance_seed_contract.py --self-test
python3 -B tools/balance_host_qualify.py --self-test
python3 -B tools/balance_host_qualify.py --jobs 4 \
  --compare docs/balance/data/456/canonical-host.json \
  --out /tmp/glassvow-456-replay
```
