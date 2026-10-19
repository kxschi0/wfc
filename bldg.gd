@tool
extends Node3D

const bldgA = preload("res://Assets/basicbldg_01.tscn")
const bldgB = preload("res://Assets/basicbldg_02.tscn")
const bldgC = preload("res://Assets/basicbldg_03.tscn")
const bldgD = preload("res://Assets/basicbldg_04.tscn")

var buildings = {
	"bldgA": bldgA,
	"bldgB": bldgB,
	"bldgC": bldgC,
	"bldgD": bldgD,
}

#SOCKETS 4 edges of eachhhh
var wfcrules = {
	"bldgA": {"N": "wall", "E": "wall", "S": "wall", "W": "wall", "U": "stack", "D": "stack"},
	"bldgB": {"N": "open", "E": "open", "S": "open", "W": "open", "U": "stack", "D": "stack"},
	"bldgC": {"N": "wall", "E": "wall", "S": "wall", "W": "wall", "U": "cut", "D": "cut"},
	"bldgD": {"N": "open", "E": "open", "S": "open", "W": "open", "U": "cut", "D": "cut"},
}

const DIRS = {
	"N": Vector3i(0, 0, 1),
	"E": Vector3i(1, 0, 0),
	"S": Vector3i(0, 0, -1),
	"W": Vector3i(-1, 0, 0),
	"U": Vector3i(0, 1, 0),
	"D": Vector3i(0, -1, 0),
}
const OPP = {"N": "S", "S": "N", "E": "W", "W": "E", "U": "D", "D": "U"}

@export var width: int = 3
@export var depth: int = 3
@export var height: int = 3

var fsize: float = 1.0
var floor_height: float = 1.0
var allcells: Dictionary = {}
var step_count: int = 0

@export var generate: bool = false:
	set(value):
		if value:
			_deleteblock()
			_run()
		generate = false

@export var delete: bool = false:
	set(value):
		if value:
			_deleteblock()
		delete = false

func _deleteblock() -> void:
	for child in get_children():
		if child.is_in_group("wfctile"):
			remove_child(child)
			child.queue_free()

func _measure_blocks() -> void:
	var size := Vector3.ZERO
	for key in buildings:
		var probe: Node3D = buildings[key].instantiate()
		var box := AABB()
		var first := true
		for m in probe.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D.IDENTITY
			var n: Node = m
			while n != null and n != probe:
				t = n.transform * t
				n = n.get_parent()
			var b: AABB = t * m.get_aabb()
			if first:
				box = b
				first = false
			else:
				box = box.merge(b)
		probe.free()
		size = size.max(box.size)
	if size.x > 0.0 and size.z > 0.0:
		fsize = max(size.x, size.z)
	if size.y > 0.0:
		floor_height = size.y
	print("Block size: ", size, " -> fsize ", fsize, " floor_height ", floor_height)

func _run() -> void:
	_measure_blocks()
	_thegrid()
	step_count = 0
	print("===== WFC START =====")
	while true:
		var cell = _lowest_cell()
		if cell == Vector3i(-1, -1, -1):
			break
		step_count += 1
		_kolapsa(cell)
		if not _propagate(cell):
			print("CONTRADICTION at step ", step_count, " - click Generate again")
			return
	print("===== DONE in ", step_count, " steps =====")
	_build()

func _thegrid() -> void:
	allcells.clear()
	for x in range(width):
		for y in range(height):
			for z in range(depth):
				allcells[Vector3i(x, y, z)] = buildings.keys()

func _lowest_cell() -> Vector3i:
	var best = Vector3i(-1, -1, -1)
	var best_score = INF
	for c in allcells:
		var n = allcells[c].size()
		if n <= 1:
			continue
		var score = n + randf() * 0.01
		if score < best_score:
			best_score = score
			best = c
	return best


func _kolapsa(cell: Vector3i) -> void:
	var options = allcells[cell]
	var picked = options.pick_random()
	print("STEP ", step_count, " | cell ", cell, " | options ", options, " -> picked ", picked)
	allcells[cell] = [picked]

func _propagate(start: Vector3i) -> bool:
	var stack = [start]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for d in DIRS:
			var n = cur + DIRS[d]
			if not allcells.has(n):
				continue
			var kept = []
			for opt in allcells[n]:
				for t in allcells[cur]:
					if wfcrules[t][d] == wfcrules[opt][OPP[d]]:
						kept.append(opt)
						break
			if kept.size() < allcells[n].size():
				print("   propagate: cell ", n, " ", allcells[n].size(), " -> ", kept.size(), " options ", kept)
				allcells[n] = kept
				if kept.is_empty():
					return false
				stack.append(n)
	return true

func _build() -> void:
	for cell in allcells:
		var block = buildings[allcells[cell][0]].instantiate()
		add_child(block)
		block.owner = get_tree().edited_scene_root
		block.add_to_group("wfctile")
		block.position = Vector3(cell.x * fsize, cell.y * floor_height, cell.z * fsize)
