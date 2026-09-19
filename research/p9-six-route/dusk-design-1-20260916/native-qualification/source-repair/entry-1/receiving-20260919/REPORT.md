# DD1-LINUX-ENTRY-1 — receiving-host admission continuation

**Outcome: BLOCKED_BEFORE_ENGINE_ENTRY — static startup/process-topology incompatibility.** Transport is resolved and the ELF's declared shared-library/symbol-version closure is staged. No Godot, loader, import, parse, fixture, helper workload or ordinary acquisition ran. This is not an observed engine failure, ENTRY_VERIFIED, FIXTURE_VERIFIED, N0 acceptance or a new B1 verdict.

The owner continuation resumes #156/5736166433 under the already-selected #421/5734400738 / selection record 5735810042. The later transport-only routing comments 5738770541 and 5738961097 are satisfied by actual mounted-byte verification, not by the prior chat claims. No new grant, allowance, account or deadline was created. Operating main remains `07b5aa9dec8436132a524511d5438c510e322070`; the existing AGENTS/AI-SDLC/Godot contract at that unchanged baseline governs. Resumed overlay: `f1acc8a16af28c19720b67c68dac049d1444b9af`; accepted B1 source/evidence remains `3bb4205caf55f882a4507272445997ae448fcd7b`.

## Completed receiving work

The actual mounted ZIP is 77,860,424 bytes, SHA256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`. Its unique member is 146,414,384 bytes, SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. Python recomputed both digests, checked ZIP decompression/CRC and inspected ELF64/little-endian/EM_X86_64 headers. Both match TRANSFER.json. The original archive is unchanged; the extracted copy remains mode 0400, not an executed program. The receiving host reports Linux 6.18.44 x86_64 LP64, glibc 2.41. BYTE-VERIFICATION.json was published/read back as the first save of this continuation.

`inspect_runtime.py` read, but did not execute, the ELF and recursively resolved all six DT_NEEDED names: librt.so.1, libpthread.so.0, libdl.so.2, libm.so.6, libc.so.6 and ld-linux-x86-64.so.2. The interpreter is `/lib64/ld-linux-x86-64.so.2`. All required ELF symbol-version names are provided by the staged dependencies. RUNTIME-CLOSURE.json contains paths, complete required/defined version sets, byte sizes and independently computed hashes. libc and the loader match the corresponding accepted B1 BUILD.json hashes. The seven payload files total 149,655,752 bytes. Staging used private regular read-only copies, not a source mount or replacement of a provisioned toolchain.

This is **DT_NEEDED/version closure only**, not complete startup/plugin/dlopen/data-file closure. In particular, the upstream Linux OS constructor has optional fontconfig loading; this work neither qualified it nor silently disabled it. Preparation copies are disclosed, not treated as free future sandbox setup: any later admitted unit would have to include all its source/runtime/control copies in the same complete raw envelope. No recovery reservation is issued here.

## Decisive static incompatibility

The exact upstream 4.7.2 source is `ed1daf0bf001b61586d9930840f2f1394092c079`. That full commit string is also present in the verified ELF at file offset 82,952,520; `4.7.2.stable.official` and `xdg-user-dir` are present too. String presence supports artifact identification, not execution or control-flow proof. The source trace is:

1. `platform/linuxbsd/godot_linuxbsd.cpp` calls `Main::setup`; it has no early `--version` shortcut.
2. `Main::setup` calls `OS::initialize()` before the argument loop. The `--version` branch occurs later in that loop.
3. `OS_LinuxBSD::initialize` initializes core services and assigns its initially empty desktop cache from `get_system_dir(SYSTEM_DIR_DESKTOP)`.
4. `get_system_dir` calls `execute("xdg-user-dir", ..., &pipe)` unless that cache is already populated. The first initialization does not have such a populated cache. No command-line or XDG environment branch in this function skips the call.
5. The inherited `OS_Unix::execute` with a non-null pipe calls `popen(..., "r")`. The verified ELF imports `popen@GLIBC_2.2.5`. Static disassembly of the exact staged libc resolves popen/_IO_popen at 0x80270, its call to _IO_proc_open at 0x7fe60, and that function's call at 0x80086 to posix_spawn at 0xf8de0. These are inspected instructions, not executed calls.
6. Accepted B1 admits only its first workload exec and tightly constrained same-process NPTL thread clones. Ordinary child-process creation does not satisfy that clone predicate; alternate fork/vfork paths are denied. clone3 ENOSYS remains its documented no-process-created fallback, not permission for a process clone. `supervisor.c` requires `denied == 0` for success.

**Inference from the pinned source and policy:** the prescribed fixed-engine entry path cannot produce a successful B1 admission with its current no-descendant rule. Even if Godot handles a failed popen and eventually prints a version/returns zero, the denied operation is a B1 failure and the operation's stop condition applies. Earlier independent startup failures could occur; this record does not pretend to predict the first observed syscall or a runtime exit code.

Adding a shell/xdg-user-dir binary would not remove the prohibited process creation. `--headless`, `--version`, or later project/thread settings cannot bypass initialization that precedes parsing. Changing the engine, preloading a substitute, patching the cache, allowing descendants, or changing B1's success policy would violate the fixed operation. None was done. A known incompatible setup call was not launched merely to spend a start.

## Graph disposition and remaining work

Stage 0 completed the receiving verification, static linked-library closure and useful entry diagnosis, then took **BLOCKED_STATIC_PROCESS_TOPOLOGY**. Stages 1 and 2 are **NOT_ENTERED**. Stage 3 is this evidence/account publication and single #156 exact-head handoff/readback. The static finding is not relabelled an observed INCOMPATIBLE engine run.

No usable stage-1 release manifest, prospective execution demand, grant, or reservation was fabricated. The desired version-check shape is not launch permission. Accepted H's previous real import/missing-manifest-refusal evidence retains its scope; no mock, permissive callback or constructed positive context was promoted into native authority. Real prospective H-bound demand remains unissued because no conforming entry stage was admitted.

The project import/cache layout, complete source/content/dlopen closure, bounded total lifetime threads and source/venue prerequisites remain unqualified. The existing read-only `/source` versus `res://.godot` issue remains; no .godot cache, import sidecar, Mac cache or writable source alias was manufactured. The pinned supervisor was not rebuilt or re-executed: doing so cannot resolve the source-level process conflict and would not add relevant compatibility evidence. The unchanged two-combat fixture remains unexecuted. Its three-start count excludes other prerequisites; no complete-stage affordability is claimed.

