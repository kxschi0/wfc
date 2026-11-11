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
	for child in container.get_children():
		if not child.is_in_group(SceneSpawner.GROUP) or child.is_queued_for_deletion():
			continue
		if child.scene_file_path == "":
			continue # temporary things like the entropy labels
		var packed := load(child.scene_file_path) as PackedScene
		if packed == null:
			continue
		var copy := packed.instantiate() as Node3D
		root.add_child(copy)
		copy.owner = root
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
