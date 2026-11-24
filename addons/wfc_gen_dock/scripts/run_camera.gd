@tool
class_name RunCamera
extends Camera3D
## ONE job: a simple camera for the game window (Run Project).
## Left-drag = orbit, right/middle-drag = move, mouse wheel = zoom.

const MIN_PITCH := -89.0
const MAX_PITCH := -5.0

var target: Vector3 = Vector3.ZERO
var distance: float = 20.0
var yaw: float = 35.0
var pitch: float = -40.0

# Looks at `center` from far enough away to see a city that is `size` wide.
func frame(center: Vector3, size: float) -> void:
	target = center
	distance = maxf(size * 1.3, 4.0)
	_apply()

func _ready() -> void:
	current = true
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if m.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= m.relative.x * 0.3
			pitch = clampf(pitch - m.relative.y * 0.3, MIN_PITCH, MAX_PITCH)
			_apply()
		elif m.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			var speed := distance * 0.0015
			target += (-basis.x * m.relative.x + basis.y * m.relative.y) * speed
			_apply()
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance * 0.9, 1.0)
			_apply()
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance * 1.1, 500.0)
			_apply()

func _apply() -> void:
	var look := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
	basis = look
	position = target + look * Vector3(0.0, 0.0, distance)
