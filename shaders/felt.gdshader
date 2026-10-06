// ==========================================
// FILE: felt.gdshader
// DESCRIPTION: Card-table background: radial felt gradient, subtle diamond weave, grain and vignette.
// VERSION: v0.100
// ==========================================
shader_type canvas_item;

uniform vec4 center_color : source_color = vec4(0.10, 0.30, 0.27, 1.0);
uniform vec4 edge_color : source_color = vec4(0.02, 0.06, 0.08, 1.0);
uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform float pattern_strength = 0.018;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 aspect = vec2(rect_size.x / rect_size.y, 1.0);
	vec2 d = (UV - vec2(0.5, 0.52)) * aspect;
	float r = length(d * vec2(0.85, 1.15));
	vec3 col = mix(center_color.rgb, edge_color.rgb, smoothstep(0.05, 1.05, r));
	vec2 g = UV * rect_size / 34.0;
	float diamond = abs(fract(g.x + g.y) - 0.5) + abs(fract(g.x - g.y) - 0.5);
	col += smoothstep(0.46, 0.5, diamond) * pattern_strength;
	col += (hash(floor(UV * rect_size)) - 0.5) * 0.03;
	col *= 1.0 - smoothstep(0.55, 1.25, r) * 0.45;
	COLOR = vec4(col, 1.0);
}
