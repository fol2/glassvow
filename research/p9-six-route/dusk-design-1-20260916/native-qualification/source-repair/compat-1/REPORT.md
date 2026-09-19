# DD1-B1-COMPAT-1 — source feasibility and real inert evidence

**Disposition: SOURCE_FEASIBILITY_STOP_ADDITIONAL_PRCTL_REFUSAL. No expected-refusal compatibility profile or import-promotion implementation is delivered or enabled.** The delivered outcome is the exact-source feasibility checker, connected harmless controls and combined remaining-obligation map. It is not compatibility acceptance, an observed Godot failure, native entry authority, or completion of the requested enabling implementation.

## Authority, input boundary and exact source

The direct owner selection is recorded/read back in #421/5744341425; the source task is recorded/read back in #542/5744342609. Work is source/inert only, on the retained overlay, with every workload child process still forbidden and the official engine unchanged. No engine/loader/version/import/parser/game run, live-account write, self-approval, review invocation, merge or release is permitted in this batch.

No new compatibility-packet attachment was mounted in this session. The actual posted related proposal is **DD1-ENTRY-COMPAT-1, #421/5744053732**, a distinct identifier. This report does not claim to have read the absent attachment or silently activate all terms of that proposal. The direct owner's narrower instruction governs. The posted proposal's explicit feasibility-first/stop rule is relevant: do not grow a one-off exception when a remaining fixed restriction prevents the useful endpoint. No extra syscall/process/thread permission or writable-original-source permission was inferred.

Resumed B=`289a6734f5ce75e85530db9abee4c44b583f040a`, tree `5ed066517de959a0b31491a5c59c703e8021da78`. New tested **source I=`7cc46c3e241f7195672d17309a179c2425097c32`, tree `ffe8f042391441d93f89b08a0b2d3edcd50c89fd`** adds only three focused test/inspection files under `tools/dd1_linux`. Later evidence/capsule publication does not modify these tested bytes. Current-main operating baseline remains `07b5aa9dec8436132a524511d5438c510e322070`; its loaded AGENTS/AI-SDLC/Godot rules are unchanged. No full repository checkout, imported project or native-context environment is claimed: the local tree is sparse owned tooling with exact H dependencies.

`SOURCE-MANIFEST.json` binds the new source, unchanged reservation/policy/isolation/supervisor inputs, real H modules, compiler products, libc/loader and static engine input. All three new source Git blobs were read back and matched local bytes at I. Original ZIP/engine identities remain those verified in `entry-1/receiving-20260919/`; the engine was read-only inspected, never executed or committed.

## Decisive source-to-control chain

The earlier popen/desktop-directory conflict remains accurate: fixed Godot initializes OS before processing `--version`, and the desktop query invokes piped `execute`/`popen`. A failed popen is handled by the engine's own ERR_CANT_OPEN -> `"."` fallback. That is not a fabricated desktop value, but it is also not zero-denial strict B1 success. A proposed optional-refusal classifier must preserve the actual refused operation and errno and cannot turn it into a successful spawn.

The complete path contains another restriction, beyond that one process refusal:

1. At fixed upstream `ed1daf0bf001b61586d9930840f2f1394092c079`, `main/main.cpp` initializes the **editor/project-manager** worker pool with `init(-1, 0.75)`. The project setting controlling non-editor worker count is not used in that branch. Fresh import preparation uses the editor path; it is not a simple non-editor version check.
2. `WorkerThreadPool::_thread_function` calls `Thread::set_name` at worker entry. The Linux POSIX callback uses `pthread_setname_np(pthread_self(), ...)`. The exact official ELF imports that function.
3. Static disassembly of the same pinned libc shows its self-thread naming branch invokes `prctl` with `PR_SET_NAME` (15). The accepted strict policy has no such permission: syscall **157** is denied, separately from non-thread `clone` syscall **56**.
4. The real harmless matched controls confirm the difference. Creating/joining an unnamed thread passes strict B1. Naming the same allowed thread returns **EOPNOTSUPP (95)**, records one denied syscall 157 and makes strict B1 fail even though the fixture recovers, saves exact bytes and exits 0. Combining failed popen and naming produces two denials; one optional process-refusal classification could not remove the other.

