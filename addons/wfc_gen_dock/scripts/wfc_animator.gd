@tool
class_name WfcAnimator
extends RefCounted
## ONE job: pacing. Collects changed cells and redraws them every few steps,
## waiting one frame so you can watch the city grow.
## In the running game (step_mode) it waits after every frame for the Right arrow instead,
## and remembers every frame so the Left arrow can go back. One frame = steps_per_frame steps.

var view: WfcView
var tree: SceneTree
var enabled: bool
var steps_per_frame: int
var pending: Dictionary = {}
var paused: bool = false # set by the Run Project window (Space key)
var step_mode: bool = false # running game only: frame by frame with the arrow keys
var live: Dictionary # the solver's wave (the same dictionary the view reads)
var frames: Array = [] # a copy of the wave at every frame
var shown: int = 0 # which frame is on screen
var waiting: bool = false # the solver is stopped, waiting for the next frame to be asked for

func _init(p_view: WfcView, p_tree: SceneTree, p_enabled: bool, p_steps_per_frame: int) -> void:
	view = p_view
	tree = p_tree
	enabled = p_enabled
	steps_per_frame = p_steps_per_frame
	live = p_view.wave
	step_mode = p_enabled and not Engine.is_editor_hint()

func reset() -> void:
	pending.clear()
	frames.clear()
	shown = 0
	waiting = false

func show(changed: Dictionary, step: int) -> void:
	if not enabled:
		return
	for c in changed:
		pending[c] = true
	if step % maxi(steps_per_frame, 1) == 0:
		for c in pending:
			view.update_cell(c)
		pending.clear()
		if step_mode:
			await _wait_for_next()
			return
		await tree.process_frame
		while paused:
			await tree.process_frame

# --- Frame by frame (running game) -----------------------------------------------

# Keeps this frame, then stops the solver until next() lets it go on.
# The solver never changes an options list in place, so a shallow copy is a safe snapshot.
func _wait_for_next() -> void:
	frames.append(live.duplicate())
	shown = frames.size() - 1
	waiting = true
	while waiting:
		await tree.process_frame

# Right arrow: show the next frame. On the newest frame, let the solver build the next one.
func next() -> void:
	if not step_mode or frames.is_empty():
		return
	if shown < frames.size() - 1:
		_show_frame(shown + 1)
	else:
		waiting = false

# Left arrow: show the previous frame.
func previous() -> void:
	if step_mode and not frames.is_empty():
		_show_frame(shown - 1)

# Called when the whole city is built, so the finished city is the last frame.
func finish(ok: bool) -> void:
	if not step_mode:
		return
	if not ok:
		frames.clear()
		return
	if frames.is_empty() or live != frames.back():
		frames.append(live.duplicate())
	shown = frames.size() - 1

# Redraws only the cells that differ from the frame that is on screen now.
func _show_frame(index: int) -> void:
	index = clampi(index, 0, frames.size() - 1)
	var on_screen: Dictionary = frames[shown]
	var target: Dictionary = frames[index]
	view.wave = live if index == frames.size() - 1 else target # the solver must always draw from the live wave
	for cell in target:
		if target[cell] != on_screen[cell]:
			view.update_cell(cell)
	shown = index
