@tool
class_name KolapsaDockPanel
extends VBoxContainer
## The City Generator panel. UI ONLY: every real action is a call to the
## CityGenerator node. Layout:
##   top bar : Generate / Regenerate / Delete | status | Check scene / Export
##   left    : settings (layout, buildings, seed, advanced)
##   right   : tabs  Ground | Middle | Roof | Streets | Report

const EXPORT_DIR := "res://exports"

var generator: CityGenerator
var _add_kind: String = ""

var _inputs: Dictionary = {}  # setting name -> SpinBox / HSlider
var _flows: Dictionary = {}   # asset kind -> HFlowContainer

var _btn_generate: Button
var _btn_regen: Button
var _btn_delete: Button
var _btn_check: Button
var _btn_export: Button
var _status: Label
var _no_generator: HBoxContainer
var _split: HSplitContainer
var _tabs: TabContainer
var _report: RichTextLabel
var _param_errors: Label
var _density_label: Label
var _chance_label: Label
var _checks: Dictionary = {}  # setting name -> CheckBox
var _offset_spins: Array[SpinBox] = []
var _adv_toggle: Button
var _adv_box: VBoxContainer
var _add_dialog: EditorFileDialog
var _export_dialog: EditorFileDialog

# ---------------------------------------------------------------- build UI

func _ready() -> void:
	custom_minimum_size = Vector2(0, 330)
	add_theme_constant_override("separation", 6)
	_build_top_bar()
	_build_no_generator()
	_split = HSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	_split.add_child(_build_settings())
	_split.add_child(_build_tabs())
	_build_dialogs()
	refresh()

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	_btn_generate = _button("Generate", "Play", _on_generate)
	_btn_regen = _button("Regenerate", "Reload", _on_regenerate)
	_btn_delete = _button("Delete", "Remove", _on_delete)
	bar.add_child(_btn_generate)
	bar.add_child(_btn_regen)
	bar.add_child(_btn_delete)
	bar.add_child(VSeparator.new())
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_status)
	_btn_check = _button("Check scene", "StatusSuccess", _on_check)
	_btn_export = _button("Export...", "Save", _on_export)
	bar.add_child(_btn_check)
	bar.add_child(_btn_export)

func _build_no_generator() -> void:
	_no_generator = HBoxContainer.new()
	var label := Label.new()
	label.text = "This scene has no City Generator."
	_no_generator.add_child(label)
	_no_generator.add_child(_button("Add City Generator", "Add", _on_add_generator))
	add_child(_no_generator)

