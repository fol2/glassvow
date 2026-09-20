"""Pinned bytes -> private sysroot. No ldd, shell, package install or engine probe.

The host-authenticated demand owns source/content/runtime closure. We reject
missing ELF interpreters/NEEDED names rather than importing host libraries.
Only copied bytes enter the root; original paths are never mounted in it.
"""
import os
from pathlib import Path, PurePosixPath
import platform
import stat
import struct
import dd1_reservations as r

ABI = "linux-x86_64-lp64-v1"
# Exact helper built/tested in this source artifact, not a unit-selected runner.
PINNED_HELPER_SHA256 = "b22fdaba90df2a1a317f1d3a690522736a1301f9b442016764d5bf173f2fdf0f"
HELPER_SOURCES = frozenset("res://tools/" + p for p in (
    "dd1_linux/policy.h", "dd1_linux/policy.c", "dd1_linux/isolate.c",
    "dd1_linux/supervisor.c", "dd1_linux_snapshot.py", "dd1_linux_backend.py",
    "dd1_meter_entry.py", "dd1_reservations.py", "dd1_recovery_meter.py",
    "dd1_linux/capabilities.h", "dd1_linux/capabilities.c",
    "dd1_compatibility.py", "dd1_preparation.py", "dd1_preparation_watch.py"))


