shader_type spatial;
render_mode cull_disabled;
// Mer : la couleur suit la profondeur lue dans le relief (turquoise près des côtes, bleu nuit au
// large), écume au bord, petites vagues animées. Opaque : rien à trier, léger pour un téléphone.

uniform sampler2D hauteurs : filter_linear, repeat_disable;
uniform float world_size = 640.0;
uniform float h_min = -10.0;
uniform float h_range = 64.0;
uniform vec3 peu_profond : source_color = vec3(0.24, 0.62, 0.64);
uniform vec3 profond : source_color = vec3(0.04, 0.16, 0.27);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ground(vec2 xz) {
	vec2 uv = xz / world_size + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return h_min;
	}
	vec3 c = texture(hauteurs, uv).rgb;
	float v = floor(c.r * 255.0 + 0.5) * 256.0 + floor(c.g * 255.0 + 0.5);
	return v / 65535.0 * h_range + h_min;
}

void fragment() {
	float depth = max(0.0, -ground(wpos.xz));
	float t = TIME;
	vec2 p = wpos.xz;
	float w1 = sin(p.x * 0.21 + t * 1.3) * cos(p.y * 0.17 - t * 0.9);
	float w2 = sin(p.x * 0.73 - p.y * 0.51 + t * 2.1);
	// Les vagues s'estompent au loin (sinon elles scintillent en moiré sur un petit écran).
	float near = smoothstep(350.0, 40.0, length(wpos - CAMERA_POSITION_WORLD));
	vec3 n = normalize(vec3((w1 * 0.08 + w2 * 0.04) * near, 1.0, (w2 * 0.05 - w1 * 0.06) * near));
	vec3 col = mix(peu_profond, profond, pow(clamp(depth / 9.0, 0.0, 1.0), 0.6));
	float foam = smoothstep(1.2, 0.0, depth) * (0.55 + 0.45 * sin(t * 1.7 + p.x * 0.3 + p.y * 0.2));
	col = mix(col, vec3(0.9, 0.95, 0.95), foam * 0.6);
	ALBEDO = col;
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
