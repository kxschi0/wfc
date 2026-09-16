extends CharacterBody3D


const SPEED = 30.0
const FLY_SPEED = 20.0

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var vertical := 0.0
	if Input.is_action_pressed("interact"):
		vertical += 1.0
	if Input.is_action_pressed("descend"):
		vertical -= 1.0

	var move_vec := direction * SPEED + Vector3.UP * vertical * FLY_SPEED
	global_position += move_vec * delta
