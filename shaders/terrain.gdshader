shader_type spatial;
// Sol de l'île : herbe par défaut, puis sable, chemins, pavés, béton et roche selon les
// cartes de mélange produites par tools/gen_island.py. Textures de Dernière Vague.

uniform sampler2D sols : filter_linear, repeat_disable;       // R sable, G roche, B chemin, A pavés
uniform sampler2D sols2 : filter_linear, repeat_disable;      // R béton
uniform sampler2D t_herbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_sable : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_roche : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_chemin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_paves : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_beton : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float world_size = 640.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.yz * s).rgb * w.x + texture(t, p.xz * s).rgb * w.y + texture(t, p.xy * s).rgb * w.z;
}

void fragment() {
	vec2 uv = wpos.xz * 0.22;
	vec4 s = texture(sols, UV);
	float beton = texture(sols2, UV).r;
	// Deux échelles d'herbe pour casser la répétition, teinte de garrigue.
	vec3 herbe = mix(texture(t_herbe, uv).rgb, texture(t_herbe, uv * 0.17).rgb, 0.45);
	herbe *= vec3(1.05, 1.0, 0.72);
	vec3 col = herbe;
	col = mix(col, texture(t_chemin, uv * 0.9).rgb * vec3(1.9, 1.75, 1.5), s.b);
	col = mix(col, texture(t_sable, uv * 0.6).rgb, s.r);
	col = mix(col, texture(t_paves, wpos.xz * 0.35).rgb * vec3(1.08, 1.0, 0.86), s.a);
	col = mix(col, texture(t_beton, uv * 1.2).rgb * vec3(0.9, 0.88, 0.82), beton);
	col = mix(col, tri(t_roche, wpos, wnorm, 0.12) * vec3(1.05, 1.0, 0.92), s.g);
	// Sable mouillé et fonds marins plus sombres.
	col *= mix(0.55, 1.0, smoothstep(-1.5, 0.9, wpos.y));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.6, smoothstep(0.9, -0.3, wpos.y));
	SPECULAR = 0.2;
}
