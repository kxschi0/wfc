@tool
class_name WfcConsoleLogger
extends WfcLogger
## ONE job: print the WFC story to the Output panel. Changes nothing.

const RIPPLE_SHOW := 3

var log_steps: bool
var detail_steps: int
var _trace_ripple: bool = false
var _ripple_lines: int = 0
var _pick_stats: Dictionary = {}
var _options_start: int = 0
var _last_undecided: int = 0

func _init(p_log_steps: bool = false, p_detail_steps: int = 3) -> void:
	log_steps = p_log_steps
	detail_steps = p_detail_steps

func setup(building_tiles: BuildingTiles, floor_count: int, levels: int) -> void:
	ConsoleFormat.header("WFC CITY BUILDINGS")
	print("tiles          : ground (", building_tiles.ground_count, " models x 4) + middle (", building_tiles.middle_count, " models x 4) + roof ", building_tiles.roof_count, " + air 1 + street 1 = ", building_tiles.tiles.size())
	print("building space : ", floor_count, " floor cells x ", levels, " levels = ", floor_count * levels, " cells")

func wave_initialized(attempt: int) -> void:
	_pick_stats.clear()
	_trace_ripple = false
	_options_start = _total_options()
	print("")
	print("attempt ", attempt)
	print("1. Initialize wave")
	print("   cells   : ", solver.gridsize, " x ", solver.levels, " x ", solver.gridsize, " = ", solver.wave.size())
	print("   options : ", _options_start, " in total")
	print("   per floor cell : ", _layer_line())

func after_first_ripple() -> void:
	var after: int = _total_options()
	var undecided: int = _count_undecided()
	print("2. Initial propagate")
	print("   options : ", _options_start, " - ", _options_start - after, " removed = ", after)
	print("   per floor cell : ", _layer_line())
	print("   cells   : ", solver.wave.size() - undecided, " decided + ", undecided, " undecided = ", solver.wave.size())
	_last_undecided = undecided
	print("3. Collapse loop")
	if not log_steps:
		print("   (turn on log_steps in the Inspector to see every step)")

func initial_dead_end() -> void:
	print("dead end inside the initial propagate")

func cell_selected(cell: Vector3i) -> void:
	var opts: Array = solver.wave[cell]
	_pick_stats[opts.size()] = int(_pick_stats.get(opts.size(), 0)) + 1
	_ripple_lines = 0
	_trace_ripple = true
	if not _full():
		return
	var h: float = solver.entropy(opts)
	var tied: int = 0
	for c in solver.wave:
		var o: Array = solver.wave[c]
		if o.size() > 1 and absf(solver.entropy(o) - h) < 0.001:
			tied += 1
	print("")
	print("STEP ", solver.step_count)
	ConsoleFormat.row("find lowest entropy", str(cell) + " has " + str(opts.size()) + " options, " + _entropy_math(opts))
	if tied > 1:
		ConsoleFormat.more(str(tied) + " cells share this H, one picked at random")

func collapsed(opts: Array, total: float, roll: float, choice: int) -> void:
	if not _full():
		return
	var tiles: Array = solver.tiles
	var text: String = ""
	if opts.size() <= 4:
		var parts := PackedStringArray()
		var start: float = 0.0
		for i in opts:
			var w: float = float(tiles[i]["weight"])
			parts.append("%s %s-%s" % [tiles[i]["name"], snappedf(start, 0.01), snappedf(start + w, 0.01)])
			start += w
		text = " | ".join(parts) + "   roll " + str(snappedf(roll, 0.01)) + " of " + str(snappedf(total, 0.01)) + " -> " + str(tiles[choice]["name"])
	else:
		text = str(opts.size()) + " options, total weight " + str(snappedf(total, 0.01)) + "   roll " + str(snappedf(roll, 0.01)) + " -> " + str(tiles[choice]["name"])
	ConsoleFormat.row("collapse", text)

func rippled(dst: Vector3i, before_n: int, after_n: int) -> void:
	if not (log_steps and _trace_ripple and _full()):
		return
	_ripple_lines += 1
	if _ripple_lines > RIPPLE_SHOW:
		return
	var text: String = str(dst) + " " + str(before_n) + " -> " + str(after_n) + " options"
	if _ripple_lines == 1:
		ConsoleFormat.row("propagate", text)
	else:
		ConsoleFormat.more(text)

func step_finished(cell: Vector3i, changed: Dictionary) -> void:
	_trace_ripple = false
	if not log_steps:
		return
	var t: Dictionary = solver.tiles[solver.wave[cell][0]]
	var nm: String = t["name"]
	var left: int = _count_undecided()
	if _full():
		if changed.size() == 1:
			ConsoleFormat.row("propagate", "no neighbour changed")
		elif _ripple_lines > RIPPLE_SHOW:
			ConsoleFormat.more("+" + str(_ripple_lines - RIPPLE_SHOW) + " more cells")
		if t["scene"] == null:
			ConsoleFormat.row("update view", nm + " at " + str(cell) + " (empty space, nothing drawn)")
		else:
			ConsoleFormat.row("update view", nm + " placed at " + str(cell))
		ConsoleFormat.row("undecided cells", str(_last_undecided) + " -> " + str(left))
	else:
		print("step ", solver.step_count, " | ", cell, " = ", nm, " | undecided ", _last_undecided, " -> ", left)
	_last_undecided = left

func dead_end(cell: Vector3i) -> void:
	_trace_ripple = false
	ConsoleFormat.row("dead end", "collapsing " + str(cell) + " left a cell with 0 options")

func attempt_failed(attempt: int) -> void:
	print("attempt ", attempt, " failed, restarting")

func summary(attempt: int) -> void:
	ConsoleFormat.header("DONE")
	print("attempts : ", attempt)
	print("steps by number of options at the moment of the pick:")
	var keys: Array = _pick_stats.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		print("  ", str(k).rpad(2), " options : ", _pick_stats[k])
		parts.append(str(_pick_stats[k]))
	print("  total      : ", " + ".join(parts), " = ", solver.step_count, " steps")

# ---------- helpers ----------

func _full() -> bool:
	return log_steps and solver.step_count <= detail_steps

func _count_undecided() -> int:
	var n: int = 0
	for c in solver.wave:
		if solver.wave[c].size() > 1:
			n += 1
	return n

func _total_options() -> int:
	var n: int = 0
	for c in solver.wave:
		n += solver.wave[c].size()
	return n

# options per grey floor cell, one entry per level: "y0 13 | y1 19 | y2 6..9"
func _layer_line() -> String:
	var parts := PackedStringArray()
	for y in range(solver.levels):
		var lo: int = 9999
		var hi: int = 0
		for c in solver.wave:
			if c.y != y or not solver.floor_cells.has(Vector2i(c.x, c.z)):
				continue
			var n: int = solver.wave[c].size()
			lo = mini(lo, n)
			hi = maxi(hi, n)
		if lo == hi:
			parts.append("y%d %d" % [y, lo])
		else:
			parts.append("y%d %d..%d" % [y, lo, hi])
	return " | ".join(parts)

func _entropy_math(opts: Array) -> String:
	var total: float = 0.0
	var wlogw: float = 0.0
	for i in opts:
		var w: float = solver.tiles[i]["weight"]
		total += w
		wlogw += w * log(w)
	var op: String = "-"
	var mag: float = wlogw
	if wlogw < 0.0:
		op = "+"
		mag = -wlogw
	return "H = ln(%s) %s %s/%s = %s" % [snappedf(total, 0.01), op, snappedf(mag, 0.001), snappedf(total, 0.01), snappedf(solver.entropy(opts), 0.001)]