See immutable upstream paths and blobs in `SOURCE-MANIFEST.json`, especially `main/main.cpp` (2030–2220), `core/object/worker_thread_pool.cpp` (175–200), `drivers/unix/thread_posix.cpp`, and the bounded libc disassembly in the joined `EVIDENCE.json.xz.part01` + `part02` payload. `get_default_thread_pool_size` delegates to processor count; the core implementation uses `hardware_concurrency`. The harmless program's `get_nprocs()` returned 1 inside this actual isolated one-CPU view. That is a libc observation, not a measurement of total engine threads. No vector capacity or affinity was relabelled as an engine lifetime-thread bound.

**Scope of inference:** this identifies an unadmitted named-worker/editor-import path under the fixed rule, not a universal impossibility for every engine configuration or every authentic pre-imported project. No complete pre-imported alternative with verified lineage was supplied/established. Zeroing a non-editor setting does not close the editor branch, other named pools or required functionality. No setting was changed or functionality silently disabled. A version banner alone would not qualify the intended fixture endpoint.

The separate thread-naming refusal is not the single optional process-creation refusal selected here. Allowing it, reclassifying it as expected, suppressing it, patching Godot or changing strict success would require a different explicit compatibility disposition. None was done. The author therefore stopped before an enabling policy patch rather than implement a misleading partial exception.

## Actual final matrix — eight controls, not eight engine starts

The unchanged strict C supervisor was rebuilt from its exact accepted source and matched its pin: **823744 bytes, SHA256 `dae7a481fd0d6c25f093c38056673a6039f98d899e816a65953537a54d00c7ce`**. The new dynamically linked harmless fixture is 17360 bytes, SHA256 `599e9b799b6674a8d78f37a9539082655a6ca7e3c0a38167babbc6ae3283ff5b`. libc/loader match the receiving/B1 pins. Compiler command lines, exit codes and complete streams are in BUILD.json and the evidence payload.

The checker creates a fresh explicitly synthetic account per control outside the repository. It uses the real unchanged `reserve_and_run`, executor lease and durable `attach_processes` before ACK, plus the byte-pinned sealed strict supervisor and actual kernel isolation/filter. It does **not** invoke `run_complete_unit`, `Prepared`, empirical H authentication or an optional-refusal profile. No arbitrary engine/runner/account argument is exposed by this harness. Internal synthetic authority and staging callbacks are disclosed; they are not native permission and OS behavior is not mocked.

| Harmless control | Workload result | Strict supervisor observation |
|---|---|---|
| scalar I/O + fsync/atomic save/readback | exit 0 | PASS; no denial |
| same plus unnamed thread | exit 0 | PASS; no denial; two lifetime threads including main |
| one failed popen | NULL, errno 95, exact save, exit 0 | FAIL; one denial, last syscall 56 |
| two failed popens | both NULL/95, exact save, exit 0 | FAIL; two denials, last syscall 56 |
| unrelated posix_spawn | error 95, PID remains -1, exact save, exit 0 | FAIL; one denial, last syscall 56 |
| named thread | name result 95, exact save, exit 0 | FAIL; one denial, last syscall 157 |
| popen then named thread | both errors 95, exact save, exit 0 | FAIL; two denials, last syscall 157 |
| sleeping workload, actual supervisor SIGKILL after save | workload adopted and reaped with SIGKILL | no fabricated final supervisor report; FAILED charge retained |

