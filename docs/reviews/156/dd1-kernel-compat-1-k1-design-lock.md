# DD1-KERNEL-COMPAT-1 — K1 design lock (source/inert only)

**Role:** Claude Code design lead. Design only; no Python module/test is implemented here, no
engine/K2/helper build is run. The implementer is a separate agent per the routing note below.

> **AMENDMENT 1 (2026-09-25) — authority fol2/glassvow#156 comment `5828245869`.**
> Previous lock SHA `454d4ac3242db1abab5ebb113ecb021c742cfc41` (unamended). The K1 lock correctly
> found the delivery blocker: at the frozen base the shared reservation/backend clock is pinned to
> the **expired** N0 window, so a K2 run through the existing inert path refuses before any release.
> The ruling's lawful minimal repair is an **operation-scoped reservation policy used only by
> DD1-KERNEL-COMPAT-1 inert controls**; the expired `DD1-N0-RECOVERY-1` constants/account stay
> immutable and unusable. This amendment supersedes **only** the text that treated the expired clock
> as an external custodian precondition and forbade touching `dd1_reservations.py` (the §1 "no
> change" bullet + files-touched list, the §8 "K2-runtime precondition" paragraph, the §9 non-claim
> naming `dd1_reservations.py`). The full amended design is in **§10**, which governs on conflict; it
> neither widens nor narrows the ruling, and the commit landing it is the implementation start SHA.
> No window is extended, reset, revived, spent or reinterpreted; the old N0 clock/account remain
> expired and keep rejecting. No new owner decision is required for this repair.

> **AMENDMENT 2 (2026-09-26) — authority fol2/glassvow#156 comment `5845725453`.**
> Previous lock SHA `2f33b6bd25076559eb146ebf7cfc1b747570f3a0`. The owner selection
> `5827591001` window (2026-09-25T05:57:00Z → 2026-09-26T05:57:00Z, grant `deadline_unix`
> `1790402220`) expired unused (0 releases). Operation ID stays `DD1-KERNEL-COMPAT-1`.
> This amendment re-pins ONLY the owner-selection id, the selected window and the grant
> `deadline_unix`. Every envelope value, the stop graph, helper pin and all design/semantics
> are unchanged. Implementer is Grok Build (grok-4.7-xhigh) per the owner exception. This
> docs-only re-pin was written by the implementer because Claude Code was unavailable, and
> is reviewed by Ash (PM). AMENDMENT 2 governs on conflict for these values only.

## 1. Scope, base, authority

- **Frozen base:** `c17ae971a447c28e597b78d0ecb5eb29f36e644a`, tree
  `50efb1e97668d58ad9c062e78f0801bf33d62c37` (tip of `research/p9-six-route/dd1-native-1-overlay`).
  Branch for this work: `research/p9-six-route/dd1-kernel-compat-1`, created from that base only.
  Operating main remains `07b5aa9dec8436132a524511d5438c510e322070` (rules authority; never mutated).
