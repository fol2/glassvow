"""COMPAT-2 exact invocation bindings; no native authority is created here.

H authenticates expected identities out of band. This module checks the fixed
profile's content, never a caller whitelist or high-level function attribution.
"""
import re
import dd1_reservations as r

PROFILE = "DD1-B1-COMPAT-2-CAPABILITIES-1"
ENGINE = "8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e"
LIBC = "fa430b8f298f817a266046af84a77533185ad6fc4406c7d3787b5a0a0c207826"
ENVIRONMENT = {"HOME": "/out", "TMPDIR": "/out", "LANG": "C", "LC_ALL": "C",
    "XDG_DATA_HOME": "/out/data", "XDG_CACHE_HOME": "/out/cache",
    "DD1_RESERVED_UNIT_PATH": "/grant.json", "DD1_NATIVE_LAUNCH_RECEIPT": "/launch-receipt.json"}
STAGES = {"identity", "preparation", "parse", "fixture"}
PROCESS = {"arch": 0xc000003e, "syscall": 56, "flags": 0x4111,
           "parent_tid": 0, "child_tid": 0, "tls": 0,
           "maximum": 1, "initial_thread_only": True, "before_thread_births": True}


def validate_profile(unit, pinned):
    profile = unit.get("compatibility")
    if profile is None:
        r.need(unit.get("mode") != "engineering" and not unit.get("preparation") and
               not unit.get("sealed_input"), "engineering/preparation requires bound profile")
        return None
    r.need(unit.get("mode") in ("engineering", "inert_control"), "profile is engineering only")
    stage = unit.get("stage")
    r.need(stage in STAGES and isinstance(profile, dict), "profile stage")
    r.need(unit.get("contained_starts") == (2 if stage == "fixture" and unit["mode"] == "engineering" else 0),
           "stage contained-start bound")
    b = unit["linux"]
    engine = r.digest(pinned["files"][unit["argv"][0]][0])
    r.need(unit["mode"] == "inert_control" or engine == ENGINE, "fixed official engine required")
    r.need(b.get("environment") == ENVIRONMENT, "unbound/changed workload environment")
    libc = [raw for name, (raw, _) in pinned["files"].items() if name.endswith("/libc.so.6")]
    r.need(len(libc) == 1 and r.digest(libc[0]) == LIBC, "profile libc identity")
    expected = dict(id=PROFILE, operation="DD1-LINUX-ENTRY-1", stage=stage,
        source_head=unit["overlay_head"], executable_sha256=engine, libc_sha256=LIBC,
        helper_sha256=r.digest(pinned["helper"]), source_manifest_sha256=r.digest(r.encode(unit["source_files"])),
        runtime_sha256=r.digest(r.encode(b["runtime"])), argv_sha256=r.digest(r.encode(unit["argv"])),
        environment_sha256=r.digest(r.encode(ENVIRONMENT)), process_signature=PROCESS,
        naming_option=15, naming_per_thread=1, naming_total=profile.get("naming_total"),
        clone3_maximum=profile.get("clone3_maximum"), attribution="CAPABILITY_CLASS_ONLY",
        task_sha256=r.digest(r.encode(unit.get("task"))),
        preparation_sha256=r.digest(r.encode(unit.get("preparation"))),
        sealed_input_sha256=r.digest(r.encode(unit.get("sealed_input"))))
    if "execution_files" in unit:
        expected["execution_files_sha256"] = r.digest(r.encode(unit["execution_files"]))
    import dd1_runtime_fit as fit
    ceiling = fit.MAX_THREADS if fit.selected(unit) else 4
    if fit.selected(unit):
        expected['runtime_fit_sha256'] = r.digest(r.encode(unit['runtime_fit']))
        expected['execution_modes_sha256'] = r.digest(r.encode(unit['execution_modes']))
    if unit.get("kernel_qualification") is not None:
        expected["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
    r.need(r.encode(profile) == r.encode(expected), "profile exact-invocation binding")
    r.need(1 <= r.natural(profile["naming_total"], "naming bound") <= b["threads"] <= ceiling and
           1 <= r.natural(profile["clone3_maximum"], "clone3 bound") <= b["threads"] + 1 <= ceiling + 1,
           "profile finite refusal bounds")
    validate_task(unit)
    return profile



def validate_task(unit):
    import dd1_preparation as prep
    task = unit.get("task")
    r.need(isinstance(task, dict) and set(task) == {"kind", "stage", "files"} and
           task["stage"] == unit["stage"], "missing/mismatched task contract")
    r.need(task["kind"] == ("exact-files" if unit["mode"] == "inert_control" else "godot-stage"),
           "wrong task kind")
    if unit["mode"] == "engineering":
        entry, stage = unit["argv"][0], unit["stage"]
        prefix = [entry, "--headless", "--path", "/source"]
        if stage == "identity":
            valid = unit["argv"] == [entry, "--version"]
        elif stage == "preparation":
            valid = unit["argv"] == prefix + ["--import", "--quit"] and bool(unit.get("preparation"))
        elif stage == "parse":
            valid = (len(unit["argv"]) == 7 and unit["argv"][:6] == prefix + ["--check-only", "-s"]
                     and unit["argv"][6] in unit["source_files"] and unit["argv"][6].endswith(".gd")
                     and bool(unit.get("sealed_input")))
        else:
            valid = (unit["argv"] == prefix + ["-s", "res://tests/run_all.gd", "--",
                     "--tests=res://tests/test_dd1_source_repair.gd"] and bool(unit.get("sealed_input")))
        r.need(valid, "argv does not implement the declared engine stage")
    files = task["files"]
    r.need(isinstance(files, dict) and len(files) <= 128 and
           (unit["mode"] != "inert_control" or bool(files)), "task output inventory")
    for name, item in files.items():
        prep.path_name(name)
        r.need(isinstance(item, dict) and set(item) == {"bytes", "sha256"} and
               0 <= r.natural(item["bytes"], "task bytes") <= unit["linux"]["workload_raw_bytes"] and
               isinstance(item["sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", item["sha256"]),
               "invalid task byte binding")


# Exact source-derived optional-service diagnostic, NOT an origin authenticator.
# The bytes are retained and counted; no arbitrary regex/whitelist is supplied.
DESKTOP_ERROR = b'ERROR: Cannot create pipe from command: "xdg-user-dir" "DESKTOP" 2>/dev/null.'


def diagnose(stderr, classification):
    errors, expected = [], 0
    for line in stderr.splitlines():
        if b"SCRIPT ERROR" in line or b"Failed to load script" in line:
            errors.append("script diagnostic")
        elif b"ERROR:" in line:
            if (line == DESKTOP_ERROR and expected == 0 and
                    classification.get("process_refusals") == 1 and
                    classification.get("unexpected_denials") == 0):
                expected += 1
            else:
                errors.append("unexpected Godot error diagnostic")
    return errors, expected

def bound_role(expected, context, name, raw):
    binding = expected["roles"].get(name, {})
    r.need(binding.get("sha256") == r.digest(raw) and
           context.resolve(binding.get("locator")) == raw, "missing/altered external role: " + name)


def native_bindings(unit, expected, context):
    """After genuine H.verify_bindings; prospective roles, NOT future outcomes."""
    if unit.get("compatibility") is None:
        r.need(unit.get("mode") != "engineering", "missing engineering profile")
        return
    import dd1_kernel_qualification as kernel_qualification
    kernel_qualification.native_bindings(unit, expected, context)
    import dd1_runtime_fit as fit
    fit.native_bindings(unit, expected, context)
    bound_role(expected, context, "compatibility_profile", r.encode(unit["compatibility"]))
    # A later host-authenticated disposition must explicitly admit this stage and
    # exact amended source. Old strict-B1 approval never fills this role.
    binding = expected["roles"].get("compatibility_disposition", {})
    raw = context.resolve(binding.get("locator"))
    r.need(isinstance(raw, bytes) and r.digest(raw) == binding.get("sha256"), "missing compatibility disposition")
    import json
    disposition = json.loads(raw)
    r.need(disposition.get("schema") == "DD1-COMPAT-2-DISPOSITION-1" and
           disposition.get("operation") == "DD1-LINUX-ENTRY-1" and
           disposition.get("source_head") == unit["overlay_head"] and
           disposition.get("profile") == PROFILE and disposition.get("stage") == unit["stage"] and
           disposition.get("independent_review") == "APPROVE" and
           disposition.get("planner_acceptance") == "ACCEPTED" and
           disposition.get("owner_selection") == 5744752364 and
           disposition.get("launch_admitted") is True, "unadmitted compatibility stage")
    authorities = expected.get("receipt_authorities", {})
    authority = authorities.get("compatibility_disposition", {})
    r.need(authority.get("sha256") == r.digest(raw) and isinstance(authority.get("authority"), str) and
           authority["authority"] and not authority["authority"].startswith("synthetic:") and
           disposition.get("authority") == authority["authority"] and
           context.receipts.get("compatibility_disposition") == raw, "unauthenticated compatibility issuer")
    if unit.get("preparation") is not None:
        bound_role(expected, context, "preparation_recipe", r.encode(unit["preparation"]))
        import dd1_prep_view as view
        view.native_bindings(unit, expected, context)
    if unit.get("sealed_input") is not None:
        sealed = expected["roles"].get("preparation_seal", {})
        r.need(sealed.get("sha256") == unit["sealed_input"]["sha256"], "missing prospective sealed input role")
        data = context.resolve(sealed.get("locator"))
        r.need(isinstance(data, bytes) and r.digest(data) == sealed["sha256"], "altered sealed input role")
        record = json.loads(data)
        if record.get("schema") == "DD1-SEALED-PREPARATION-3":
            bound_role(expected, context, "preparation_projection", r.encode(record["execution_view"]))
            r.need(record.get("semantic_scope") == "HOST_QUALIFICATION_REQUIRED", "inert PREP-1 seal is not native authority")


def task_outcome(unit, capture, classification=None):
    """Task evidence is independent of syscall classification and process exit.

    Whole stdout/stderr are retained. Expected refusal records do not make
    arbitrary engine errors acceptable. No task contract means old strict scope.
    """
    task = unit.get("task")
    if task is None:
        return {"ok": unit.get("compatibility") is None, "scope": "legacy exit-status only"}
    import dd1_preparation as prep
    outputs = {}
    errors = []
    expected_diagnostics = 0
    for name, specification in task.get("files", {}).items():
        try:
            prep.path_name(name)
            raw = prep._regular(capture / name, specification["bytes"])
            outputs[name] = {"bytes": len(raw), "sha256": r.digest(raw)}
            if len(raw) != specification["bytes"] or r.digest(raw) != specification["sha256"]:
                errors.append("task bytes mismatch:" + name)
        except (OSError, ValueError, r.ReservationError) as exc:
            errors.append(str(exc))
    if unit["mode"] == "inert_control":
        r.need(task.get("kind") == "exact-files" and bool(task.get("files")), "inert task contract")
    else:
        r.need(task.get("kind") == "godot-stage", "native task contract")
        stdout = prep._regular(capture / "stdout.bin", unit["linux"]["workload_raw_bytes"])
        stderr = prep._regular(capture / "stderr.bin", unit["linux"]["workload_raw_bytes"])
        diagnostic_errors, expected_diagnostics = diagnose(stderr, classification or {})
        errors.extend(diagnostic_errors)
        stage = unit["stage"]
        if stage == "identity" and stdout.strip() != b"4.7.2.stable.official.ed1daf0bf":
            errors.append("exact version mismatch")
        if stage == "fixture" and not re.search(rb"(?m)^PASS \(1 tests?\)\s*$", stdout):
            errors.append("missing focused fixture success marker")
        if stage == "preparation" and not unit.get("preparation"):
            errors.append("missing generated-input validation")
        if stage in ("parse", "fixture") and not unit.get("sealed_input"):
            errors.append("missing sealed project inputs")
    return {"ok": not errors, "errors": errors, "verified_files": outputs,
            "expected_diagnostic_count": expected_diagnostics,
            "diagnostic_origin_authenticated": False,
            "attribution": "CAPABILITY_CLASS_ONLY"}
