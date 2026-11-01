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
		var node := spawner.spawn(t["scene"] as PackedScene)
		node.position = pos
		node.rotation_degrees.y = 90.0 * float(t["rot"])
		views[cell] = node
	elif show_entropy and opts.size() > 1:
		# A number = how many pieces could still go in this cell.
		var label := Label3D.new()
		label.text = str(opts.size())
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.01
		label.font_size = 32
		spawner.add_temporary(label)
		label.position = pos
		views[cell] = label

func clear() -> void:
	for c in views:
		_free_view(views[c])
	views.clear()

func _free_view(view) -> void:
	if is_instance_valid(view):
		view.queue_free()
