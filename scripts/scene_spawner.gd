@tool
class_name SceneSpawner
extends RefCounted
## ONE job: put nodes into the edited scene and tag them, so they can be deleted later.

const GROUP := "wfctile"

var parent: Node3D

func _init(p_parent: Node3D) -> void:
	parent = p_parent

# A node that gets saved with the scene.
func spawn(scene: PackedScene) -> Node3D:
	var node: Node3D = scene.instantiate()
	parent.add_child(node)
	node.owner = parent.get_tree().edited_scene_root
	node.add_to_group(GROUP)
	return node

# A node that is only for display (not saved), like the entropy labels.
func add_temporary(node: Node) -> void:
	parent.add_child(node)
	node.add_to_group(GROUP)

func clear() -> void:
	for child in parent.get_children():
		if child.is_in_group(GROUP):
			child.queue_free()
