"""Delivery-only typed-array repair; preserve original sources and failed capture."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
OLD = HERE.parent
BEFORE = '\tvar consumers: Array[int] = [901, 902] if scenario == "repeat_consumer" else [901]\n'
AFTER = '\tvar consumers: Array[int] = [901]\n\tif scenario == "repeat_consumer":\n\t\tconsumers.append(902)\n'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def require(ok, why):
    if not ok:
        raise ValueError(why)


def assemble(destination):
    destination = Path(destination).resolve()
    require(not destination.exists(), 'FRESH_SOURCE_ASSEMBLY')
    freeze = json.loads((HERE/'REPAIR-FREEZE.json').read_bytes())
    require(sha((HERE/'repair.py').read_bytes()) == freeze['repair_sha256'], 'REPAIR_IDENTITY')
    old = (OLD/'FREEZE.json').read_bytes()
    require(sha(old) == freeze['original_freeze_sha256'], 'ORIGINAL_FREEZE')
    destination.mkdir(parents=True)
    for name, expected in json.loads(old)['source_sha256'].items():
        b = (OLD/name).read_bytes()
        require(sha(b) == expected, 'ORIGINAL_SOURCE:'+name)
        if name == 'probe.gd':
            s = b.decode(); require(s.count(BEFORE) == 1, 'EXACT_REPAIR_ANCHOR')
            b = s.replace(BEFORE, AFTER, 1).encode()
        require(sha(b) == freeze['source_sha256'][name], 'ASSEMBLED_SOURCE:'+name)
        (destination/name).write_bytes(b)
    (destination/'FREEZE.json').write_bytes((HERE/'REPAIR-FREEZE.json').read_bytes())
    sys.path.insert(0, str(destination))
    spec = importlib.util.spec_from_file_location('temporal_repaired_execute', destination/'execute.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    require(Path(module.C.__file__).resolve() == destination/'check.py', 'READER_LOCATION')
    return module


if __name__ == '__main__':
    action, source, *args = sys.argv[1:]
    module = assemble(source)
    if action == 'run':
        raise SystemExit(module.run(*args))
    elif action == 'verify':
        module.verify(*args)
    else:
        raise SystemExit('run SOURCE PARENT ENGINE OUT PROJECT | verify SOURCE ORIGINAL COLD RECEIPT')
