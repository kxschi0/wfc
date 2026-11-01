@tool
extends Node3D
## ORCHESTRATOR ONLY. It reads the Inspector, creates the helpers and calls
## them in order. All real work lives in the other files.

const MAX_ATTEMPTS := 10

@export var gridsize: int = 16
@export var horizontal_streets: int = 1
@export var vertical_streets: int = 2
@export var blocks: int = 3
@export_range(0.0, 1.0) var partial_chance: float = 0.5
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

# Every random call in all the scripts uses Godot's global generator,
# so seeding it here once makes the whole city repeatable.
func _apply_seed() -> void:
	if randomize_seed:
		randomize()
		seed_value = randi()
	seed(seed_value)
	if console_output:
		print("seed : ", seed_value)

func _delete_all() -> void:
	SceneSpawner.new(self).clear()

func _run() -> void:
	if running:
		return
	running = true
	_delete_all()
	_apply_seed()

	var catalog := TileCatalog.new()
	catalog.check()
	var streets := StreetPlanner.new(gridsize, blocks, partial_chance)
	var ground := GroundPlanner.new(gridsize, catalog)

	var roads := streets.make_streets(horizontal_streets, vertical_streets)
	var plan := ground.plan(roads)
	if console_output:
		LayoutReport.new().print_report(streets, ground, roads, plan)

	await get_tree().process_frame
	var placer := GroundPlacer.new(SceneSpawner.new(self), catalog)
	for cell in plan:
		if not roads.has(cell):
			placer.place(plan[cell], cell)
	for cell in roads:
		placer.place(plan[cell], cell)
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout

	if build_buildings:
		await _build_buildings(ground.floor_cells)
	running = false

func _build_buildings(floor_cells: Dictionary) -> void:
	if floor_cells.is_empty():
		print("No grey floor cells to build on. Raise gridsize or blocks.")
		return
	if roof_scene == null:
		push_warning("roof_scene is empty: buildings need a roof, so none will appear.")

	var building_tiles := BuildingTiles.new()
	building_tiles.build(ground_buildings, middle_buildings, roof_scene, roof, empty_space)

	var logger: WfcLogger = WfcLogger.new() # silent
	if console_output:
		logger = WfcConsoleLogger.new(log_steps, detail_steps)

	var spawner := SceneSpawner.new(self)
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

	if ok:
		view.update_all()
		logger.summary(attempt)
	else:
		push_warning("Gave up after %d attempts. The rules may be too strict." % MAX_ATTEMPTS)
