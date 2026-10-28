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


## Les appuis ne valent que pour un pas ; ce qui est maintenu reste.
func consume() -> void:
	jump = false
	crouch = false
	sprint = false
	look = Vector2.ZERO
