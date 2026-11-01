@tool
class_name WfcSolver
extends RefCounted
## ONE job: Wave Function Collapse. It never draws and never prints itself.
## It only TELLS `logger` and `animator` what happened.

var wave: Dictionary = {} # Vector3i -> Array of tile indexes still possible
var step_count: int = 0
var tiles: Array
var compat: Array
var floor_cells: Dictionary
var gridsize: int
var levels: int
var logger: WfcLogger
var animator: WfcAnimator

func _init(p_tiles: Array, p_compat: Array, p_floor_cells: Dictionary, p_gridsize: int, p_levels: int, p_logger: WfcLogger, p_animator: WfcAnimator) -> void:
	tiles = p_tiles
	compat = p_compat
	floor_cells = p_floor_cells
	gridsize = p_gridsize
	levels = p_levels
	logger = p_logger
	animator = p_animator
	logger.attach(self)

func init_wave() -> void:
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
					# THE RULE: buildings and roofs only above the grey floor.
					if not on_floor and t["solid"]:
						continue
					opts.append(i)
				wave[Vector3i(x, y, z)] = opts

# Repeats: pick the cell with the fewest options, roll the dice, ripple the effect.
func solve() -> bool:
	step_count = 0
	var changed: Dictionary = {}
	if not propagate(wave.keys(), changed):
		logger.initial_dead_end()
		return false
	logger.after_first_ripple()
	await animator.show(changed, step_count)

	var cell: Vector3i = lowest_entropy_cell()
	while cell != CityConst.NONE:
		step_count += 1
		logger.cell_selected(cell)
		collapse(cell)
		changed = {cell: true}
		if not propagate([cell], changed):
			logger.dead_end(cell)
			return false
		logger.step_finished(cell, changed)
		await animator.show(changed, step_count)
		cell = lowest_entropy_cell()
	return true

func entropy(opts: Array) -> float:
	var total: float = 0.0
	var wlogw: float = 0.0
	for i in opts:
		var w: float = tiles[i]["weight"]
		total += w
		wlogw += w * log(w)
	return log(total) - wlogw / total

func lowest_entropy_cell() -> Vector3i:
	var best: Vector3i = CityConst.NONE
	var best_h: float = INF
	for c in wave:
		var opts: Array = wave[c]
		if opts.size() <= 1:
			continue
		var h: float = entropy(opts) + randf() * 0.001
		if h < best_h:
			best_h = h
			best = c
	return best

func collapse(cell: Vector3i) -> void:
	var opts: Array = wave[cell]
	var total: float = 0.0
	for i in opts:
		total += float(tiles[i]["weight"])
	var roll: float = randf() * total
	var roll_start: float = roll
	var choice: int = opts[opts.size() - 1]
	for i in opts:
		roll -= float(tiles[i]["weight"])
		if roll <= 0.0:
			choice = i
			break
	logger.collapsed(opts, total, roll_start, choice)
	wave[cell] = [choice]

# Ripple: remove every option that can no longer fit next to its neighbours,
# and keep going until nothing changes. Returns false on a dead end.
func propagate(start: Array, changed: Dictionary) -> bool:
	var queue: Array = start.duplicate()
	while queue.size() > 0:
		var cell: Vector3i = queue.pop_back()
		var opts: Array = wave[cell]
		if opts.is_empty():
			return false
		for d in range(6):
			var n: Vector3i = cell + CityConst.WDIRS[d]
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
				logger.rippled(n, n_opts.size(), kept.size())
				wave[n] = kept
				changed[n] = true
				if kept.is_empty():
					return false
				queue.append(n)
	return true
