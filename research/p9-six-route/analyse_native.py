"""Read native study summaries without treating policy labels as P9 certificates."""
import json
import math
import sys
from pathlib import Path


def wilson(wins, n, z=1.959963984540054):
    if n <= 0:
        raise ValueError("nonpositive denominator")
    p = wins / n
    d = 1 + z*z/n
    c = (p + z*z/(2*n))/d
    h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n))/d
    return [c-h, c+h]


def analyse(records):
    groups = {}
    for record in records:
        if not record.get("complete"):
            raise ValueError("incomplete native cell")
        s, m = record["spec"], record["summary"]
        name = Path(s["content_path"]).stem
        key = (name, s["aspect"], s["vow"])
        row = {
            "route": s["route"], "random_build": s.get("random_build", False),
            "wins": m["wins"], "n": m["n"], "rate": m["wins"] / m["n"],
            "nominal_wilson95": wilson(m["wins"], m["n"]),
            "anchors": m["anchors"], "mechanism": m["mechanism"],
        }
        groups.setdefault(key, []).append(row)
    cells = []
    for (name, aspect, vow), rows in sorted(groups.items()):
        planned = [r for r in rows if not r["random_build"]]
        random = [r for r in rows if r["random_build"]]
        if not planned or not random:
            continue
        top = max(r["rate"] for r in planned)
        rb = max(r["rate"] for r in random)
        floor = (top + rb) / 2
        routes = [r for r in planned if r["route"] != "balanced"]
        cells.append({
            "content": name, "aspect": aspect, "vow": vow,
            "planned_top": top, "random_worst": rb, "gap": top-rb,
            "diagnostic_floor": floor,
            "min_route_floor_margin": min(r["rate"]-floor for r in routes),
            "route_spread": max(r["rate"] for r in routes)-min(r["rate"] for r in routes),
            "named_policy_rates": rows,
        })
    return {
        "status": "DISCOVERY_NOT_P9_CERTIFIED",
        "rows": sum(r["summary"]["n"] for r in records), "cells": cells,
        "limitations": [
            "Intervals are nominal cell-level summaries, not corrected selection evidence.",
            "A maximum of sampled rates is not an upper bound on all policies.",
            "Generic RandomBuild screening is not the signed acceptance arm.",
            "Three policy names do not establish the original C1 four-cell condition.",
            "Causal dependence and fresh optimisation retention need separate evidence.",
        ],
    }


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: analyse_native.py summary.json output.json")
    report = analyse(json.loads(Path(sys.argv[1]).read_text()))
    Path(sys.argv[2]).write_text(json.dumps(report, indent=2) + "\n")
    for cell in report["cells"]:
        print(cell["content"], cell["aspect"], cell["vow"],
              "top", round(cell["planned_top"], 3),
              "random", round(cell["random_worst"], 3),
              "gap", round(cell["gap"], 3),
              "floor_margin", round(cell["min_route_floor_margin"], 3))
