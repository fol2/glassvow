"""Build ONLY owned harmless fixtures/helper; never discover or execute an engine.

The dynamic fixture pins copies of this host's libc/loader. There is no ldd or
loader invocation on an untrusted binary; ELF inspection supplies dependencies.
"""
import argparse
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


def build(compat2_only=False):
    out = HERE / "build"; out.mkdir(exist_ok=True)
    common = ["cc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror"]
    commands = [common + ["-static", *[str(HERE / n) for n in
        ("supervisor.c", "policy.c", "isolate.c", "capabilities.c")], "-o", str(out / "supervisor")]]
    if compat2_only:
        commands.append(common + ["-pthread", str(HERE / "compat2_inert.c"), "-o", str(out / "compat2-inert")])
    else:
        commands.extend([
            common + ["-static", "-pthread", str(HERE / "inert.c"), "-o", str(out / "inert")],
            common + ["-pthread", str(HERE / "inert.c"), "-o", str(out / "inert-dynamic")]])
    records = []
    for cmd in commands:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        records.append(dict(argv=cmd, exit=p.returncode, stdout=p.stdout, stderr=p.stderr))
        if p.returncode: raise RuntimeError(json.dumps(records))
    dynamic = out / ("compat2-inert" if compat2_only else "inert-dynamic")
    interp, needed = snapshot.elf(dynamic.read_bytes())
    r.need(needed == ["libc.so.6"] and interp == "/lib64/ld-linux-x86-64.so.2", "unsupported inert runtime closure")
    runtime = {"/lib/x86_64-linux-gnu/libc.so.6": Path("/lib/x86_64-linux-gnu/libc.so.6").resolve(),
               interp: Path(interp).resolve()}
    for dest, source in runtime.items():
        shutil.copyfile(source, out / Path(dest).name)
    result = dict(commands=records, host=platform.uname()._asdict(),
        libc=platform.libc_ver(), binaries={p.name: dict(bytes=p.stat().st_size, sha256=r.digest(p.read_bytes())) for p in out.iterdir() if p.is_file() and p.name != "BUILD.json"})
    (out / "BUILD.json").write_bytes(r.encode(result))
    from dd1_meter_entry import INERT_BINARIES
    r.need(result["binaries"]["supervisor"]["sha256"] == snapshot.PINNED_HELPER_SHA256, "rebuilt helper differs from code pin")
    r.need(r.digest(dynamic.read_bytes()) in INERT_BINARIES, "rebuilt harmless fixture differs from code pin")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--compat2-only", action="store_true")
    print(json.dumps(build(parser.parse_args().compat2_only), indent=2))
