@tool
extends Node3D

const flooring=preload("res://Assets/floor.tscn")
const sidewalk=preload("res://Assets/sidewalk_nobevel.tscn")
const roadN=preload("res://Assets/roadN.tscn")
const roadS=preload("res://Assets/roadS.tscn")
const roadW=preload("res://Assets/roadW.tscn")
const roadE=preload("res://Assets/roadE.tscn")
const crossroadN=preload("res://Assets/crossroadN.tscn")
const crossroadS=preload("res://Assets/crossroadS.tscn")
const crossroadW=preload("res://Assets/crossroadW.tscn")
const crossroadE=preload("res://Assets/crossroadE.tscn")
const roadstripeN=preload("res://Assets/roadstripeN.tscn")
const roadstripeE=preload("res://Assets/roadstripeE.tscn")
var floors={
	"floor":flooring,
	"sidewalk":sidewalk,
	"roadN":roadN,
	"roadS":roadS,
	"roadW":roadW,
	"roadE":roadE,
	"crossroadN":crossroadN,
	"crossroadS":crossroadS,
	"crossroadW":crossroadW,
	"crossroadE":crossroadE,
	"roadstripeN":roadstripeN,
	"roadstripeE":roadstripeE,
}
@export var gridsize:int=16
@export var horizontal_streets:int=1
@export var vertical_streets:int=2
@export var blocks:int=3
@export_range(0.0,1.0)var partial_chance:float=0.5
@export var delay:float=0.02
const cell_size:=1.0
const level_height:=1.0
const front_dir:=Vector3i(0,0,1) # the front of the models faces +Z
const weight_street:=0.5
const max_attempts:=10
var running:bool=false
var tiles_for={
	"straight_ns":["roadstripeN"],
	"straight_ew":["roadstripeE"],
	"cross4":["roadN"],
	"tee_N":["roadN"],
	"tee_S":["roadS"],
	"tee_E":["roadE"],
	"tee_W":["roadW"],
	"crosswalk_N":["crossroadE"],
	"crosswalk_S":["crossroadW"],
	"crosswalk_E":["crossroadN"],
	"crosswalk_W":["crossroadS"],
	"sidewalk":["sidewalk"],
	"floor":["floor"],
}
const DIRS={
	"N":Vector2i(0,1),
	"E":Vector2i(1,0),
	"S":Vector2i(0,-1),
	"W":Vector2i(-1,0),
}
@export_tool_button("Generate") var generate=_run
@export_tool_button("Delete") var delete=_deleteblock

@export_group("Buildings")
@export var build_buildings:bool=true
## Buildings that can ONLY be on the ground floor (shop fronts, doors, gates).
@export var ground_buildings:Array[PackedScene]=[]
## Buildings that can ONLY sit on top of another building (window floors).
@export var middle_buildings:Array[PackedScene]=[]
@export var roof_scene:PackedScene
@export var levels:int=4
## Shift every building (set Y to lift buildings on top of the floor tile).
@export var origin_offset:Vector3=Vector3(0,1,0)

@export_group("Building weights")
@export var roof:float=3.0
@export var empty_space:float=1.5

@export_group("Building debug")
@export var animate:bool=true
@export var steps_per_frame:int=3
@export var show_entropy:bool=true
@export var log_steps:bool=false

# 0 = up, 1 = down, 2 = +x, 3 = -x, 4 = +z, 5 = -z. (d ^ 1 is always the opposite side)
const WDIRS=[
	Vector3i(0,1,0),Vector3i(0,-1,0),
	Vector3i(1,0,0),Vector3i(-1,0,0),
	Vector3i(0,0,1),Vector3i(0,0,-1),
]
const NONE:=Vector3i(-1,-1,-1)

var floor_cells:Dictionary={}
var tiles:Array=[]
var compat:Array=[]
var wave:Dictionary={}
var views:Dictionary={}
var step_count:int=0

###############################################################
# YOUR CODE (street planner) - only two small changes, marked NEW
###############################################################

func _deleteblock()->void:
	views.clear() # NEW
	for child in get_children():
		if child.is_in_group("wfctile"):
			child.queue_free()
