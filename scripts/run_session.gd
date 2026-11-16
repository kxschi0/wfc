@tool
class_name RunSession
extends Node
## ONE job: make the game window useful when you press Run Project.
## It adds a camera (only if the scene has none), a small live status panel
## and a few keys. It never changes how the city is generated.
##   R = new city    Space = pause / resume    N = show / hide the numbers
##   Up / Down = faster / slower    Left-drag orbit, right-drag move, wheel zoom

const MAX_SPEED := 96

var generator: CityGenerator
var camera: RunCamera
var label: Label
var paused: bool = false
var last_message: String = ""
var undecided: int = 0
var total: int = 0

func _init(p_generator: CityGenerator) -> void:
	generator = p_generator

func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		camera = RunCamera.new()
		add_child(camera)
		var half := float(generator.gridsize - 1) * 0.5 * generator.tile_size
		camera.frame(generator.to_global(Vector3(half, 1.0, half)), float(generator.gridsize) * generator.tile_size)
	_build_hud()
	generator.message.connect(_on_message)
	generator.state_changed.connect(_on_state_changed)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	label = Label.new()
	panel.add_child(label)

func _on_message(text: String, _level: int) -> void:
	last_message = text

func _on_state_changed(state: String) -> void:
	if state == "Generating":
		paused = false
		last_message = ""

func _process(_delta: float) -> void:
	var solver := generator.live_solver
	if generator.running and solver != null:
		undecided = 0
		for cell in solver.wave:
			if (solver.wave[cell] as Array).size() > 1:
				undecided += 1
		total = solver.wave.size()
	var state := "Paused" if (paused and generator.running) else ("Generating" if generator.running else "Done")
	var lines := PackedStringArray()
	lines.append("%s  |  seed %d" % [state, generator.seed_value])
	if solver != null:
		lines.append("attempt %d  |  step %d  |  undecided cells %d of %d" % [generator.live_attempt, solver.step_count, undecided, total])
	lines.append("speed %d steps/frame  |  numbers %s" % [generator.steps_per_frame, "on" if generator.show_entropy else "off"])
	if last_message != "":
		lines.append(last_message)
	lines.append("R new city  |  Space pause  |  N numbers  |  Up/Down speed  |  drag to look")
	label.text = "\n".join(lines)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			if not generator.running:
				generator.start_regeneration()
		KEY_SPACE:
			paused = not paused
			_apply_pause()
		KEY_N:
			generator.show_entropy = not generator.show_entropy
			if generator.live_view != null:
				generator.live_view.show_entropy = generator.show_entropy
				generator.live_view.update_all()
		KEY_UP:
			_set_speed(generator.steps_per_frame * 2)
		KEY_DOWN:
			_set_speed(int(generator.steps_per_frame * 0.5))

func _set_speed(value: int) -> void:
	generator.steps_per_frame = clampi(value, 1, MAX_SPEED)
	if generator.live_animator != null:
		generator.live_animator.steps_per_frame = generator.steps_per_frame

func _apply_pause() -> void:
	if generator.live_animator != null:
		generator.live_animator.paused = paused
