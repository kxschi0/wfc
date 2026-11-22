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
## true = every straight road cell is the plain road (only crossings are marked).
## false = the old look: a stripe tile on every straight road cell.
var plain_roads: bool = true
## true = the outer ring of the grid is sidewalk, except where a road reaches the edge (the road stays a road).
## false = no ring at all: the cells at the edge are floor (or the usual sidewalk beside a street).
var sidewalk_border: bool = true

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
		elif plain_roads:
			result[cell] = catalog.pick("straight_plain")
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
	if sidewalk_border:
		# Last step: the outer ring becomes sidewalk. Roads are left alone, so a road
		# that reaches the edge stays a road.
		for cell in result.keys():
			if _is_grid_edge(cell) and not roads.has(cell):
				result[cell] = catalog.pick("sidewalk")
				floor_cells.erase(cell) # no building on the border
	return result

func _junction_tile(cell: Vector2i, roads: Dictionary) -> String:
	var missing := []
	for d in DIRS:
		if not roads.has(cell + DIRS[d]):
			missing.append(d)
	if missing.size() == 1:
		return catalog.pick("tee_" + missing[0])
	return catalog.pick("cross4")

func _is_grid_edge(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == gridsize - 1 or cell.y == gridsize - 1

# A cell right next to a road. (The outer ring is NOT decided here: it belongs to the
# "sidewalk border" option, applied at the end of plan().)
func _is_block_edge(cell: Vector2i, roads: Dictionary) -> bool:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if roads.has(cell + Vector2i(dx, dz)):
				return true
	return false
