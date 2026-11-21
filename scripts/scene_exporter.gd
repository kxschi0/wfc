@tool
class_name SceneExporter
extends RefCounted
## ONE job: save the generated city as a standalone Godot scene (UC-06).
## The saved scene is a plain Node3D with the tiles as children. It has no
## script, so it works without this plug-in.

static func export_scene(container: Node3D, path: String) -> Error:
	if not path.ends_with(".tscn"):
		path += ".tscn"

	var root := Node3D.new()
	root.name = "City"
	root.scale = container.scale # keeps the chosen tile size

	var count := 0
	for folder in container.get_children():
		if folder.is_queued_for_deletion():
			continue
		# A folder (Floors, Roads, Roofs...) holds the tiles. A tile directly under the
		# container (older scenes) is exported as it is.
		var is_folder: bool = folder.scene_file_path == ""
		var tile_list: Array = folder.get_children() if is_folder else [folder]
		var target: Node3D = root
		for child in tile_list:
			if not child.is_in_group(SceneSpawner.GROUP) or child.is_queued_for_deletion():
				continue
			var packed: PackedScene = null
			var kind := TileBody.NONE
			var with_collision := false
			if child.scene_file_path != "":
				packed = load(child.scene_file_path) as PackedScene
			elif child is PhysicsBody3D:
				# A tile wrapped in a body: find the model inside it.
				for inner in child.get_children():
					if inner.scene_file_path != "":
						packed = load(inner.scene_file_path) as PackedScene
				kind = TileBody.RIGID if child is RigidBody3D else TileBody.STATIC
				with_collision = child.get_node_or_null(TileBody.COLLISION_NAME) != null
			var merged_piece := packed == null and child is PhysicsBody3D and child.get_node_or_null(GroundMerger.MESH_NAME) != null
			if packed == null and not merged_piece:
				continue # temporary things like the entropy labels
			if is_folder and target == root:
				target = Node3D.new() # same folder name as in the editor
				target.name = folder.name
				root.add_child(target)
				target.owner = root
			var copy: Node3D
			if merged_piece:
				copy = child.duplicate() as Node3D # a merged ground piece: mesh and collision come along
				copy.remove_from_group(SceneSpawner.GROUP)
			else:
				copy = TileBody.make(packed, kind, with_collision)
			copy.name = child.name
			target.add_child(copy)
			TileBody.set_owner_all(copy, root)
			copy.transform = (child as Node3D).transform
			count += 1

	if count == 0:
		root.free()
		return ERR_UNCONFIGURED

	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		err = ResourceSaver.save(scene, path)
	root.free()
	return err
