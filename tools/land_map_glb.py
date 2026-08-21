#!/usr/bin/env python3
"""Copy a Studio GLB onto a map-kit path and capture a 20-placement review.

Does not generate. Does not call the Tripo API. Default landing/capture does
not write canonical provenance. Accepted provenance is a later, provenance-only
step: --accept-signed-capture plus --reviewer fol2, with no mesh copy.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone, timedelta
from io import StringIO
from pathlib import Path
from typing import Any

FILE_REPO = Path(__file__).resolve().parent.parent
REPO = FILE_REPO
sys.path.insert(0, str(FILE_REPO / "tools"))
from map_asset_checks import inspect_glb  # noqa: E402

HKT = timezone(timedelta(hours=8))
AUTHORITY_REVIEWER = "fol2"
REVIEW_SIZE = (1280, 720)
REVIEW_MODES = {"RGB", "RGBA"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def dump_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


def manifest_row(asset_id: str) -> dict[str, Any]:
    data = load_json(REPO / "assets/art/map/map-assets.json")
    for row in data["assets"]:
        if row["id"] == asset_id:
            return row
    raise SystemExit(f"asset_id {asset_id} not in map-assets.json")


def run(cmd: list[str], timeout: int = 300) -> str:
    proc = subprocess.run(
        cmd, cwd=str(REPO), capture_output=True, text=True, timeout=timeout, check=False,
    )
    if proc.returncode != 0:
        tail = (proc.stderr or proc.stdout or "").strip()[-1200:]
        raise RuntimeError(f"{' '.join(cmd[:4])} rc={proc.returncode}: {tail}")
    return (proc.stdout or "") + (proc.stderr or "")


def _fail(summary: str) -> int:
    print(json.dumps({"ok": False, "summary": summary}))
    return 2


def validate_signed_acceptance(
    reviewer: str | None,
    capture: Path | None,
    asset_id: str,
) -> tuple[str, Path]:
    """Provenance-only accept: fol2 plus this asset's canonical 20-placement PNG."""
    if reviewer is None or str(reviewer).strip() != AUTHORITY_REVIEWER:
        raise ValueError(f"--reviewer must be {AUTHORITY_REVIEWER}")
    if capture is None:
        raise ValueError("--accept-signed-capture is required to write provenance")
    raw = capture if capture.is_absolute() else REPO / capture
    if ".." in raw.parts:
        raise ValueError("signed capture path must be canonical (no ..)")
    try:
        meta = raw.lstat()
    except OSError as error:
        raise ValueError(f"signed capture missing: {capture}") from error
    if stat.S_ISLNK(meta.st_mode) or not stat.S_ISREG(meta.st_mode):
        raise ValueError(f"signed capture must be a non-symlink regular file: {capture}")
    resolved = raw.resolve()
    try:
        rel = resolved.relative_to(REPO.resolve())
    except ValueError as error:
        raise ValueError(f"signed capture is outside the repo: {capture}") from error
    parts = rel.parts
    if len(parts) != 4 or parts[0] != "docs" or parts[1] != "reviews":
        raise ValueError("signed capture must be docs/reviews/<ticket>/<asset_id>-20.png")
    ticket = parts[2]
    if not ticket.isdigit() or int(ticket) <= 0:
        raise ValueError(f"review ticket must be a positive issue number, not {ticket!r}")
    if parts[3] != f"{asset_id}-20.png":
        raise ValueError(f"signed capture name must be {asset_id}-20.png")
    expected = (REPO / "docs" / "reviews" / ticket / f"{asset_id}-20.png").resolve()
    if resolved != expected or expected.is_symlink():
        raise ValueError(f"signed capture must be the exact file {expected}")
    try:
        from PIL import Image
    except ImportError as error:
        raise RuntimeError("Pillow is required to accept a signed capture") from error
    with Image.open(resolved) as image:
        if image.format != "PNG" or image.size != REVIEW_SIZE or image.mode not in REVIEW_MODES:
            raise ValueError(
                f"signed capture must be PNG {REVIEW_SIZE[0]}x{REVIEW_SIZE[1]} "
                f"RGB/RGBA, got {image.format} {image.size} {image.mode}")
        image.load()
        image.convert("RGBA")
    return AUTHORITY_REVIEWER, expected


