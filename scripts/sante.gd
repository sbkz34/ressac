class_name Sante
extends Node
## Santé et armure d'un combattant (joueur, mannequin, plus tard les bots).
## 100 points de vie qui se régénèrent après quelques secondes sans dégâts, et une armure de
## 0 à 150 en trois plaques de 50 qui ne se régénèrent pas : on les remet une par une.

signal damaged(amount: float, zone: String, on_armor: bool, armor_broken: bool, killed: bool)
signal died
signal changed

const HP_MAX := 100.0
const REGEN_DELAY := 4.5
const REGEN_RATE := 35.0

var hp := HP_MAX
var armor := 0.0
var armor_max := Armes.PLAQUE * Armes.PLAQUES_MAX
var dead := false
var invulnerable := false
var regen_delay := REGEN_DELAY
var last_cause := ""          # "balle", "grenade", "brume", "chute"
var last_attacker: Node = null   # qui a touché en dernier (crédit de l'élimination)
var attacker_age := 99.0         # secondes depuis ce dernier coup
var _since_hit := 99.0


func reset(plates := 0) -> void:
	last_attacker = null
	attacker_age = 99.0
	hp = HP_MAX
	armor = minf(armor_max, Armes.PLAQUE * plates)
	dead = false
	_since_hit = 99.0
	changed.emit()


func plates_full() -> int:
	return int(floor(armor / Armes.PLAQUE + 0.001))


## Une plaque répare le segment entamé (ou en ajoute un) : 0 → 50, 120 → 150.
func insert_plate() -> bool:
	if armor >= armor_max - 0.01 or dead:
		return false
	armor = minf(armor_max, (plates_full() + 1) * Armes.PLAQUE)
	changed.emit()
	return true


## Applique des dégâts ; l'armure encaisse d'abord (sauf la Brume et les chutes, qui passent
## à travers). Renvoie les dégâts réellement infligés.
func take(amount: float, zone := "torse", cause := "balle", through_armor := false, attacker: Node = null) -> float:
	if dead or invulnerable or amount <= 0.0:
		return 0.0
	_since_hit = 0.0
	last_cause = cause
	if attacker:
		last_attacker = attacker
		attacker_age = 0.0
	var on_armor := armor > 0.0 and not through_armor
	var absorbed := 0.0 if through_armor else minf(armor, amount)
	armor -= absorbed
	var rest := amount - absorbed
	var broken := on_armor and armor <= 0.0
	var dealt := absorbed + minf(hp, rest)
	hp -= rest
	var killed := hp <= 0.0
	if killed:
		hp = 0.0
		dead = true
	damaged.emit(dealt, zone, on_armor, broken, killed)
	changed.emit()
	if killed:
		died.emit()
	return dealt


func _physics_process(delta: float) -> void:
	attacker_age += delta
	if dead:
		return
	_since_hit += delta
	if _since_hit > regen_delay and hp < HP_MAX:
		hp = minf(HP_MAX, hp + REGEN_RATE * delta)
		changed.emit()


## Zones de touche d'un combattant debout (hauteur 1,8 m), en Area3D sur la couche L_HITBOX.
## Les tirs les trouvent avec un rayon qui accepte les aires ; chaque zone porte sa santé.
static func make_hitboxes(parent: Node3D, sante: Sante) -> Array[Area3D]:
	var out: Array[Area3D] = []
	var defs := [
		["tete", Vector3(0, 1.62, 0), Vector3(0.26, 0.28, 0.26)],
		["torse", Vector3(0, 1.17, 0), Vector3(0.52, 0.66, 0.32)],
		["jambes", Vector3(0, 0.43, 0), Vector3(0.44, 0.86, 0.28)],
	]
	for d in defs:
		var a := Area3D.new()
		a.name = "Zone_" + d[0]
		a.collision_layer = G.L_HITBOX
		a.collision_mask = 0
		a.monitoring = false
		a.set_meta("zone", d[0])
		a.set_meta("sante", sante)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = d[2]
		cs.shape = bs
		a.add_child(cs)
		parent.add_child(a)
		a.position = d[1]
		a.set_meta("base_y", d[1].y)
		out.append(a)
	return out
