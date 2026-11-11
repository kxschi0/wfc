@tool
class_name CityGenerator
extends Node3D
## ORCHESTRATOR ONLY. It reads the settings, creates the helpers and calls
## them in order. All real work lives in the other files.
## The City Generator panel (addons/wfc_gen_dock) talks to this node through
## the signals and the public functions at the bottom of this file.

signal message(text: String, level: int) # level: 0 info, 1 warning, 2 error
signal state_changed(state: String)
signal generated(valid: bool, problems: PackedStringArray)
signal assets_changed

const MAX_ATTEMPTS := 10
const TILES_NODE := "KolapsaTiles" # every generated tile lives under this node

@export var gridsize: int = 16
@export var horizontal_streets: int = 1
@export var vertical_streets: int = 2
@export var blocks: int = 3
@export_range(0.0, 1.0) var partial_chance: float = 0.5
@export_range(0.25, 4.0, 0.25) var tile_size: float = 1.0:
	set(value):
		tile_size = value
		_apply_tile_size()
@export_range(0.0, 1.0, 0.05) var density: float = 0.7
@export var delay: float = 0.02
@export_tool_button("Generate") var generate = _run
@export_tool_button("Delete") var delete = _delete_all

@export_group("Buildings")
@export var build_buildings: bool = true
## Buildings that can ONLY be on the ground floor (shop fronts, doors, gates).
@export var ground_buildings: Array[PackedScene] = []
## Buildings that can ONLY sit on top of another building (window floors).
@export var middle_buildings: Array[PackedScene] = []
@export var roof_scene: PackedScene
@export var levels: int = 4
## Shift every building (set Y to lift buildings on top of the floor tile).
@export var origin_offset: Vector3 = Vector3(0, 1, 0)

@export_group("Building weights")
@export var roof: float = 3.0
## Weight of "empty air". The density slider scales this.
@export var empty_space: float = 1.5

@export_group("Building debug")
@export var animate: bool = true
@export var steps_per_frame: int = 3
@export var show_entropy: bool = true
## Turn off to silence ALL printing.
@export var console_output: bool = true
@export var log_steps: bool = false
## How many steps are printed in full. After that: one line per step.
@export var detail_steps: int = 3

@export_group("Seed")
## Untick to reuse the seed below and get the SAME city again.
@export var randomize_seed: bool = true
## The seed that made the current city. Copy it to keep a layout you like.
@export var seed_value: int = 0

var running: bool = false
var is_valid: bool = false
var problems: PackedStringArray = PackedStringArray()
var last_result: Dictionary = {} # what the last successful run produced
var _force_new_seed: bool = false

# ------------------------------------------------------------------ seed

# Every random call in all the scripts uses Godot's global generator,
# so seeding it here once makes the whole city repeatable.
func _apply_seed() -> void:
	if randomize_seed or _force_new_seed:
		randomize()
		seed_value = randi()
	seed(seed_value)
	if console_output:
		print("seed : ", seed_value)

# ------------------------------------------------------- scene housekeeping

func _container() -> Node3D:
	var c := get_node_or_null(TILES_NODE) as Node3D
	if c == null:
		c = Node3D.new()
		c.name = TILES_NODE
		add_child(c)
		if is_inside_tree() and get_tree().edited_scene_root != null:
			c.owner = get_tree().edited_scene_root
	c.scale = Vector3.ONE * tile_size
	return c

func _apply_tile_size() -> void:
	if not is_inside_tree():
		return
	var c := get_node_or_null(TILES_NODE) as Node3D
	if c != null:
		c.scale = Vector3.ONE * tile_size

# Clears tiles under the container AND any left directly under this node by
# older versions of the plug-in.
func _clear_scene() -> void:
	SceneSpawner.new(self).clear()
	SceneSpawner.new(_container()).clear()

func _reset_result() -> void:
	last_result = {}
	problems = PackedStringArray()
	is_valid = false

# The Delete button. Does nothing while a city is being generated.
func _delete_all() -> void:
	if running:
		return
	_clear_scene()
	_reset_result()
	generated.emit(false, problems)

func _say(text: String, level: int = 0) -> void:
	EditorToast.push(text, level as EditorToast.Level)
	message.emit(text, level)

func _set_state(new_state: String) -> void:
	state_changed.emit(new_state)

# ------------------------------------------------------------- generating

# The Generate button. `running` is reset here, so every exit path of
# _generate() (errors, early returns, normal finish) resets it.
func _run() -> void:
	if running:
		return
	running = true
	_set_state("Generating")
	await _generate()
	running = false
	_force_new_seed = false
	_set_state("Idle")

func _generate() -> void:
	var errors := ParamValidator.validate(gridsize, levels, blocks, horizontal_streets, vertical_streets, build_buildings, roof_scene, ground_buildings, middle_buildings, tile_size, density)
	if not errors.is_empty():
		_say("Can't generate:\n" + "\n".join(errors), 2)
		return

	_clear_scene()
	_reset_result()
	_apply_seed()

	var catalog := TileCatalog.new()
	catalog.check()
	var streets := StreetPlanner.new(gridsize, blocks, partial_chance)
	var ground := GroundPlanner.new(gridsize, catalog)

	var roads := streets.make_streets(horizontal_streets, vertical_streets)
	var street_warning := ParamValidator.street_warning(streets)
	if street_warning != "":
		_say(street_warning, 1)
	var plan := ground.plan(roads)
	if console_output:
		LayoutReport.new().print_report(streets, ground, roads, plan)

	await get_tree().process_frame
	var spawner := SceneSpawner.new(_container())
	var placer := GroundPlacer.new(spawner, catalog)
	for cell in plan:
		if not roads.has(cell):
			placer.place(plan[cell], cell)
	for cell in roads:
		placer.place(plan[cell], cell)
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout

	if not build_buildings:
		last_result = {"streets_only": true}
		_finish(true)
		return
	var ok: bool = await _build_buildings(ground.floor_cells, spawner)
	_finish(ok)

