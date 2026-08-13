#!/usr/bin/env python3
"""Self-checking Native Proof coordinate conversion (also run via tools/dev.py --check)."""

from __future__ import annotations

import importlib.util
from pathlib import Path

_DEV = Path(__file__).with_name("dev.py")
_SPEC = importlib.util.spec_from_file_location("glassvow_dev", _DEV)
if _SPEC is None or _SPEC.loader is None:
    raise SystemExit(f"unable to load {_DEV}")
_DEV_MOD = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_DEV_MOD)

if __name__ == "__main__":
    _DEV_MOD.check()
