@tool
class_name GroundMerger
extends RefCounted
## ONE job: join neighbouring ground tiles of the same kind into one piece
## (one mesh, one collision) instead of one node per tile.
## Hierarchy of one merged piece:
##   <tile name>_x_z_WxH   (StaticBody3D or RigidBody3D)
##   ├─ Mesh               (MeshInstance3D, all the tiles in one mesh)
##   └─ Collision          (CollisionShape3D, one box over the whole piece)

const MESH_NAME := "Mesh"

# cells: Dictionary of cell (Vector2i) -> tile name.
# Returns an Array of {"tile": String, "rect": Rect2i}: neighbours with the same tile name
# become as few rectangles as possible.
static func rectangles(cells: Dictionary) -> Array:
	var by_tile: Dictionary = {}
	for cell in cells:
		var tile_name: String = cells[cell]
		if not by_tile.has(tile_name):
			by_tile[tile_name] = []
		by_tile[tile_name].append(cell)

	var result: Array = []
	for tile_name in by_tile:
		var left: Dictionary = {}
		for cell in by_tile[tile_name]:
			left[cell] = true
		var sorted: Array = by_tile[tile_name].duplicate()
		sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		for cell: Vector2i in sorted:
			if not left.has(cell):
				continue
			var w := 1
			while left.has(Vector2i(cell.x + w, cell.y)):
				w += 1
			var h := 1
			while _row_free(left, cell.x, cell.y + h, w):
				h += 1
			for dz in range(h):
				for dx in range(w):
					left.erase(Vector2i(cell.x + dx, cell.y + dz))
			result.append({"tile": tile_name, "rect": Rect2i(cell.x, cell.y, w, h)})
	return result

# One piece that covers `rect`. Its origin is the corner cell of the rectangle.
static func make_piece(scene: PackedScene, rect: Rect2i, kind: int, with_collision: bool) -> Node3D:
	# Every mesh of the tile model, with where it sits inside the model.
	var parts: Array = []
	var model := scene.instantiate() as Node3D
	_collect(model, model.transform, parts)
	model.free()

	var merged := ArrayMesh.new()
	for part in parts:
		var mesh: Mesh = part["mesh"]
		var inside: Transform3D = part["xf"]
		for s in range(mesh.get_surface_count()):
			var st := SurfaceTool.new()
			for dz in range(rect.size.y):
				for dx in range(rect.size.x):
					var shift := Transform3D(Basis(), Vector3(dx * CityConst.CELL_SIZE, 0.0, dz * CityConst.CELL_SIZE))
					st.append_from(mesh, s, shift * inside)
			st.commit(merged)
			var material: Material = part["material"]
			if material == null:
				material = mesh.surface_get_material(s)
			merged.surface_set_material(merged.get_surface_count() - 1, material)

	var body := TileBody.new_body(kind)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = MESH_NAME
	mesh_node.mesh = merged
	body.add_child(mesh_node)
	if with_collision:
		TileBody.add_box(body, merged.get_aabb())
	return body

static func _row_free(left: Dictionary, x: int, z: int, width: int) -> bool:
	for dx in range(width):
		if not left.has(Vector2i(x + dx, z)):
			return false
	return true

static func _collect(node: Node3D, xf: Transform3D, parts: Array) -> void:
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		parts.append({"mesh": mesh_node.mesh, "xf": xf, "material": mesh_node.material_override})
	for child in node.get_children():
		var child_3d := child as Node3D
		if child_3d != null:
			_collect(child_3d, xf * child_3d.transform, parts)
