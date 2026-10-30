class_name Intentions
extends RefCounted
## Ce que le joueur veut faire pendant un pas de simulation. Le joueur local, les bots et (plus
## tard) les joueurs distants remplissent tous cette même structure : la simulation du
## mouvement ne sait pas d'où viennent les ordres.

var move := Vector2.ZERO      # x : droite, y : arrière (comme Input.get_vector)
var look := Vector2.ZERO      # degrés à tourner pendant ce pas (x : lacet, y : tangage)
var jump := false             # appui pendant ce pas
var jump_held := false
var crouch := false
var crouch_held := false
var sprint := false
var sprint_held := false
var fire_held := false
var ads_held := false
var reload := false
var swap := false
var interact := false
var use := false              # manette : ramasser s'il y a quelque chose, sinon recharger
var use_held := false         # manette : maintenu pour ramasser une arme (appui bref = recharger)
var plate_held := false
var lethal := false           # lancer la grenade
var tactical := false         # lancer le fumigène


## Les appuis ne valent que pour un pas ; ce qui est maintenu reste.
func consume() -> void:
	jump = false
	crouch = false
	sprint = false
	reload = false
	swap = false
	interact = false
	use = false
	lethal = false
	tactical = false
	look = Vector2.ZERO
