# PREP-1 publication recovery — INCOMPLETE, missing retained bytes

This is a publication-only recovery record under #542/5754063752, not a final PREP-1 evidence receipt, test result, review, acceptance or launch admission. The current source identity remains I=`d4e91e4fc70d57c81922cc1883b339877d835a53`, tree `f635cace1f659b236590cd44ed502841233d2d93`. PREP-1 base is `36c607355bb7add7968ae51bf7b738c2c078d7d8`. Current-main instructions were refreshed at `07b5aa9dec8436132a524511d5438c510e322070` (AGENTS `114f0215fdc211b7171b073e767dfef37f1055f2`, AI-SDLC `22dd5f564ef9d2964506cba39c0b86fe94854afe`). No packaged script, helper, checker, test or engine was executed.

## Retained input actually available

The active runtime did not contain the original final PREP-1 TRANSPORT.json, tar parts or 284-record directory in its /mnt/data inventory; the bounded /tmp and /home/oai/share recovery check found no PREP-1 work directory. The original supplied `prep-publication-readback.png` IS mounted: 328829 bytes, SHA256 `57b4e72f5a999e5798bc8f3b8b6a9e403ac5e5235370c6ecf709039b4374c770`. It displays the final TRANSPORT.json fields and RESULTS.json summary. The earlier COMPAT-2 ZIP and engine-transfer files are different artifacts and were not substituted.

`TRANSPORT-FROM-READBACK.json` is a visual transcription of that displayed manifest, with the same recorded field values. It is NOT asserted byte-identical to the unavailable original JSON file: whitespace/serialization are newly emitted. Its recorded chunk hashes, whole-archive hashes and record count remain expectations, not newly computed archive results. Transcription integrity checks validated hexadecimal lengths and the 239664-byte part sum. One initial transcription omitted a character from part03's SHA256; the length check rejected it and the enlarged original image supplied the corrected `...95d931bfbdac...` value before publication. No result data were reconstructed from the chat summary.

## Exact-object reconciliation

Three expected blobs already exist and have been reused without re-upload. GitHub directory/object readback reports 18000 bytes each, matching the displayed manifest's exact Git object identities:

| Part | Git blob | Readback |
|---|---|---|
| RECORDS.tar.xz.part01 | 842b8f7ceebea99766f895f3a6a7638429fccb91 | PRESENT, 18000 bytes |
| RECORDS.tar.xz.part02 | 7fcb6cf11585751f62deb03494fe520c039c48ae | PRESENT, 18000 bytes |
| RECORDS.tar.xz.part03 | 275609f89cbb0626999367e2b4ef88d2ed7138f6 | PRESENT, 18000 bytes |
| RECORDS.tar.xz.part04 | fe19fe054aea46a5e86f744e1711b5416c9b4f08 | GET returned 404 |
| RECORDS.tar.xz.part05 | d19163319e12039ea23b149b5541e1b1a976a7ef | GET returned 404 |
| RECORDS.tar.xz.part06 | 5ac8d0e7c77db79f32aad44e96044c4a201b7094 | GET returned 404 |
| RECORDS.tar.xz.part07 | f6aa60282642a1841031cdd67cd695a96d666c12 | GET returned 404 |
| RECORDS.tar.xz.part08 | 1ba8a89d9fcada4daac4f386587bacd0545fd78a | GET returned 404 |
| RECORDS.tar.xz.part09 | 2640f56824cff77e44e89c3531e6105c686408f0 | GET returned 404 |
| RECORDS.tar.xz.part10 | e0f611d5f3e2c2ec7c4565036e6a813d4fc8d0f3 | GET returned 404 |
| RECORDS.tar.xz.part11 | 1fe5d0a5e37c98928cb440f5326eb5fdf6434f09 | GET returned 404 |
| RECORDS.tar.xz.part12 | 5f958d808541bc2191349193f96f74aad47f5bb5 | GET returned 404 |
| RECORDS.tar.xz.part13 | a4368ef33e5753c77b4e2e65e59e53d9a1706c30 | GET returned 404 |
| RECORDS.tar.xz.part14 | 0e0671f5cad881b0a8527366c8350e9c3b567a34 | GET returned 404 |

All eleven missing expected objects were checked individually through the ordinary GitHub interface. A tree creation referencing all fourteen was rejected with 422 at the first missing blob (part04); no ref changed. These responses establish unavailability at the specified content identities, not a general write-permission denial or proof that every possible old copy is absent.

Two other exact, previously submitted blobs were reconciled: `bb41910a11303a5db94b3c50b67fea9ecf503b39` is 18420 bytes and `e00fc7e5a0ef339f6792d8835cf5554b846ff52b` is 23445 bytes. Neither identity or length matches any of the fourteen expected parts. They remain separate unmatched submissions, not replacements, corrected logs or proof of original-record corruption. An unreferenced inspection commit `1310f16384d36a4e9652c22784c546130b3cc6fe` made the five known submissions readable by Contents API; it is not the tested source or a new branch. This publication preserves the unmatched transfer objects under `unmatched-submissions/` without counting them in the lossless payload.

## Byte-verification boundary

Recovered expected payload: 54000 of 239664 compressed bytes. Missing: parts04–14, 185664 compressed bytes. No complete join, XZ/TAR decode, 284-record restoration, per-record hash verification, original-to-derived-to-sealed map inspection, or final tested-source mapping verification was possible. The 45 connected groups, 32 H/binding/source checks, four metadata samples and 60 cleaned-up process identities remain original-author-reported; they have not been re-observed or validated here. No new RESULTS.json or execution logs were manufactured. Historical CHECKPOINT.json (`14f1ddb8dbf42fe28abef3f6594d0cefabeffdd9`) remains untouched and is not relabelled as the final exact-head run.

Present-part verification is Git-object identity and GitHub size readback, NOT local SHA256/decoded-byte verification. Binary fetch_blob failed UTF-8 decoding; fetch_file with `encoding=base64` supplied a readable ordinary binary surface after naming the existing objects. The obstacle to full decoding is the missing expected chunks, not a claimed absence of binary read capability. Direct container HTTPS also failed DNS; the separate download route's URL-view precondition could not be satisfied. Neither was retried through a restricted alternative. GitHub write calls succeeded.

## Preservation and next action

Only PREP-1 recovery evidence/transport and the existing source-repair capsule are changed. Every source/test/product/configuration/sidecar/supervisor file outside those allowed paths is inherited exactly from I; final GitHub comparison/readback is required before the handoff. Accepted COMPAT-2/B1/D/C/H/#547 and earlier evidence are not reopened. ACCOUNT remains blob `8b7e4e6367ad4bc366c04b930ef4fc3810e2a900`: recovery reported 2040/2048, historical 1277/8192, consumed attempt, UNKNOWNs and unspendable remainder preserved. Deadline `2026-09-24T17:54:40Z` is not extended. No account/reservation write, funding change, engine/contained start, review, approval, merge or release occurs.

The smallest missing input is the ORIGINAL `RECORDS.tar.xz.part04` through `part14` (or the intact original 239664-byte RECORDS.tar.xz) and preferably the original TRANSPORT.json. Expected archive SHA256 is `3ad76192ea0038b380b9e8086418330782428f4c41a4485b4121292e18a694d6`. Recover those bytes from the prior environment/retained files; do not regenerate tests, logs or cache contents. Then upload only verified missing chunks, decode and verify the original 284 records, finish the actual final evidence/capsule and one completed handoff. This recovery anchor is a save, not completed PREP-1 publication or a review-ready package.
