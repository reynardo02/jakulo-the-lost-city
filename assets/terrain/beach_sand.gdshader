shader_type spatial;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float grain = fract(sin(dot(floor(world_pos.xz*90.0),vec2(12.9898,78.233)))*43758.5453);
	float wet = 1.0-smoothstep(-0.65,-0.25,world_pos.y);
	vec3 dry = vec3(0.59,0.46,0.29);
	vec3 damp = vec3(0.28,0.23,0.15);
	ALBEDO = mix(dry,damp,wet)+(grain-0.5)*0.045;
	ROUGHNESS = mix(0.95,0.45,wet);
}