func _run()->void:
	if running:return
	running=true
	_check_tiles()
	_deleteblock()
	floor_cells.clear() # NEW
	var roads=_make_streets()
	if roads.is_empty():
		print("No room for streets. Raise gridsize, or lower blocks / the street counts.")
	var plan=_plan(roads)
	print("================================")
	print("CITY BUILT: ",roads.size()," road cells on a ",gridsize,"x",gridsize," grid")
	print("================================")
	await get_tree().process_frame
	for cell in plan:
		if not roads.has(cell):
			_place(plan[cell],cell)
	for cell in roads:
		_place(plan[cell],cell)
		if delay>0.0:
			await get_tree().create_timer(delay).timeout
	if build_buildings: # NEW
		await _build_buildings()
	running=false
func _make_streets()->Dictionary:
	var roads={}
	var h_rows=_pick_lines(horizontal_streets)
	var v_cols=_pick_lines(vertical_streets)
	print("EAST-WEST STREETS at rows: ",h_rows)
	print("NORTH-SOUTH STREETS at columns: ",v_cols)
	for r in h_rows:
		for x in range(gridsize):
			_mark(roads,Vector2i(x,r),"h")
	for c in v_cols:
		var y_from=0
		var y_to=gridsize-1
		if not h_rows.is_empty() and randf()<partial_chance:
			var r=h_rows.pick_random()
			if randf()<0.5:
				y_from=r
			else:
				y_to=r
		for y in range(y_from,y_to+1):
			_mark(roads,Vector2i(c,y),"v")
	return roads
func _mark(roads:Dictionary,cell:Vector2i,kind:String)->void:
	if not roads.has(cell):
		roads[cell]={"h":false,"v":false}
	roads[cell][kind]=true
func _pick_lines(count:int)->Array:
	var candidates=[]
	for i in range(blocks,gridsize-blocks):
		candidates.append(i)
	candidates.shuffle()
	var chosen=[]
	for c in candidates:
		if chosen.size()>=count:break
		var ok=true
		for other in chosen:
			if absi(c-other)<blocks+1:
				ok=false
				break
		if ok:
			chosen.append(c)
	chosen.sort()
	return chosen
func _plan(roads:Dictionary)->Dictionary:
	var plan={}
	var crosswalks={}
	for cell in roads:
		var info=roads[cell]
		if info["h"] and info["v"]:
			plan[cell]=_junction_tile(cell,roads)
			for d in DIRS:
				var n=cell+DIRS[d]
				if roads.has(n) and not(roads[n]["h"] and roads[n]["v"]):
					crosswalks[n]=d
		elif info["h"]:
			plan[cell]=_pick("straight_ew")
		else:
			plan[cell]=_pick("straight_ns")
	for n in crosswalks:
		plan[n]=_pick("crosswalk_"+crosswalks[n])
	for x in range(gridsize):
		for z in range(gridsize):
			var cell=Vector2i(x,z)
			if roads.has(cell):continue
			if _is_block_edge(cell,roads):
				plan[cell]=_pick("sidewalk")
			else:
				plan[cell]=_pick("floor")
				floor_cells[cell]=true # NEW: remember the grey floor cells
	return plan
func _junction_tile(cell:Vector2i,roads:Dictionary)->String:
	var missing=[]
	for d in DIRS:
		if not roads.has(cell+DIRS[d]):
			missing.append(d)
	if missing.size()==1:
		return _pick("tee_"+missing[0])
	return _pick("cross4")
func _is_block_edge(cell:Vector2i,roads:Dictionary)->bool:
	if cell.x==0 or cell.y==0 or cell.x==gridsize-1 or cell.y==gridsize-1:
		return true
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			if roads.has(cell+Vector2i(dx,dz)):
				return true
	return false
func _pick(role:String)->String:
	var options=tiles_for.get(role,[])
	if options.is_empty():
		push_warning("No tile set for role '%s' - using floor"%role)
		return "floor"
	return options.pick_random()
func _check_tiles()->void:
	for role in tiles_for:
		for t in tiles_for[role]:
			if not floors.has(t):
				push_warning("tiles_for['%s'] uses unknown tile '%s'"%[role,t])
func _place(tile_name:String,cell:Vector2i)->void:
	if not floors.has(tile_name):
		push_warning("Unknown tile: "+tile_name)
		return
	var block=floors[tile_name].instantiate()
	add_child(block)
	block.owner=get_tree().edited_scene_root
	block.add_to_group("wfctile")
	block.position=Vector3(cell.x*cell_size,0.0,cell.y*cell_size)

