#!/usr/bin/env python3
"""Thin wrapper: bun tools/studio_image_to_glb.ts (New Headless Chrome for Testing).

The walked driver is the .ts file. This exists so
`.grok/workflows/studio-dcc-map-glb.rhai` can keep calling python3.

Workflow: image in → arguments → 3D model out. Pass-through flags include
--textured (HD Model albedo), --dry-run (no Chrome, no credits), --smoke-run
(form only, Generate not clicked), --texture-quality, --pbr, --ultra-mesh,
--ai-complete. See `bun tools/studio_image_to_glb.ts --help`.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "studio_image_to_glb.ts"


def main() -> int:
    return subprocess.call(["bun", str(SCRIPT), *sys.argv[1:]], cwd=str(HERE.parent), env=os.environ)


if __name__ == "__main__":
    raise SystemExit(main())