def append_provenance(
    asset_id: str,
    dest: Path,
    src: Path,
    concept: Path,
    task_id: str,
    extras: dict[str, Any],
    *,
    reviewer: str,
    signed_capture: Path,
    ledger: Path | None = None,
) -> None:
    reviewer, signed_capture = validate_signed_acceptance(reviewer, signed_capture, asset_id)
    path = ledger or (REPO / "assets/art/map/provenance.json")
    data = load_json(path)
    paid = data.get("paid_product") or {}
    if paid.get("product") != "Studio" or paid.get("api_forbidden") is not True:
        raise RuntimeError("paid_product is not Studio with api_forbidden true")
    if (data.get("record_schema") or {}).get("verdicts") != ["accepted", "rejected"]:
        raise RuntimeError("record_schema.verdicts is not accepted/rejected")
    source_sha = sha256(src)
    final_sha = sha256(dest)
    concept_sha = sha256(concept) if concept.is_file() else ""
    capture_rel = signed_capture.resolve().relative_to(REPO.resolve())
    edits = list(extras.get("edits") or [
        "land_map_glb.py copy; Studio Export GLB kept if it already meets the ordinary contract",
    ])
    edits.append(
        f"accepted after signed capture {capture_rel.as_posix()} sha256 {sha256(signed_capture)}"
    )
    record = {
        "asset_id": asset_id,
        "source": "Studio",
        "created_at": datetime.now(HKT).isoformat(timespec="seconds"),
        "license": "Tripo Studio Pro commercial grant (paid product Studio, not API)",
        "source_sha256": source_sha,
        "final_sha256": final_sha,
        "edits": edits,
        "reviewer": reviewer,
        "verdict": "accepted",
        "task_id": task_id,
        "face_limit": 1500,
        "texture": False,
        "pbr": False,
        "concept_path": str(concept.relative_to(REPO)) if concept.is_file() and concept.is_relative_to(REPO)
        else str(concept),
        "concept_sha256": concept_sha,
        "land_method": extras.get("land_method") or "studio_download",
        "polycount_target": 1500,
    }
    if extras.get("faces_reported") is not None:
        record["faces_reported"] = extras["faces_reported"]
    if record["verdict"] not in {"accepted", "rejected"}:
        raise RuntimeError("refusing to write a non-canonical provenance verdict")
    records = [row for row in data.get("records") or [] if row.get("asset_id") != asset_id]
    records.append(record)
    data["records"] = records
    dump_json(path, data)


def review_png(dest: Path, asset_id: str) -> Path:
    png = REPO / "docs/reviews/292" / f"{asset_id}-20.png"
    png.parent.mkdir(parents=True, exist_ok=True)
    rel = dest.resolve().relative_to(REPO)
    cmd = [
        os.environ.get("GODOT", "godot"),
        "--path", str(REPO),
        "--position", os.environ.get("GLASSVOW_SHOT_POSITION", "-4000,-4000"),
        "-s", "res://tools/raster_map_silhouette.gd", "--",
        f"--glb=res://{rel.as_posix()}",
        "--out=/tmp/map-sil-review",
        f"--review=res://docs/reviews/292/{asset_id}-20.png",
    ]
    run(cmd, timeout=120)
    if not png.is_file():
        raise RuntimeError(f"20-placement PNG missing: {png}")
    return png


