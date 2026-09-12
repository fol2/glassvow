# Single-asset Tripo trial

Question: can image-to-3D retain the approved Act I sculpted, painterly forms
better than the current purely constructive Blender gateway?

Use one gateway, not a batch or production replacement. Compare its native
55-degree Godot rendering with the current kit; inspect depth, the passage and
trefoil apertures, reverse surfaces, material response and topology after a
24,000-triangle trial reduction. Reject a visually weak or structurally closed
candidate. A successful preview does not qualify the whole asset pipeline.

`arch-reference.png` is derived with imagegen from the approved
`docs/map/concepts/act1-combat-aligned-v2.png`. The first reference had a four-lobed
opening; it was corrected to the required trefoil before upload. This isolated
modelling reference omits the lamps, brackets and surrounding landscape, so
they cannot be fused into the generated stone geometry.

On 5 September 2026, the reference was uploaded through the native Chrome file
chooser. The browser extension's direct file-chooser API lacked file-URL access;
no extension permissions were changed. Native Go To input required an ordinary
key event after text insertion before the path suggestion updated.

Tripo settings: HD Model v3.1 Best Quality, Geometry & Texture, Private,
Generate in Parts off, 8K Texture off. One generation consumed 55 existing
credits (915 to 860); no plan or credits were purchased.

Task: `e3e99453-7a1f-4933-8d9d-03be72222437`.
Generation completed and the original GLB was downloaded as
`/Users/jamesto/Downloads/stone archway 3d model.glb` (59,434,036 bytes).
SHA-256: `b6cacc9a9ebdfb020bf1f5be497a1c04f1f166f8f7732ac1bc59a8f459862a7f`.
No second Tripo generation was submitted.

`tools/map_atelier/journey/prepare_trial.py` prepares an isolated copy for review;
it does not replace the existing kit. It was exercised against the download:
1,977,064 triangles became 24,000 with UVs, base colour and normal maps retained,
normalised to 5.5 units tall. Use Blender's `--python-exit-code 1` flag so an
assertion cannot masquerade as a successful background process.

## Native findings and decision

`native-front.png` and `native-reverse.png` show the reduced initial copy under
the workshop's actual 55-degree camera. It retains stronger ashlar, carving and
reverse-side form than the constructive prototype, but the generated surface
was excessively glossy. The matte variant removes the metallic/roughness map,
sets metallic to zero and roughness to 0.92, and reduces normal strength to 0.45.
The original download and initial reduced copy remain unchanged.

The thick ornamental web partly concealed its own trefoil at the game camera.
The `--thin-web` variant compresses only the central ornamental depth with a
smooth spatial transition; the main outer arch and piers retain their depth.
Read-only BVH probes confirm the door is clear and piers remain solid. Clear
rays through the upper opening at 55 degrees increase from 5/11 to 9/11 sampled
centre rays (`geometry-matte.log`, `geometry-web.log`). This narrow geometry
check is corroborated by `native-context-web.png`, where the trefoil is visibly
clearer than `native-context.png`.

The latest trial is `assets/art/map-journey/trials/tripo-arch-web.glb`.
The separate original Blender `lamp-pair.glb` adds paired bronze/amber lamps;
Godot adds real local illumination. `--assets --site --trial=res://...` selects
the candidate in the generator-backed native context. `--gallery --trial=res://...`
selects it on the asset sheet. Neither flag changes the production map.

Decision: continue with this generated-and-edited sculpted gateway as the leading
asset candidate. The single-asset method has earned further use; it does not
qualify an unattended batch, foliage, the entire kit, or Step 3 completion.
Other assets still need a matching level of surface treatment and silhouette
quality. The current context retains greybox terrain and an off-road landmark
placement, so it is not a finished section or the owner-review presentation.
