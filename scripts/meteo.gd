class_name Meteo
extends Node
## Météo d'une partie, tirée au sort au début :
##  - le soleil descend au fil des phases : on finit au coucher du soleil puis au crépuscule
##    (le phare s'allume et balaie l'île) — dans toutes les parties ;
##  - « pluie » : le ciel se couvre, la pluie tombe (souvent un orage avec éclairs et tonnerre), puis
##    elle passe avant la fin ; elle couvre le bruit des pas et réduit la visibilité ;
##  - « brouillard » : un épais brouillard marin au départ, qui se lève vers la phase 3 ;
##  - « beau » : rien d'autre que le coucher du soleil.
## Tout revient à l'éclairage d'origine à la fin de la partie.

const TYPES := {"beau": "Beau temps", "pluie": "Averse orageuse", "brouillard": "Brouillard marin"}
const POIDS := {"beau": 0.5, "pluie": 0.27, "brouillard": 0.23}

## Heure : [avancement 0..1, hauteur du soleil (°), couleur, énergie, haut du ciel, horizon,
## lumière ambiante, couleur du brouillard].
const CLES := [
	[0.0, 34.0, Color(1.0, 0.92, 0.8), 1.3, Color(0.26, 0.45, 0.72), Color(0.88, 0.78, 0.64), 1.0, Color(0.78, 0.74, 0.68)],
	[0.55, 20.0, Color(1.0, 0.85, 0.66), 1.2, Color(0.24, 0.4, 0.66), Color(0.92, 0.72, 0.52), 0.95, Color(0.82, 0.7, 0.6)],
	[0.8, 8.0, Color(1.0, 0.62, 0.38), 1.0, Color(0.2, 0.27, 0.5), Color(0.98, 0.55, 0.32), 0.85, Color(0.85, 0.6, 0.45)],
	[1.0, 1.5, Color(0.95, 0.42, 0.28), 0.8, Color(0.12, 0.13, 0.3), Color(0.75, 0.38, 0.32), 0.72, Color(0.45, 0.35, 0.4)],
]

static var courante: Meteo         # la météo de la partie en cours (null hors partie)

var type := "beau"
var avancement := 0.0              # 0 : début de partie, 1 : Brume refermée
var pluie := 0.0                   # 0..1
var brouillard := 0.0              # 0..1
var orage := false
var ile: Ile
var partie: Partie
var rng := RandomNumberGenerator.new()
var _pluie_debut := 0.4
var _pluie_fin := 0.82
var _orage_t := 0.0
var _eclair := 0.0
var _annonce_pluie := false
var _defaut := {}
var _gouttes: CPUParticles3D
var _bruit: AudioStreamPlayer
var _faisceau: Node3D
var _lampe: OmniLight3D


func setup(p: Partie, i: Ile) -> void:
	partie = p
	ile = i
	var sm := ile.env.sky.sky_material as ProceduralSkyMaterial
	_defaut = {"sun_rot": ile.sun.rotation_degrees, "sun_col": ile.sun.light_color, "sun_e": ile.sun.light_energy,
		"top": sm.sky_top_color, "hor": sm.sky_horizon_color, "amb": ile.env.ambient_light_energy,
		"fog_d": ile.env.fog_density, "fog_c": ile.env.fog_light_color, "fog_sky": ile.env.fog_sky_affect,
		"shadow": ile.sun.shadow_opacity, "gnd": sm.ground_horizon_color}
	if ile.lantern:
		for c in ile.lantern.get_children():
			if c is OmniLight3D:
				_lampe = c
		if _lampe:
			_defaut["lampe_e"] = _lampe.light_energy
			_defaut["lampe_r"] = _lampe.omni_range


## Tire la météo de la partie (ou beau temps si le réglage le demande).
func tirer(seed_value: int, force := "") -> void:
	rng.seed = seed_value + 99
	type = "beau"
	if force != "":
		type = force
	elif String(G.settings.get("meteo", "aleatoire")) == "aleatoire":
		var r := rng.randf()
		for k in POIDS:
			r -= float(POIDS[k])
			if r <= 0.0:
				type = k
				break
	orage = type == "pluie" and rng.randf() < 0.65
	_pluie_debut = rng.randf_range(0.18, 0.45)
	_pluie_fin = minf(_pluie_debut + rng.randf_range(0.3, 0.45), 0.85)
	brouillard = 1.0 if type == "brouillard" else 0.0
	pluie = 0.0
	_annonce_pluie = false
	courante = self
	_build()
	_appliquer(0.0)


func nom() -> String:
	return String(TYPES.get(type, ""))


