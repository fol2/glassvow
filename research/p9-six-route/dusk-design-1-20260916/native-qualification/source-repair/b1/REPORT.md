# #542 B1 — connected Linux backend and real inert evidence

**Author disposition: B1 source implemented and inert-verified on the explicitly supported host. Godot/game/native qualification remains UNVERIFIED. No independent review, N0 acceptance or launch authority is claimed.**

Authority: [B1 batch 5723004762](https://github.com/fol2/glassvow/issues/542#issuecomment-5723004762), continuing batch 5721191528; [planner primitive probe 5722990084](https://github.com/fol2/glassvow/issues/542#issuecomment-5722990084). The probe's allow-most filter was not adopted. This implementation closes the allowed topology and syscall surface and connects them to the existing reservation transaction.

## Exact source and proof

Implementation I: `efdac6a25dd0436de5ef2c52136b5f8ce71c4da7`, tree `19781b453689203eb3d6696a247e3d5a08ca8d3a`. Actual resumed checkpoint: `5d10f2182f55cc2ee44b90474c823b0c312eaee7` (the retained capsule update after `cb72d1042086d9688d23eecdbfa61e10ce9acea4`). Earlier implementation, evidence and handoff #156/5722807792 remain historical, not attributed to this run. Current-main M remains `07b5aa9dec8436132a524511d5438c510e322070`; active AGENTS/AI-SDLC were refreshed separately from frozen science.

`SOURCE-RESULTS.json` records 22 exact local/GitHub source or dependency blobs, SHA256s, sizes, unchanged after the final tests. It includes actual commands, environment, timestamps, exit codes and complete stdout/stderr. `BUILD.json` records the three successful harmless C compilations, empty compiler diagnostics, executable/loader/libc identities and host. `TESTS.log` is a readable copy of the final test streams. Evidence-only commits after I do not imply a retest of changed implementation.

**Final results: 23 retained Python tests PASS, exit 0; 12 connected B1 test methods PASS, exit 0.** The B1 set stores **64 controls**, not 64 native launches or 64 independent certificates. Some controls are in-process authority/ancestry checks; real workload controls contain their process, output and reservation records. No Godot executable, parser, import, engine version command, game, capture or profile was run. The retained H adapter tests explicitly use mocks, and GDScript assertions inspect source shape only; neither is new H/native integration proof.

## B1.1 — process, input and source boundary

`tools/dd1_linux_snapshot.py:prepare/read_regular/elf` loads the demanded bytes through component-wise `openat`/NOFOLLOW, rejects symlinks and multiply linked files, checks exact digests and safe destinations, and validates ELF64 x86-64 executable/interpreter/NEEDED closure. There is no `ldd`, host-library fallback or later reopening of original source for execution. Missing dependencies or different executable/helper/source/demand/receipt/output identities reject. Source/content closure must be supplied by the host-authenticated demand; this author has not qualified an engine's complete closure.

`tools/dd1_linux_backend.py:Prepared` copies those retained bytes into a fresh private root and readbacks them. `tools/dd1_linux/isolate.c` establishes private user/mount/network namespaces, a read-only NOSUID/NODEV root, a separately writable NOEXEC output mount and chroot, with no proc/sys/dev mount or alias to the original source tree. Setup capabilities, bounding capabilities and root-exec privileges are dropped and checked; NO_NEW_PRIVS remains set. All inherited descriptors except the explicitly selected streams/bootstrap socket are closed. The bootstrap socket and notification-listener descriptor close before workload exec. A fixed minimal environment removes preload, credentials and ambient paths. The exact pre-reservation account is a read-only copied input for the existing GDScript reader, never a writable account mount.

The static supervisor's digest is a code-pinned constant, not merely a caller-selected hash. It executes from a sealed memfd. The two test workload digests are also pinned: private inert entry cannot substitute a game or arbitrary executable by naming it `/workload` and supplying a self-hash.

`policy.c:dd1_listener/dd1_notify` permits one initial trusted-bootstrap exec. All later exec/execveat, fork/vfork, non-NPTL clone and namespace creation are denied. Exactly one workload process may create at most four lifetime thread births including its initial thread, using the permitted scalar NPTL clone flags. Failed births are not refunded. clone3 is explicitly denied with ENOSYS to permit glibc's scalar fallback; its counter is retained. No mutable clone_args/iovec/path is inspected and then approved with CONTINUE. Unknown syscalls are denied and make the unit unsuccessful rather than silently losing output.

Real positives include static and dynamically linked three-thread save workloads. The escape control changes and renames the original source after the release record, supplies a stale inherited fd 64, and attempts source writes/rename/hardlink, original-path/symlink and traversal escapes. The child reads the original immutable copy, cannot write the original or source mount, and cannot find fd 64. Changed binary/helper, arbitrary static helper, non-fixture workload, symlink/hardlink/traversal input, wrong ELF machine, missing loader/libc and output alias controls reject at their named guards.

This is a workload isolation boundary under a trusted host/controller/kernel, not protection against a malicious host administrator or a second writer modifying the private staging directory. The task's sole-writer constraint remains material.

## B1.2 — complete CPU and lifetime partition

`controller_limits` requires a fresh dedicated single-threaded Python controller; the recorded invocations use `python -I -S`. CPU baseline must be below one second. Its process-total hard CPU limit is three seconds. The supervisor gets two; the workload including bootstrap and all allowed threads gets `B - 10`, where the complete pre-reserved B is at least 11 and at most 300 CPU seconds. Workload and supervisor are pinned to one allowed CPU; workload affinity/scheduler/priority and resource-limit mutation are denied.

The conservative partition allocates one second of enforcement granularity to each of the three participants: `(3+1) + (2+1) + ((B-10)+1) = B-2`, leaving two further seconds of headroom. RLIMIT_CPU is a process-total limit including its threads, not a separate budget per unrestricted descendant. This is not a claim of an instantaneous cutoff or a portable kernel timing theorem. Unsupported hosts are rejected; the actual controlled host and observations are pinned below. Workload/supervisor CPU is measured with wait4/getrusage; controller usage is recorded at reporting. Conservative hard ceilings, not post-exit observations, authorize the complete reservation.

A declared wall envelope of at least three seconds includes setup and cleanup. A fatal controller deadline stays armed; the workload/supervisor soft deadline leaves two seconds within that envelope for cleanup. The recovery deadline also limits the envelope. Stuck reads, sleeping workloads and a stopped supervisor cannot continue indefinitely merely because they burn little CPU.

The controller is a subreaper. Controller-to-supervisor and supervisor-to-workload parent-death KILL signals include parent-identity race checks; workload setup re-establishes its death guard after credential changes. Before releasing execution, the controller durably appends PID/start-tick/boot identities to the existing RESERVED row (`B1-ACK-1`); the supervisor and workload await the ACK. The executor lease survives in the supervisor until cleanup. A dead controller or supervisor cannot grant a second live executor through a normal lock-release shortcut: unresolved backend reservations block, and explicit stale reconciliation requires the exclusive lease plus recorded PID absence. Reconciliation changes no starts/CPU/raw totals and never reissues the same unit.

Actual final three-thread CPU control: SIGKILL with workload CPU **1.035275 s**, supervisor CPU **0.005111 s** on a one-second workload hard limit within an eleven-second reserved unit. The blocked-I/O control was killed on the wall timer. Real supervisor TERM/KILL/STOP and controller TERM/KILL controls verified recorded PID absence and stable output after cleanup. A killed controller retained a RESERVED charge; a fresh unit was refused pending cleanup evidence. Explicit synthetic reconciliation retained starts 2041, CPU 409617197992 ns and raw 9281747 bytes with `launch_permitted=false`. Missing final supervisor reporting is retained as missing, not fabricated CPU/output zeros.

## B1.3 — cumulative raw emissions before effect

Every permitted workload write/pwrite64 reserves the scalar requested length in the single supervisor before the kernel can continue the syscall. Requests from competing threads share that monotone counter. Partial/failed writes can be overcounted; they cannot create credit. truncate/ftruncate reserve the full requested length conservatively. Creating/mutating filesystem names reserves conservative path metadata (4096 or 8192 bytes); unlinking, truncating, overwriting, moving and compression never refund prior emission. The isolated filesystem, not a raced user-space pathname check, controls which destinations exist.

Vectored/positional-vector writes, sendfile/splice/copy_file_range, shared file mappings including initially read-only shared mappings later subject to mprotect, AIO/io_uring, device creation, sockets/network and unknown channels are denied before effect. Private COW mappings and subsequent mprotect cannot write back to a file. Future unsupported engine syscalls must produce an unsupported/failed unit, not an apparent native success.

The existing transaction now reserves a conservative trusted-metadata envelope before releasing any workload: account/grant/result copies, control records and bounded diagnostics; snapshot payload copies and path metadata plus the sealed helper have a separate explicitly fitted setup charge; only the demanded remainder reaches the workload. The supervisor emits bounded fixed-format diagnostics, not reflected workload data. stdout/stderr and all permitted file/save/trace writes use the same before-write allowance. Directory occupancy and RLIMIT_FSIZE are not the cumulative accounting mechanism. Post-run evidence transport is an inert publication operation, not an allowance adjustment.

Both positive builds created thread files, wrote stdout/stderr, stored and fsynced `save.tmp`, atomically renamed it to `save.json` and verified exact `{"v":2}\n` bytes. Each reserved 20522 of 65536 workload raw bytes including conservative metadata. Overwrite and competing-thread controls reached exactly 65536 reserved bytes and then received EFBIG at pwrite64 (syscall 18), despite final data occupancy of only 1024 or 2048 bytes respectively. The complete unit was failed even when the adverse fixture handled errno and exited zero.

Each named alternative-output/process control records its actual denied syscall number, stdout/stderr and exit/signal. x32 syscall-number control received SIGSYS. **The int-0x80 control received host SIGSEGV before the intended seccomp architecture branch. It is not counted as execution evidence of that branch.** The non-x86-64 ELF guard and BPF architecture branch remain separate source/host limitations; no other ABI is supported.

## B1.4 — existing entry and authority, not a demonstration-only runner

Public `run_metered` delegates to `run_complete_unit`; it cannot construct native authority from CLI fields, synthetic receipts, a test clock or a permissive callback. The native entry uses H's existing externally authenticated context/role binding for the exact `execution_demand` bytes and artifact head, then the existing recovery receipt checks. The demand also binds an immutable Git ancestry chain verified in-process: no unaccounted Git subprocess is launched inside the unit. This is content-addressed linkage, not a new issuer-authentication scheme.

Both native and private inert paths select the concrete `Prepared` implementation and existing `reserve_and_run` transaction. Starts/CPU/raw reservation is durable before helper/workload release, output must be new, replay and concurrent execution reject, and failure never refunds. The private test path requires a synthetic account outside the repository, a bound inert-only receipt and one of the two pinned harmless fixture binaries. The public native path cannot select it. The original callback seam remains only an internal transaction-test seam; the native public entry explicitly refuses such callbacks.

Real connected controls run through this implementation without OS mocks. Public missing-authority rejection, actual concurrent lock rejection, duplicate unit, exhausted starts/CPU/raw, altered identities and unresolved stale process records are all distinct recorded guards. Full empirical H authority integration and game execution are intentionally not performed here. There is no unconditional backend-blocked stub left, but a missing future native authority or unsupported venue still refuses correctly.

## Host, reproducibility and evidence access

Supported/tested scope: Linux **6.18.44**, x86_64 LP64, glibc **2.41**, recorded Python 3.13.5, required seccomp USER_NOTIF/user/mount/network/chroot/close_range/memfd/PDEATHSIG primitives. No cgroup, FUSE, Landlock or private /proc mount is assumed. Limits: one workload process, up to four thread births, one CPU affinity, 2 GiB address space, 128 fds, CPU 11–300 s, whole wall 3–3600 s further limited by expiry. Denied channels are intentional support limits, not proof that an untested Godot build will start.

On the qualified inert host, from the exact I checkout:

```sh
python -I -S tools/dd1_linux/build_inert.py
python -I -S -c 'import sys,runpy;sys.path.insert(0,"tools");runpy.run_path("tools/test_dd1_source_repair.py",run_name="__main__")'
DD1_INERT_CODE_HEAD=efdac6a25dd0436de5ef2c52136b5f8ce71c4da7 \
DD1_B1_OUTPUT=/tmp/dd1-b1-new-evidence \
python -I -S tools/dd1_linux/test_backend.py
```

A different toolchain/helper digest is rejected, not silently accepted as the tested binary. `BUILD.json` gives exact actual compilation argv, output and hashes. No engine compilation or launch belongs to those commands.

`TRANSPORT.json` lists four binary chunks which concatenate to an XZ stream. Decode with standard Python only, checking every part and the complete raw SHA256:

```python
from pathlib import Path
import hashlib, json, lzma
root = Path("research/p9-six-route/dusk-design-1-20260916/native-qualification/source-repair/b1")
m = json.loads((root / "TRANSPORT.json").read_text())
parts = []
for entry in m["parts"]:
    raw = (root / entry["path"]).read_bytes()
    assert len(raw) == entry["bytes"]
    assert hashlib.sha256(raw).hexdigest() == entry["sha256"]
    parts.append(raw)
packed = b"".join(parts)
assert len(packed) == m["compressed_bytes"]
assert hashlib.sha256(packed).hexdigest() == m["compressed_sha256"]
raw = lzma.decompress(packed)
assert len(raw) == m["raw_bytes"]
assert hashlib.sha256(raw).hexdigest() == m["raw_sha256"]
with Path("/tmp/dd1-b1-records.json").open("xb") as f:
    f.write(raw)
```

The 765752 decoded bytes contain all 64 stored controls, exact synthetic demands/receipts, account before/after data, complete bounded output bytes, grant/results, actual errors, identities and cleanup checks. Compression is transport only, never raw-budget credit. `tools/dd1_linux/evidence.py` is the separately bounded zlib text-transport utility; these binary XZ chunks use the standard decoder above, not that utility.

## Reuse, preserved accounts and next boundary

The delivered driver, transparent Pilot observer, provenance checks, source reader and GDScript fixtures are unchanged at I. Their earlier native-unverified status and mocked H limits remain. Old pending/save, reader/collateral/control and visual evidence retains the dependency scope in the prior `../EVIDENCE.md`; B1 does not rerun or independently accept it. Old replay outcomes remain history and cannot validate the corrected producer or new backend. No retrospective counter refund, repaired historical trace or P5 success prediction is made.

The GitHub diff from the resumed checkpoint changes only owned tooling; no production/domain/content/Pilot file, accepted D/C/H artifact or old evidence changes. Recovery ACCOUNT blob remains `8b7e4e6367ad4bc366c04b930ef4fc3810e2a900` before and after tests. Its recovery account reports 2040/2048, arithmetic eight NOT AUTHORISED; historical account remains 1277/8192, arithmetic 6915 unspendable, attempt 1/1 consumed and UNKNOWN observations. Tests did not access or mutate that live account. H ALLOCATION is independently retained at H, blob `824ff18acbca2f776533beed83a43b21d9a50f2c`; it is not copied into this overlay.

D=`746388323b8e886967e0e13fe109490a70206a66`; C=`cf27285a3103d8867a179f700c5ebf32661453d5`; H=`5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6`. Main and bound #547 acceptance remain unchanged. No clock reset, new allowance, reviewer invocation, self-approval, production PR/CI, merge, closure or release. Certificates remain 0/3.

The next process decision is scoped independent review and native venue/source/resource disposition, owned by the planner under the existing process. See `EXECUTION-DEMAND.md`. This source author neither invokes a concurrent reviewer nor approves its own work. B1 inert success is not an engine setup permit, cross-host equivalence, ordinary profile, N0 certificate or permission to spend the remaining eight starts.
