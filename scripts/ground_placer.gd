@tool
class_name GroundPlacer
extends RefCounted
## ONE job: place one ground tile (by name) at one grid cell.

var spawner: SceneSpawner
var catalog: TileCatalog

func _init(p_spawner: SceneSpawner, p_catalog: TileCatalog) -> void:
	spawner = p_spawner
	catalog = p_catalog

func place(tile_name: String, cell: Vector2i) -> void:
	var scene := catalog.scene_for(tile_name)
	if scene == null:
		push_warning("Unknown tile: " + tile_name)
		return
	var block := spawner.spawn(scene)
	block.position = Vector3(cell.x * CityConst.CELL_SIZE, 0.0, cell.y * CityConst.CELL_SIZE)