func _build() -> void:
	if _gouttes == null:
		_gouttes = CPUParticles3D.new()
		_gouttes.amount = [350, 650, 1000][clampi(int(G.settings.qualite), 0, 2)]
		_gouttes.lifetime = 0.9
		_gouttes.local_coords = false
		_gouttes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_gouttes.emission_box_extents = Vector3(16, 1, 16)
		_gouttes.direction = Vector3(0.08, -1, 0.04)
		_gouttes.spread = 2.0
		_gouttes.gravity = Vector3.ZERO
		_gouttes.initial_velocity_min = 20.0
		_gouttes.initial_velocity_max = 24.0
		var q := QuadMesh.new()
		q.size = Vector2(0.025, 0.75)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.8, 0.85, 0.95, 0.35)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
		q.material = m
		_gouttes.mesh = q
		_gouttes.emitting = false
		_gouttes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_gouttes)
		_bruit = AudioStreamPlayer.new()
		_bruit.bus = "Ambiance"
		var s: AudioStream = G.sound("pluie")
		if s is AudioStreamWAV:
			s = (s as AudioStreamWAV).duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		_bruit.stream = s
		_bruit.volume_db = -80.0
		add_child(_bruit)
	# Le faisceau du phare (deux pinceaux de lumière qui tournent), visible au crépuscule.
	if _faisceau == null and ile.lantern:
		_faisceau = Node3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.9, 0.6, 0.0)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for side in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.6
			cm.bottom_radius = 3.5
			cm.height = 90.0
			cm.radial_segments = 8
			cm.rings = 1
			cm.cap_top = false
			cm.cap_bottom = false
			mi.mesh = cm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.rotation_degrees = Vector3(0, 0, 90.0 * side)
			mi.position = Vector3(45.0 * side, 0, 0)
			_faisceau.add_child(mi)
		_faisceau.set_meta("mat", mat)
		ile.lantern.add_child(_faisceau)
		var lamp_y := 0.0
		if _lampe:
			lamp_y = _lampe.position.y
		_faisceau.position = Vector3(0, lamp_y, 0)
		_faisceau.visible = false


## Avancement de la partie (0..1) d'après les phases de la Brume.
func _progres() -> float:
	if partie == null or partie.brume.phase == 0:
		return avancement
	var b := partie.brume
	var n := b.phase
	var ph: Array = Brume.PHASES[n - 1]
	var sub := 0.0
	if b.closing:
		sub = 0.5 + 0.5 * (1.0 - b.time_left / maxf(float(ph[1]), 0.01))
	else:
		sub = 0.5 * (1.0 - b.time_left / maxf(float(ph[0]), 0.01))
	if b.finished:
		return 1.0
	return clampf((n - 1 + clampf(sub, 0.0, 1.0)) / float(Brume.PHASES.size()), 0.0, 1.0)


func _process(delta: float) -> void:
	if courante != self:
		return
	avancement = maxf(avancement, _progres())
	# Pluie : arrive, tombe, puis passe.
	var cible := 0.0
	if type == "pluie" and avancement >= _pluie_debut and avancement < _pluie_fin:
		cible = 1.0
	pluie = move_toward(pluie, cible, delta / 25.0)
	if type == "pluie" and cible > 0.0 and not _annonce_pluie and partie:
		_annonce_pluie = true
		partie.announce.emit("ORAGE EN APPROCHE" if orage else "AVERSE EN APPROCHE", "La pluie couvre le bruit des pas")
	# Brouillard marin : se lève entre la phase 2 et la phase 3.
	if type == "brouillard":
		brouillard = clampf(1.0 - (avancement - 0.12) / 0.25, 0.0, 1.0)
	# Éclairs.
	if orage and pluie > 0.6:
		_orage_t -= delta
		if _orage_t <= 0.0:
			_orage_t = rng.randf_range(10.0, 26.0)
			_eclair = 1.0
			var d := rng.randf_range(0.4, 2.2)
			get_tree().create_timer(d).timeout.connect(func(): G.play("thunder", -6.0 - d * 2.0, rng.randf_range(0.85, 1.05)))
	_eclair = maxf(0.0, _eclair - delta * 5.0)
	_appliquer(delta)