def read_regular(root: Path, name: str, maximum: int = 1 << 30) -> bytes:
    parts = PurePosixPath(name).parts
    r.need(len(name.encode()) <= 384 and len(parts) <= 12, "input path bound")
    r.need(parts and not name.startswith("/") and all(x not in (".", "..", "") for x in parts), "unsafe input path")
    r.need(not any(x in (".git", ".ssh", ".env") for x in parts) and parts[-1] != "ACCOUNT.json", "private/account source forbidden")
    fd = os.open(root, os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for component in parts[:-1]:
            new = os.open(component, os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd); fd = new
        file = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(file, "rb") as stream:
            s = os.fstat(stream.fileno())
            r.need(stat.S_ISREG(s.st_mode) and s.st_nlink == 1 and s.st_size <= maximum, "nonregular/linked/oversized input")
            raw = stream.read(maximum + 1)
            r.need(len(raw) == s.st_size, "input changed while reading")
            return raw
    finally:
        os.close(fd)


def elf(raw: bytes) -> tuple[str | None, list[str]]:
    r.need(len(raw) >= 64 and raw[:6] == b"\x7fELF\x02\x01" and
           struct.unpack_from("<H", raw, 18)[0] == 62, "unsupported executable architecture/ABI")
    phoff = struct.unpack_from("<Q", raw, 32)[0]
    size, count = struct.unpack_from("<HH", raw, 54)
    r.need(size == 56 and 0 < count <= 1024 and phoff + size * count <= len(raw), "malformed ELF headers")
    interp, loads, dynamic = None, [], b""
    for i in range(count):
        kind, flags, offset, addr, _, filesz, _, _ = struct.unpack_from("<IIQQQQQQ", raw, phoff + i * size)
        r.need(offset + filesz <= len(raw), "truncated ELF segment")
        if kind == 1: loads.append((addr, offset, filesz))
        if kind == 3:
            r.need(interp is None and 1 < filesz <= 4096, "ELF interpreter")
            interp = raw[offset:offset + filesz].rstrip(b"\0").decode("utf-8")
        if kind == 2: dynamic = raw[offset:offset + filesz]
    needed, string_addr, string_size = [], None, 0
    for i in range(0, len(dynamic) - 15, 16):
        tag, value = struct.unpack_from("<QQ", dynamic, i)
        if tag == 0: break
        if tag == 1: needed.append(value)
        if tag == 5: string_addr = value
        if tag == 10: string_size = value
    strings = b""
    if needed:
        for addr, offset, size in loads:
            if string_addr is not None and addr <= string_addr and string_addr + string_size <= addr + size:
                strings = raw[offset + string_addr - addr:offset + string_addr - addr + string_size]
        r.need(strings, "ELF string table missing")
    names = []
    for at in needed:
        end = strings.find(b"\0", at)
        r.need(0 <= at < end and end - at <= 4096, "ELF dependency string")
        names.append(strings[at:end].decode("utf-8"))
    return interp, names


def prepare(unit: dict, command: list[str], repo: Path, generated=None) -> dict:
    r.need(platform.system() == "Linux" and platform.machine() == "x86_64" and platform.release() == "6.18.44" and struct.calcsize("P") == 8,
           "unsupported host/ABI; no fallback")
    b = unit.get("linux", {})
    r.need(b.get("abi") == ABI, "missing supported Linux demand")
    r.need(HELPER_SOURCES <= unit["source_files"].keys(), "backend source closure missing")
    r.need(1 <= r.natural(b.get("threads"), "threads") <= 4, "unsafe thread bound")
    r.need(11 <= unit["cpu_seconds"] <= 300, "CPU partition requires at least eleven reserved seconds")
    r.need(0 < r.natural(b.get("workload_raw_bytes"), "workload raw") <= unit["raw_bytes"], "invalid workload raw bound")
    source, files = {}, {}
    for name, wanted in unit["source_files"].items():
        raw = read_regular(repo, name[6:])
        r.need(r.digest(raw) == wanted, "actual source bytes differ: " + name)
        if name in HELPER_SOURCES and name.endswith(".py"):
            actual = read_regular(Path(__file__).resolve().parents[1], name[6:])
            r.need(actual == raw, "loaded controller source differs:" + name)
        source[name] = raw; files["/source/" + name[6:]] = (raw, False)
    for name, raw in (generated or {}).items():
        r.need(name not in source and name.startswith("res://"), "generated source collision")
        files["/source/" + name[6:]] = (raw, False)
    runtime = b.get("runtime")
    r.need(isinstance(runtime, dict) and runtime and len(files) + len(runtime) <= 4096, "runtime closure size")
    for dest, item in runtime.items():
        parts = PurePosixPath(dest).parts
        r.need(len(dest.encode()) <= 384 and len(parts) <= 12 and dest.startswith("/") and str(PurePosixPath(dest)) == dest and
               ".." not in parts and len(parts) > 1 and parts[1] not in ("source", "out", "proc", "sys", "dev") and
               dest not in ("/grant.json", "/launch-receipt.json", "/dd1-preparation.layout"), "unsafe runtime destination")
        raw = read_regular(repo, item["path"])
        r.need(r.digest(raw) == item["sha256"] and type(item["executable"]) is bool, "runtime identity mismatch")
        files[dest] = (raw, item["executable"])
    r.need(b.get("entry") == command[0] and command[0] in files and files[command[0]][1], "unbound executable/argv")
    elf(files[command[0]][0])
    basenames = {PurePosixPath(x).name for x in files}
    for name, (raw, executable) in files.items():
        if executable or raw.startswith(b"\x7fELF"):
            interp, needed = elf(raw)
            r.need(interp is None or interp in files, "unbound interpreter: " + str(interp))
            r.need(all(n in files if n.startswith("/") else n in basenames for n in needed), "unbound runtime dependency")
    helper = read_regular(repo, b["helper"]["path"])
    r.need(r.digest(helper) == b["helper"]["sha256"] == PINNED_HELPER_SHA256 and elf(helper) == (None, []), "helper must be pinned static ELF")
    # Payload copies + worst-case path/creation metadata. No compression credit.
    setup_raw = len(helper) + sum(len(raw) + 16384 for raw, _ in files.values()) + 32768
    r.need(setup_raw + b["workload_raw_bytes"] + 524288 < unit["raw_bytes"], "raw cannot fit immutable inputs and workload")
    import dd1_preparation as preparation
    import dd1_compatibility as compatibility
    recipe = preparation.validate_recipe(unit, source)
    promotion = preparation.reserve_copy_bytes(recipe, source)
    result = dict(files=files, source=source, helper=helper, setup_raw=setup_raw + promotion,
                  config=b, preparation=recipe, promotion_raw=promotion)
    result["profile"] = compatibility.validate_profile(unit, result)
    r.need(result["setup_raw"] + b["workload_raw_bytes"] + 524288 < unit["raw_bytes"],
           "complete preparation/copy raw envelope")
    return result


def verify_ancestry(bodies, head: str, ancestor: str) -> None:
    """Verify supplied Git commit bytes without spawning Git inside the unit.

    The same H-bound demand carries these immutable object bytes; this checks
    ancestry, not issuer authentication. A path may follow any declared parent.
    """
    import hashlib
    r.need(isinstance(bodies, list) and len(bodies) <= 128, "bounded Git ancestry bytes required")
    current = head
    for index, body in enumerate(bodies):
        r.need(isinstance(body, str) and 0 < len(body.encode()) <= 65536, "invalid Git commit bytes")
        raw = body.encode()
        actual = hashlib.sha1(b"commit " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        r.need(actual == current and current != ancestor, "Git ancestry object mismatch")
        parents = [line[7:] for line in body.split("\n\n", 1)[0].splitlines() if line.startswith("parent ")]
        if index + 1 == len(bodies):
            current = ancestor
        else:
            nxt = bodies[index + 1]
            r.need(isinstance(nxt, str), "invalid next Git commit")
            data = nxt.encode()
            current = hashlib.sha1(b"commit " + str(len(data)).encode() + b"\0" + data).hexdigest()
        r.need(current in parents, "Git ancestry parent mismatch")
    r.need(current == ancestor, "missing Git ancestry chain")
