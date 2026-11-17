shader_type spatial;
render_mode blend_mix, depth_draw_never;
uniform vec4 paths[8];
uniform int path_count = 0;
uniform float width = 0.8;
uniform float opacity = 0.82;
varying vec2 world_xz;
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	float d = 1000.0;
	for (int i=0; i<8; i++) {
		if (i >= path_count) { break; }
		vec2 a = paths[i].xy;
		vec2 ab = paths[i].zw - a;
		float t = clamp(dot(world_xz-a, ab) / max(dot(ab,ab),0.001),0.0,1.0);
		d = min(d,length(world_xz-a-ab*t));
	}
	float grain = sin(world_xz.x*23.1)*sin(world_xz.y*19.7);
	float edge = sin(world_xz.x*2.7+world_xz.y*1.2)*0.12;
	ALBEDO = vec3(0.21,0.15,0.085) + grain*0.018;
	ROUGHNESS = 0.98;
	float patches = mix(0.65,1.0,0.5+0.5*sin(world_xz.x*1.7+sin(world_xz.y*0.8)));
	float softness = clamp((0.82-opacity)*2.0,0.0,1.0);
	ALPHA = (1.0-smoothstep(width*mix(0.6,0.35,softness),width+mix(0.35,0.55,softness),d+edge))*opacity*mix(1.0,patches,softness);
}
