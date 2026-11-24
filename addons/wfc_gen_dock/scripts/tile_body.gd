@tool
class_name TileBody
extends RefCounted
## ONE job: wrap one tile in a StaticBody3D or RigidBody3D, with a box collision that fits its mesh.
## Hierarchy of one tile:
##   <tile name>          (StaticBody3D or RigidBody3D)
##   ├─ <model>           (the building / floor / road scene)
##   └─ Collision         (CollisionShape3D, box sized to the model)

const NONE := -1 # no body: the model is used as it is
const STATIC := 0
const RIGID := 1
const COLLISION_NAME := "Collision"

# model_xf (optional): the transform the model gets inside the body (see BlockFit).
# null = the model keeps the transform its scene has. The collision box follows the model.
static func make(scene: PackedScene, kind: int, with_collision: bool, model_xf: Variant = null) -> Node3D:
	var model := scene.instantiate() as Node3D
	if kind == NONE:
		return model
	if model_xf != null:
		model.transform = model_xf
	var body := new_body(kind)
	body.add_child(model)
	if with_collision:
		add_box(body, _fit(model, model.transform, AABB()))
	return body

# An empty StaticBody3D or RigidBody3D.
static func new_body(kind: int) -> PhysicsBody3D:
	if kind == RIGID:
		var rigid := RigidBody3D.new()
		rigid.sleeping = true # stays where it is until something touches it
		return rigid
	return StaticBody3D.new()

# Adds a box collision that covers `box`.
static func add_box(body: PhysicsBody3D, box: AABB) -> void:
	if not box.has_surface():
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(box.size.x, 0.01), maxf(box.size.y, 0.01), maxf(box.size.z, 0.01))
	var collision := CollisionShape3D.new()
	collision.name = COLLISION_NAME
	collision.shape = shape
	collision.position = box.get_center()
	body.add_child(collision)

# Makes the tile (and the parts we added to it) belong to the scene, so they get saved.
# The inside of the model keeps its own owner.
static func set_owner_all(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	if node.scene_file_path == "" and node is PhysicsBody3D:
		for child in node.get_children():
			child.owner = new_owner

# The box around every mesh of a model, in the space of the model's parent.
static func measure(model: Node3D) -> AABB:
	return _fit(model, model.transform, AABB())

# The box that holds every mesh of the model, in the body's space.
static func _fit(node: Node3D, to_body: Transform3D, box: AABB) -> AABB:
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		var part: AABB = to_body * mesh_node.mesh.get_aabb()
		box = box.merge(part) if box.has_surface() else part
	for child in node.get_children():
		var child_3d := child as Node3D
		if child_3d != null:
			box = _fit(child_3d, to_body * child_3d.transform, box)
	return box
