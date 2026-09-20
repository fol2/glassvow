# Operational collection notes

The first post-matrix collector was called from the Python-tool kernel, whose
user could not read the normal-shell test parent's private /tmp directory.
It failed at the initial directory enumeration with PermissionError, before
writing a collection file or changing any control/account. The retained
collect_artifacts.py was then executed by the same normal container shell that
created the matrix, and collected its own test outputs successfully. No
permission was weakened in the workload or original source.

The first packet-integrity invocation omitted isolated Python flags. Its own
hash checks passed (exit0), but a provisioned startup hook emitted unrelated
spreadsheet-runtime warmup stderr. Both streams are retained. The final
integrity invocation uses -I -B -S and does not load that startup hook.
These are collection/packaging observations, not additional workload controls
or successful engine evidence.
