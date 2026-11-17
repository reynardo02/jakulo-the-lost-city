shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform float wet_level = -0.4;
varying float world_height;
void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	float wet = 1.0 - smoothstep(wet_level - 0.15, wet_level + 0.12, world_height);
	ALBEDO = vec3(0.055, 0.08, 0.045);
	ROUGHNESS = 0.32;
	ALPHA = wet * 0.28;
}