func _finish(ok: bool) -> void:
	if not ok:
		is_valid = false
		problems = PackedStringArray(["The city could not be finished. See the messages above."])
		generated.emit(false, problems)
		return
	var found := validate_current(false)
	if found.is_empty():
		_say("City generated and checked: no conflicts (seed %d)." % seed_value, 0)
	else:
		_say("%d conflict(s) found. Export is blocked until you regenerate." % found.size(), 2)

# Density scales the "empty" weights. At the default density (0.7) the factor
# is exactly 1, so the weights are the ones you set: air = empty_space,
# empty lot = 0.5. Higher density = fewer gaps, lower = more gaps.
func _density_factor() -> float:
	return exp((0.7 - density) * 3.0)

func _empty_weight() -> float:
	return empty_space * _density_factor()

func _street_weight() -> float:
	return 0.5 * _density_factor()

func _build_buildings(floor_cells: Dictionary, spawner: SceneSpawner) -> bool:
	if floor_cells.is_empty():
		_say("No room for buildings. Raise the grid size or lower the block size.", 1)
		return false

	var building_tiles := BuildingTiles.new()
	building_tiles.build(ground_buildings, middle_buildings, roof_scene, roof, _empty_weight(), _street_weight())

	var logger: WfcLogger = WfcLogger.new() # silent
	if console_output:
		logger = WfcConsoleLogger.new(log_steps, detail_steps)

	var solver := WfcSolver.new(building_tiles.tiles, building_tiles.compat, floor_cells, gridsize, levels, logger, null)
	var view := WfcView.new(spawner, building_tiles.tiles, solver.wave, show_entropy, origin_offset)
	var animator := WfcAnimator.new(view, get_tree(), animate, steps_per_frame)
	solver.animator = animator

	logger.setup(building_tiles, floor_cells.size(), levels)

	var ok := false
	var attempt := 0
	while not ok and attempt < MAX_ATTEMPTS:
		attempt += 1
		view.clear()
		animator.reset()
		solver.init_wave()
		logger.wave_initialized(attempt)
		ok = await solver.solve()
		if not ok:
			logger.attempt_failed(attempt)

	if not ok:
		view.clear() # don't leave a half-built city behind
		_say("Gave up after %d failed attempts. The building rules may be too strict for this layout. Try Regenerate, a bigger grid, or more assets." % attempt, 2)
		return false

	view.update_all()
	logger.summary(attempt)
	last_result = {
		"tiles": building_tiles.tiles,
		"wave": solver.wave.duplicate(true),
		"floor_cells": floor_cells,
		"rules": building_tiles.rules,
		"levels": levels,
	}
	return true

# ------------------------------------------- THE PANEL TALKS TO THESE

func start_generation() -> void:
	_run()

func start_regeneration() -> void:
	_force_new_seed = true
	_run()

func clear_city() -> void:
	_delete_all()

func number_errors() -> PackedStringArray:
	return ParamValidator.validate_numbers(gridsize, levels, blocks, horizontal_streets, vertical_streets, build_buildings, tile_size, density)

func tileset_errors() -> PackedStringArray:
	return ParamValidator.validate_tileset(build_buildings, roof_scene, ground_buildings, middle_buildings)

# Re-checks the last generated city (UC-05). Also runs after every generation.
func validate_current(announce: bool = true) -> PackedStringArray:
	problems = SceneValidator.check(last_result)
	is_valid = problems.is_empty()
	if is_valid and announce:
		_say("Scene check passed: every piece follows the rules.", 0)
	generated.emit(is_valid, problems)
	return problems

# Saves the city as a standalone scene (UC-06). Only valid cities.
func export_to(path: String) -> Error:
	if running:
		return ERR_BUSY
	if not is_valid:
		_say("Export is blocked: the city has problems or hasn't been generated.", 2)
		return ERR_INVALID_DATA
	var err := SceneExporter.export_scene(_container(), path)
	if err == OK:
		_say("Exported to " + path, 0)
	else:
		_say("Export failed (error code %d). Check the path and try again." % err, 2)
	return err

# The lists shown in the panel's tabs. kind: "ground", "middle" or "roof".
func assets(kind: String) -> Array:
	match kind:
		"ground":
			return ground_buildings
		"middle":
			return middle_buildings
		"roof":
			return [] if roof_scene == null else [roof_scene]
	return []

func add_asset(kind: String, scene: PackedScene) -> bool:
	if scene == null:
		return false
	match kind:
		"roof":
			roof_scene = scene
		"ground":
			if ground_buildings.has(scene):
				return false
			var list: Array[PackedScene] = []
			list.assign(ground_buildings)
			list.append(scene)
			ground_buildings = list
		"middle":
			if middle_buildings.has(scene):
				return false
			var list: Array[PackedScene] = []
			list.assign(middle_buildings)
			list.append(scene)
			middle_buildings = list
		_:
			return false
	assets_changed.emit()
	return true

func remove_asset(kind: String, index: int) -> void:
	match kind:
		"roof":
			roof_scene = null
		"ground":
			if index >= 0 and index < ground_buildings.size():
				var list: Array[PackedScene] = []
				list.assign(ground_buildings)
				list.remove_at(index)
				ground_buildings = list
		"middle":
			if index >= 0 and index < middle_buildings.size():
				var list: Array[PackedScene] = []
				list.assign(middle_buildings)
				list.remove_at(index)
				middle_buildings = list
	assets_changed.emit()