The **test assertions** pass for all eight; that does not make the six adverse strict runs successful. Both final checker commands exit 0 with empty checker stderr. Each normal workload exits 0, allowing syscall refusal to be distinguished from an unrelated early crash. The fixture's stderr is retained, not discarded. Clone3's ENOSYS fallback remains reported separately and is not treated as successful process creation or a new exception.

Every final case verifies before-child reservation, durable identities before ACK, exact saved bytes, no descendant marker, kernel absence of recorded supervisor/workload after cleanup and rejection of the same unit before any second spawn. Full synthetic reservations remain **one start, 11 CPU seconds and 8 MiB**, including failure/kill. The real accounts are never read into these tests. The raw scalar allowance is 131072 bytes; normal cases reserve 12414–12498 bytes before writes. These are particular test envelopes, not qualification of 300-second engine units or complete engine output.

The unrelated-spawn case and popen case both have the same one-denial/last-56 summary. This is a concrete falsifier for **count-only attribution**, not proof that every more informative attribution mechanism is impossible. No trustworthy exact startup-stage/call signature classifier has been implemented or tested, and stdout is never used to authenticate one.

### Failed development attempts are retained

The joined evidence payload also contains **17 pre-final helper attempts and their exact source versions**, separately from the final eight. The first eight were an incorrectly continuing collector: a requested workload hard CPU limit of 10 could not raise the inherited controller hard limit of 3, so intended guards were not reached. The collector's success exit was not proof; the kill target was not reached either. A subsequent one-case matched positive exposed a test-staging mistake: the loader lacked executable permission (fixture not entered, exit 123). The harness was corrected to stop on early failure, use the supported 11-second partition and executable loader, then eight preliminary controls reached the intended operations. Finally the get_nprocs observation and explicit expected-denial/cleanup/strict-verdict assertions were added, producing the eight final controls at I.

None of these early records is hidden, claimed as a passing guard test, or charged to the live recovery remainder. The total is **25 harmless helper attempts**, not 25 engine launches. The inherited-limit observation also means these controls do not establish larger unit-envelope feasibility; that remains an explicit engineering limit rather than a quiet B1 repair.

## Real unchanged H and prospective binding boundary

The actual accepted `evidence_boundary.py` and `reference_kernel.py` were materialized, Git-blob verified and imported without mocks. Six targeted checks cover missing external manifest, structurally consistent **synthetic** execution-demand/owner-selection roles, missing role, wrong locator, altered demand bytes and rejection when only the context is relabelled empirical. All expected guards were reached; H source remained unchanged. The role-shape positive is not even a DD1 complete-unit demand and carries no usable argv, reservation or grant.

This demonstrates real H binding mechanics only. H assumes its expected identities/issuers are already authenticated out of band; these tests do not provide that authority. Prospective native entry would require a real external binding of the exact complete unit, source head, engine/libc/helper/source, stage/argv/output, current account/receipt and applicable owner selection/profile. `verify_bindings` is the relevant pre-output boundary; no future P_v, extraction outcome or post-output receipt conjunction is invented as a circular prerequisite. The old H epoch and ALLOCATION are not revived as spending authority.

## Combined remaining obligations and dormant demand

