@tool
class_name WfcView
extends RefCounted
## ONE job: show one WFC cell in the 3D scene
## (the model if decided, a number label if undecided, nothing if empty air).

var spawner: SceneSpawner
var tiles: Array
var wave: Dictionary
var show_entropy: bool
var origin_offset: Vector3
var views: Dictionary = {}
var _fits: Dictionary = {} # asset + mode -> the transform that fits it to one block (measured once)
var body_kind: int = TileBody.NONE # TileBody.STATIC or TileBody.RIGID
var with_collision: bool = false

func _init(p_spawner: SceneSpawner, p_tiles: Array, p_wave: Dictionary, p_show_entropy: bool, p_origin_offset: Vector3) -> void:
	spawner = p_spawner
	tiles = p_tiles
	wave = p_wave
	show_entropy = p_show_entropy
	origin_offset = p_origin_offset

func update_all() -> void:
	for c in wave:
		update_cell(c)

func update_cell(cell: Vector3i) -> void:
	if views.has(cell):
		_free_view(views[cell])
		views.erase(cell)
	var opts: Array = wave[cell]
	var pos := Vector3(cell.x * CityConst.CELL_SIZE, cell.y * CityConst.LEVEL_HEIGHT, cell.z * CityConst.CELL_SIZE) + origin_offset
	if opts.size() == 1:
		var t: Dictionary = tiles[opts[0]]
		if t["scene"] == null:
			return
		var scene := t["scene"] as PackedScene
		var folder := "UpperFloors"
		if t["name"] == "roof":
			folder = "Roofs"
		elif t["bottom"] == "ground":
			folder = "GroundFloors"
		var label_text := "%s_L%d_x%d_z%d" % [scene.resource_path.get_file().get_basename(), cell.y, cell.x, cell.z]
		var mode := BlockFit.SLAB if t["name"] == "roof" else BlockFit.FILL
		var node := spawner.spawn(scene, folder, label_text, body_kind, with_collision, _fit_for(scene, mode))
		node.position = pos
		node.rotation_degrees.y = 90.0 * float(t["rot"])
		views[cell] = node
	elif show_entropy and opts.size() > 1:
		# A number = how many pieces could still go in this cell.
		var label := Label3D.new()
		label.text = str(opts.size())
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.02 # big enough to read in the game window
		label.font_size = 32
		spawner.add_temporary(label, "EntropyLabels", "Entropy_L%d_x%d_z%d" % [cell.y, cell.x, cell.z])
		label.position = pos
		views[cell] = label

# How the asset is scaled and shifted to fill one block. Measured once per asset, then reused.
func _fit_for(scene: PackedScene, mode: int) -> Variant:
	if body_kind == TileBody.NONE:
		return null # no body to hold the fit
	var key := "%d_%d" % [scene.get_instance_id(), mode]
	if not _fits.has(key):
		_fits[key] = BlockFit.model_transform(scene, mode)
	return _fits[key]

func clear() -> void:
	for c in views:
		_free_view(views[c])
	views.clear()

func _free_view(view) -> void:
	if is_instance_valid(view):
		# Leave the tree now, so the cell's name is free when it is redrawn in the same frame.
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		view.queue_free()
