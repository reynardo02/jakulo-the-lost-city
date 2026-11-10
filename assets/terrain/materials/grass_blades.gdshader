shader_type spatial;
render_mode cull_disabled;
// Grashalme für scripts/grass_field.gd. Farbe kommt aus derselben Welt-Textur wie der Boden,
// dadurch gehen Halme und Boden ineinander über. Leichter Wind über die Welt-Position.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_size = 3.0;              // wie grass_ground.gdshader
uniform vec3 tip_tint : source_color = vec3(1.25, 1.3, 0.95);
uniform vec3 root_tint : source_color = vec3(0.45, 0.55, 0.4);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.4;
uniform vec2 wind_dir = vec2(1.0, 0.35);

varying vec3 world_root;

void vertex() {
	// UV.y: 0 = Spitze, 1 = Wurzel
	float bend = pow(1.0 - UV.y, 2.0);
	world_root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = dot(world_root.xz, vec2(0.21, 0.17)) + TIME * wind_speed;
	float gust = sin(phase) * 0.7 + sin(phase * 2.3 + 1.7) * 0.3;
	vec3 offset_world = vec3(wind_dir.x, 0.0, wind_dir.y) * gust * wind_strength * bend;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;
}

void fragment() {
	vec3 ground = texture(albedo_tex, world_root.xz / tile_size).rgb;
	ALBEDO = ground * mix(tip_tint, root_tint, UV.y);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
