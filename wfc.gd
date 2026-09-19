@tool

extends Node
const flooring = preload("res://Assets/floor.tscn")
const road = preload("res://Assets/roadN.tscn")
const sidewalk = preload("res://Assets/sidewalk_nobevel.tscn")
const crossroad = preload("res://Assets/crossroadS.tscn")
const roadstripe = preload("res://Assets/roadstripeN.tscn")

var floors = {
	"flooring": flooring,
	"road": road,
	"sidewalk": sidewalk,
	"roadstripe":roadstripe,
	"crossroad": crossroad
}
var horizontalr = {
	"flooring":["flooring"],
	"road":["road"],
	"sidewalk":["sidewalk"],
	"roadstripe": ["roadstripe"],
	"crossroad": ["crossroad"],
}
var verticalr = {
	"flooring": ["flooring", "sidewalk"],
	"road": ["road", "roadstripe","crossroad"],
	"sidewalk": ["flooring", "roadstripe"],
	"roadstripe": ["sidewalk", "crossroad"],
	"crossroad": [ "sidewalk"]
}

const floor_size: float = 1.0
var grid: int = 24
var placedgrid: = {}

@export var trigger_generate: bool = false:
	set(value):
		if value:
			generate_grid()
		trigger_generate = false

func generate_grid() -> void:
	placedgrid.clear()
	_clear_previous_tiles()
	for x in range(grid):
		for z in range(grid):
			var gridpos := Vector2i(x,z)
			_spawn_block(gridpos, Vector3(x * floor_size, 0.0, z * floor_size))

	for z in range(grid):
		var row := ""
		for col in range(grid):
			var tile = placedgrid[Vector2i(col, z)]
			if tile == "flooring":
				row += "F"
			elif tile == "road":
				row += "R"
			elif tile == "roadstripe":
				row+="Rs"
			elif tile == "roadstripeR":
				row += "Rr"
			else:
				row += "S"
		print(row)

@export var delete_button: bool = false:
	set(value):
		if value:
			placedgrid.clear()
			_clear_previous_tiles()
			delete_button = false

func _clear_previous_tiles() -> void:
	for child in get_children():
		if child.is_in_group("wfc_tile"):
			child.queue_free()

func _spawn_block(gridpos: Vector2i, spawn_position: Vector3) -> void:
	var chosen_key = _picktile(gridpos)
	var chosen_scene = floors[chosen_key]

	placedgrid[gridpos] = chosen_key

	var block = chosen_scene.instantiate()
	add_child(block)
	block.add_to_group("wfc_tile")
	block.owner = get_tree().edited_scene_root
	block.position = spawn_position

func _can_be_neighbors(tilea: String, tileb: String, axis: String) -> bool:
	if axis == "horizontal":
		return tileb in horizontalr[tilea]
	else:
		return tileb in verticalr[tilea]

func _picktile(gridpos: Vector2i) -> String:
	var candidate_list = floors.keys()
	candidate_list.shuffle()

	for candidate in candidate_list:
		var valid = true

		var westpos = Vector2i(gridpos.x - 1, gridpos.y)
		if placedgrid.has(westpos):
			if not _can_be_neighbors(placedgrid[westpos], candidate, "horizontal"):
				valid = false

		var southpos = Vector2i(gridpos.x, gridpos.y - 1)
		if valid and placedgrid.has(southpos):
			if not _can_be_neighbors(placedgrid[southpos], candidate, "vertical"):
				valid = false

		if valid:
			return candidate

	return candidate_list[0]
