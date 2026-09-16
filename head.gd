extends Node3D

@onready var cam = $Camera3D
@onready var ch3d = $".."
var v = Vector3()
var sens = 0.12

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	v.x = clamp(v.x,-80,90)

func _process(delta):
	cam.rotation_degrees.x = v.x
	ch3d.rotation_degrees.y = v.y

func _input(event):
	if event is InputEventMouseMotion:
		v.y -= (event.relative.x*sens)
		v.x -= (event.relative.y*sens)
