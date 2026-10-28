class_name NavIle
extends NavigationRegion3D
## Maillage de navigation de toute l'île (sol, bâtiments, escaliers, quais), pour les bots.
## Il est précalculé une fois (`godot --headless --path . -- --bake-nav`) et enregistré dans
## assets/map/navigation.res : le téléphone n'a rien à calculer au lancement.

const PATH := "res://assets/map/navigation.res"


static func make_params() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = G.L_WORLD
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.cell_size = 0.3
	nm.cell_height = 0.2
	nm.agent_radius = 0.35
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.45
	nm.agent_max_slope = 46.0
	nm.region_min_size = 1.0     # garder les escaliers étroits (petites régions)
	nm.region_merge_size = 30.0
	nm.edge_max_length = 14.0
	nm.edge_max_error = 1.4
	nm.detail_sample_distance = 8.0
	nm.detail_sample_max_error = 1.2
	# On ne garde pas les fonds marins : la mer commence un peu sous la surface.
	nm.filter_baking_aabb = AABB(Vector3(-320, -0.9, -320), Vector3(640, 80, 640))
	nm.filter_walkable_low_height_spans = true
	nm.filter_ledge_spans = false   # sinon les escaliers étroits (bord ouvert) disparaissent
	return nm


## Calcule le maillage à partir des collisions de l'île et l'enregistre (outil, sans écran).
func bake_from(ile: Node3D) -> Error:
	var nm := make_params()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, source, ile)
	NavigationServer3D.bake_from_source_geometry_data(nm, source)
	navigation_mesh = nm
	return ResourceSaver.save(nm, PATH, ResourceSaver.FLAG_COMPRESS)


func load_mesh() -> bool:
	if not ResourceLoader.exists(PATH):
		push_warning("Pas de maillage de navigation : lancer --bake-nav")
		return false
	navigation_mesh = load(PATH)
	return true


## Chemin (liste de points) d'un point à un autre sur le maillage.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(get_navigation_map(), from, to, true)


## Point du maillage le plus proche.
func closest(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_navigation_map(), p)