func _build_settings() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)

	_title(box, "Layout")
	_spin(box, "gridsize", "Grid size", 4, 32, 1, "Cells along each side of the city.")
	_spin(box, "blocks", "Block size", 1, 8, 1, "Smallest block of buildings between two streets, in cells.")
	_spin(box, "horizontal_streets", "Horizontal streets", 0, 6, 1, "Streets running left to right.")
	_spin(box, "vertical_streets", "Vertical streets", 0, 6, 1, "Streets running front to back.")

	_title(box, "Buildings")
	_check(box, "build_buildings", "Build buildings", "Untick to generate streets, sidewalks and floor only.")
	_spin(box, "levels", "Max floors", 2, 6, 1, "Tallest a building can be, roof included.")
	var density := HSlider.new()
	density.min_value = 0.0
	density.max_value = 1.0
	density.step = 0.05
	density.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	density.value_changed.connect(_on_setting_changed.bind("density"))
	_inputs["density"] = density
	_density_label = Label.new()
	_density_label.custom_minimum_size = Vector2(44, 0)
	var density_row := HBoxContainer.new()
	density_row.add_child(density)
	density_row.add_child(_density_label)
	_row(box, "Building density", density_row, "Higher means more buildings and fewer empty lots.", density)
	_spin(box, "tile_size", "Tile size", 0.25, 4.0, 0.25, "Scales the whole city. 1 = original size.")

	_title(box, "Seed")
	_check(box, "randomize_seed", "New random seed every time", "Untick to reuse the seed value below and get the same city again.")
	var seed_spin := _make_spin("seed_value", 0, 2147483647, 1)
	var copy := _button("Copy", "ActionCopy", _on_copy_seed)
	var seed_row := HBoxContainer.new()
	seed_row.add_child(seed_spin)
	seed_row.add_child(copy)
	_row(box, "Seed value", seed_row, "Untick the box above and reuse this number to get the same city again.", seed_spin)

	_adv_toggle = Button.new()
	_adv_toggle.text = "Advanced"
	_adv_toggle.flat = true
	_adv_toggle.toggle_mode = true
	_adv_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_adv_toggle.icon = _icon("GuiTreeArrowRight")
	_adv_toggle.toggled.connect(_on_advanced_toggled)
	box.add_child(_adv_toggle)
	_adv_box = VBoxContainer.new()
	_adv_box.visible = false
	box.add_child(_adv_box)
	_title(_adv_box, "Streets")
	var chance := HSlider.new()
	chance.min_value = 0.0
	chance.max_value = 1.0
	chance.step = 0.05
	chance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chance.value_changed.connect(_on_setting_changed.bind("partial_chance"))
	_inputs["partial_chance"] = chance
	_chance_label = Label.new()
	_chance_label.custom_minimum_size = Vector2(44, 0)
	var chance_row := HBoxContainer.new()
	chance_row.add_child(chance)
	chance_row.add_child(_chance_label)
	_row(_adv_box, "Short side streets", chance_row, "Chance that a vertical street stops at a horizontal one.", chance)
	_spin(_adv_box, "delay", "Street build delay", 0.0, 0.2, 0.01, "Seconds between each street tile while it is placed. 0 = instant.")

	_title(_adv_box, "Building tuning")
	_spin(_adv_box, "roof", "Roof weight", 0, 10, 0.5, "Higher means buildings end sooner.")
	_spin(_adv_box, "empty_space", "Air weight", 0, 10, 0.1, "How likely a spot is left empty. Higher means more gaps. The density slider scales this.")
	var offset_row := HBoxContainer.new()
	for axis in 3:
		var s := SpinBox.new()
		s.min_value = -10.0
		s.max_value = 10.0
		s.step = 0.1
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.prefix = "xyz"[axis] + " "
		s.value_changed.connect(_on_offset_changed.bind(axis))
		offset_row.add_child(s)
		_offset_spins.append(s)
	_row(_adv_box, "Origin offset", offset_row, "Shifts every building. Raise Y to lift buildings onto the floor tile.", offset_row)

	_title(_adv_box, "Preview and debug")
	_check(_adv_box, "animate", "Watch the city grow", "Show the buildings appearing step by step.")
	_spin(_adv_box, "steps_per_frame", "Growth speed", 1, 20, 1, "Steps drawn per frame while watching.")
	_check(_adv_box, "show_entropy", "Show option counts", "Shows a number on cells that are not decided yet.")
	_check(_adv_box, "console_output", "Print to Output", "Turn off to silence all printing.")
	_check(_adv_box, "log_steps", "Print every step", "Writes each WFC step to the Output panel.")
	_spin(_adv_box, "detail_steps", "Steps printed in full", 0, 20, 1, "After this many steps, only one line per step is printed.")

	_param_errors = Label.new()
	_param_errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_param_errors.modulate = Color(1.0, 0.55, 0.45)
	box.add_child(_param_errors)
	return scroll

func _build_tabs() -> Control:
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size = Vector2(420, 0)
	_make_asset_tab("ground", "Ground", "Shop fronts and doors. Stands on the ground; its front must face open space.")
	_make_asset_tab("middle", "Middle", "Upper floors. Stacks on a ground or middle floor.")
	_make_asset_tab("roof", "Roof", "Closes the top of a building. One roof is used for every building.")
	_build_streets_tab()
	_build_report_tab()
	return _tabs

func _make_asset_tab(kind: String, title: String, hint: String) -> void:
	var page := VBoxContainer.new()
	page.name = title
	_tabs.add_child(page)
	var head := HBoxContainer.new()
	var label := Label.new()
	label.text = hint
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color(1, 1, 1, 0.7)
	head.add_child(label)
	var add_text := "Set Roof" if kind == "roof" else "Add Asset"
	var add := _button(add_text, "Add", _on_add_asset.bind(kind))
	add.tooltip_text = "Pick scenes (.tscn or .glb) from your project. You can also drag them from the FileSystem dock onto this tab."
	head.add_child(add)
	page.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_drag_forwarding(Callable(), _can_drop.bind(kind), _drop.bind(kind))
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(flow)
	page.add_child(scroll)
	_flows[kind] = flow