Continuing execution would require an explicit compatibility/scope decision outside this graph, not another transport attempt, repeated grant or automatic top-up. This author did not make that decision or change accepted B1/D/C/H.

## Evidence and accounting

`DECISIVE-STATIC-TOOLS.json.xz` losslessly preserves complete stdout/stderr and exit codes of the seven listed bounded readelf/objdump commands. TRANSPORT.json gives compressed/decoded hashes. All seven exited zero with empty stderr; these are static-tool results, **not seven engine starts or tests of engine runtime behavior**. `inspect_runtime.py` and its actual RUNTIME-CLOSURE.json result make the recursive library/version check reproducible. Redundant exploratory symbol dumps are not claimed as delivered decisive evidence. The initial symbolic objdump query returned only headings; it is not counted as proof; numeric-address queries supplied the stated disassembly.

Recovery ACCOUNT at the publication checkpoint is unchanged blob `8b7e4e6367ad4bc366c04b930ef4fc3810e2a900`, reported 2040/2048 starts, 398617197992/14400000000000 CPU ns, and 893139/1073741824 raw bytes. No new unit reservation, live-account write, engine start or contained start occurred. This is exact published-ledger identity, not retrospective certification of missing historical metering or another executor's private state. Historical 1277/8192, unspendable 6915, attempt 1/1 and UNKNOWNs are unchanged. Deadline remains 2026-09-24T17:54:40Z. Eight is the shared conditional ceiling across this operation, not eight per continuation.

Only receiving evidence, its task-local inspector and the existing capsule are changed. Accepted B1, D/C/H, H ALLOCATION/kernel, #547, driver/Pilot/provenance/Dawn/save laws and older closed/protected evidence remain unchanged. No ordinary acquisition, P0/P5 search, N1/N2, alpha/#548, reviewer invocation, self-approval, production PR/CI, main edit, merge, closure or release. Certificates remain 0/3.