def gates() -> str:
    chunks: list[str] = []
    chunks.append(run(["bash", "tools/check_imports.sh"], timeout=180))
    chunks.append(run(["bash", "tools/check_scripts.sh"], timeout=180))
    suite = run(
        [os.environ.get("GODOT", "godot"), "--headless", "-s", "res://tests/run_all.gd"],
        timeout=180,
    )
    if "PASS" not in suite:
        raise RuntimeError("test suite did not print PASS")
    chunks.append(suite)
    chunks.append(run([sys.executable, "tools/check_map_assets.py"], timeout=180))
    chunks.append(run([sys.executable, "tools/check_anchors.py"], timeout=60))
    chunks.append(run([sys.executable, "tools/check_benchmark_freeze.py"], timeout=60))
    return "\n".join(chunks)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Land a Studio GLB onto a map kit path")
    parser.add_argument("--asset", required=True)
    parser.add_argument("--src", required=True, type=Path)
    parser.add_argument("--concept", type=Path)
    parser.add_argument("--task-id", default="")
    parser.add_argument("--land-method", default="studio_download")
    parser.add_argument(
        "--edit",
        action="append",
        default=[],
        help="provenance edits[] row; repeatable. Default is an unmodified Studio Export copy.",
    )
    parser.add_argument("--gates", action="store_true")
    parser.add_argument("--no-review", action="store_true")
    parser.add_argument(
        "--accept-signed-capture",
        type=Path,
        default=None,
        help="Canonical 20-placement PNG. Provenance-only; skips recapture. No default.",
    )
    parser.add_argument(
        "--reviewer",
        default=None,
        help="Must be fol2 (#293 visual authority). Required with --accept-signed-capture.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    if argv is None and "--self-test" in sys.argv:
        return self_test()
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.reviewer and args.accept_signed_capture is None:
        parser.error("--reviewer is only valid with --accept-signed-capture")
    os.chdir(REPO)
    row = manifest_row(args.asset)
    src = args.src if args.src.is_absolute() else Path(args.src)
    dest = REPO / "assets/art/map" / row["path"]
    concept = args.concept
    if concept is None:
        concept = REPO / "assets/art/map-concepts" / f"{args.asset}.jpg"
    elif not concept.is_absolute():
        concept = REPO / concept
    extras = {"land_method": args.land_method, "edits": args.edit or [
        "land_map_glb.py copy of Studio Export GLB; no blender pass",
    ]}
    if args.accept_signed_capture is not None:
        if not dest.is_file():
            return _fail(f"landed dest missing: {dest}")
        if not src.is_file():
            return _fail(f"source GLB missing: {src}")
        if src.resolve() != dest.resolve():
            return _fail("accept is provenance-only; --src must resolve to the already-landed dest")
        findings = inspect_glb(dest, str(dest), row)
        if findings:
            return _fail("; ".join(str(item) for item in findings))
        capture = args.accept_signed_capture
        if not capture.is_absolute():
            capture = REPO / capture
        try:
            reviewer, capture = validate_signed_acceptance(args.reviewer, capture, args.asset)
            append_provenance(
                args.asset, dest, src, concept, args.task_id, extras,
                reviewer=reviewer, signed_capture=capture,
            )
        except (TypeError, ValueError, RuntimeError) as error:
            return _fail(str(error))
        review = None
        provenance_written = True
    else:
        if not src.is_file():
            return _fail(f"source GLB missing: {src}")
        findings = inspect_glb(src, str(src), row)
        if findings:
            return _fail("; ".join(str(item) for item in findings))
        dest.parent.mkdir(parents=True, exist_ok=True)
        if src.resolve() != dest.resolve():
            shutil.copy2(src, dest)
        provenance_written = False
        review = None if args.no_review else str(review_png(dest, args.asset).relative_to(REPO))
    gate_out = gates() if args.gates else ""
    print(json.dumps({
        "ok": True,
        "summary": f"landed {dest.relative_to(REPO)}" + ("; gates ran" if args.gates else ""),
        "glb_path": str(dest.relative_to(REPO)),
        "dest_path": str(dest.relative_to(REPO)),
        "land_method": args.land_method,
        "task_id": args.task_id,
        "review_path": review,
        "provenance_written": provenance_written,
        "gate_tail": gate_out[-400:] if gate_out else "",
    }))
    return 0


def _empty_ledger(verdicts: list[str] | None = None, api_forbidden: bool = True) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "paid_product": {"product": "Studio", "api_forbidden": api_forbidden},
        "record_schema": {
            "required": [
                "asset_id", "source", "created_at", "license", "source_sha256",
                "final_sha256", "edits", "reviewer", "verdict",
            ],
            "verdicts": ["accepted", "rejected"] if verdicts is None else verdicts,
        },
        "records": [],
    }


def _png(path: Path, size: tuple[int, int] = REVIEW_SIZE, mode: str = "RGBA") -> None:
    from PIL import Image
    path.parent.mkdir(parents=True, exist_ok=True)
    color = (8, 16, 24, 255) if mode == "RGBA" else (8, 16, 24)
    Image.new(mode, size, color).save(path, "PNG")