func _build_streets_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Streets"
	_tabs.add_child(page)
	var hint := Label.new()
	hint.text = "Placed by the street planner, not editable here. Roads join end to end and sidewalks line every block."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.7)
	page.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var groups := {"Roads": [], "Crossroads": [], "Sidewalk and floor": []}
	for tile_name in TileCatalog.FLOORS:
		groups[_street_group(tile_name)].append(tile_name)
	for title in groups:
		var heading := Label.new()
		heading.text = title
		heading.theme_type_variation = &"HeaderSmall"
		col.add_child(heading)
		var flow := HFlowContainer.new()
		col.add_child(flow)
		for tile_name in groups[title]:
			flow.add_child(_make_item(TileCatalog.FLOORS[tile_name], tile_name, "", -1))

func _build_report_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Report"
	_tabs.add_child(page)
	_report = RichTextLabel.new()
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.scroll_following = true
	_report.selection_enabled = true
	page.add_child(_report)
	var clear := _button("Clear", "Clear", func() -> void: _report.clear())
	clear.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(clear)

func _build_dialogs() -> void:
	_add_dialog = EditorFileDialog.new()
	_add_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	_add_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_add_dialog.add_filter("*.tscn, *.scn, *.glb, *.gltf", "Scenes and models")
	_add_dialog.files_selected.connect(_on_assets_picked)
	add_child(_add_dialog)
	_export_dialog = EditorFileDialog.new()
	_export_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_export_dialog.add_filter("*.tscn", "Godot scene")
	_export_dialog.file_selected.connect(_on_export_path)
	add_child(_export_dialog)

# ------------------------------------------------------------ small helpers

func _icon(icon_name: String) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon(icon_name, "EditorIcons"):
		return theme.get_icon(icon_name, "EditorIcons")
	return null

