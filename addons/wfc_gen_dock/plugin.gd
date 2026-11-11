@tool
extends EditorPlugin
## Adds the "City Generator" panel at the bottom of the editor.

var panel: KolapsaDockPanel

func _enter_tree() -> void:
	panel = KolapsaDockPanel.new()
	add_control_to_bottom_panel(panel, "City Generator")
	scene_changed.connect(panel.on_scene_changed)

func _exit_tree() -> void:
	if panel != null:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null
