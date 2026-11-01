@tool
class_name WfcAnimator
extends RefCounted
## ONE job: pacing. Collects changed cells and redraws them every few steps,
## waiting one frame so you can watch the city grow.

var view: WfcView
var tree: SceneTree
var enabled: bool
var steps_per_frame: int
var pending: Dictionary = {}

func _init(p_view: WfcView, p_tree: SceneTree, p_enabled: bool, p_steps_per_frame: int) -> void:
	view = p_view
	tree = p_tree
	enabled = p_enabled
	steps_per_frame = p_steps_per_frame

func reset() -> void:
	pending.clear()

func show(changed: Dictionary, step: int) -> void:
	if not enabled:
		return
	for c in changed:
		pending[c] = true
	if step % maxi(steps_per_frame, 1) == 0:
		for c in pending:
			view.update_cell(c)
		pending.clear()
		await tree.process_frame
