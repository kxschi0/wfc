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

const bldgbig = preload("res://Assets/bldgbig.tscn")

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
	"bldgbig": bldgbig,
}

@export var gridsize: int = 16
@export var road_tile: String = "roadstripeN"
@export_range(0.0, 1.0) var building_density: float = 0.5
@export var building_offset: Vector3 = Vector3(0, 1, 0)
@export var delay_time: float = 0.02
@export var log_steps: bool = true

var fsize: float = 1.0
var running: bool = false
var footprint: Vector2i = Vector2i(1, 1)
var wave: Dictionary = {}
var step_count: int = 0

@export var generate: bool = false:
	set(value):
		if value:
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
			child.queue_free()

func _run() -> void:
	if running:
		return
	running = true
	_deleteblock()
	await get_tree().process_frame

	footprint = _measure_footprint()
	print("bldgbig FOOTPRINT: ", footprint.x, " x ", footprint.y, " cells")

	for x in range(gridsize):
		for z in range(gridsize):
			_place(road_tile, Vector2i(x, z))
			if delay_time > 0.0:
				await get_tree().create_timer(delay_time).timeout

	_run_wfc()

	for x in range(gridsize):
		for z in range(gridsize):
			var cell = Vector2i(x, z)
			if wave[cell][0] == "building":
				_place_building(cell)
				if delay_time > 0.0:
					await get_tree().create_timer(delay_time).timeout

	running = false

###############################################################
# WFC
###############################################################

func _run_wfc() -> void:
	_init_wave()
	step_count = 0
	print("===== WFC START =====")
	while true:
		var cell: Vector2i = _lowest_entropy_cell()
		if cell == Vector2i(-1, -1):
			break
		step_count += 1
		_collapse(cell)
		if wave[cell][0] == "building":
			_propagate(cell)
	var count = 0
	for c in wave:
		if wave[c][0] == "building":
			count += 1
	print("===== WFC DONE: ", step_count, " steps, ", count, " buildings =====")

# Every cell starts with both options, except cells too close to the
# edge for a whole building to fit (those can only be empty).
func _init_wave() -> void:
	wave.clear()
	for x in range(gridsize):
		for z in range(gridsize):
			if x + footprint.x > gridsize or z + footprint.y > gridsize:
				wave[Vector2i(x, z)] = ["empty"]
			else:
				wave[Vector2i(x, z)] = ["empty", "building"]

func _weight(t: String) -> float:
	var d: float = clampf(building_density, 0.001, 0.999)
	if t == "building":
		return d
	return 1.0 - d

func _entropy(options: Array) -> float:
	var total: float = 0.0
	var wlogw: float = 0.0
	for t in options:
		var w: float = _weight(t)
		total += w
		wlogw += w * log(w)
	return log(total) - wlogw / total

func _lowest_entropy_cell() -> Vector2i:
	var best = Vector2i(-1, -1)
	var best_h: float = INF
	for c in wave:
		if wave[c].size() <= 1:
			continue
		var h: float = _entropy(wave[c]) + randf() * 0.001
		if h < best_h:
			best_h = h
			best = c
	return best

func _collapse(cell: Vector2i) -> void:
	var options: Array = wave[cell]
	var total: float = 0.0
	for t in options:
		total += _weight(t)
	var roll: float = randf() * total
	var choice: String = options[options.size() - 1]
	for t in options:
		roll -= _weight(t)
		if roll <= 0.0:
			choice = t
			break
	if log_steps:
		print("STEP ", step_count, " | cell ", cell, " | entropy ", snapped(_entropy(options), 0.01), " | options ", options, " -> picked ", choice)
	wave[cell] = [choice]

func _propagate(cell: Vector2i) -> void:
	for dx in range(-footprint.x + 1, footprint.x):
		for dz in range(-footprint.y + 1, footprint.y):
			var n: Vector2i = cell + Vector2i(dx, dz)
			if n == cell or not wave.has(n):
				continue
			if wave[n].has("building") and wave[n].size() > 1:
				wave[n] = ["empty"]
				if log_steps:
					print("   propagate: cell ", n, " lost 'building' -> ['empty']")

###############################################################

func _measure_footprint() -> Vector2i:
	var temp = bldgbig.instantiate()
	var aabbs: Array = []
	_collect_aabbs(temp, Transform3D.IDENTITY, aabbs)
	temp.free()

	if aabbs.is_empty():
		push_warning("Couldn't measure bldgbig (no meshes found) - assuming 1x1 cell")
		return Vector2i(1, 1)

	var combined: AABB = aabbs[0]
	for i in range(1, aabbs.size()):
		combined = combined.merge(aabbs[i])

	var cells_x = max(1, int(ceil(combined.size.x / fsize - 0.001)))
	var cells_z = max(1, int(ceil(combined.size.z / fsize - 0.001)))
	return Vector2i(cells_x, cells_z)

func _collect_aabbs(node: Node, xform: Transform3D, aabbs: Array) -> void:
	if node is VisualInstance3D:
		aabbs.append(xform * node.get_aabb())
	for child in node.get_children():
		var child_xform = xform
		if child is Node3D:
			child_xform = xform * child.transform
		_collect_aabbs(child, child_xform, aabbs)

func _place(tile_name: String, cell: Vector2i) -> void:
	if not floors.has(tile_name):
		push_warning("Unknown tile: " + tile_name)
		return
	var block = floors[tile_name].instantiate()
	add_child(block)
	block.owner = get_tree().edited_scene_root
	block.add_to_group("wfctile")
	block.position = Vector3(cell.x * fsize, 0.0, cell.y * fsize)

#for placing thee buildings
func _place_building(cell: Vector2i) -> void:
	var block = bldgbig.instantiate()
	add_child(block)
	block.owner = get_tree().edited_scene_root
	block.add_to_group("wfctile")
	block.position = Vector3(cell.x * fsize, 0.0, cell.y * fsize) + Vector3(0, 1, 0)