func _cle(p: float) -> Array:
	for k in range(1, CLES.size()):
		if p <= float(CLES[k][0]):
			var a: Array = CLES[k - 1]
			var b: Array = CLES[k]
			var t := (p - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			var out := []
			for i in a.size():
				if a[i] is Color:
					out.append((a[i] as Color).lerp(b[i], t))
				else:
					out.append(lerpf(float(a[i]), float(b[i]), t))
			return out
	return CLES[-1]


func _appliquer(delta: float) -> void:
	var k := _cle(avancement)
	var sm := ile.env.sky.sky_material as ProceduralSkyMaterial
	var gris := pluie
	var flash := _eclair * (1.0 if _eclair > 0.6 or (_eclair > 0.25 and _eclair < 0.4) else 0.3)
	# Soleil : bas à l'ouest, de plus en plus orangé ; voilé sous la pluie.
	ile.sun.rotation_degrees = Vector3(-float(k[1]), float(_defaut.sun_rot.y), 0)
	ile.sun.light_color = (k[2] as Color).lerp(Color(0.75, 0.78, 0.85), gris * 0.7)
	ile.sun.light_energy = float(k[3]) * (1.0 - 0.6 * gris) + flash * 1.5
	ile.sun.shadow_opacity = lerpf(1.0, 0.35, gris)
	sm.sky_top_color = (k[4] as Color).lerp(Color(0.3, 0.33, 0.38), gris * 0.85).lerp(Color(0.8, 0.82, 0.86), brouillard * 0.6)
	sm.sky_horizon_color = (k[5] as Color).lerp(Color(0.5, 0.52, 0.55), gris * 0.85).lerp(Color(0.85, 0.87, 0.88), brouillard * 0.8)
	sm.ground_horizon_color = (_defaut.gnd as Color).lerp(sm.sky_horizon_color, 0.6)
	ile.env.ambient_light_energy = float(k[6]) * (1.0 - 0.25 * gris) + flash * 2.0
	ile.env.fog_light_color = (k[7] as Color).lerp(Color(0.55, 0.58, 0.62), gris * 0.8).lerp(Color(0.8, 0.82, 0.84), brouillard)
	ile.env.fog_density = float(_defaut.fog_d) + 0.0045 * gris + 0.024 * brouillard
	ile.env.fog_sky_affect = clampf(0.75 * brouillard + 0.3 * gris, 0.0, 1.0)
	# Pluie autour de la caméra, et son bruit.
	if _gouttes:
		var cam := get_viewport().get_camera_3d()
		_gouttes.emitting = pluie > 0.02
		((_gouttes.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a = 0.38 * clampf(pluie, 0.0, 1.0)
		if cam:
			_gouttes.global_position = cam.global_position + Vector3(0, 9.0, 0) + (-cam.global_basis.z * Vector3(1, 0, 1)) * 6.0
		var vol := -60.0 if pluie < 0.02 else lerpf(-30.0, -9.0, pluie)
		if pluie > 0.02 and not _bruit.playing:
			_bruit.play()
		_bruit.volume_db = vol
		if pluie <= 0.02 and _bruit.playing:
			_bruit.stop()
	# Le phare s'allume à la tombée du jour (ou sous l'orage).
	var nuit := clampf((avancement - 0.72) / 0.2, 0.0, 1.0)
	var phare := maxf(nuit, gris * 0.7)
	if _lampe:
		_lampe.light_energy = lerpf(float(_defaut.lampe_e), 7.0, phare)
		_lampe.omni_range = lerpf(float(_defaut.lampe_r), 32.0, phare)
	if _faisceau:
		# Le faisceau seulement au crépuscule, et discret quand on est tout près (sur la galerie).
		var cam := get_viewport().get_camera_3d()
		var pres := 1.0
		if cam:
			pres = clampf((cam.global_position.distance_to(_faisceau.global_position) - 10.0) / 30.0, 0.15, 1.0)
		_faisceau.visible = nuit > 0.05
		(_faisceau.get_meta("mat") as StandardMaterial3D).albedo_color.a = 0.11 * nuit * pres
		_faisceau.rotation.y += delta * 0.7


## Portée de vue (m) : le brouillard et la pluie la réduisent (bots).
func portee_vue() -> float:
	var d := ile.env.fog_density if ile else 0.001
	return minf(2.6 / maxf(d, 0.0001), 1000.0) * (1.0 - 0.25 * pluie)


## Les pas s'entendent moins sous la pluie : facteur de portée et décibels en moins.
static func pas_portee() -> float:
	return 1.0 - 0.45 * (courante.pluie if courante else 0.0)


static func pas_db() -> float:
	return -9.0 * (courante.pluie if courante else 0.0)


## Retour à l'éclairage d'origine (fin de partie, lobby, entraînement).
func restaurer() -> void:
	if _defaut.is_empty():
		return
	var sm := ile.env.sky.sky_material as ProceduralSkyMaterial
	ile.sun.rotation_degrees = _defaut.sun_rot
	ile.sun.light_color = _defaut.sun_col
	ile.sun.light_energy = _defaut.sun_e
	ile.sun.shadow_opacity = _defaut.shadow
	sm.sky_top_color = _defaut.top
	sm.sky_horizon_color = _defaut.hor
	sm.ground_horizon_color = _defaut.gnd
	ile.env.ambient_light_energy = _defaut.amb
	ile.env.fog_density = _defaut.fog_d
	ile.env.fog_light_color = _defaut.fog_c
	ile.env.fog_sky_affect = _defaut.fog_sky
	if _lampe:
		_lampe.light_energy = _defaut.lampe_e
		_lampe.omni_range = _defaut.lampe_r
	if is_instance_valid(_faisceau):
		_faisceau.queue_free()
	_faisceau = null
	if courante == self:
		courante = null


func _exit_tree() -> void:
	restaurer()
