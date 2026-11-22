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
## How many cells wide each street is (1 to 3).
@export_range(1, 3) var road_width: int = 3
## On: plain asphalt, only crossings are marked. Off: stripe tile on every road cell (use with width 1).
@export var plain_roads: bool = true
## On: the outer ring of the grid is all sidewalk (a street that reaches the edge is replaced by sidewalk there).
## Off: streets run to the edge of the grid.
@export var sidewalk_border: bool = true
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
## Style of each Ground / Middle asset, in the same order (0 = Any, 1 to 4 = A to D). Set in the panel.
@export_storage var ground_styles: Array[int] = []
@export_storage var middle_styles: Array[int] = []
@export var roof_scene: PackedScene
@export var levels: int = 4
## Shift every building (set Y to lift buildings on top of the floor tile).
@export var origin_offset: Vector3 = Vector3(0, 1, 0)

@export_group("Building weights")
@export var roof: float = 3.0
## Weight of "empty air". The density slider scales this.
@export var empty_space: float = 1.5

@export_group("Physics")
## What each floor, sidewalk and road tile becomes. Every tile is its own body.
@export_enum("Static body", "Rigid body") var ground_body: int = 0
## What each building piece (shop fronts, floors, roofs) becomes.
@export_enum("Static body", "Rigid body") var building_body: int = 0
## Adds a box collision to every tile, sized to fit its mesh.
@export var add_collision: bool = true
## Joins neighbouring floor, sidewalk and road tiles into one mesh and one collision.
## Off: every tile stays its own node. (Buildings are not affected.)
@export var merge_ground: bool = false

@export_group("Building debug")
@export var animate: bool = true
@export var steps_per_frame: int = 3
@export var show_entropy: bool = true
## Turn off to silence ALL printing.
@export var console_output: bool = true
@export var log_steps: bool = false
## How many steps are printed in full. After that: one line per step.
@export var detail_steps: int = 3

@export_group("Run Project")
## Press Run and watch a new city being built live in the game window.
@export var generate_on_run: bool = true
## Developer: orbit camera, status panel and the step-by-step animation (the keys listed there).
## Game: no camera or panel of ours and no animation. The city appears at once and your own player can move.
@export_enum("Developer", "Game") var run_mode: int = 0
## On: Run Project builds the city of the seed set below, so it matches the editor.
## Off: it follows "Randomize Seed". Pressing R in the game always makes a new random city.
@export var run_with_editor_seed: bool = true

@export_group("Seed")
## Untick to reuse the seed below and get the SAME city again.
## (Typing a seed in the Inspector unticks this for you.)
@export var randomize_seed: bool = true
## The seed that made the current city. Copy it to keep a layout you like.
@export var seed_value: int = 0:
	set(value):
		seed_value = value
		# You typed a seed in the Inspector: you want THAT city, so stop randomizing.
		# Not while the scene loads (not in the tree yet) or while the generator picks a seed itself.
		if Engine.is_editor_hint() and is_inside_tree() and not _picking_seed and randomize_seed:
			randomize_seed = false
			notify_property_list_changed()

var running: bool = false
var _picking_seed: bool = false
var is_valid: bool = false
var problems: PackedStringArray = PackedStringArray()
var last_result: Dictionary = {} # what the last successful run produced
var _force_new_seed: bool = false

# What the game window (RunSession) watches while a city is being built.
var live_solver: WfcSolver
var live_view: WfcView
var live_animator: WfcAnimator
var live_attempt: int = 0

# ------------------------------------------------------------- run project

func _ready() -> void:
	if Engine.is_editor_hint():
		return # in the editor, the Generate button / panel is used
	if run_mode == 1:
		# Game: only for this run (the settings in the editor are not changed).
		animate = false
		show_entropy = false
		delay = 0.0
	else:
		add_child(RunSession.new(self))
	if run_with_editor_seed:
		randomize_seed = false # only for this run; the setting in the editor is not changed
	if generate_on_run:
		_run()

# ------------------------------------------------------------------ seed

