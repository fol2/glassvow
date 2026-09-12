# #489 Tier-1 control plane — s009 sealed, current main integrated, hosts re-qualified

Issue: [fol2/glassvow#489](https://github.com/fol2/glassvow/issues/489).
Child of [#488](https://github.com/fol2/glassvow/issues/488). Engine pin:
**4.7.2.stable**. Live catalogue remains **H39**. `s009` is the Tier-1 reference
candidate, not live content.

## Integrated head

| Field | SHA |
|---|---|
| Campaign base (`work/454-content-doe`) | `a676a0a91625053388bc4dab102b50e510a0ce21` |
| Integrated `origin/main` | `44acd15c4b8de2531a1788c0b83d65c3a12c9919` |
| Merge commit | `b327098625a2f2481cc31eff40fb0a345fdcb0d8` |
| Merge tree | `4088c47b942d685ee21cede9bb529d145e6be957` |
| H39 file SHA-256 | `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1` |
| H39 semantic SHA-256 | `38e1f4f65901fefd4e6a0f6399c5f76d17355a19c8317f4714c33c9199dbe7aa` |
| Search-space SHA-256 | `524f277331012daeec1a70d9c193141c4b8cfa4723f896341e25547e99c72bca` |
| Driver SHA-256 (balance CLI scripts) | `97a7b07381eda0c5cdbbb4b154aeb2abc1df75249562ec75db88f1b6740b6f6c` |

Conflicts in map/studio docs and `presentation/map/map_scene.gd` were taken from
main. Live `content/full-content.json` stayed H39. #455–#458 tools, the H10/H11
identity split, and Godot 4.7.2 were preserved.

## s009 reconstruction

`python3 -B tools/balance_s009_reconstruct.py --self-test` applies the `s009`
numeric patch and hydrated content strings from
[`data/458/finalists.json`](data/458/finalists.json) onto a **copy** of live
H39. It refuses to write `content/full-content.json`.

| Field | SHA |
|---|---|
| Reconstructed file SHA-256 | `5b3504f133a7e180f20426a8f28c5f2685c9d00d4e3c93c39a432a1a859ea448` |
| Reconstructed semantic SHA-256 | `6359c4958039d37fc05df5bd9487fac12c4cb3b0e8ee4c4f287d87d876b89fc3` |
| Exam commit | `b30b290813d88109c5b9bc34354babefdc406f8d` |

That file SHA is the exam identity. The F1 search candidate file SHA
`0b277c9a…` is a compact numeric catalogue without hydrated `text` fields and
is not the exam artefact.

Exam readout: [`2026-08-25-421-s009-full-exam.md`](2026-08-25-421-s009-full-exam.md).

## Seed / root contract

Registry: [`421-content-search-seeds-v1.json`](421-content-search-seeds-v1.json).
Guards: `python3 -B tools/balance_seed_contract.py --self-test` (CI) and
`BalanceCatalogue.stage_error`. The #454 bands remain occupied. Overlap with
any prior development, audit, acceptance or reserve band fails closed.

| Band | Stage | Seeds | Root |
|---|---|---|---|
| Frozen exam | `exam` | 3000–3039, 4000–4199, 4200–4999, 5000–5199 | **215 / 216** |
| Reserve | — | 5200–5399 | — |
| #454 fingerprint | `fingerprint` | 5600–5663 | default policy |
| #454 F0 controls | `f0-controls` | 6000–6031 | **454** |
| #454 F0 mini-landscape | `f0-mini-landscape` | 6100–6107 | **454** |
| #454 F1 racing | `f1-racing` | 6200–6399 | **1454** |
| #454 mini-CEM train | `f1-mini-cem-train` | 6400–6799 | **2454** |
| #454 mini-CEM validate | `f1-mini-cem-validate` | 6800–6999 | **2454** |
| #454 audit | `audit` | 8000–8199 | 454 / 1454 / 2454, sealed until `finalist` |
| **Tier-1 fingerprint** | `tier1-fingerprint` | **9000–9063** | default policy |
| **Tier-1 F0 controls** | `tier1-f0-controls` | **9100–9131** | **3454** |
| **Tier-1 F0 mini-landscape** | `tier1-f0-mini-landscape` | **9200–9207** | **3454** |
| **Tier-1 F1 racing** | `tier1-f1-racing` | **9300–9599** | **4454** |
| **Tier-1 mini-CEM train** | `tier1-mini-cem-train` | **9600–9999** | **6454** |
| **Tier-1 mini-CEM validate** | `tier1-mini-cem-validate` | **10000–10399** | **6454** |
| **Tier-1 audit** | `tier1-audit` | **11000–11199** | 3454 / 4454 / 6454, sealed until `tier1-finalist` |

## Host qualification (seeds 9000–9063)

Fingerprint: 64 seeds × duskblade/ashwarden × vows 0/5 = **256** rows, default
policy, shipping mix, H39, Godot **4.7.2.stable**, `--stage=tier1-fingerprint`.
Canonical packet: [`data/489/canonical-host.json`](data/489/canonical-host.json).

Seed-1000 digest `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf`
**PIN_MATCH** on both hosts.

| Host | `godot --version` | 256-row hash | Stalls/errors | Rows/s (8 workers) | Verdict |
|---|---|---|---|---:|---|
| **M4 Mac mini 16GB** | `4.7.2.stable.official.ed1daf0bf` | `12c28a6523463cc642e86cd56194bb2f48c68073f94aad384f597b422afcfd8e` | 0 / 0 | 66.005 | **QUALIFIED** (canonical) |
| **M1 Max 64GB** | `4.7.2.stable.official.ed1daf0bf` | `12c28a6523463cc642e86cd56194bb2f48c68073f94aad384f597b422afcfd8e` | 0 / 0 | 95.948 | **QUALIFIED** (primary sim worker) |
| **Linux/x86 cloud VM** | — | — | — | — | **NOT QUALIFIED** |

`compare_packets` between the M4 and M1 packets is empty (godot, content
SHAs, search-space SHA, driver SHA, seed-1000 digest, 256-row hash). Cloud
remains NOT QUALIFIED: no parity packet was produced.

M1 ran from an rsync of this worktree at `/tmp/glassvow-489-qualify` so it
would not edit `~/Coding/glassvow`. That copy had no `.git`, so Godot left
`commit` blank; the packet is stamped with merge commit `b327098` because
its content, search-space and driver SHAs matched the M4 packet from that
HEAD exactly. The 256-row hash does not include the git commit.

Replay:

```bash
python3 -B tools/balance_seed_contract.py --self-test
python3 -B tools/balance_s009_reconstruct.py --self-test
python3 -B tools/balance_host_qualify.py --self-test
python3 -B tools/balance_host_qualify.py --jobs 8 \
  --compare docs/balance/data/489/canonical-host.json \
  --out /tmp/glassvow-489-replay
```
