# #462 — TestFlight build-4 map defect corpus

This packet freezes the visual baseline for TestFlight `1.0.0 (4)`. It records the production map as shipped; it does not tune the generator, camera, materials, layout, or assets.

## Immutable bindings

- Build-4 production source: `52a56e726da70c2dd57254e8c6618682c7558f90`.
- Godot: exact runtime string recorded in every generated `manifest.json`; the workflow installs `4.7.2` and rejects any version not beginning `4.7.2.stable`.
- Asset manifest: `res://assets/art/map/map-assets.json`; its SHA-256 is computed before capture, passed into the driver, independently recomputed there, and recorded in the manifest.
- Capture head: the wrapper requires the full checked-out `git rev-parse HEAD`, and the generated manifest records it. Local capture refuses when production inputs differ from the build-4 source commit (`--on-production-drift=fail`, the default). GitHub Actions detects that drift first and skips capture green rather than regenerating a later map or painting the tree red.
- Frozen capture packet: GitHub Actions run [32790383346](https://github.com/fol2/glassvow/actions/runs/32790383346) at `4fe17d40b51178fe2f9a1e92d848787b3dc337c7`, artifact `build4-map-defect-corpus-4fe17d40b51178fe2f9a1e92d848787b3dc337c7`. Later rebases onto `main` must not recapture; production had already drifted.
- Locale: `en`.

The fixed matrix is 168 frames:

- generated Acts I–III: seeds `717` and `17634`;
- authored Act IV: seed binding `717` (the authored first-clear road does not use a generated-map seed);
- all `StageShape.SHIPPING`: `pad-landscape`, `desktop-landscape`, `phone-landscape`;
- all four `MapCameraRig.ZOOM_STOPS`: indices `0..3`, sizes `12`, `16`, `20`, `28`;
- camera poses: canonical `opening` (`MapCameraRig.DEFAULT_XZ`) and `focused` (the production `WorldMapScreen.refresh → _seat_marker → _focus_xz` path).

Every raw frame filename carries act, seed, shape, zoom stop/size, pose, and locale. The manifest repeats those dimensions and records the resolved camera XZ, viewport, map region, node/reachable counts, post-map RNG cursor, and active asset paths.

## Rebuild command

From the repository root, with Godot 4.7.2, Pillow, and an X display (or `xvfb-run` on Linux):

```bash
tools/capture_build4_map_corpus.sh \
  --verify-repeat \
  --output artifacts/build4-map-corpus
```

That one command:

1. verifies the exact checked-out head and the build-4 production boundary;
2. hashes `map-assets.json`;
3. captures the 168-frame matrix twice with the production `WorldMapScreen`;
4. validates every PNG and filename dimension;
5. requires byte-identical `manifest.json` and `dimensions.json` across the two runs;
6. writes diagnostic PNG hashes and a `repeatability.json` report;
7. produces seven labelled contact sheets while retaining both raw runs.

`pixel-hashes.json` is diagnostic, not the cross-machine acceptance contract. GPU/driver implementation, anti-aliasing, PNG encoder details, and font rasterisation can change pixels without changing the matrix. Within the pinned GitHub Actions runner, the repeat report records whether the two immediate runs are pixel-identical; manifest and dimensions must always be identical.

## Evidence layout

- `docs/reviews/462/contact-sheets/`: compact review sheets from the first successful 168-frame capture. The GitHub Actions artifact `build4-map-defect-corpus-<full-head>` is the packet bound to the HEAD that produced it.
- `docs/reviews/462/defect-ledger.csv`: stable defect-class IDs and exact frame references, or `NOT_OBSERVED` for a class absent from this corpus.
- `docs/reviews/462/summary.md`: architectural-vs-asset classification only; no fixes.
- `docs/reviews/462/device/`: owner-supplied TestFlight/device images, kept separate from desktop/Xvfb evidence. None were supplied for this packet.
- GitHub Actions artifact `build4-map-defect-corpus-<full-head>`: both raw 168-frame runs, canonical manifest/dimensions/hash indexes, contact sheets, and repeatability report.

The desktop/Xvfb corpus proves reproducibility of the checked-in production composition. It is not evidence of iPhone GPU output, safe-area behaviour, touch interaction, or TestFlight packaging.