| Obligation | This artifact / exact remaining gap |
|---|---|
| Keep workload descendants forbidden and strict zero-denial default | Unchanged policy/supervisor. Real popen/spawn refusals and matched positives demonstrated. No permissive fallback. |
| One externally bound expected-refusal treatment | **Not implemented.** Counts alone are insufficient; the named-worker refusal is separately outside the selected exception. No profile misuse/tampering acceptance tests are claimed for an absent profile. |
| Original engine and original source immutable | Engine hash unchanged, read-only static inspection only. No gameplay/Pilot/GDScript or B1 bytes edited. |
| Imports, UID/class metadata and sealed promotion | **Not implemented or engine-tested.** Existing `/source` stays immutable. Genuine generated `.godot`/import/UID/class metadata needs exact lineage and declared generated paths, not a blanket writable source, handmade cache or unqualified Mac cache. |
| Separate preparation-output phase | The posted proposal suggests immutable originals -> disposable derived output -> validation -> sealed runtime input. That plan is not silently activated from a missing packet. No generated-output allow-list, promotion validator or mutable-runtime fallback is claimed. A fresh editor import still reaches the named-worker conflict. Failed/mismatched preparation must never promote. |
| Full engine runtime/dlopen/content closure | Prior declared ELF closure is preserved, not upgraded to plugin/font/data/import or whole-project qualification. Optional refusal does not resolve missing runtime inputs. |
| All lifetime threads and resources | Named-worker conflict is source-linked and inert-reproduced; complete engine pool/threads and required functionality remain unqualified. No one-core or pool-capacity shortcut. Larger CPU envelopes are not proved by these tests. |
| H prospective native demand | Real H negative and synthetic role-shape mechanics tested; genuine empirical demand remains absent, with no fake issuer or future outcomes. |
| Release/native transition | Not admitted; no engine call or live reservation may follow this author artifact. No new reviewer/N0 acceptance gate is commissioned by the author. |

The existing later engine-entry ceiling remains at most min(8, actual lawful remainder), shared across continuations. With one identity process and the unchanged fixture's one engine plus two contained starts, **at most four starts** would remain for all import/parser/other engine prerequisites. `check_scripts.sh` runs one engine per selected script. The actual relevant count cannot be replaced by guessed affordability or an invented exact deficit.

The receiving payload lower bound is 149655752 bytes per fresh engine/runtime snapshot before the full project, path metadata, helper, generated inputs, raw writes and retained copies. Six such copies alone are 897934512 bytes. This is conditional accounting, not a complete one-GiB admission envelope. Setup, rewrites and deleted/compressed copies are not free; no new live reservation was made. A qualifying implementation and scoped disposition would still need complete raw/CPU/start/wall demands before a later run, under the unchanged deadline.

## Publication, accounts and exclusions

the joined `EVIDENCE.json.xz.part01` + `part02` payload is a lossless UTF-8 JSON record transport, not an executable archive. TRANSPORT.json gives decoded/compressed hashes, sizes and decode command. It includes all final fixture/helper streams, actual grants/accounts, identities, kill/reap observations, builds, bounded libc disassembly, precisely labelled selected ELF symbols and failed development records/source snapshots. TESTS.log preserves the final outer command streams. RESULTS.json is the machine-readable disposition and matrix; it explicitly says the enabling profile and promotion implementation are absent.

Recovery ACCOUNT retains blob `8b7e4e6367ad4bc366c04b930ef4fc3810e2a900`: reported 2040/2048 starts, CPU 398617197992/14400000000000 ns, raw 893139/1073741824 bytes. New live commitments/starts/writes: **0**. Historical 1277/8192, unspendable 6915, attempt 1/1 and UNKNOWNs remain. Deadline remains **2026-09-24T17:54:40Z**. Published-ledger identity is not a retrospective completeness certification or knowledge of another executor's private state.

Accepted strict B1 E=`3bb4205caf55f882a4507272445997ae448fcd7b` and implementation `efdac6a25dd0436de5ef2c52136b5f8ce71c4da7`, D/C/H, H ALLOCATION/kernel/#547, the official engine, driver/provenance/Pilot/Dawn/save repairs, thresholds and closed/protected results are preserved. The old 23+12 B1 suite and H numerical suite were not rerun. No ordinary acquisition, P0/P5, N1/N2, alpha/#548, self-approval, production PR/CI, main edit, merge, closure or release. Certificates remain 0/3.

This source/inert feasibility stop is not the requested enabling implementation finished. The next question is whether an exact compatibility contract addresses the additional named-worker refusal and full preparation path without silently broadening the current exception. The author has not made that further selection. One exact-head #156 handoff holds the final publication head/tree and readback; no self-referential evidence-commit loop is needed.
