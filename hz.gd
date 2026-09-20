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
@export var min_block:int=3
@export_range(0.0,1.0)var partial_chance:float=0.5
@export_range(0.0,1.0)var crosswalk_chance:float=1.0
@export var delay_time:float=0.02
@export var cell_size:float=1.0
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
@export var generate:bool=false:
	set(value):
		if value:_run()
		generate=false
@export var delete:bool=false:
	set(value):
		if value:_deleteblock()
		delete=false
@export var preview_tiles:bool=false:
	set(value):
		if value:_preview()
		preview_tiles=false
func _deleteblock()->void:
	for child in get_children():
		if child.is_in_group("wfctile"):
			child.queue_free()

func _run()->void:
	if running:return
	running=true
	_check_tiles()
	_deleteblock()
	var roads=_make_streets()
	if roads.is_empty():
		print("No room for streets. Raise gridsize, or lower min_block / the street counts.")
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
		if delay_time>0.0:
			await get_tree().create_timer(delay_time).timeout
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
	for i in range(min_block,gridsize-min_block):
		candidates.append(i)
	candidates.shuffle()
	var chosen=[]
	for c in candidates:
		if chosen.size()>=count:break
		var ok=true
		for other in chosen:
			if absi(c-other)<min_block+1:
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
					if randf()<crosswalk_chance:
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
func _preview()->void:
	_deleteblock()
	await get_tree().process_frame
	var i=0
	for tile_name in floors:
		var cell=Vector2i(i*2,0)
		_place(tile_name,cell)
		_label(tile_name,cell)
		i+=1
func _label(text:String,cell:Vector2i)->void:
	var label=Label3D.new()
	label.text=text
	label.font_size=48
	label.pixel_size=0.004
	label.rotation_degrees=Vector3(-90,0,0)
	label.position=Vector3(cell.x*cell_size,0.05,(cell.y-0.7)*cell_size)
	add_child(label)
	label.owner=get_tree().edited_scene_root
	label.add_to_group("wfctile")
func _place(tile_name:String,cell:Vector2i)->void:
	if not floors.has(tile_name):
		push_warning("Unknown tile: "+tile_name)
		return
	var block=floors[tile_name].instantiate()
	add_child(block)
	block.owner=get_tree().edited_scene_root
	block.add_to_group("wfctile")
	block.position=Vector3(cell.x*cell_size,0.0,cell.y*cell_size)
