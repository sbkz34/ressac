class_name VueVide
extends WeaponView
## Vue d'arme des bots : rien à afficher à la première personne. Garde la même interface que
## WeaponView pour que l'arsenal fonctionne pareil pour un bot et pour le joueur.

func _ready() -> void:
	pass


func set_weapon(_w: Dictionary, _animate := true) -> void:
	pass


func play_anim(_name: String, _length: float) -> void:
	pass


func play_reload(_length: float, _empty: bool, _shells: int) -> void:
	pass


func shot(_kick: float, _guns := 1) -> void:
	pass


func update_view(_delta: float, _speed: float, _sprinting: bool, _on_floor: bool) -> void:
	pass


func add_sway(_look_delta: Vector2) -> void:
	pass


func land(_speed: float) -> void:
	pass


func muzzle_global(_left := false) -> Vector3:
	return global_position - global_basis.z * 0.6 + Vector3(0, -0.15, 0)
