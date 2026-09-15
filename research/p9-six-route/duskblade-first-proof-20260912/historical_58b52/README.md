# Historical implementation — not active admission or current evidence

These three files are exact, unchanged Git blobs from the pre-R1–R3 candidate. Their original names were prefixed with `original_` so normal test discovery does not execute historical false-positive probes. They are not imported by the active adapter, fixture or test suite. The move is a mechanical 100% rename, not a rewrite or retroactive approval of the old evidence.

The old count-first synthetic fixture and supplied-bit reduction are intentionally historical only. Current execution enters `../prospective_admission.py` and uses the complete primitive fixture in `../synthetic_records.py`. See `../ADAPTER_RECORDS.md` for the current record contract and `../verify_r1_r3.py` for repeatable author-side checks.

Original blob identities:

- prospective_admission.py: `1c7ec1fe35041d8a07cf14644b76757a452a914a`
- synthetic_evidence.py: `957fd13e036cf31498a4ca4dc2f4b4ffa0f93106`
- test_prospective_admission.py: `e22ebdb0f203457d8ed64b7df7ad24ca0f4e8b8d`
