"""Build ONLY owned harmless fixtures/helper; never discover or execute an engine.

The dynamic fixture pins copies of this host's libc/loader. There is no ldd or
loader invocation on an untrusted binary; ELF inspection supplies dependencies.
"""
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import dd1_linux_snapshot as snapshot
import dd1_reservations as r


def build():
    out = HERE / "build"; out.mkdir(exist_ok=True)
    commands = [
        ["cc", "-std=c11", "-static", "-O2", "-Wall", "-Wextra", "-Werror", *[str(HERE / n) for n in ("supervisor.c", "policy.c", "isolate.c")], "-o", str(out / "supervisor")],
        ["cc", "-std=c11", "-static", "-pthread", "-O2", "-Wall", "-Wextra", "-Werror", str(HERE / "inert.c"), "-o", str(out / "inert")],
        ["cc", "-std=c11", "-pthread", "-O2", "-Wall", "-Wextra", "-Werror", str(HERE / "inert.c"), "-o", str(out / "inert-dynamic")]]
    records = []
    for cmd in commands:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        records.append(dict(argv=cmd, exit=p.returncode, stdout=p.stdout, stderr=p.stderr))
        if p.returncode: raise RuntimeError(json.dumps(records))
    interp, needed = snapshot.elf((out / "inert-dynamic").read_bytes())
    r.need(needed == ["libc.so.6"] and interp == "/lib64/ld-linux-x86-64.so.2", "unsupported inert runtime closure")
    runtime = {"/lib/x86_64-linux-gnu/libc.so.6": Path("/lib/x86_64-linux-gnu/libc.so.6").resolve(),
               interp: Path(interp).resolve()}
    for dest, source in runtime.items():
        shutil.copyfile(source, out / Path(dest).name)
    result = dict(commands=records, host=platform.uname()._asdict(),
        libc=platform.libc_ver(), binaries={p.name: dict(bytes=p.stat().st_size, sha256=r.digest(p.read_bytes())) for p in out.iterdir() if p.is_file() and p.name != "BUILD.json"})
    (out / "BUILD.json").write_bytes(r.encode(result))
    return result


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
