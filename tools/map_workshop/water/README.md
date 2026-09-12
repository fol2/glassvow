# Shared top-down water study

One horizontal mesh per continuous body, one shader, three shared procedural textures. This is a Step 3 rendering module, not campaign integration. Act II uses it now; Act I retains its approved study pending an explicit migration review. Act III and IV can supply mood settings without copying the shader.

```gdscript
const Water = preload("res://tools/map_workshop/water/surface.gd")
var surface: Water = Water.new()
var footprint: PlaneMesh = PlaneMesh.new()
footprint.size = Vector2(40, 60)
surface.configure(footprint, preload("res://tools/map_workshop/water/presets.gd").drowned_city())
surface.position.y = water_level
world.add_child(surface)
```

For a river or irregular lake, pass a horizontal, upward-facing ArrayMesh clipped to the basin instead of a rectangle. Positions use world XZ; moving or resizing the mesh does not stretch the ripple textures. Keep one water level per body and avoid overlapping surfaces. The caller owns opaque banks, submerged beds and structures: water colour cannot manufacture their relief.

Each surface owns its material and capture clock; noise textures are cached and shared. `set_capture_time(seconds)` freezes motion for repeatable captures; `set_capture_time()` restores live time. Procedural texture seeds are local and do not consume gameplay randomness. The quiet-river preset is a starting point, not an approved replacement for Act I.

## Rendering decisions

- Reverse-Z scene depth is reconstructed through the inverse projection matrix. The compatibility NDC branch is present, but current visual qualification is the provisioned Mobile renderer.
- View-space thickness controls light absorption. Reconstructed vertical depth controls the shore band so its world width does not change with the camera angle.
- Two seamless normal textures scroll in different directions. Their world slopes are transformed into view space for lighting and screen distortion.
- Refraction rejects samples above the water or in front of the surface. Screen edges clamp instead of wrapping.
- Restrained broken contact foam and optional shallow caustics avoid white outlines and sparkling deep water.
- Screen colour is composited once with depth colour. Alpha is one because a second blend would count the bed twice; the screen-reading material still requires the transparent rendering pass.
- No SSR, reflection camera, extra viewport, collision, buoyancy or displaced wave mesh.

The source reference is the owner's corrected top-down-water research attachment supplied on 6 September 2026. Its example was adapted rather than copied verbatim, particularly normal-space refraction, vertical shore depth and double transparency blending.

## Rounded toon-water revision

The owner requested a stylised alternative using these references:

- [NekotoArts: Wind Waker Water](https://godotshaders.com/shader/wind-waker-water-no-textures-needed/)
- [Megalithium: Toon Style 3D Water](https://godotshaders.com/shader/toon-style-3d-water-shader-no-textures-needed/)

Both use layered circular patterns. This implementation takes that visual principle, with an independently generated periodic distance field: rounded broken crests and a second drifting colour layer. The field is generated once on the CPU, cached with mipmaps and shared between water bodies. It replaces the previous foam-noise texture; it does not add another texture. No reference shader code or circle-coordinate table is copied.

The per-fragment budget remains seven texture lookups (two normals, two pattern layers, two depth samples, one scene-colour sample), with no procedural circle loop, fractal noise loop, extra mesh subdivision or additional render target. This is an operation budget, not a device-performance claim. The same shallow-water transmission and foreground rejection remain. Screen derivatives soften distant crests to reduce aliasing; a world-pixel-footprint fade reduces their contrast in the whole-act view. `toon_strength` and `crest_colour` control the graphic treatment; the city's lighting and muted palette still govern the result.
