@tool
class_name GroundPlacer
extends RefCounted
## ONE job: place one ground tile (by name) at one grid cell.

var spawner: SceneSpawner
var catalog: TileCatalog
var body_kind: int = TileBody.NONE # TileBody.STATIC or TileBody.RIGID
var with_collision: bool = false

func _init(p_spawner: SceneSpawner, p_catalog: TileCatalog) -> void:
	spawner = p_spawner
	catalog = p_catalog

func place(tile_name: String, cell: Vector2i) -> void:
	var scene := catalog.scene_for(tile_name)
	if scene == null:
		push_warning("Unknown tile: " + tile_name)
		return
	var block := spawner.spawn(scene, folder_for(tile_name), "%s_x%d_z%d" % [tile_name, cell.x, cell.y], body_kind, with_collision)
	block.position = Vector3(cell.x * CityConst.CELL_SIZE, 0.0, cell.y * CityConst.CELL_SIZE)

# Merged option: one piece for a whole rectangle of the same tile.
func place_merged(tile_name: String, rect: Rect2i) -> void:
	var scene := catalog.scene_for(tile_name)
	if scene == null:
		push_warning("Unknown tile: " + tile_name)
		return
	var piece := GroundMerger.make_piece(scene, rect, body_kind, with_collision)
	spawner.add_node(piece, folder_for(tile_name), "%s_x%d_z%d_%dx%d" % [tile_name, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	piece.set_meta(PlacementCheck.CELLS_META, rect.size.x * rect.size.y) # one piece = many blocks
	piece.position = Vector3(rect.position.x * CityConst.CELL_SIZE, 0.0, rect.position.y * CityConst.CELL_SIZE)

static func folder_for(tile_name: String) -> String:
	if tile_name == "floor":
		return "Floors"
	if tile_name == "sidewalk":
		return "Sidewalks"
	return "Roads"
