@tool
extends Node3D

const flooring = preload("res://Assets/floor.tscn")
const sidewalk = preload("res://Assets/sidewalk_nobevel.tscn")

const roadN = preload("res://Assets/roadN.tscn")
const roadS = preload("res://Assets/roadS.tscn")
const roadW = preload("res://Assets/roadW.tscn")
const roadE = preload("res://Assets/roadE.tscn")

const crossroadN = preload("res://Assets/crossroadN.tscn")
const crossroadS = preload("res://Assets/crossroadS.tscn")
const crossroadW = preload("res://Assets/crossroadW.tscn")
const crossroadE = preload("res://Assets/crossroadE.tscn")

const roadstripeN = preload("res://Assets/roadstripeN.tscn")
const roadstripeE = preload("res://Assets/roadstripeE.tscn")

var floors = {
	"roadN": roadN,
	"roadS": roadS,
	"roadW": roadW,
	"roadE": roadE,
	"crossroadN": crossroadN,
	"crossroadS": crossroadS,
	"crossroadW": crossroadW,
	"crossroadE": crossroadE,
	"roadstripeN": roadstripeN,
	"roadstripeE": roadstripeE,
}

#what kind of edge
#crossing is for edges that will have pedestrian lanes
#rpath is for edges that will have straight roads
var wfcrules = {
	"roadN": {
		"north": ["crossingS", "rpathS"],
		"south": ["crossingN"],
		"west": ["crossingE", "rpathE"],
		"east": ["crossingW", "rpathW"]
	},
	"roadS": {
		"north": ["crossingS"],
		"south": ["crossingN", "rpathN"],
		"west": ["crossingE", "rpathE"],
		"east": ["crossingW", "rpathW"]
	},
	"roadW": {
		"north": ["crossingS", "rpathS"],
		"south": ["crossingN", "rpathN"],
		"west": ["crossingE", "rpathE"],
		"east": ["crossingW"]
	},
	"roadE": {
		"north": ["crossingS", "rpathS"],
		"south": ["crossingN", "rpathN"],
		"west": ["crossingE"],
		"east": ["crossingW", "rpathW"]
	},
	"crossroadN": {
		"north": ["crossingN"],
		"south": ["rpathS", "crossingS"],
		"west": [],
		"east": []
	},
	"crossroadS": {
		"north": ["rpathS", "crossingS"],
		"south": ["crossingN"],
		"west": [],
		"east": []
	},
	"crossroadW": {
		"north": [],
		"south": [],
		"west": ["crossingW"],
		"east": ["rpathE", "crossingE"]
	},
	"crossroadE": {
		"north": [],
		"south": [],
		"west": ["rpathW", "crossingW"],
		"east": ["crossingE"]
	},
	"roadstripeN": {
		"north": ["rpathN"],
		"south": ["rpathS"],
		"west": [],
		"east": []
	},
	"roadstripeE": {
		"north": [],
		"south": [],
		"west": ["rpathW"],
		"east": ["rpathE"]
	}
};

var allcells: Dictionary = {
	
}
#variables
var gridsize = 3.0
var pickedkey = _firstrand()

@export var generate: bool = false:
	set(value):
		if value:
			_thegrid()
			_instantiate_rando()
			
		generate = false
func _placeblock(placeblockpos: Vector3) -> void:
	var block = roadN.instantiate()
	add_child(block)
	block.owner = get_tree().edited_scene_root
	block.add_to_group("wfctile")
	block.position = placeblockpos

@export var delete: bool = false:
	set(value):
		if value:
			_deleteblock()
		delete = false
func _deleteblock () -> void:
	for child in get_children():
		if child.is_in_group("wfctile"):
			child.queue_free()
			
###############################################################

func _instantiate_rando ()->void:
	print("======================================")
	print("Before collapse: ", allcells[pickedkey])
	print("======================================")
	var allcells_pickedkey = allcells[pickedkey]
	var picked_tile = allcells_pickedkey.pick_random()
	allcells[pickedkey] = [picked_tile]
	print("After collapse: ", allcells[pickedkey])
	
	var neighbors = _checknearby(pickedkey)

	print(neighbors["north"])
	print(neighbors["south"])
	print(neighbors["east"])
	print(neighbors["west"])
	
func _kolapsa () -> void:
	pass
#using the for loop to get to randomize pick a cell
func _firstrand() -> Vector2i:
	var keys = allcells.keys()
	keys.shuffle()
	return keys[0]
	# no collapse, i js reaturned one from array. 10 left still.

# for placing the blocks within the grid
func _thegrid() -> void:
	for x in range(gridsize):
		for z in range(gridsize):
			allcells[Vector2i(x,z)] = floors.keys().duplicate()
			_placeblock(Vector3(x, 0.0, z))
	print("ALL CELLS AND 2I")
	print(allcells)

func _checknearby (cell: Vector2i) -> Dictionary:
	var neighbors = {
		"north": cell + Vector2i(0, 1),
		"south": cell + Vector2i(0, -1),
		"east": cell + Vector2i(1, 0),
		"west": cell + Vector2i(-1, 0)
	}
	return neighbors
	
	
	pass
