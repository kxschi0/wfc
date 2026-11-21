@tool
class_name SceneSpawner
extends RefCounted
## ONE job: put nodes into the edited scene and tag them, so they can be deleted later.
## Nodes are sorted into named folders (Floors, Roads, Roofs...) so the Scene tree stays readable.

const GROUP := "wfctile"

var parent: Node3D

func _init(p_parent: Node3D) -> void:
	parent = p_parent

# A node that gets saved with the scene.
# folder: the group node it goes into (made on first use). name_text: its label in the Scene tree.
# kind / with_collision: wrap it in a body (see TileBody). The returned node is the body.
func spawn(scene: PackedScene, folder: String = "", name_text: String = "", kind: int = TileBody.NONE, with_collision: bool = false) -> Node3D:
	var node := TileBody.make(scene, kind, with_collision)
	if name_text != "":
		node.name = name_text
	_folder(folder, true).add_child(node, true)
	TileBody.set_owner_all(node, parent.get_tree().edited_scene_root)
	node.add_to_group(GROUP)
	return node

# Same as spawn(), for a node that was already built (a merged ground piece).
func add_node(node: Node3D, folder: String = "", name_text: String = "") -> void:
	if name_text != "":
		node.name = name_text
	_folder(folder, true).add_child(node, true)
	TileBody.set_owner_all(node, parent.get_tree().edited_scene_root)
	node.add_to_group(GROUP)

# A node that is only for display (not saved), like the entropy labels.
func add_temporary(node: Node, folder: String = "", name_text: String = "") -> void:
	if name_text != "":
		node.name = name_text
	_folder(folder, false).add_child(node, true)
	node.add_to_group(GROUP)

func clear() -> void:
	for child in parent.get_children():
		if child.is_in_group(GROUP):
			child.queue_free()

# The group node called `folder` under the parent. Empty name = the parent itself.
func _folder(folder: String, saved: bool) -> Node3D:
	if folder == "":
		return parent
	var f := parent.get_node_or_null(folder) as Node3D
	if f == null:
		f = Node3D.new()
		f.name = folder
		parent.add_child(f)
		if saved:
			f.owner = parent.get_tree().edited_scene_root
	return f
