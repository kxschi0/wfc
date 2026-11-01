@tool
class_name LayoutReport
extends RefCounted
## ONE job: print the street/ground layout math. Changes nothing.

func print_report(streets: StreetPlanner, ground: GroundPlanner, roads: Dictionary, plan: Dictionary) -> void:
	ConsoleFormat.header("LAYOUT")
	var gridsize: int = streets.gridsize
	print("gridsize ", gridsize, " | horizontal ", streets.requested_horizontal, " | vertical ", streets.requested_vertical, " | min block size ", streets.blocks)
	print(gridsize, " x ", gridsize, " = ", gridsize * gridsize, " cells")
	for line in streets.notes:
		print(line)
	if roads.is_empty():
		print("No room for streets. Raise gridsize, or lower blocks / the street counts.")

	var h_cells: int = 0
	var v_cells: int = 0
	var both: int = 0
	for cell in roads:
		if roads[cell]["h"]:
			h_cells += 1
		if roads[cell]["v"]:
			v_cells += 1
		if roads[cell]["h"] and roads[cell]["v"]:
			both += 1
	var sidewalks: int = 0
	for cell in plan:
		if plan[cell] == "sidewalk":
			sidewalks += 1
	var total: int = gridsize * gridsize
	var non_road: int = total - roads.size()
	print("roads    : ", h_cells, " + ", v_cells, " - ", both, " = ", roads.size())
	print("non-road : ", total, " - ", roads.size(), " = ", non_road)
	print("sidewalk : ", sidewalks)
	print("floor    : ", non_road, " - ", sidewalks, " = ", ground.floor_cells.size())
	var formula: int = (streets.row_count + 1) * (streets.col_count + 1)
	var counted: int = _count_floor_blocks(ground)
	var line: String = "blocks   : (" + str(streets.row_count) + " + 1) x (" + str(streets.col_count) + " + 1) = " + str(formula)
	if counted != formula:
		line += " | counted on the map: " + str(counted)
	print(line)

# Counts separate groups of grey floor cells (flood fill).
func _count_floor_blocks(ground: GroundPlanner) -> int:
	var seen: Dictionary = {}
	var count: int = 0
	for start in ground.floor_cells:
		if seen.has(start):
			continue
		count += 1
		seen[start] = true
		var stack: Array = [start]
		while stack.size() > 0:
			var cur: Vector2i = stack.pop_back()
			for d in GroundPlanner.DIRS:
				var nb: Vector2i = cur + GroundPlanner.DIRS[d]
				if ground.floor_cells.has(nb) and not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
	return count
