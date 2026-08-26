# #501 Tier-2 control plane — current main integrated, mob identity, fresh seeds

Issue: [fol2/glassvow#501](https://github.com/fol2/glassvow/issues/501).
Child of [#500](https://github.com/fol2/glassvow/issues/500). Engine pin:
**4.7.2.stable**. Live catalogue remains **H39**. Live `content/mob-overrides.json`
remains canonical `{}`. `s009` stays the non-destructive reference candidate.
`t2-c000` is exact s009 content plus the exact empty override.

## Integrated head

| Field | SHA |
|---|---|
| Campaign base (`work/454-content-doe`) | `e8a05ad63b64e140d935f68452b3f73aaceb1b5e` |
| Integrated `origin/main` | `455dd6071b3cc0b0ff87083a42287265e83f7442` |
| Merge commit | `39167244d9d1286c8b705a0797c5afdee61079b6` |
| Merge tree | `2f8d27acf8f912124478b678b24df13badc0d142` |
| Feat commit | `5fa98a375fa8ea0aade5c4c083c606fb540472f3` |
| H39 file SHA-256 | `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1` |
| H39 semantic SHA-256 | `38e1f4f65901fefd4e6a0f6399c5f76d17355a19c8317f4714c33c9199dbe7aa` |
| Live mobs file SHA-256 | `ca3d163bab055381827226140568f3bef7eaac187cebd76878e0b63e9e442356` |
| Live mobs semantic SHA-256 | `44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a` |
| Search-space SHA-256 | `524f277331012daeec1a70d9c193141c4b8cfa4723f896341e25547e99c72bca` |
| Seed-contract SHA-256 | `bbfb5104f642668ae52a581c3f530b23a3f11b16bd58e5ede5cbffd408dd1ef3` |
| Driver SHA-256 (balance CLI scripts) | `1db461a66d4e8a39882463add0fc4439d62174677a4920d173a459ffc72fa257` |

Map/studio commits from main (`088a533f`, `455dd607`) merged cleanly. Live
`content/full-content.json` stayed H39. s009 reconstruction, #455–#492 evidence,
H10/H11 identity, and Godot 4.7.2 were preserved. No Tier-2 row existed before
this merge.

## Candidate-specific mob identity

`--mobs=PATH` is wired through `tools/balance_sim.gd`, `tools/balance_sweep.gd`
and `tools/balance_cem.gd` via `tools/balance_catalogue.gd`. F0 and mini-CEM
Python drivers pass the same flag. Default remains the live empty override.
The loader never replaces, checks out, symlinks or edits
`content/mob-overrides.json`. Missing, malformed, unknown-id or incomplete
complete-entry overlays fail closed before any run row. Manifests bind:

- content **file** and **semantic** SHA-256;
- mob-override **file** and **canonical semantic** SHA-256;
- source **commit**;
- **search-space**, **seed-contract** and **driver** SHAs.

`ContentDB.enemy_override_faults` is unchanged: names stay locale-owned, IDs
and move-ID sets stay fixed, application stays whole-candidate-before-mutation.

Two candidate overlays were run concurrently; the live override SHA did not
move. Proof: `python3 -B tools/balance_host_qualify.py --self-test`.

## Seed / root contract

Registry: [`421-content-search-seeds-v1.json`](421-content-search-seeds-v1.json).
Guards: `python3 -B tools/balance_seed_contract.py --self-test` (CI) and
`BalanceCatalogue.stage_error`. Every overlap with prior development, audit,
acceptance or reserve bands/roots fails closed. 13400–13999 stays unused.

| Band | Stage | Seeds | Root |
|---|---|---|---|
| Frozen exam | `exam` | 3000–3039, 4000–4199, 4200–4999, 5000–5199 | **215 / 216** |
| Reserve | — | 5200–5399 | — |
| #454 / Tier-1 bands | (occupied) | 5600–11199 | 454 / 1454 / 2454 / 3454 / 4454 / 6454 |
| **Tier-2 fingerprint** | `tier2-fingerprint` | **12000–12063** | default policy |
| **Profile census** (#502) | `tier2-profile-census` | **12064–12095** | **7354** |
| **Tier-2 F0 controls** | `tier2-f0-controls` | **12100–12131** | **7454** |
| **Tier-2 F0 mini-landscape** | `tier2-f0-mini-landscape` | **12200–12207** | **7454** |
| **Tier-2 F1 racing** | `tier2-f1-racing` | **12300–12599** | **8454** |
| **Tier-2 mini-CEM train** | `tier2-mini-cem-train` | **12600–12999** | **9454** |
| **Tier-2 mini-CEM validate** | `tier2-mini-cem-validate` | **13000–13399** | **9454** |
| Unused | — | **13400–13999** | — |
| **Tier-2 audit** | `tier2-audit` | **14000–14199** | 7454 / 8454 / 9454, sealed until `tier2-finalist` |

## Host qualification (seeds 12000–12063)

Fingerprint: 64 seeds × duskblade/ashwarden × vows 0/5 = **256** rows, default
policy, shipping mix, H39, Godot **4.7.2.stable**, `--stage=tier2-fingerprint`.
Canonical packet: [`data/501/canonical-host.json`](data/501/canonical-host.json).

Seed-1000 digest `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf`
**PIN_MATCH** on M4.

| Host | `godot --version` | 256-row hash | Stalls/errors | Rows/s (8 workers) | Verdict |
|---|---|---|---|---:|---|
| **M4 Mac mini 16GB** | `4.7.2.stable.official.ed1daf0bf` | `3a887fec19d0ca50d2738056d6f5ca3e07d12c2edff59095b12acefce71fc648` | 0 / 0 | 83.840 | **QUALIFIED** (canonical) |
| **M1 Max 64GB** | — | — | — | — | **NOT YET QUALIFIED** (no parity packet on this head) |
| **Linux/x86 cloud VM** | — | — | — | — | **NOT QUALIFIED** |

M4 bench 4/6/8 workers: fingerprint hash identical; 8 workers is the stable
throughput pick (4: 69.366, 6: 64.127, 8: 83.840 rows/s). Cloud remains NOT
QUALIFIED: no exact-parity packet. Host packets also bind reconstructed s009
file/semantic SHA `5b3504f133a7e180f20426a8f28c5f2685c9d00d4e3c93c39a432a1a859ea448`
/ `6359c4958039d37fc05df5bd9487fac12c4cb3b0e8ee4c4f287d87d876b89fc3`.

## Ticket stop

M4 is QUALIFIED. This session has no M1 Max SSH path, so per done-when the
ticket **stops** with M1 **NOT YET QUALIFIED**. #502 stays blocked until an
immutable M1 packet compares empty against `canonical-host.json`. Cloud remains
NOT QUALIFIED.

Host packets bind feat `5fa98a375fa8ea0aade5c4c083c606fb540472f3` (the dirty-tree
M4 run sat on merge `39167244`; a docs stamp rewrote the recorded commit only).
`compare_packets` does not grade git commit. M1 must rsync this feat (or later
docs-only stamp) so the tree contains `--stage=tier2-fingerprint`, and must not
mutate the checkout.

Authored tools+tests exceed the 400-line stop (self-tests, seed JSON, host
packets). No enemy IDs, F0/racing/CEM/audit rows, or live-catalogue edits.

Owner-generated M1 command:

```bash
python3 -B tools/balance_seed_contract.py --self-test
python3 -B tools/balance_host_qualify.py --self-test
python3 -B tools/balance_host_qualify.py --jobs 8 \
  --compare docs/balance/data/501/canonical-host.json \
  --out /tmp/glassvow-501-m1
python3 -B tools/balance_host_qualify.py --bench --jobs 6,8,10 \
  --compare docs/balance/data/501/canonical-host.json \
  --out /tmp/glassvow-501-m1-bench
```

Replay on M4:

```bash
python3 -B tools/balance_seed_contract.py --self-test
python3 -B tools/balance_s009_reconstruct.py --self-test
python3 -B tools/balance_host_qualify.py --self-test
python3 -B tools/balance_host_qualify.py --jobs 8 \
  --compare docs/balance/data/501/canonical-host.json \
  --out /tmp/glassvow-501-replay
```
