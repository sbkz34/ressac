class_name SonsJoueur
extends Node
## Sons continus du joueur, selon ce qu'il fait : le moteur dans l'avion, le vent en chute libre
## (plus fort en piqué), le vent plus doux et la toile sous la voile, les battements de cœur
## quand il ne lui reste presque plus de vie. Les volumes glissent d'un état à l'autre.

var joueur: Joueur
var _moteur: AudioStreamPlayer
var _vent: AudioStreamPlayer
var _voile: AudioStreamPlayer
var _coeur: AudioStreamPlayer
var _coeur_t := 0.0


func _ready() -> void:
	_moteur = _loop("moteur_avion")
	_vent = _loop("vent_chute")
	_voile = _loop("vent_voile")
	_coeur = AudioStreamPlayer.new()
	_coeur.stream = G.sound("coeur")
	add_child(_coeur)


func _loop(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := G.sound(name)
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		p.stream = w
	p.volume_db = -80.0
	add_child(p)
	return p


func _fade(p: AudioStreamPlayer, target_db: float, delta: float, speed := 40.0) -> void:
	if p.stream == null:
		return
	p.volume_db = move_toward(p.volume_db, target_db, speed * delta)
	if p.volume_db > -60.0 and not p.playing:
		p.play()
	elif p.volume_db <= -60.0 and p.playing:
		p.stop()


func _process(delta: float) -> void:
	if joueur == null:
		return
	var e := joueur.etat
	var dead := joueur.sante.dead
	_fade(_moteur, -14.0 if e == Joueur.Etat.AVION and not dead else -80.0, delta, 60.0)
	# Chute libre : le vent forcit avec la vitesse de chute.
	var vy := absf(joueur.velocity.y)
	var free_db := lerpf(-16.0, -5.0, clampf((vy - 20.0) / 30.0, 0.0, 1.0))
	_fade(_vent, free_db if e == Joueur.Etat.CHUTE_LIBRE else -80.0, delta, 50.0)
	if _vent.playing:
		_vent.pitch_scale = lerpf(0.9, 1.15, clampf((vy - 20.0) / 30.0, 0.0, 1.0))
	_fade(_voile, -12.0 if e == Joueur.Etat.PARACHUTE else -80.0, delta, 50.0)
	# Cœur : en dessous de 35 points de vie, de plus en plus vite.
	var hp := joueur.sante.hp
	if not dead and hp < 35.0 and e != Joueur.Etat.DRONE:
		_coeur_t -= delta
		if _coeur_t <= 0.0:
			_coeur_t = lerpf(0.65, 1.0, hp / 35.0)
			_coeur.volume_db = lerpf(-4.0, -12.0, hp / 35.0)
			_coeur.play()
	else:
		_coeur_t = 0.0
