shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Mur de la Brume : rideau jaune-vert, plus dense en bas, qui ondule lentement.

uniform vec4 couleur : source_color = vec4(0.78, 0.84, 0.52, 1.0);
uniform float densite = 0.55;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float ang = atan(wpos.z, wpos.x);
	vec2 p = vec2(ang * 40.0 + TIME * 0.4, wpos.y * 0.08 - TIME * 0.15);
	float n = noise(p) * 0.6 + noise(p * 2.7) * 0.4;
	float h = clamp(1.0 - (wpos.y + 10.0) / 140.0, 0.0, 1.0);
	ALBEDO = couleur.rgb * (0.85 + 0.3 * n);
	ALPHA = densite * (0.35 + 0.65 * h) * (0.75 + 0.25 * n);
}
