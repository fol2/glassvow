shader_type canvas_item;
// CSS `filter: drop-shadow(dx dy blur colour)` for one opaque rectangle.
//
// The title banner is `styles.css:343`:
//
//   .title-banner .raster-art { ... filter: drop-shadow(0 12px 40px rgba(0,0,0,.6)); }
//
// and the port carried the plate's three ratios but never the filter, so the
// raster ended flush against the living sky with a hard rectangular cut on
// three sides. That edge is the whole reason the plate read as a pasted patch
// rather than as something lying over the night.
//
// Nothing is sampled. `background.png` is RGB with no alpha channel, so its
// drop-shadow is by definition a blurred axis-aligned RECTANGLE — which has a
// closed form, separable in x and y. That is cheaper than a two-pass blur, has
// no texture read at all, and cannot band.
//
// CSS states the third argument as a blur RADIUS and defines it as twice the
// Gaussian standard deviation, so `sigma` here is 20 for a 40px filter.

uniform vec2 ctrl_size = vec2(1.0, 1.0);
/// The shadow's rectangle in this Control's pixels — the plate, already moved
/// by the filter's offset.
uniform vec2 box_min = vec2(0.0);
uniform vec2 box_max = vec2(1.0);
/// The plate's OWN rectangle, unmoved. Subtracted because CSS applies the
/// group's `opacity: 0.35` to the composite of shadow-under-image, and the
/// image is opaque: no shadow survives behind it. Two nodes each at 0.35 would
/// otherwise darken that overlap twice.
uniform vec2 plate_min = vec2(0.0);
uniform vec2 plate_max = vec2(1.0);
uniform float sigma = 20.0;
uniform vec4 shade : source_color = vec4(0.0, 0.0, 0.0, 0.6);

/// A Gaussian-blurred step. The exact answer is an erf, which the shading
/// language does not carry; this tanh form stays within about 1% of it, which
/// on a shadow this faint is far below one 8-bit level.
float blurred_step(float x, float s) {
	return 0.5 + 0.5 * tanh(1.2533 * x / max(s, 0.0001));
}

float band(float lo, float hi, float x, float s) {
	return blurred_step(x - lo, s) - blurred_step(x - hi, s);
}

void fragment() {
	vec2 p = UV * ctrl_size;
	float blurred = band(box_min.x, box_max.x, p.x, sigma)
		* band(box_min.y, box_max.y, p.y, sigma);
	float covered = step(plate_min.x, p.x) * step(p.x, plate_max.x)
		* step(plate_min.y, p.y) * step(p.y, plate_max.y);
	COLOR = vec4(shade.rgb, shade.a * clamp(blurred - covered, 0.0, 1.0));
}
