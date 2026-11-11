@tool
class_name EditorToast
extends RefCounted
## ONE job: show a short message to the user.
## In the editor it pops up as a toast (bottom-right). It is also printed to Output.

enum Level { INFO, WARNING, ERROR } # same order as Godot's EditorToaster severity

static func push(message: String, level: Level = Level.INFO) -> void:
	print("[City] ", message)
	if Engine.is_editor_hint():
		var toaster: Object = EditorInterface.get_editor_toaster()
		toaster.push_toast(message, level)
