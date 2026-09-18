"""DD1-LINUX-ENTRY-1 stage-0 import/refusal control; no launch authority.

Use the exact accepted H files at the directory argument. This does not run
H's numerical tests, call its post-output receipt conjunction, debit an account,
or import an engine/backend. The sole context below has NO manifest/authority.
"""
import ast
import hashlib
import importlib
import json
from pathlib import Path
import sys
from types import SimpleNamespace

EXPECTED = {
    "evidence_boundary.py": "a88db0791572f430ea3e5cde85683c8527cead39",
    "reference_kernel.py": "ee091fb503849117358b3691264fca71803f8bbc",
}

def blob(raw):
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()

def main():
    root = Path(sys.argv[1]).resolve(strict=True)
    sys.dont_write_bytecode = True
    identities = {}
    for name, expected in EXPECTED.items():
        path = root / name
        if path.is_symlink():
            raise RuntimeError("symbolic H module")
        raw = path.read_bytes()
        if blob(raw) != expected:
            raise RuntimeError("not accepted H bytes: " + name)
        imports = set()
        for node in ast.walk(ast.parse(raw)):
            if isinstance(node, ast.Import):
                imports.update(x.name.split(".")[0] for x in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imports.add(node.module.split(".")[0])
        if not imports <= (sys.stdlib_module_names | {"reference_kernel"}):
            raise RuntimeError("unmaterialised non-stdlib dependency")
        identities[name] = {"git_blob": expected, "sha256": hashlib.sha256(raw).hexdigest(),
                            "bytes": len(raw), "imports": sorted(imports)}
    sys.path.insert(0, str(root))
    boundary = importlib.import_module("evidence_boundary")
    assert Path(boundary.__file__).resolve() == root / "evidence_boundary.py"
    assert Path(boundary.kernel.__file__).resolve() == root / "reference_kernel.py"
    # Explicit ABSENT-AUTHORITY control, not a fabricated empirical context.
    no_authority = SimpleNamespace(expected_identities={})
    try:
        boundary.verify_bindings({"evidence": {}}, no_authority)
    except boundary.MissingAuthority as exc:
        assert str(exc) == "missing_external_manifest"
        refusal = {"exception": type(exc).__name__, "reason": str(exc)}
    else:
        raise RuntimeError("missing manifest did not refuse")
    assert all(blob((root / name).read_bytes()) == expected for name, expected in EXPECTED.items())
    print(json.dumps({"scope": "STAGE0_REAL_H_IMPORT_AND_ABSENT_AUTHORITY_REFUSAL_ONLY",
        "accepted_h": "5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6", "files": identities,
        "import": "PASS", "absent_authority": refusal, "H_modified_or_mocked": False,
        "numerical_suite_executed": False, "post_output_receipts_required": False,
        "native_demand_authenticated": False, "engine_starts": 0, "account_writes": 0}, indent=2))

if __name__ == "__main__":
    main()
