"""Test harness child, not a native launch CLI. Arguments locate a temporary case."""
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dd1_reservations as r
from dd1_meter_entry import _run_inert_unit

if __name__ == "__main__":
    root, repo = map(lambda x: Path(x).resolve(), sys.argv[1:3])
    unit = r.read(root / "demand.json")
    try:
        result = _run_inert_unit(unit["argv"], unit=unit, account_path=root / "ACCOUNT.json",
            receipt_path=root / "receipt.json", output=root / "result",
            head=unit["overlay_head"], repo=repo)
        (root / "returned.json").write_bytes(r.encode(result))
        print(json.dumps({"completed": True, "success": result["success"], "n0_accepted": False}))
        sys.exit(0 if result["success"] else 1)
    except Exception as exc:
        print(json.dumps({"completed": False, "error": type(exc).__name__ + ":" + str(exc)}))
        sys.exit(2)