# Every random call in all the scripts uses Godot's global generator,
# so seeding it here makes the street/ground layout repeatable.
func _apply_seed() -> void:
	if randomize_seed or _force_new_seed:
		randomize()
		_picking_seed = true
		seed_value = randi()
		_picking_seed = false
		if Engine.is_editor_hint():
			notify_property_list_changed() # show the new seed in the Inspector
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
	# Everything under the container is a generated tile, so remove ALL of it, not only the
	# tagged ones. A saved scene forgets the tag, so a city saved in the editor used to
	# survive Run Project and the new city was built on top of it.
	for tile in _container().get_children():
		tile.queue_free()

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
	var errors := ParamValidator.validate(gridsize, levels, blocks, horizontal_streets, vertical_streets, build_buildings, roof_scene, ground_buildings, middle_buildings, tile_size, density, road_width)
	if not errors.is_empty():
		_say("Can't generate:\n" + "\n".join(errors), 2)
		return

	_clear_scene()
	_reset_result()
	_apply_seed()

	var catalog := TileCatalog.new()
	catalog.check()
	var streets := StreetPlanner.new(gridsize, blocks, partial_chance, road_width)
	var ground := GroundPlanner.new(gridsize, catalog)
	ground.plain_roads = plain_roads
	ground.sidewalk_border = sidewalk_border

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
	placer.body_kind = ground_body
	placer.with_collision = add_collision
	if merge_ground:
		await _place_ground_merged(placer, plan, roads)
	else:
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

# The "Merge ground" option: floor and sidewalks first, then the roads, one piece per rectangle.
func _place_ground_merged(placer: GroundPlacer, plan: Dictionary, roads: Dictionary) -> void:
	var other_cells: Dictionary = {}
	for cell in plan:
		if not roads.has(cell):
			other_cells[cell] = plan[cell]
	var road_cells: Dictionary = {}
	for cell in roads:
		road_cells[cell] = plan[cell]
	for piece in GroundMerger.rectangles(other_cells):
		placer.place_merged(piece["tile"], piece["rect"])
	for piece in GroundMerger.rectangles(road_cells):
		placer.place_merged(piece["tile"], piece["rect"])
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout

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
	building_tiles.build(ground_buildings, middle_buildings, roof_scene, roof, _empty_weight(), _street_weight(), ground_styles, middle_styles)

	var logger: WfcLogger = WfcLogger.new() # silent
	if console_output:
		logger = WfcConsoleLogger.new(log_steps, detail_steps)

	var solver := WfcSolver.new(building_tiles.tiles, building_tiles.compat, floor_cells, gridsize, levels, logger, null)
	var view := WfcView.new(spawner, building_tiles.tiles, solver.wave, show_entropy, origin_offset)
	view.body_kind = building_body
	view.with_collision = add_collision
	var animator := WfcAnimator.new(view, get_tree(), animate, steps_per_frame)
	solver.animator = animator
	live_solver = solver
	live_view = view
	live_animator = animator

	logger.setup(building_tiles, floor_cells.size(), levels)

	var ok := false
	var attempt := 0
	while not ok and attempt < MAX_ATTEMPTS:
		attempt += 1
		live_attempt = attempt
		# The solver has its own dice (solver.rng), seeded here, so nothing that happens
		# between frames can change the buildings: the same seed gives the same buildings.
		solver.rng.seed = seed_value + attempt
		view.clear()
		animator.reset()
		solver.init_wave()
		logger.wave_initialized(attempt)
		ok = await solver.solve()
		if not ok:
			logger.attempt_failed(attempt)

	if not ok:
		view.clear() # don't leave a half-built city behind
		_say("Gave up after %d failed attempts (seed %d). The building rules may be too strict for this layout. Try Regenerate, a bigger grid, or more assets." % [attempt, seed_value], 2)
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
	if running:
		return # don't leave the flag set for a later run
	_force_new_seed = true
	_run()

func clear_city() -> void:
	_delete_all()

func number_errors() -> PackedStringArray:
	return ParamValidator.validate_numbers(gridsize, levels, blocks, horizontal_streets, vertical_streets, build_buildings, tile_size, density, road_width)

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
				_remove_style("ground", index)
		"middle":
			if index >= 0 and index < middle_buildings.size():
				var list: Array[PackedScene] = []
				list.assign(middle_buildings)
				list.remove_at(index)
				middle_buildings = list
				_remove_style("middle", index)
	assets_changed.emit()

# The style of one Ground or Middle asset: 0 = Any, 1 to 4 = A to D.
func asset_style(kind: String, index: int) -> int:
	var list: Array[int] = ground_styles if kind == "ground" else middle_styles
	return list[index] if index >= 0 and index < list.size() else 0

func set_asset_style(kind: String, index: int, style: int) -> void:
	var list: Array[int] = []
	list.assign(ground_styles if kind == "ground" else middle_styles)
	while list.size() <= index:
		list.append(0)
	list[index] = style
	if kind == "ground":
		ground_styles = list
	else:
		middle_styles = list

func _remove_style(kind: String, index: int) -> void:
	var list: Array[int] = []
	list.assign(ground_styles if kind == "ground" else middle_styles)
	if index < list.size():
		list.remove_at(index)
	if kind == "ground":
		ground_styles = list
	else:
		middle_styles = list
