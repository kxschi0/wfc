@tool
class_name GroundPlanner
extends RefCounted
## ONE job: turn the road map into a tile NAME for every cell
## (junctions, crosswalks, sidewalks, floor). Does not create any nodes.

const DIRS := {
	"N": Vector2i(0, 1),
	"E": Vector2i(1, 0),
	"S": Vector2i(0, -1),
	"W": Vector2i(-1, 0),
}

var gridsize: int
var catalog: TileCatalog
var floor_cells: Dictionary = {} # the grey floor cells (buildings may stand here)

func _init(p_gridsize: int, p_catalog: TileCatalog) -> void:
	gridsize = p_gridsize
	catalog = p_catalog

func plan(roads: Dictionary) -> Dictionary:
	floor_cells.clear()
	var result := {}
	var crosswalks := {}
	for cell in roads:
		var info = roads[cell]
		if info["h"] and info["v"]:
			result[cell] = _junction_tile(cell, roads)
			for d in DIRS:
				var n = cell + DIRS[d]
				if roads.has(n) and not (roads[n]["h"] and roads[n]["v"]):
					crosswalks[n] = d
		elif info["h"]:
			result[cell] = catalog.pick("straight_ew")
		else:
			result[cell] = catalog.pick("straight_ns")
	for n in crosswalks:
		result[n] = catalog.pick("crosswalk_" + crosswalks[n])
	for x in range(gridsize):
		for z in range(gridsize):
			var cell := Vector2i(x, z)
			if roads.has(cell):
				continue
			if _is_block_edge(cell, roads):
				result[cell] = catalog.pick("sidewalk")
			else:
				result[cell] = catalog.pick("floor")
				floor_cells[cell] = true
	return result

func _junction_tile(cell: Vector2i, roads: Dictionary) -> String:
	var missing := []
	for d in DIRS:
		if not roads.has(cell + DIRS[d]):
			missing.append(d)
	if missing.size() == 1:
		return catalog.pick("tee_" + missing[0])
	return catalog.pick("cross4")

func _is_block_edge(cell: Vector2i, roads: Dictionary) -> bool:
	if cell.x == 0 or cell.y == 0 or cell.x == gridsize - 1 or cell.y == gridsize - 1:
		return true
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if roads.has(cell + Vector2i(dx, dz)):
				return true
	return false