###############################################################
# NEW: WFC BUILDINGS
###############################################################

func _build_buildings() -> void:
	if floor_cells.is_empty():
		print("No grey floor cells to build on. Raise gridsize or blocks.")
		return
	_build_tiles()
	if roof_scene == null:
		push_warning("roof_scene is empty: buildings need a roof, so none will appear.")
	print("BUILDING TILES: ", tiles.size(), " (after roles and rotations), floor cells: ", floor_cells.size())

	var ok := false
	var attempt := 0
	while not ok and attempt < max_attempts:
		attempt += 1
		_clear_views()
		_init_wave()
		ok = await _solve()
		if not ok:
			print("DEAD END on attempt ", attempt, " -> restarting with new dice")

	if ok:
		for c in wave:
			_update_view(c)
		print("===== BUILDING WFC DONE: ", step_count, " steps, attempt ", attempt, " =====")
	else:
		push_warning("Gave up after %d attempts. The rules may be too strict." % max_attempts)

# Repeats: pick the cell with the fewest options, roll the dice, ripple the effect.
func _solve() -> bool:
	step_count = 0
	var changed: Dictionary = {}
	if not _propagate(wave.keys(), changed):
		return false
	var pending: Dictionary = {}
	if animate:
		for c in changed:
			pending[c] = true
		await _flush(pending)

	var cell: Vector3i = _lowest_entropy_cell()
	while cell != NONE:
		step_count += 1
		_collapse(cell)
		changed = {cell: true}
		if not _propagate([cell], changed):
			return false
		if animate:
			for c in changed:
				pending[c] = true
			if step_count % maxi(steps_per_frame, 1) == 0:
				await _flush(pending)
		cell = _lowest_entropy_cell()
	return true

###############################################################
# TILES AND RULES
###############################################################

func _build_tiles() -> void:
	tiles.clear()
	for s in ground_buildings:
		_add_rotated(s, "ground", "floor")
	for s in middle_buildings:
		_add_rotated(s, "floor", "floor")
	if roof_scene != null:
		_add_fixed("roof", roof_scene, "floor", "sky", roof, "side", true)
	_add_fixed("air", null, "sky", "sky", empty_space, "open", false)
	_add_fixed("street", null, "ground", "sky", weight_street, "open", false)
	_build_compat()

# One building model becomes 4 tiles (turned 0, 90, 180, 270 degrees).
func _add_rotated(scene: PackedScene, bottom: String, top: String) -> void:
	if scene == null:
		return
	for rot in range(4):
		var t: Dictionary = {
			"name": scene.resource_path.get_file().get_basename() + "_" + bottom + "_r" + str(rot),
			"scene": scene, "rot": rot, "bottom": bottom, "top": top,
			"weight": 1.0, "solid": true, "sock": {},
		}
		for d in range(2, 6):
			# Which side of the UNROTATED model ends up facing world direction d?
			var local: Vector3 = Vector3(WDIRS[d]).rotated(Vector3.UP, deg_to_rad(-90.0 * rot))
			var li := Vector3i(roundi(local.x), 0, roundi(local.z))
			var kind := "side"
			if li == front_dir:
				kind = "front"
			elif li == -front_dir:
				kind = "back"
			t["sock"][d] = kind
		tiles.append(t)

func _add_fixed(nm: String, scene: PackedScene, bottom: String, top: String, weight: float, side_kind: String, solid: bool) -> void:
	var t: Dictionary = {
		"name": nm, "scene": scene, "rot": 0, "bottom": bottom, "top": top,
		"weight": maxf(weight, 0.001), "solid": solid, "sock": {},
	}
	for d in range(2, 6):
		t["sock"][d] = side_kind
	tiles.append(t)

func _build_compat() -> void:
	compat.clear()
	for d in range(6):
		var per_tile: Array = []
		for a in range(tiles.size()):
			var ok := PackedInt32Array()
			for b in range(tiles.size()):
				if _fits(a, b, d):
					ok.append(b)
			per_tile.append(ok)
		compat.append(per_tile)

