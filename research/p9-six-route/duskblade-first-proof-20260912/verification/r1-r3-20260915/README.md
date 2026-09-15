# R1–R3 exact-code author evidence — review pending

Tested code commit: `f8a6bd076c55feeab2a99266deb65e8e6a8c34c3` on the existing `research/p9-six-route-local-20260905` branch. Later publication commits add evidence only; they do not change the tested code. Current-main instructions were read and rechecked at `07b5aa9dec8436132a524511d5438c510e322070`.

## Result and reproduction

The final exact-byte run used Python 3.13.5 and passed 57 entry/primitive test methods plus an explicit 16-method unchanged reference-kernel suite, with zero errors or failures. One entry test also invokes those same 16 kernel methods internally; this repeated invocation is not extra independent evidence. The run recorded 230 entry probe results. The coherent positive derives 204 counts and 152 PASS predicates from 40,960 fabricated trajectory records, with no overlapping paired gain/loss bits.

From the owned source directory:

```sh
python verify_r1_r3.py \
  --code-head f8a6bd076c55feeab2a99266deb65e8e6a8c34c3 \
  --output /tmp/d547-r1-r3-evidence \
  --export-fixture /tmp/d547-expanded
```

The complete [verification source](../../verify_r1_r3.py), [primitive fixture source](../../synthetic_records.py), [public entry](../../prospective_admission.py), [record/trust contract](../../ADAPTER_RECORDS.md), and all control implementations are committed plain-text files. No network, native executable or third-party Python package is needed for these checks.

## Complete captured artifacts

| File | Content |
|---|---|
| [AUTHOR-R1-R3-RUN.json](AUTHOR-R1-R3-RUN.json) | Exact code head, commands, runtime, test counts, per-source Git blobs, captured artifact SHA256/blob/size identities and zero-action declarations. |
| [AUTHOR-R1-R3-STDOUT.txt](AUTHOR-R1-R3-STDOUT.txt) | Complete final unittest output, including every method, both results and the unchanged-source assertion. |
| [AUTHOR-R1-R3-POSITIVE.json](AUTHOR-R1-R3-POSITIVE.json) | All 204 derived counts, all 152 predicates, every prediction stream, manifests and reconciled synthetic ledger. |
| [AUTHOR-R1-R3-PROBES.json](AUTHOR-R1-R3-PROBES.json) | All 230 recorded probe outcomes and their complete decision vectors; no filtering of adverse or deliberately mocked outcomes. |
| [AUTHOR-R1-R3-INPUTS.json](AUTHOR-R1-R3-INPUTS.json) | Complete submitted packet, external synthetic context identities/receipts, and every generated store locator with byte length and SHA256. |
| [AUTHOR-R1-R3-READBACK.json](AUTHOR-R1-R3-READBACK.json) | Remote code-tree readback matched to local tested blobs, protected-file identities, exact historical rename evidence and scope. |

`POSITIVE` scalar arrays use lossless `$rle` encoding, decoded by `verify_r1_r3.unpack`. `PROBES` gives the explicit ordered 152-key registry and code map P/F/I; a vector represents that entire predicate map. An empty vector means no predicates. Both encodings were round-trip checked during capture.

**Read the mock controls correctly:** `guard-deleted-*` and `digest-guard-deleted` intentionally disable a production guard under `unittest.mock`; the same malformed input is rejected with the real guard before and after. The single record named **`probe`** is likewise the deliberately mocked unconditional-PASS entry in `EntryTests.test_label_only_or_unconditional_pass_is_detected`. It is not a real-entry admission, and its empty predicate vector is intentional. The subsequent `load-bearing-packet-guard` record rejects the same fabricated-binding packet using the unmodified entry.

The deterministic fixture produces 56,424,156 store bytes. Those expanded fabricated input files are reproducible in full with `--export-fixture`; the GitHub delivery contains their complete generation source and byte-exact manifest rather than a duplicate 56 MB expansion. This is not a collection of empirical raw outcomes. The mock CPU values and mock receipt verdict strings are synthetic input data, not actual budget usage, approval or binding.

## Scope and residual gate

Actual native invocations: **0**. Actual new game outcomes: **0**. Actual binding: **none**. Independent review: **not performed**. Certificates: **false**. The real `ALLOCATION.json` remains its original zero-spend Git blob `824ff18acbca2f776533beed83a43b21d9a50f2c`; the restored design and numerical kernel are unchanged. Historical source is preserved as exact original blobs and is not imported or discovered as active tests.

The adapter consumes an externally authenticated native/extractor-record boundary; it does not authenticate receipt issuers or native MEC semantics by itself. Real extraction, external authorization and genuinely fresh, isolated exact-head review remain separate requirements. This evidence is author verification, not a reviewer verdict, #547 binding, #542 empirical PASS, #548 admission, C2/P9 closure or a release authorization.
