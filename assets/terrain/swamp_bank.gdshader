shader_type spatial;
// Uferböschung der Sumpfinseln: oben ausfransender Grasrand, darunter Erde mit Wurzelfasern,
// an der Wasserlinie dunkler, glänzender Schlamm. Höhen sind lokal zur Insel (Oberkante y = 0).

uniform vec3 earth_color : source_color = vec3(0.30, 0.22, 0.14);
uniform vec3 mud_color : source_color = vec3(0.14, 0.11, 0.07);
uniform vec3 grass_color : source_color = vec3(0.24, 0.34, 0.12);
uniform float waterline = -0.4;   // lokale Höhe der Wasseroberfläche zu Beginn
uniform float grass_amount = 1.0; // 0 = reine Schlammbank

varying vec3 world_pos;
varying float local_y;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_y = VERTEX.y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = world_pos.xz + world_pos.y * 0.7;
	float n = noise(p * 3.0) * 0.6 + noise(p * 11.0) * 0.4;
	// senkrechte Wurzelfasern
	float fibres = smoothstep(0.75, 0.95, noise(vec2((world_pos.x + world_pos.z) * 9.0, world_pos.y * 1.2)));
	vec3 col = mix(earth_color * 0.85, earth_color * 1.15, n);
	col = mix(col, vec3(0.36, 0.27, 0.17), fibres * 0.6);
	// nasser Schlamm um die Wasserlinie und darunter
	float wet = smoothstep(waterline + 0.28, waterline - 0.05, local_y + (n - 0.5) * 0.12);
	col = mix(col, mud_color, wet);
	// ausfransender Grasrand oben
	float grass = smoothstep(-0.16, -0.02, local_y + (n - 0.5) * 0.1);
	col = mix(col, grass_color * (0.8 + n * 0.4), grass * grass_amount);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.35, wet);
	SPECULAR = mix(0.25, 0.5, wet);
}
