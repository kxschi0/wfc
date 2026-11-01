@tool
class_name StreetPlanner
extends RefCounted
## ONE job: decide which grid cells are road. Knows nothing about scenes.
## Returns { Vector2i : {"h": bool, "v": bool} }

var gridsize: int
var blocks: int
var partial_chance: float
var requested_horizontal: int = 0
var requested_vertical: int = 0
var row_count: int = 0
var col_count: int = 0
var notes: Array[String] = [] # what happened, for the reporter to print

func _init(p_gridsize: int, p_blocks: int, p_partial_chance: float) -> void:
	gridsize = p_gridsize
	blocks = p_blocks
	partial_chance = p_partial_chance

func make_streets(horizontal_streets: int, vertical_streets: int) -> Dictionary:
	notes.clear()
	requested_horizontal = horizontal_streets
	requested_vertical = vertical_streets
	var roads := {}
	var h_rows := _pick_lines(horizontal_streets)
	var v_cols := _pick_lines(vertical_streets)
	row_count = h_rows.size()
	col_count = v_cols.size()
	for r in h_rows:
		for x in range(gridsize):
			_mark(roads, Vector2i(x, r), "h")
		notes.append("row %d    : x 0..%d = %d cells" % [r, gridsize - 1, gridsize])
	for c in v_cols:
		var y_from := 0
		var y_to := gridsize - 1
		var note := ""
		if not h_rows.is_empty() and randf() < partial_chance:
			var r = h_rows.pick_random()
			note = " (partial)"
			if randf() < 0.5:
				y_from = r
			else:
				y_to = r
		for y in range(y_from, y_to + 1):
			_mark(roads, Vector2i(c, y), "v")
		notes.append("column %d : z %d..%d = %d cells%s" % [c, y_from, y_to, y_to - y_from + 1, note])
	return roads

func _mark(roads: Dictionary, cell: Vector2i, kind: String) -> void:
	if not roads.has(cell):
		roads[cell] = {"h": false, "v": false}
	roads[cell][kind] = true

func _pick_lines(count: int) -> Array:
	var candidates := []
	for i in range(blocks, gridsize - blocks):
		candidates.append(i)
	candidates.shuffle()
	var chosen := []
	for c in candidates:
		if chosen.size() >= count:
			break
		var ok := true
		for other in chosen:
			if absi(c - other) < blocks + 1:
				ok = false
				break
		if ok:
			chosen.append(c)
	chosen.sort()
	return chosen
