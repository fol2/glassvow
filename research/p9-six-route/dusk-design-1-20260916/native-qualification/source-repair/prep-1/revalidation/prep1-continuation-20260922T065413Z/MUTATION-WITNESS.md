# PREP-1 — new verification of retained NEW mutation evidence

Authority: #542/5757861057. Verification run `prep1-continuation-20260922T065413Z`; observed 2026-09-22T07:22:50.675179+00:00. Actual connected execution belongs to `prep1-revalidation-20260921T211017Z`, not this continuation. No missing original PREP-1 record was recovered and no connected command was rerun.

## Exact recoverable input

At evidence head `5d40619df0511c158069ed58db8b9cd6edc0a761`, sibling `../prep1-revalidation-20260921T211017Z/semantic-and-mutation.json` is independently decodable. Whole wrapper Git blob `d1fe923841392fb3768d00860cf4c79a6b7b7f88`, 34,522 bytes; XZ bytes 24,108, SHA256 `96a3e61af0ef5a698a4f88c5f0162e610dea8e6b9a59fc6f204420b51386a860`; decoded bytes 1,048,046, SHA256 `2de8f1e46b7daf748c52b0010d7c59f0c906bb65650eb74c3ac0273feb0598b9`. This continuation verified all of those identities and restored all sixteen original raw records to their exact recorded byte length and SHA256. No tail or missing continuation part is needed.

## Stronger witness: data changed, was used, and was not promoted

In restored `mutate-restore.json` (84,466 bytes, SHA256 `f701625860a450249fb4ea1da6b41cec84ab396bcdf6400561060a78830da414`), actual captured `derived/0/imported/probe.resource` is exactly:

```text
DD1-INERT-RESOURCE:quality=9:ASSET-INERT
```

Its actual captured `derived/1` is:

```ini
; DERIVED-INERT
[remap]
importer="dd1_inert"
type="Resource"
uid="uid://dd1seed"
path="res://.godot/imported/probe.resource"

[deps]
source_file="res://assets/probe.bin"
dest_files=["res://.godot/imported/probe.resource"]

[params]
quality=7
```

Both shown byte strings include a final LF. Thus this is not merely an unsuccessful mutation attempt or a final-hash-only test: the resource contains quality 9 while the sidecar again presents quality 7.

The retained mutation audit has 23 events, reads 512 bytes, journal SHA256 `4812444fa330a49ad03d6cce31dcf170c340a215ea93c5df3e6c3103aff0216d`, and error `unqualified seed read/rewrite history:1`. Seed state 1 reports access_before_write=true, closes=2, modified=true, writing=false. Both audit.ok and seed_history.ok are false. Raw journal bytes were rehashed and matched the audit. The observation explicitly limits this to `SUPPORTING_KERNEL_ORDERING; NOT COMPLETE READ/CALL TRACE`.

Controller exit is 0 because it successfully recorded the negative test. Actual task success is false, cleanup_confirmed is true, task_outcome.ok is false, sealed_preparation is null, and the synthetic account row is FAILED. No native qualification or N0 acceptance is asserted.

## Sixteen full negative records checked

For every record below, verification checked the original restored bytes/SHA256, complete controller stdout/result agreement, empty controller stderr, synthetic account and unchanged historical section, failed task with no seal, cleanup, full reserved charge, and raw UNIT-RESULT/journal consistency. Per the exact `reserve_and_run` source at I, UNIT-RESULT contains `{unit: reservation, result: observation}`; the returned controller object additionally has `charged` and `n0_accepted=false`. It is not the same schema as the nested observation.

| Record | Original bytes | Original SHA256 |
|---|---:|---|
| alias | 88912 | e98e4757f9c573e8292d4a5220201fa01032699bc42c5731f3e6d41178ed3dbd |
| config-mutation | 83491 | ed98e44502f52dca576c2909f760dd21b157264817bef4cc07e73a4e65a86232 |
| double-write | 84377 | 67bef4c035563d2bfac1ee9bdc399affa4f5e39240abcd3217453a8bc5a084a1 |
| failed | 83179 | 656a7b34c3db0ab122a27ddd65b5b3f1f2338561c0a849759b387c06157f81ff |
| hardlink | 88888 | 3cd208191f7326038c6d1339cc144e357e1c6fdbed2f1297d3390b205815c2ee |
| incomplete | 82981 | 07598729ae2f4435de5406580a47286dbbb67cfd12a15eaf84c3b1e97b44fa81 |
| invalid | 83231 | 422a30f6adc6089af39bdcd4743eb7c6c344fb1f9630fe5d09db30d1535eb8d0 |
| malformed | 82710 | 1868e19727739f87bbe87ddecf2bf61936da951e3cf2e43d50081dab5934a829 |
| missing-resource | 83218 | 6b7cb53a34c0aa7dfb67fba8d37c40adff00819b0477318edca751b3d8af0aa3 |
| mutate-restore | 84466 | f701625860a450249fb4ea1da6b41cec84ab396bcdf6400561060a78830da414 |
| never-read | 85693 | 2e80211d0003914f6d9f190716a326f1d31a6f8d2d287ddbd0c74ead38ab7e68 |
| source-mutation | 83418 | edcbdf8166c5cccdcbfa406406187371e6c83d9401298c0f76fc41b042bf9686 |
| undeclared | 84737 | 1c7878ffc9cec03829f55095c0575897667baa8058844be62e0c70b975183cfd |
| wrong-param | 83454 | 1fe58d7fa2f6523739a661c308b2b75d821293eb05e7342863a468b053da778e |
| wrong-source | 83482 | 1d23c2022a9f8be4976fac7b9b0d06a487a408a8982fc7b43a39f38596d4cc5c |
| wrong-uid | 83425 | 49c2bf20489bb3a2e2388bddda682c6f9b723f4898cb7e7b6fe9dd29efb41c83 |

All sixteen are correctly rejected without promotion. UID/parameter/source/incomplete cases specifically fail semantic identity; malformed fails incomplete import string; invalid fails invalid generated sidecar; missing-resource fails unexpected empty generated directory. Never-read, double-write and mutate-restore all have false seed-history verdicts. Other negative paths fail successful enforcement/task-exit prerequisites; this statement does not relabel every failure as a semantic-reader rejection.

Every failed connected case retains its synthetic reservation of one start, 16,000,000,000 CPU ns and 12,582,912 raw bytes. These are reserved envelopes, not measured CPU, live-account spending or a refund. The final sixteen-case readback predicate pass itself measured 0.014043097000012494 wall seconds and 0.013997 reader CPU seconds; these narrow measurements exclude transport, earlier inspection/decoder corrections and analysis, and confer no historical-account credit.

Implementation remains I=`d4e91e4fc70d57c81922cc1883b339877d835a53`. Actual Godot seed consumption, engine import semantics and whole native writer closure are not established by this inert witness. N0 remains BLOCKED, certificates 0/3. This document is evidence authoring, not self-approval or an independent review.