# THE RULES. Can tile b sit next to tile a, in direction d from a?
func _fits(a: int, b: int, d: int) -> bool:
	var ta: Dictionary = tiles[a]
	var tb: Dictionary = tiles[b]
	match d:
		0:
			return ta["top"] == tb["bottom"]
		1:
			return tb["top"] == ta["bottom"]
		_:
			return _side_ok(ta["sock"][d], tb["sock"][d ^ 1])

# A front must face "open" space. Everything else can touch anything.
func _side_ok(a: String, b: String) -> bool:
	if a == "front":
		return b == "open"
	if b == "front":
		return a == "open"
	return true

###############################################################
# WFC
###############################################################

func _init_wave() -> void:
	wave.clear()
	for x in range(gridsize):
		for y in range(levels):
			for z in range(gridsize):
				var on_floor: bool = floor_cells.has(Vector2i(x, z))
				var opts: Array = []
				for i in range(tiles.size()):
					var t: Dictionary = tiles[i]
					if y == 0 and t["bottom"] != "ground":
						continue
					if y == levels - 1 and t["top"] != "sky":
						continue
					# THE NEW RULE: buildings and roofs only above the grey floor.
					if not on_floor and t["solid"]:
						continue
					opts.append(i)
				wave[Vector3i(x, y, z)] = opts

func _entropy(opts: Array) -> float:
	var total: float = 0.0
	var wlogw: float = 0.0
	for i in opts:
		var w: float = tiles[i]["weight"]
		total += w
		wlogw += w * log(w)
	return log(total) - wlogw / total

func _lowest_entropy_cell() -> Vector3i:
	var best: Vector3i = NONE
	var best_h: float = INF
	for c in wave:
		var opts: Array = wave[c]
		if opts.size() <= 1:
			continue
		var h: float = _entropy(opts) + randf() * 0.001
		if h < best_h:
			best_h = h
			best = c
	return best

func _collapse(cell: Vector3i) -> void:
	var opts: Array = wave[cell]
	var total: float = 0.0
	for i in opts:
		total += float(tiles[i]["weight"])
	var roll: float = randf() * total
	var choice: int = opts[opts.size() - 1]
	for i in opts:
		roll -= float(tiles[i]["weight"])
		if roll <= 0.0:
			choice = i
			break
	if log_steps:
		print("STEP ", step_count, " | cell ", cell, " | options ", opts.size(), " -> picked ", tiles[choice]["name"])
	wave[cell] = [choice]

# Ripple: remove every option that can no longer fit next to its neighbours,
# and keep going until nothing changes. Returns false on a dead end.
func _propagate(start: Array, changed: Dictionary) -> bool:
	var queue: Array = start.duplicate()
	while queue.size() > 0:
		var cell: Vector3i = queue.pop_back()
		var opts: Array = wave[cell]
		if opts.is_empty():
			return false
		for d in range(6):
			var n: Vector3i = cell + WDIRS[d]
			if not wave.has(n):
				continue
			var allowed := PackedByteArray()
			allowed.resize(tiles.size())
			for a in opts:
				for b in compat[d][a]:
					allowed[b] = 1
			var n_opts: Array = wave[n]
			var kept: Array = []
			for b in n_opts:
				if allowed[b] == 1:
					kept.append(b)
			if kept.size() != n_opts.size():
				wave[n] = kept
				changed[n] = true
				if kept.is_empty():
					return false
				queue.append(n)
	return true

###############################################################
# VISUALS
###############################################################

func _flush(pending: Dictionary) -> void:
	for c in pending:
		_update_view(c)
	pending.clear()
	await get_tree().process_frame

func _clear_views() -> void:
	for c in views:
		(views[c] as Node).queue_free()
	views.clear()

func _update_view(cell: Vector3i) -> void:
	if views.has(cell):
		(views[cell] as Node).queue_free()
		views.erase(cell)
	var opts: Array = wave[cell]
	var pos: Vector3 = Vector3(cell.x * cell_size, cell.y * level_height, cell.z * cell_size) + origin_offset
	if opts.size() == 1:
		var t: Dictionary = tiles[opts[0]]
		if t["scene"] == null:
			return
		var node: Node3D = (t["scene"] as PackedScene).instantiate()
		add_child(node)
		node.owner = get_tree().edited_scene_root
		node.add_to_group("wfctile")
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
		add_child(label)
		label.add_to_group("wfctile")
		label.position = pos
		views[cell] = label
