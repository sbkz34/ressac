class_name Tyrolienne
extends Node3D
## Tyrolienne : un câble du sol au sommet d'une tour (Phare, Sémaphore, Citerne). On s'y accroche
## (interaction) en bas pour monter, en haut pour descendre. Pendant le trajet on peut tirer ;
## sauter lâche le câble (et, assez haut, on ouvre le parachute).
## Le nœud reste à l'origine : toutes les positions sont dans le repère du monde.

const VITESSE_MONTEE := 11.0
const VITESSE_DESCENTE := 14.0
const VITESSE_BORD := 4.0       # le petit passage entre le bout du câble et la plateforme
const PRISE := 2.3              # hauteur du câble au-dessus des pieds

var bas: Vector3                # pieds, au sol, sous le départ du câble
var bord: Vector3               # pieds, accroché au bout du câble, au bord de la plateforme
var haut: Vector3               # pieds, posé sur la plateforme
var coffre: Vector3             # coffre au sommet
var coffre_cap := 0.0
var ancre_bas: Node3D           # points d'interaction (dans pillage.tyroliennes)
var ancre_haut: Node3D


func setup(ile: Ile, b: Vector3, bo: Vector3, h: Vector3) -> void:
	bas = b
	bord = bo
	haut = h
	var dir := Vector3(bord.x - bas.x, 0, bord.z - bas.z).normalized()
	# Poteau du bas (un peu en retrait), sur un socle, bandes jaunes.
	var post := bas - dir * 0.5
	ile.box(self, post + Vector3(0, 0.08, 0), Vector3(0.9, 0.16, 0.9), ile.mats.concrete)
	ile.box(self, post + Vector3(0, (PRISE + 0.3) / 2.0, 0), Vector3(0.16, PRISE + 0.3, 0.16), ile.mats.metal)
	ile.box(self, post + Vector3(0, 1.1, 0), Vector3(0.2, 0.5, 0.2), ile.mats.jaune, false)
	# En haut : un mât au bord de la plateforme et une potence qui tient le câble.
	var edge := haut.lerp(bord, 0.55)
	ile.box(self, edge + Vector3(0, (PRISE + 0.3) / 2.0, 0), Vector3(0.14, PRISE + 0.3, 0.14), ile.mats.metal, false)
	_bar(ile, edge + Vector3(0, PRISE + 0.2, 0), bord + Vector3(0, PRISE + 0.1, 0), 0.06, ile.mats.metal)
	ile.box(self, edge + Vector3(0, 1.1, 0), Vector3(0.18, 0.5, 0.18), ile.mats.jaune, false)
	# Le câble.
	_bar(ile, post + Vector3(0, PRISE + 0.1, 0), bord + Vector3(0, PRISE + 0.1, 0), 0.035, ile.mats.metal)
	ancre_bas = _ancre(bas + Vector3(0, 0.9, 0), true)
	ancre_haut = _ancre(edge + Vector3(0, 0.9, 0), false)


## Cylindre fin d'un point à un autre (sans collision, fusionné avec le décor).
func _bar(ile: Ile, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var d := b - a
	var mi := ile.cylinder(self, (a + b) / 2.0, r, d.length(), m, false, r, 6)
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y))


func _ancre(p: Vector3, monte: bool) -> Node3D:
	var n := Node3D.new()
	n.set_meta("tyrolienne", self)
	n.set_meta("monte", monte)
	add_child(n)
	n.position = p
	return n


## Points du trajet (pieds), dans le sens du parcours.
func trajet(monte: bool) -> PackedVector3Array:
	return PackedVector3Array([bas, bord, haut]) if monte else PackedVector3Array([haut, bord, bas])