- **Authority comments (issue fol2/glassvow#156):**
  - Owner selection `5827591001` — selected 2026-09-25T05:57:00Z, absolute deadline
    2026-09-26T05:57:00Z. Verbatim original owner authorisation of DD1-KERNEL-COMPAT-1.
    Historical: that window expired unused (0 releases) and is not the current selection.
  - Renewed-window selection + implementer exception `5845725453` — start
    2026-09-26T11:02:00Z, absolute deadline 2026-09-27T11:02:00Z (`deadline_unix`
    `1790506920`). Current selection record for DD1-KERNEL-COMPAT-1; names Grok Build
    (grok-4.7-xhigh) as this K1 implementer only.
  - Envelope + K0–K5 stop graph `5827472523`.
  - K0 bounded JSON `5827803459` — `K0.json` sha256
    `e4dbba67824aeb6b5d52c5697e948e4baec78e38f19ed9cd6cefb790de139c66`; custodian Tushar,
    executor grokbot-vm; all counters 0; 17 HELPER_SOURCES clone bytes equal the git blobs at base.
    Historical under the expired `5827591001` window. Tushar must re-verify K0 custody for
    the `5845725453` window before K2.
  - The exact K1/K2 contract packet is `5827737668`; this lock designs against it verbatim and
    neither widens nor narrows it.
- **Files touched by K1 (nothing else changes) — amended by §10:**
  1. **add** `tools/dd1_kernel_qualification.py`
  2. **modify** `tools/dd1_linux_snapshot.py` — `prepare()` gate + `HELPER_SOURCES`
  3. **modify** `tools/dd1_compatibility.py` — `validate_profile()`, `native_bindings()`
  4. **modify** `tools/dd1_reservations.py` — internal optional `policy=None` seam (§10.2); `FIRST`,
     `DEADLINE`, `OPERATION` and legacy account schema/caps/history semantics **unchanged**
  5. **modify** `tools/dd1_linux_backend.py` — `controller_limits(unit, deadline_utc=None)` (§10.3)
  6. **modify** `tools/dd1_meter_entry.py` — `_complete`/`_run_inert_unit` policy plumbing (§10.4)
  7. **add** `tools/dd1_linux/kernel_compat_controls.py` (the one K2 driver)
  8. **add** `tools/test_dd1_kernel_qualification.py`
- **No** change to `supervisor.c/policy.c/isolate.c/capabilities.c/.h/policy.h` or any
  `tools/dd1_linux/*.c|*.h`; **no** change to `PINNED_HELPER_SHA256`; **no** change to accepted
  B1/D/C/H/FIT/PREP/COMPAT-2/HOST-BRIDGE semantics, P9/#108, `main`, or the overlay branch.
  <br>~~**No** change to `dd1_reservations.py`.~~ **Superseded by AMENDMENT 1 / §10.2:**
  `dd1_reservations.py` gains an internal `policy=None` parameter only; with `policy is None` its
  behaviour is byte-for-byte the legacy behaviour, so accepted semantics are preserved.

## 2. `tools/dd1_kernel_qualification.py` — signatures and constants

```python
SCHEMA     = "DD1-KERNEL-QUALIFICATION-1"
OPERATION  = "DD1-KERNEL-COMPAT-1"
SELECTION  = 5845725453
DISPOSITION_SCHEMA = "DD1-KERNEL-COMPAT-DISPOSITION-1"
PRIMITIVES = frozenset((                       # exact required primitive-name set (9)
    "seccomp_user_notif", "user_namespace", "mount_namespace", "network_namespace",
    "readonly_bind_remount", "subreaper", "pdeathsig", "rlimit_cpu", "cgroup_v2"))
IDENTITY_FIELDS = ("system", "machine", "kernel_release", "kernel_version",
                   "pointer_bytes", "libc")   # exactly the packet's 6; no more
LEGACY_RELEASE = "6.18.44"                     # strict B1, no fallback
QUALIFIED_IDENTITY = dict(                     # this grokbot-vm, exact equality only
    system="Linux", machine="x86_64", kernel_release="6.12.94+",
    kernel_version="#1 SMP PREEMPT_DYNAMIC Mon Sep 14 19:13:20 UTC 2026",
    pointer_bytes=8, libc=["glibc", "2.41"])

def require(unit, host_facts): ...            # source/inert admission gate (called by prepare)
def native_bindings(unit, expected, context): ...   # native/engineering disposition gate
def profile_sha256(unit): ...                 # r.digest(r.encode(unit["kernel_qualification"]))
```

Reuse `dd1_reservations` as `r` for `need`, `natural`, `digest`, `encode` (never a second impl).
`require`/`native_bindings` raise `r.ReservationError` on any mismatch. No I/O, no clock, no host
probe inside this module — `host_facts` is passed in by the caller.

### `require(unit, host_facts)`

1. `q = unit.get("kernel_qualification")`.
2. **Legacy / no-profile path (`q is None`)** — preserve strict B1 exactly:
   `r.need(host_facts["system"] == "Linux" and host_facts["machine"] == "x86_64"
   and host_facts["pointer_bytes"] == 8 and host_facts["kernel_release"] == LEGACY_RELEASE,
   "unsupported host/ABI; no fallback")`. No fallback, no ranges. Return.
3. **Profile present** — `r.need(isinstance(q, dict), ...)` then validate, in this order:
   - keys are **exactly** `{"schema","operation","selection","source_head","status","mode",
     "host_identity","primitives"}` — `r.need(set(q) == KEYS, "no extra fields")`.
   - `q["schema"] == SCHEMA`, `q["operation"] == OPERATION`, `q["selection"] == SELECTION`.
   - `q["source_head"] == unit["overlay_head"]` and matches `^[0-9a-f]{40}$` (binds the K1 head; see §3).
   - `q["status"] in ("REQUALIFYING", "QUALIFIED")`.
   - `q["mode"] == unit.get("mode")`.
   - `set(q["host_identity"]) == set(IDENTITY_FIELDS)` and, for every field,
     `q["host_identity"][field] == host_facts[field]` by **exact equality**
     (`kernel_version` and `libc` included; no prefix/family/regex/range). `libc` compared as a list.
   - `sorted(q["primitives"]) == sorted(PRIMITIVES)` and `len(q["primitives"]) == len(PRIMITIVES)`
     (exact set, no missing/extra/dup name).
   - **REQUALIFYING is inert-only:** if `q["status"] == "REQUALIFYING"`,
     `r.need(q["mode"] == "inert_control" and unit.get("mode") == "inert_control",
     "REQUALIFYING is inert-control only")`. It is never native/engineering authority.
   - `require` **never** grants native admission for `QUALIFIED`; it only accepts the profile's
     shape/identity so an inert unit may run. Native consumption is gated solely in
     `native_bindings` (below), which K1/K2 cannot satisfy.

### `native_bindings(unit, expected, context)`

Called from `dd1_compatibility.native_bindings` before native stage admission (see §3). Only
enforced when a kernel qualification is present:

1. `q = unit.get("kernel_qualification")`; if `q is None`, return (legacy strict path already
   rejected 6.12.94+ in `prepare()`; nothing to add).
2. **Native requires QUALIFIED:** `r.need(q.get("status") == "QUALIFIED",
   "REQUALIFYING/incomplete kernel qualification is not native authority")`. (REQUALIFYING fails here.)
3. Bind the externally authenticated disposition role, mirroring the COMPAT-2 pattern
   (`bound_role` / `receipt_authorities` / `context.receipts`):
   - `role = expected["roles"].get("kernel_qualification_disposition", {})`;
     `raw = context.resolve(role.get("locator"))`;
     `r.need(isinstance(raw, bytes) and r.digest(raw) == role.get("sha256"),
     "missing kernel qualification disposition")`.
   - `d = json.loads(raw)`; require **all** of:
     `d["schema"] == DISPOSITION_SCHEMA`, `d["operation"] == OPERATION`,
     `d["owner_selection"] == SELECTION`,
     `d["profile_sha256"] == profile_sha256(unit)`,
     `d["source_head"] == unit["overlay_head"]`,
     `d["kernel_identity"] == q["host_identity"]` (exact),
     `d["independent_review"] == "APPROVE"`, `d["planner_acceptance"] == "ACCEPTED"`,
     `d["launch_admitted"] is True`.
   - **Non-synthetic receipt authority:**
     `auth = expected.get("receipt_authorities", {}).get("kernel_qualification_disposition", {})`;
     `r.need(isinstance(auth.get("authority"), str) and auth["authority"]
     and not auth["authority"].startswith("synthetic:")
     and auth.get("sha256") == r.digest(raw) and d.get("authority") == auth["authority"]
     and context.receipts.get("kernel_qualification_disposition") == raw,
     "unauthenticated kernel qualification issuer")`.
4. Also `r.need(context.kind == "empirical", "kernel qualification rejects synthetic native authority")`.

**Consequence (invariant):** K1/K2 cannot manufacture a `DD1-KERNEL-COMPAT-DISPOSITION-1` record —
it requires K4 `independent_review==APPROVE`, K5 `planner_acceptance==ACCEPTED`, and owner
`launch_admitted==True`, none of which exist inside this operation. **Native admission therefore
stays rejected in DD1-KERNEL-COMPAT-1.** A K2 PASS qualifies only this exact kernel identity for a
later, separately-priced engineering operation.

## 3. Edits to existing modules

### `tools/dd1_linux_snapshot.py`

- `HELPER_SOURCES`: add `"res://tools/dd1_kernel_qualification.py"` to the frozenset (Python
  source-closure only; see §6). No other member changes.
- `prepare()`: replace **only** the current gate at line 85–86:
  ```python
  r.need(platform.system() == "Linux" and platform.machine() == "x86_64"
         and platform.release() == "6.18.44" and struct.calcsize("P") == 8,
         "unsupported host/ABI; no fallback")
  ```
  with:
  ```python
  import dd1_kernel_qualification as kernel_qualification
  host = dict(system=platform.system(), machine=platform.machine(),
              kernel_release=platform.release(), kernel_version=platform.version(),
              pointer_bytes=struct.calcsize("P"), libc=list(platform.libc_ver()))
  kernel_qualification.require(unit, host)
  ```
  Everything after (ABI `linux-x86_64-lp64-v1`, `HELPER_SOURCES <= source_files`, `fit.limit`,
  CPU/raw bounds, source-byte digests, the "loaded controller source differs" check, ELF/interp/
  helper pin, preparation/fit/compat validation, raw envelope) is **unchanged**. The `host` dict
  keys are exactly `IDENTITY_FIELDS`, in identity order.

### `tools/dd1_compatibility.py`

- `validate_profile(unit, pinned)`: after the existing `expected = dict(...)` is built and **before**
  the `r.need(r.encode(profile) == r.encode(expected), ...)` exact-invocation compare, add — only
  when `unit.get("kernel_qualification") is not None`:
  ```python
  expected["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
  ```
  This binds the qualification into the exact COMPAT-2 invocation profile so a substituted
  qualification breaks the profile binding. When no kernel qualification exists, the key is absent
  and the existing binding is byte-identical to today (no regression to accepted COMPAT-2/FIT units).
- `native_bindings(unit, expected, context)`: inside the existing non-`None` branch (i.e. after the
  `if unit.get("compatibility") is None: ... return` guard), **before** `fit.native_bindings(...)`
  and before any reservation/effect, add:
  ```python
  import dd1_kernel_qualification as kernel_qualification
  kernel_qualification.native_bindings(unit, expected, context)
  ```
  Order rationale: `native_bindings` runs in `dd1_meter_entry.run_complete_unit` strictly before
  `_complete` → `reserve_and_run`, so a missing / REQUALIFYING / synthetic qualification fails
  before reservation or any child. The existing `compatibility_disposition`, FIT, PREP, seal, and
  receipt-authority checks are left intact and still run.

No other function in either module changes. `PINNED_HELPER_SHA256` stays
`41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4`.

## 4. Qualification profile schema — `unit["kernel_qualification"]`

Exactly these keys, no extra fields:

| key | type | allowed value |
|---|---|---|
| `schema` | str | `"DD1-KERNEL-QUALIFICATION-1"` |
| `operation` | str | `"DD1-KERNEL-COMPAT-1"` |
| `selection` | int | `5845725453` |
| `source_head` | str | `^[0-9a-f]{40}$`, **== `unit["overlay_head"]`** |
| `status` | str | `"REQUALIFYING"` \| `"QUALIFIED"` |
| `mode` | str | `== unit["mode"]`; `"inert_control"` when `status=="REQUALIFYING"` |
| `host_identity` | dict | exactly `{system,machine,kernel_release,kernel_version,pointer_bytes,libc}` |
| `primitives` | list[str] | exactly the 9 `PRIMITIVES` names (order-insensitive, no dup) |

`host_identity` values for this grokbot-vm (exact equality, no ranges/prefix/regex):

```json
{"system":"Linux","machine":"x86_64","kernel_release":"6.12.94+",
 "kernel_version":"#1 SMP PREEMPT_DYNAMIC Mon Sep 14 19:13:20 UTC 2026",
 "pointer_bytes":8,"libc":["glibc","2.41"]}
```

**Chicken-and-egg (`source_head`):** the profile's `source_head` is bound to `unit["overlay_head"]`,
which `dd1_reservations.validate_unit` already forces to equal the driver's `--head <K1_HEAD>`. The
K2 driver passes the exact K1 candidate head as `--head`; the fixture writes `overlay_head = HEAD`;
`require` then checks `source_head == unit["overlay_head"]`. So the profile self-binds to the head it
is delivered under; no separate head field is introduced and no forward reference is needed.

**boot_id decision:** the packet's identity field list is exactly the six above, so `boot_id` is
**not** a profile identity field. If used at all it is a **K2 driver / K0-record precondition**
(the driver may compare the live `boot_id_sha256` against K0's
`dd8efe44b65f4435135f7d4c98b68c7a71f2e828c35838e52e20475a1cd96a0f` to detect a reboot before a
release), never a `kernel_qualification` field. K1 adds no boot_id anywhere.

## 5. Fail-closed rules (invariants)

- **Legacy / no-profile path is exactly strict B1:** Linux, x86_64, LP64, `release == "6.18.44"`,
  message `"unsupported host/ABI; no fallback"`, no fallback. 6.12.94+ with no profile fails closed.
- **`REQUALIFYING`** is accepted by `require` **only** for `mode == "inert_control"` under this
  selected operation; it is never native/engineering authority and is rejected in `native_bindings`.
- **`QUALIFIED`** is consumable by a later engineering unit **only** via the externally authenticated
  `kernel_qualification_disposition` role: schema `DD1-KERNEL-COMPAT-DISPOSITION-1`, owner selection
  `5845725453`, exact `profile_sha256`, exact `source_head`, exact `kernel_identity`,
  `independent_review=="APPROVE"`, `planner_acceptance=="ACCEPTED"`, `launch_admitted is True`,
  non-synthetic receipt authority, `context.kind=="empirical"`. K1/K2 cannot manufacture it, so
  **native admission stays rejected in this operation.**
- Existing COMPAT-2 / FIT / PREP / HOST-BRIDGE checks are **not** weakened; the qualification binding
  is additive (extra `expected` key only when a qualification is present) and the new native gate is
  an added precondition, never a relaxation.

## 6. Helper identity (no compiled change)

The pinned helper `supervisor` is compiled by `tools/dd1_linux/build_inert.py` from **only**
`supervisor.c`, `policy.c`, `isolate.c`, `capabilities.c` (verified: `build_inert.build()` command
list). It does **not** read `HELPER_SOURCES`. `HELPER_SOURCES` is a **Python controller source
closure** consumed at runtime by `prepare()` (`HELPER_SOURCES <= source_files` and the per-`.py`
"loaded controller source differs" equality check). Therefore adding
`res://tools/dd1_kernel_qualification.py` to `HELPER_SOURCES` is a source-closure change with **no**
effect on the compiled helper bytes. `PINNED_HELPER_SHA256` stays
`41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4`; baseline unchanged. **No
`HELPER_CHANGE_REQUIRED`.** (If any future edit did require compiled-helper source change, K1 stops
as `HELPER_CHANGE_REQUIRED` and this lock is amended first — the packet forbids inheriting
`dae7a481…`/`b22fdaba…` approval for changed bytes.)

Consequence for fixtures: the inert/compat2/fit fixtures build `source_files` from
`snap.HELPER_SOURCES | {…}`, so they automatically include the new `.py` (now 18 closure files) and
stage its loaded bytes. This is expected and Codex handles it in the fixtures/driver.

## 7. `tools/test_dd1_kernel_qualification.py` — test matrix

Pure logic: build a `unit` dict + an injected `host_facts` dict and call
`kernel_qualification.require(...)` / `.native_bindings(...)` directly (a tiny fake `context` /
`expected` for the native cases, mirroring the COMPAT-2 role/receipt shape). **No real kernel, no
subprocess, no engine, no fixture build** — must pass on macOS with plain `python3`. One named test
per packet requirement:

1. `test_legacy_no_profile_6_18_44_passes` — `q=None`, host release `6.18.44` → returns (no raise).
2. `test_legacy_no_profile_6_12_94_fails` — `q=None`, host release `6.12.94+` → raises
   `unsupported host/ABI; no fallback`.
3. `test_requalifying_inert_6_12_94_passes` — exact REQUALIFYING inert profile + 6.12.94+ host → ok.
4. `test_requalifying_rejected_for_engineering_native` — REQUALIFYING with `unit["mode"]=="engineering"`
   → `require` raises (mode mismatch) **and** `native_bindings` raises
   (`not native authority`).
5. `test_host_release_change_rejects` — profile identity `kernel_release` altered → raises.
6. `test_host_version_change_rejects` — `kernel_version` altered (e.g. different `uname -v`) → raises.
7. `test_host_machine_change_rejects` — `machine` != `x86_64` → raises.
8. `test_host_pointer_change_rejects` — `pointer_bytes` != 8 → raises.
9. `test_host_libc_change_rejects` — `libc` != `["glibc","2.41"]` → raises.
10. `test_wrong_selection_rejects`, `test_wrong_operation_rejects`, `test_wrong_source_head_rejects`
    — each single-field mutation raises.
11. `test_missing_primitive_rejects` / `test_extra_primitive_rejects` — primitive set off by one → raises.
12. `test_extra_field_rejects` — an extra top-level key → raises (`no extra fields`).
13. `test_missing_disposition_rejects_native` — QUALIFIED unit, native path, no
    `kernel_qualification_disposition` role → raises.
14. `test_synthetic_disposition_rejects_native` — disposition present but authority starts
    `synthetic:` / `context.kind != "empirical"` / receipt mismatch → raises.
15. `test_staged_controller_source_substitution_differs` — assert the loaded
    `dd1_kernel_qualification.py` bytes are what `prepare()`'s "loaded controller source differs"
    check compares against: stage a self-consistent but different copy in a temp `source_files`
    entry and confirm the digest differs from the loaded module bytes (pure byte assertion; no run).
16. `test_k2_plan_is_exactly_16_cases` — `kernel_compat_controls.plan()` returns 16 cases, no engine
    executable in any argv, every `cpu_cap <= 30`, `sum(cpu_cap) == 204 <= 240`, and
    `sum(cpu_cap) + BUILD_RESERVE(60) == 264 <= 300`.

Run command:
```bash
python3 -I -B -S tools/test_dd1_kernel_qualification.py
```
**Must still pass unchanged** (Codex re-runs before pushing): `tools/dd1_linux/test_backend.py`
selection where runnable, `tools/test_dd1_host_bridge.py`, `tools/test_dd1_source_repair.py`, and the
COMPAT-2/FIT matrices — the additive binding must not perturb accepted no-qualification units.

## 8. K2 driver — `tools/dd1_linux/kernel_compat_controls.py`

One driver, one case per process. It **reuses** existing `inert_cases`, `compat2_controls`,
`fit_controls`, `dd1_meter_entry._run_inert_unit`, and the `reservations`/`backend`/`supervisor`
paths — **no second sandbox, no alternate runner, no engine**.

**CLI (one case per process):**
```bash
python3 -I -B -S tools/dd1_linux/kernel_compat_controls.py \
  --head <K1_HEAD> --root /home/box/ops/glassvow --case <CASE_ID>
```

**Refusal preconditions (all must hold before any workload release `G`):** valid K0 record present;
owner selection `5845725453`; now `< 2026-09-27T11:02:00Z` deadline; whole-operation `flock -n LOCK`
held under `--root`; `--head` equals the exact K1 candidate head bound in the unit
(`unit["overlay_head"]`). Any failure → emit one JSON record and refuse **before** `G`.

**Pure `plan()` / case table** (unit-testable without running anything). `BUILD_RESERVE = 60`,
`HEADROOM = 36`, `RELEASE_TOTAL = 204`, `RELEASE_LIMIT = 240`, `AGGREGATE = 300`, exactly 16 rows:

| # | CASE_ID | fixture · mode/argv | cap s |
|---|---|---|---:|
| 1 | `KC01_STRICT_POSITIVE` | `inert.c` `positive` | 12 |
| 2 | `KC02_READONLY_ESCAPE` | `inert.c` `escape` | 12 |
| 3 | `KC03_CLONE3_FALLBACK` | `inert.c` `clone3` | 10 |
| 4 | `KC04_STRICT_THREAD_CEILING` | `inert.c` `thread_limit` | 12 |
| 5 | `KC05_CPU_EXHAUST` | `inert.c` `cpu` | 20 |
| 6 | `KC06_RAW_OVERWRITE` | `inert.c` `overwrites` | 12 |
| 7 | `KC07_SOCKET_DENY` | `inert.c` `socket` | 10 |
| 8 | `KC08_X32_ABI_KILL` | `inert.c` `abi` | 10 |
| 9 | `KC09_CONTROLLER_KILL` | `inert.c` `linger`, driver SIGKILL **controller** after LIVE/binding | 12 |
| 10 | `KC10_SUPERVISOR_KILL` | `inert.c` `linger`, driver SIGKILL **supervisor** | 12 |
| 11 | `KC11_COMPAT_COMBINED` | `compat2_inert.c` `combined` | 16 |
| 12 | `KC12_CPU_ABOVE_3` | `compat2_inert.c` `cpu-above-three` | 16 |
| 13 | `KC13_FIT_14_BOUNDARY` | `fit_inert.c` `sequential`, threads=14, births=13 | 16 |
| 14 | `KC14_FIT_NEXT_BIRTH_DENY` | `fit_inert.c` `sequential`, threads=14, births=14 | 16 |
| 15 | `KC15_IA32_REACHABILITY` | `inert.c` `ia32` | 8 |
| 16 | `KC16_NESTED_NAMESPACE_DENY` | `inert.c` `namespace` | 10 |

Sum of caps = **204 s** (`RELEASE_TOTAL`); `+60 s` build reserve = 264 s; `+36 s` headroom = 300 s
aggregate. No 17th release exists. `plan()` returns for each row: `case_id`, `source_file`, `mode`,
`argv_tokens`, `cpu_cap`, optional `threads`/`births` (KC13/KC14), optional `kill`
(`controller`/`supervisor`, KC09/KC10), and `special` (`ia32_reachability` for KC15). Each row's
`required_observation` is the packet's exact wording for that case.

**Ledger / release / CPU accounting** (driver enforces before `G`):
- A case counts **one release** when the controller has durably bound the case/process identities and
  sends `G`; if evidence cannot determine whether `G` was sent, count it as released.
- Compilation, hashing, pure Python tests, and any rejection **before** `G` do not consume the
  16-release count, but their process CPU still counts against the 300 s aggregate.
- Before each `G`, reserve that row's complete-process-tree CPU cap in the operation ledger. **No
  refund** after release, failure, signal, or interrupted capture.
- Per-case retained canonical evidence ≤ **8 MiB**; total retained operation evidence/output ≤
  **128 MiB**. Never delete the first failure to make a later run look clean.
- **No automatic reruns.** Any unexpected syscall result, missing intended guard, cleanup ambiguity,
  CPU/raw accounting mismatch, topology drift, helper/source identity drift, or required-primitive
  failure stops K2.

**Output:** one complete JSON record per case (bounded; secrets/endpoints excluded), including
before/after source identities, process identities + post-cleanup absence, streams, classification,
charge row, and the case's required observation.

**Stop outcomes:** `INCOMPATIBLE`, `INCONCLUSIVE`, `INCOMPATIBLE_BUILD` (preparation build /
supervisor-hash mismatch, zero releases), and `NOT_REACHABLE_ON_HOST` (KC15 only: if the host faults
first with SIGSEGV and zero forbidden effects, record `NOT_REACHABLE_ON_HOST` and make **no**
seccomp-arch claim; exit 0 / any effect ⇒ `INCOMPATIBLE`; SIGSYS at the seccomp arch guard ⇒ pass).

**K2-runtime clock (SUPERSEDED by AMENDMENT 1 / §10).** ~~At the frozen base the shared
reservation/backend clock is pinned to the expired N0 window; resolving it for K2 was recorded here
as a custodian/owner precondition and K1 was told not to touch `dd1_reservations.py`.~~ Per
#156/`5828245869`, the diagnosis stands but the resolution changes: the expired window is repaired
inside K1 by the operation-scoped inert reservation policy of **§10**, not deferred to a custodian.
The base facts remain true and are why §10 exists — `dd1_reservations.DEADLINE ==
"2026-09-24T17:54:40Z"`; `controller_limits` computes `wall = min(wall_seconds, DEADLINE -
time.time())` with `need(wall >= 3)`; `totals` enforces `first_engine_launch_utc == FIRST` /
`deadline_utc == DEADLINE` and `start <= now < expiry`, so a legacy-path run on 2026-09-25/26 raises
`outside recovery window` / `complete wall envelope needs two seconds of cleanup headroom` before any
release. §10 connects the already owner-selected K1 window to a K1-only synthetic inert
reservation/backend path so this exact operation runs, while the legacy default (`policy is None`)
keeps rejecting on the expired N0 clock unchanged.

## 9. Out of scope / non-claims

- No Godot/engine/import/parse/game run; K2 is **not** executed here; no helper/fixture compile or run.
- No change to P9/#108, accepted B1/D/C/H/FIT/PREP/COMPAT-2/HOST-BRIDGE semantics beyond the exact
  additive packet, `main`, or the overlay branch. No merge, release, or self-approval. **Amended by
  §10:** the "no change to `dd1_reservations.py`" clause is superseded — the module gains an internal
  `policy=None` seam whose `policy is None` path is byte-for-byte the legacy behaviour, so accepted
  semantics are still not changed; the FIRST/DEADLINE/OPERATION constants and expired N0 account
  remain untouched. No N0 window is extended, reset, revived, spent or reinterpreted.
- A K2 PASS would qualify **only** this exact grokbot-vm `6.12.94+` kernel identity for the amended
  enforcement contract; it is not Godot/native/N0/scientific qualification, and it does not create the
  `DD1-KERNEL-COMPAT-DISPOSITION-1` record that native admission still requires downstream.

## 10. AMENDMENT 1 — operation-scoped inert reservation policy (authority #156/`5828245869`)

The K2 clock repair. Scope is exactly the ruling; §10 governs where it conflicts with earlier text.

### 10.1 `tools/dd1_kernel_qualification.py` — selected-operation policy authority

In addition to the §2 host-qualification schema, define the exact inert reservation policy **in
code** (a module constant; no caller shapes it):

```python
INERT_RESERVATION_POLICY = {
    "operation": "DD1-KERNEL-COMPAT-1",
    "selection": 5845725453,
    "start_utc": "2026-09-26T11:02:00Z",
    "deadline_utc": "2026-09-27T11:02:00Z",
    "synthetic_only": True,
    "starts_cap": 16,             # starts / reserved-case ceiling
    "cpu_ns_cap": 300_000_000_000,  # aggregate CPU ceiling (300 s)
    "raw_bytes_cap": 134_217_728,   # aggregate retained raw ceiling (128 MiB)
    "per_invocation_cpu_seconds": 30,
    "executors": 1,
}
```

`inert_reservation_policy(unit)` returns **exactly** `INERT_RESERVATION_POLICY` (a fresh copy) only
when **all** hold, else fail closed via `r.need(...)`:
- `unit.get("mode") == "inert_control"`;
- `unit.get("operation") == "DD1-KERNEL-COMPAT-1"` — this is the **existing top-level `unit["operation"]`
  key** that `dd1_reservations.validate_unit` already reads (today `== OPERATION`; under `policy` it
  must be `"DD1-KERNEL-COMPAT-1"`, see §10.2);
- `unit["kernel_qualification"]["selection"] == 5845725453` and
  `unit["kernel_qualification"]["operation"] == "DD1-KERNEL-COMPAT-1"`;
- **the selected window lives in two new top-level unit keys** (the §2/§4 `kernel_qualification`
  profile is closed "no extra fields", so it cannot carry them): `unit["operation_start_utc"] ==
  "2026-09-26T11:02:00Z"` and `unit["operation_deadline_utc"] == "2026-09-27T11:02:00Z"`, each
  compared by **exact equality** to `INERT_RESERVATION_POLICY["start_utc"]` /
  `["deadline_utc"]`. Mismatch **or absence** of either key ⇒ fail closed. The returned deadline is
  always the code-pinned `INERT_RESERVATION_POLICY["deadline_utc"]`, never a copied caller field;
- `unit["kernel_qualification"]["status"] == "REQUALIFYING"` for the **exact K0 host identity**
  (`host_identity == QUALIFIED_IDENTITY`, the §2 grokbot-vm 6.12.94+ identity, exact equality).

`inert_reservation_policy` is **never** authority for `run_complete_unit` or any engineering/native
mode; it raises there (mode/operation/status mismatch). It performs no I/O and reads no clock.

### 10.2 `tools/dd1_reservations.py` — internal `policy=None` seam; legacy default byte-for-byte

**Unchanged:** `FIRST, DEADLINE = "2026-09-17T17:54:40Z", "2026-09-24T17:54:40Z"`,
`OPERATION = "DD1-N0-RECOVERY-1"`, `STARTS_CAP/CPU_CAP/RAW_CAP`, `M`, and the legacy
`DD1-N0-RECOVERY-1-ACCOUNT-1` schema/caps/history/recovery-minima/expired-window semantics.

Add an internal optional `policy=None` to the real existing signatures:
- `totals(account, now=None, policy=None)`
- `available(account, starts, cpu_ns, raw_bytes, now=None, policy=None)`
- `validate_unit(unit, command, *, head, receipt_sha, account_sha, source_reader, policy=None)`
- `reserve_and_run(account_path, unit, *, command, head, receipt_sha, source_reader,
  authority_check, output, runner, now=None, policy=None)` — threads `policy` into its internal
  `validate_unit` and `available` calls.

**`policy is None` ⇒ execute the existing legacy behaviour unchanged** (exact N0 schema/id/FIRST/
DEADLINE, history, recovery minima, `start <= now < expiry` expired-window rejection, the
`deadline_unix` from `DEADLINE` at the current `reserve_and_run` grant line). Byte-for-byte identical
output; no accepted no-qualification unit is perturbed.

**`policy is not None`** ⇒ enforce every ruling rule (`r.need(...)` fail-closed on each):
- `policy` must **equal** the exact code-pinned object returned by
  `dd1_kernel_qualification.inert_reservation_policy(unit)` — no caller-shaped deadline/range is
  accepted; a caller may pass a `policy` object but it is compared for equality against the pinned
  one and rejected if it differs.
- `account.get("synthetic") is True` and `unit.get("mode") == "inert_control"`.
- account schema `"DD1-KERNEL-COMPAT-1-SYNTHETIC-ACCOUNT-1"` with recovery `id ==
  "DD1-KERNEL-COMPAT-1"`, exact selection `5845725453`, `first_engine_launch_utc ==
  policy["start_utc"]`, `deadline_utc == policy["deadline_utc"]`, caps `starts_cap==16`,
  `cpu_ns_cap==300_000_000_000`, `raw_bytes_cap==134_217_728`, `per_invocation_cpu_seconds==30`,
  `executors==1`, and **no `historical` credit section** (its presence is rejected).
- `unit.get("operation") == "DD1-KERNEL-COMPAT-1"` (no scientific `M` and no old N0 account identity
  is borrowed); `validate_unit`'s operation check is parameterised so `policy` selects the
  KERNEL-COMPAT operation while `policy is None` still requires `OPERATION`/`M` exactly as today.
- **the two top-level window keys `unit["operation_start_utc"]` / `unit["operation_deadline_utc"]`**
  (§10.1) are read by `validate_unit` **only when `policy is not None`**, where they must be present
  and exactly equal to `policy["start_utc"]` / `policy["deadline_utc"]` (mismatch or absence ⇒ fail
  closed). Legacy safety: today's `validate_unit` reads named keys via `unit.get(...)` and has **no**
  closed unit-key set (verified — no `set(unit) == …` check), so when `policy is None` these keys are
  simply ignored, adding neither a new rejection nor a new acceptance path; the legacy unit remains
  byte-for-byte. They are metadata only — the enforced window still comes from the code-pinned
  `policy`, not from these keys.
- **real current UTC time** is used against `policy["start_utc"]`/`policy["deadline_utc"]`
  (`start <= now < deadline`); see the test-seam rule below.
- sum durable reservations against the **16 / 300 s / 128 MiB** operation caps; **no refund** after
  reservation.
- `UNIT-GRANT.deadline_unix` is taken from `policy["deadline_utc"]`, never from a caller field:
  `datetime.fromisoformat(policy["deadline_utc"].replace("Z","+00:00")).timestamp()` = **`1790506920`**
  (integer, `2026-09-27T11:02:00Z`).
- A pre-`G` failure may conservatively retain its durable reservation (the existing
  RESERVED→FAILED/INTERRUPTED no-refund path is unchanged). The separately recorded K2
  `workload_releases` counter still follows #156/`5827737668` (increment on known/uncertain `G`);
  conservative retention only reduces available work, never manufactures a 17th release.

**Exact new synthetic-account JSON shape** (`policy is not None`):
```json
{"schema": "DD1-KERNEL-COMPAT-1-SYNTHETIC-ACCOUNT-1", "synthetic": true,
 "recovery": {"id": "DD1-KERNEL-COMPAT-1", "selection": 5845725453,
   "starts_used": 0, "starts_cap": 16,
   "cpu_ns_used": 0, "cpu_ns_cap": 300000000000,
   "raw_bytes_used": 0, "raw_bytes_cap": 134217728,
   "executors": 1, "per_invocation_cpu_seconds": 30,
   "first_engine_launch_utc": "2026-09-26T11:02:00Z",
   "deadline_utc": "2026-09-27T11:02:00Z",
   "unit_reservations_v2": [],
   "events": [{"note": "SYNTHETIC K1 inert reservation account; no historical credit"}]}}
```
No `historical` key exists; `totals(..., policy=...)` computes `used` from `recovery` cap fields +
`unit_reservations_v2` sums only (no `historical` recovery-minima block).

**Test seam / "no caller clock in K2" (ruling test 10).** The existing `now=` parameter is retained
**for pure unit tests only** (§10.6 tests 3/4). It is unreachable in K2: `kernel_compat_controls.py`
and `dd1_meter_entry` never accept or forward `now`/deadline, so every K2 path uses
`datetime.now(timezone.utc)`; the `deadline_unix` and window bounds come from the code-pinned
`policy` (equal-checked against `inert_reservation_policy`), never a caller field; a non-pinned
`policy` is rejected at that equality check before any reservation or grant.

### 10.3 `tools/dd1_linux_backend.py::controller_limits(unit, deadline_utc=None)`

- `deadline_utc is None` ⇒ existing behaviour **exactly** (the `deadline = fromisoformat(r.DEADLINE)`
  line and `wall = min(float(unit["wall_seconds"]), deadline - time.time())` with `need(wall >= 3)`
  cleanup headroom).
- Non-null `deadline_utc` is accepted **only** for an exact `DD1-KERNEL-COMPAT-1` inert REQUALIFYING
  unit and must **equal** the code-pinned selected deadline
  `dd1_kernel_qualification.inert_reservation_policy(unit)["deadline_utc"]` (else `r.need` raises).
  Then `deadline = fromisoformat(deadline_utc)` and the same
  `wall = min(float(unit["wall_seconds"]), deadline - time.time())`, `need(wall >= 3)` headroom
  computation runs. No fake time, no extension, no native use. All other `controller_limits` work
  (single-thread guard, CPU baseline, rlimits, subreaper, itimer) is unchanged.

### 10.4 `tools/dd1_meter_entry.py`

- `_complete(command, unit, account_path, receipt_path, output, head, repo, check, lifetime,
  inert=False, reservation_policy=None)`: pass `reservation_policy` into
  `reservations.available(...)` (line 57) and `reservations.reserve_and_run(...)` (line 75) as
  `policy=reservation_policy`. `reservation_policy=None` ⇒ today's calls exactly.
- `_run_inert_unit(...)`: for an **exact** `DD1-KERNEL-COMPAT-1` REQUALIFYING unit, obtain the policy
  **only** from `dd1_kernel_qualification.inert_reservation_policy(unit)`, call
  `backend.controller_limits(unit, policy["deadline_utc"])`, and pass the **same** policy into
  `_complete(..., reservation_policy=policy)`. All **old** inert units (N0-operation
  `inert.c`/`compat2_inert.c`/`prep_inert.c`/`fit_inert.c` fixtures) keep `policy=None` and call
  `controller_limits(unit)` with no deadline — byte-for-byte today.
- `run_complete_unit` remains legacy/native and **must never select this policy**
  (`controller_limits(unit)`, `reservation_policy=None`); existing native/H/FIT/PREP/COMPAT admission
  is unchanged.

### 10.5 `tools/dd1_linux/kernel_compat_controls.py` (K2 driver — additions to §8)

Its disposable account is built with the **§10.2 synthetic-account schema/caps** (never the §8/legacy
`DD1-N0-RECOVERY-1-ACCOUNT-1` shape, never the published or historical N0 account). Into **every** K2
unit it binds: `unit["operation"] == "DD1-KERNEL-COMPAT-1"`, selection comment `5845725453`, the
selected window as **exactly the two top-level keys** `unit["operation_start_utc"] ==
"2026-09-26T11:02:00Z"` and `unit["operation_deadline_utc"] == "2026-09-27T11:02:00Z"` (§10.1/§10.2;
never inside the closed `kernel_qualification` profile), and the exact K0/K1 host qualification (§2
REQUALIFYING profile with `QUALIFIED_IDENTITY`). The separate whole-operation ledger remains authoritative for the
packet's 16-release / 300 s / 128 MiB accounting and K0/K2 custody (§8 unchanged).

### 10.6 `tools/test_dd1_kernel_qualification.py` — reservation-policy tests (added)

Pure logic on `python3`; build a synthetic account + unit and call `totals`/`available`/
`reserve_and_run`/`controller_limits` directly. In addition to the §7 kernel/profile tests and the
16-case `test_k2_plan_is_exactly_16_cases`, add the ruling's 12 (names as in the ruling):
1. `test_legacy_deadline_constant_unchanged` — `FIRST/DEADLINE/OPERATION` still the exact old values.
2. `test_legacy_after_expiry_rejects` — legacy N0-shaped path, `now` after 2026-09-24, rejects
   `outside recovery window` exactly as before.
3. `test_kernel_policy_before_selected_deadline_passes` — exact K1 synthetic account + pinned policy,
   `now` within 2026-09-26T11:02:00Z..2026-09-27T11:02:00Z, validates.
4. `test_kernel_policy_at_or_after_deadline_rejects` — same, `now >= 2026-09-27T11:02:00Z` rejects.
5. `test_kernel_policy_field_mismatch_rejects` — parametrised: wrong/missing `unit["operation_start_utc"]`
   / wrong/missing `unit["operation_deadline_utc"]` / wrong account `first_engine_launch_utc` or
   `deadline_utc` / wrong selection / operation / account schema / any cap / `synthetic!=True` each
   rejects.
6. `test_kernel_policy_for_old_inert_unit_rejects` — pinned policy for an old N0 inert unit rejects.
7. `test_kernel_policy_on_native_path_rejects_before_effect` — policy on a native/engineering unit
   rejects before any reservation/effect.
8. `test_grant_deadline_is_selected_deadline` — durable K1 reservation emits `deadline_unix ==
   1790506920` (`2026-09-27T11:02:00Z`).
9. `test_backend_default_vs_k1_clock` — `controller_limits(unit)` uses the old N0 deadline;
   `controller_limits(unit, policy["deadline_utc"])` uses the selected deadline with `wall >= 3`.
10. `test_no_caller_clock_reaches_k2_release` — no caller `now`/deadline/alternate policy reaches a
    K2 release (driver/meter never forward one; non-pinned policy rejected).
11. `test_operation_totals_16_300s_128mib_no_refund` — totals enforce 16 reservations, 300 s CPU and
    128 MiB raw, no refund after reservation.
12. `test_legacy_reservation_tests_unchanged` — existing legacy reservation expectations stay green
    with unchanged N0 semantics (guards `test_dd1_source_repair.py`/`test_backend.py`).

### 10.7 Helper / source-closure impact

This amendment **does** change the `HELPER_SOURCES` Python controller-closure bytes:
`tools/dd1_reservations.py`, `tools/dd1_linux_backend.py`, `tools/dd1_meter_entry.py`, and the new
`tools/dd1_kernel_qualification.py`. It does **not** change any compiled-helper input —
`supervisor.c`, `policy.c`, `isolate.c`, `capabilities.c/.h`, `policy.h`, and no `tools/dd1_linux/*.c
|*.h`. Therefore `PINNED_HELPER_SHA256` stays
`41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4`. Before K2, Tushar refreshes the
K1-candidate `HELPER_SOURCES` path/hash map (the Python closure changed from the K0 base bytes) and
rebuilds/reads back the **unchanged** helper once as already budgeted. A helper-hash mismatch is
`INCOMPATIBLE_BUILD`; **do not** re-pin to match an unexplained binary.

### 10.8 Invariants / non-claims / routing

- No N0 window extension, reset, revival, spend or reinterpretation; the expired
  `DD1-N0-RECOVERY-1` account and FIRST/DEADLINE/OPERATION constants stay immutable and continue
  rejecting on the legacy (`policy is None`) path.
- No new owner decision is needed for the §10 deadline repair itself (ruling "Owner decision"): it connects the
  current owner-selected K1 window (`5845725453`) to the K1-only synthetic inert reservation/backend
  path. It does not extend, reset, revive, spend or reinterpret the expired N0 window. The prior
  selection `5827591001` expired unused and is historical (AMENDMENT 2).
- **Routing resolved by #156/`5845725453`:** Grok Build (grok-4.7-xhigh) is the named K1 implementer
  for this operation only (owner implementer exception). Scope, budget, helper pin and the fresh
  isolated K4 reviewer are unchanged. Changing the implementer does not reduce K4 independence.
