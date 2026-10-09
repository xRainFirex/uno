// ==========================================
// FILE: felt.gdshader
// DESCRIPTION: Pixel-art table background: chunky pixels, a dithered radial gradient, a diamond weave
//              and a vignette, all quantised to a small palette for a retro look.
// VERSION: v0.100
// ==========================================
shader_type canvas_item;

uniform vec4 center_color : source_color = vec4(0.10, 0.30, 0.27, 1.0);
uniform vec4 edge_color : source_color = vec4(0.02, 0.06, 0.08, 1.0);
uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform float pixel_size = 5.0;
uniform float levels = 10.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int index = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[index] / 16.0 - 0.5;
}

void fragment() {
	// Snap to a coarse pixel grid.
	vec2 cell = floor(UV * rect_size / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size / rect_size;
	vec2 aspect = vec2(rect_size.x / rect_size.y, 1.0);
	vec2 d = (uv - vec2(0.5, 0.52)) * aspect;
	float r = length(d * vec2(0.85, 1.15));
	// Dithered, quantised gradient between the two mood colours.
	float t = smoothstep(0.05, 1.05, r);
	t = floor(t * levels + bayer4(cell) + 0.5) / levels;
	vec3 col = mix(center_color.rgb, edge_color.rgb, clamp(t, 0.0, 1.0));
	// Diamond weave every 8 cells.
	vec2 g = cell / 8.0;
	float diamond = abs(fract(g.x + g.y) - 0.5) + abs(fract(g.x - g.y) - 0.5);
	col += step(0.94, diamond) * 0.035;
	COLOR = vec4(col, 1.0);
}