func _button(text: String, icon_name: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = _icon(icon_name)
	b.pressed.connect(callback)
	return b

func _title(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HeaderSmall"
	parent.add_child(l)

func _make_spin(prop: String, min_v: float, max_v: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(_on_setting_changed.bind(prop))
	_inputs[prop] = s
	return s

func _spin(parent: Control, prop: String, text: String, min_v: float, max_v: float, step: float, tip: String) -> void:
	var s := _make_spin(prop, min_v, max_v, step)
	_row(parent, text, s, tip, s)

func _check(parent: Control, prop: String, text: String, tip: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.tooltip_text = tip
	c.toggled.connect(_on_bool_changed.bind(prop))
	_checks[prop] = c
	parent.add_child(c)

func _row(parent: Control, text: String, content: Control, tip: String, tip_target: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(130, 0)
	l.tooltip_text = tip
	tip_target.tooltip_text = tip
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(content)
	parent.add_child(h)

static func _street_group(tile_name: String) -> String:
	if tile_name.begins_with("crossroad"):
		return "Crossroads"
	if tile_name.begins_with("road"):
		return "Roads"
	return "Sidewalk and floor"

func _mark_dirty() -> void:
	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()

# ------------------------------------------------------- generator wiring

func on_scene_changed(_root: Node) -> void:
	refresh()

func refresh() -> void:
	var root := EditorInterface.get_edited_scene_root()
	_set_generator(_find_generator(root) if root != null else null)

func _find_generator(node: Node) -> CityGenerator:
	if node is CityGenerator:
		return node
	for child in node.get_children():
		var found := _find_generator(child)
		if found != null:
			return found
	return null

func _set_generator(g: CityGenerator) -> void:
	if g != generator:
		_disconnect_generator()
		generator = g
		if generator != null:
			generator.message.connect(_on_message)
			generator.state_changed.connect(_on_state_changed)
			generator.generated.connect(_on_generated)
			generator.assets_changed.connect(_fill_all_assets)
	_sync_inputs()
	_fill_all_assets()
	_update_ui()

func _disconnect_generator() -> void:
	if not is_instance_valid(generator):
		return
	if generator.message.is_connected(_on_message):
		generator.message.disconnect(_on_message)
	if generator.state_changed.is_connected(_on_state_changed):
		generator.state_changed.disconnect(_on_state_changed)
	if generator.generated.is_connected(_on_generated):
		generator.generated.disconnect(_on_generated)
	if generator.assets_changed.is_connected(_fill_all_assets):
		generator.assets_changed.disconnect(_fill_all_assets)

func _has_generator() -> bool:
	return generator != null and is_instance_valid(generator)

# Put the generator's values into the controls (without firing their signals).
func _sync_inputs() -> void:
	if not _has_generator():
		return
	for prop in _inputs:
		(_inputs[prop] as Range).set_value_no_signal(generator.get(prop))
	for prop in _checks:
		(_checks[prop] as CheckBox).set_pressed_no_signal(generator.get(prop))
	var offset := generator.origin_offset
	_offset_spins[0].set_value_no_signal(offset.x)
	_offset_spins[1].set_value_no_signal(offset.y)
	_offset_spins[2].set_value_no_signal(offset.z)
	_update_value_labels()

func _update_value_labels() -> void:
	if not _has_generator():
		return
	_density_label.text = "%d%%" % roundi(generator.density * 100.0)
	_chance_label.text = "%d%%" % roundi(generator.partial_chance * 100.0)

# ------------------------------------------------------------ asset grids

func _fill_all_assets() -> void:
	for kind in _flows:
		_fill_assets(kind)

func _fill_assets(kind: String) -> void:
	var flow: HFlowContainer = _flows[kind]
	for c in flow.get_children():
		flow.remove_child(c)
		c.queue_free()
	var items: Array = generator.assets(kind) if _has_generator() else []
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nothing here yet. Click the button above, or drag scenes onto this tab."
		empty.modulate = Color(1, 1, 1, 0.6)
		flow.add_child(empty)
		return
	for i in items.size():
		var scene := items[i] as PackedScene
		if scene == null:
			continue
		var title := scene.resource_path.get_file().get_basename()
		flow.add_child(_make_item(scene, title, kind, i))

func _make_item(scene: PackedScene, title: String, kind: String, index: int) -> Control:
	var card := PanelContainer.new()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(104, 0)
	card.add_child(box)
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(96, 96)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(rect)
	var label := Label.new()
	label.text = title
	label.tooltip_text = scene.resource_path
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	if index >= 0:
		var remove := _button("Remove", "Close", _on_remove_asset.bind(kind, index))
		remove.flat = true
		remove.tooltip_text = "Remove from the library (the file itself is not deleted)."
		box.add_child(remove)
	AssetThumb.apply.call_deferred(rect, scene)
	return card

func _can_drop(_at: Vector2, data: Variant, _kind: String) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "files"

func _drop(_at: Vector2, data: Variant, kind: String) -> void:
	_add_paths(kind, PackedStringArray(data["files"]))

func _on_add_asset(kind: String) -> void:
	if not _has_generator():
		return
	_add_kind = kind
	_add_dialog.popup_centered_ratio(0.6)

func _on_assets_picked(paths: PackedStringArray) -> void:
	_add_paths(_add_kind, paths)

func _add_paths(kind: String, paths: PackedStringArray) -> void:
	if not _has_generator():
		return
	var added := 0
	for p in paths:
		var res := load(p)
		if res is PackedScene and generator.add_asset(kind, res):
			added += 1
		else:
			_log("Skipped %s (not a scene, or already in the library)." % p.get_file(), 1)
		if kind == "roof":
			break
	if added > 0:
		_mark_dirty()

func _on_remove_asset(kind: String, index: int) -> void:
	if _has_generator():
		generator.remove_asset(kind, index)
		_mark_dirty()

# ------------------------------------------------------------ user actions

func _on_setting_changed(value: float, prop: String) -> void:
	if not _has_generator():
		return
	var old: Variant = generator.get(prop)
	generator.set(prop, roundi(value) if typeof(old) == TYPE_INT else value)
	var errors := generator.number_errors()
	if errors.is_empty():
		_param_errors.text = ""
		_mark_dirty()
	else:
		# Keep the previous valid value and say why.
		generator.set(prop, old)
		(_inputs[prop] as Range).set_value_no_signal(old)
		_param_errors.text = "Not changed:\n" + "\n".join(errors)
	_update_value_labels()
	_update_ui()

func _on_bool_changed(pressed: bool, prop: String) -> void:
	if _has_generator():
		generator.set(prop, pressed)
		_mark_dirty()
		_update_ui()

func _on_offset_changed(_value: float, _axis: int) -> void:
	if _has_generator():
		generator.origin_offset = Vector3(_offset_spins[0].value, _offset_spins[1].value, _offset_spins[2].value)
		_mark_dirty()

func _on_advanced_toggled(pressed: bool) -> void:
	_adv_box.visible = pressed
	_adv_toggle.icon = _icon("GuiTreeArrowDown" if pressed else "GuiTreeArrowRight")

func _on_copy_seed() -> void:
	if _has_generator():
		DisplayServer.clipboard_set(str(generator.seed_value))
		_log("Seed %d copied." % generator.seed_value, 0)

func _on_generate() -> void:
	if _has_generator():
		_param_errors.text = ""
		generator.start_generation()

func _on_regenerate() -> void:
	if _has_generator():
		_param_errors.text = ""
		generator.start_regeneration()

func _on_delete() -> void:
	if _has_generator():
		generator.clear_city()
		_mark_dirty()

func _on_check() -> void:
	if _has_generator():
		generator.validate_current()

func _on_export() -> void:
	if not _has_generator():
		return
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	_export_dialog.current_dir = EXPORT_DIR
	_export_dialog.current_file = "city.tscn"
	_export_dialog.popup_centered_ratio(0.6)

func _on_export_path(path: String) -> void:
	if _has_generator() and generator.export_to(path) == OK:
		EditorInterface.get_resource_filesystem().scan()

func _on_add_generator() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_log("Open or create a 3D scene first.", 1)
		return
	var g := CityGenerator.new()
	g.name = "CityGenerator"
	root.add_child(g)
	g.owner = root
	_mark_dirty()
	refresh()

# --------------------------------------------------- feedback from generator

func _on_state_changed(_state: String) -> void:
	_update_ui()

func _on_generated(valid: bool, problems: PackedStringArray) -> void:
	_sync_inputs() # the seed value changes after a run
	if not valid:
		for p in problems:
			_log(p, 2)
	_update_ui()

func _on_message(text: String, level: int) -> void:
	_log(text, level)

func _log(text: String, level: int) -> void:
	var prefix := ""
	if level == 1:
		prefix = "Warning: "
	elif level == 2:
		prefix = "Error: "
	_report.add_text(prefix + text.replace("\n", " ") + "\n")
	if level == 2:
		_tabs.current_tab = _tabs.get_tab_count() - 1 # show the Report tab

func _update_ui() -> void:
	var has := _has_generator()
	_no_generator.visible = not has
	_split.visible = has
	for b in [_btn_generate, _btn_regen, _btn_delete, _btn_check, _btn_export]:
		b.disabled = true
	if not has:
		_status.text = "Open a 3D scene to begin."
		return

	var busy := generator.running
	var blockers := generator.number_errors()
	blockers.append_array(generator.tileset_errors())
	var can_generate := not busy and blockers.is_empty()
	var why := "Wait until the city is finished." if busy else "\n".join(blockers)

	_btn_generate.disabled = not can_generate
	_btn_regen.disabled = not can_generate
	_btn_generate.tooltip_text = "Build a city with the current settings." if can_generate else why
	_btn_regen.tooltip_text = "Build again with a new random seed." if can_generate else why
	_btn_delete.disabled = busy
	_btn_delete.tooltip_text = "Remove the generated city from the scene."

	var has_city := not generator.last_result.is_empty()
	_btn_check.disabled = busy or not has_city
	_btn_check.tooltip_text = "Check every placed piece against the rules." if has_city else "Generate a city first."
	_btn_export.disabled = busy or not generator.is_valid
	if generator.is_valid and not busy:
		_btn_export.tooltip_text = "Save the city as a standalone Godot scene."
	elif has_city and not busy:
		_btn_export.tooltip_text = "Fix the problems in the Report tab or regenerate first."
	else:
		_btn_export.tooltip_text = "Generate a city first."

	if busy:
		_status.text = "Generating..."
	elif not has_city and not blockers.is_empty():
		_status.text = blockers[0]
	elif not has_city:
		_status.text = "No city yet. Press Generate."
	elif generator.is_valid:
		_status.text = "City ready. Scene check passed."
	else:
		_status.text = "%d problem(s) found. See the Report tab." % generator.problems.size()