def self_test() -> int:
    global REPO
    errors: list[str] = []
    cwd = Path.cwd()
    saved_repo = REPO

    def must_fail(fn: Any, label: str, kinds: tuple[type, ...] = (ValueError,)) -> None:
        try:
            fn()
            errors.append(f"{label} did not fail")
        except kinds:
            print(f"self-test {label}: correctly failed")

    def cli(argv: list[str]) -> tuple[int, str]:
        buf = StringIO()
        old = sys.stdout
        sys.stdout = buf
        try:
            return main(argv), buf.getvalue()
        except SystemExit as error:
            return int(error.code or 1), buf.getvalue()
        finally:
            sys.stdout = old

    defaults = build_parser().parse_args(["--asset", "x", "--src", "y", "--no-review"])
    if defaults.reviewer is not None or defaults.accept_signed_capture is not None:
        errors.append("parser defaults a reviewer or accept path")
    else:
        print("self-test parser: no default reviewer or accept path")
    if should_append := defaults.accept_signed_capture:
        errors.append(f"default land would accept {should_append}")
    else:
        print("self-test default-land: does not write provenance")

    must_fail(lambda: validate_signed_acceptance(None, Path("x"), "a"), "missing reviewer")
    must_fail(lambda: validate_signed_acceptance("not-fol2", Path("x"), "a"), "arbitrary reviewer")
    must_fail(lambda: validate_signed_acceptance("fol2", None, "a"), "missing capture")
    must_fail(
        lambda: append_provenance("x", REPO / "x.glb", REPO / "x.glb", REPO / "x.jpg", "", {}),
        "append without accept args",
        (TypeError,),
    )

    asset = "shared-road-slab-a"
    with tempfile.TemporaryDirectory(prefix="land-map-glb-") as raw:
        root = Path(raw)
        shutil.copytree(FILE_REPO / "assets/art/map", root / "assets/art/map")
        dest = root / "assets/art/map/geometry/shared/road-slab-a.glb"
        other = root / "assets/art/map/geometry/shared/road-slab-b.glb"
        before = dest.read_bytes()
        capture = root / "docs/reviews/293" / f"{asset}-20.png"
        _png(capture)
        tmp_png = root / f"{asset}-20.png"
        _png(tmp_png)
        wrong = root / "docs/reviews/293/road-slab-a-20.png"
        _png(wrong)
        REPO = root
        try:
            must_fail(lambda: validate_signed_acceptance("fol2", tmp_png, asset), "tmp capture")
            must_fail(lambda: validate_signed_acceptance("fol2", wrong, asset), "wrong asset")
            must_fail(
                lambda: validate_signed_acceptance(
                    "fol2", root / "docs/reviews/293/../293" / f"{asset}-20.png", asset),
                "traversal")
            exact_small = root / "docs/reviews/294" / f"{asset}-20.png"
            _png(exact_small, size=(64, 64))
            must_fail(lambda: validate_signed_acceptance("fol2", exact_small, asset), "wrong size")
            link = root / "docs/reviews/295" / f"{asset}-20.png"
            link.parent.mkdir(parents=True)
            link.symlink_to(capture)
            must_fail(lambda: validate_signed_acceptance("fol2", link, asset), "symlink")
            validate_signed_acceptance("fol2", capture, asset)
            print("self-test exact-path: accepted docs/reviews/293/shared-road-slab-a-20.png")

            (root / "assets/art/map/provenance.json").write_text(json.dumps(_empty_ledger()))
            rc, _out = cli([
                "--asset", asset, "--src", str(other),
                "--accept-signed-capture", str(capture), "--reviewer", "fol2",
            ])
            if rc == 0 or dest.read_bytes() != before:
                errors.append("failing accept mutated dest or succeeded")
            else:
                print("self-test cli-fail: dest bytes unchanged")

            copied = []
            recaptured = []
            orig_copy, orig_review = shutil.copy2, review_png

            def _copy(*args: Any, **kwargs: Any) -> Any:
                copied.append(1)
                return orig_copy(*args, **kwargs)

            def _review(*args: Any, **kwargs: Any) -> Path:
                recaptured.append(1)
                raise RuntimeError("acceptance recaptured")

            shutil.copy2 = _copy  # type: ignore[method-assign]
            globals()["review_png"] = _review
            try:
                rc, out = cli([
                    "--asset", asset, "--src", str(dest),
                    "--accept-signed-capture", str(capture), "--reviewer", "fol2",
                ])
            finally:
                shutil.copy2 = orig_copy  # type: ignore[method-assign]
                globals()["review_png"] = orig_review
            payload = json.loads(out.strip().splitlines()[-1]) if out.strip() else {}
            if rc != 0 or copied or recaptured or dest.read_bytes() != before:
                errors.append(f"successful accept copied/recaptured/mutated dest rc={rc} {payload}")
            elif payload.get("provenance_written") is not True:
                errors.append("successful accept did not write provenance")
            else:
                print("self-test cli-accept: no copy, no recapture, dest unchanged")

            pending = root / "pending.json"
            pending.write_text(json.dumps(_empty_ledger(["accepted", "rejected", "pending"])))
            must_fail(
                lambda: append_provenance(
                    asset, dest, dest, dest, "", {"edits": ["t"]},
                    reviewer="fol2", signed_capture=capture, ledger=pending,
                ),
                "pending schema",
                (RuntimeError,),
            )
            banned = root / "api.json"
            banned.write_text(json.dumps(_empty_ledger(api_forbidden=False)))
            must_fail(
                lambda: append_provenance(
                    asset, dest, dest, dest, "", {"edits": ["t"]},
                    reviewer="fol2", signed_capture=capture, ledger=banned,
                ),
                "api not forbidden",
                (RuntimeError,),
            )
        finally:
            REPO = saved_repo
            os.chdir(cwd)

    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("self-test FAILED", file=sys.stderr)
        return 1
    print("self-test OK (default land writes no provenance; accept is provenance-only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
