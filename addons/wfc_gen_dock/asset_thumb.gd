@tool
class_name AssetThumb
extends RefCounted
## ONE job: put a preview picture of a scene into a TextureRect.
## 1) Ask the editor for the preview (the same one the FileSystem dock and the
##    Inspector show).
## 2) If the editor gives nothing (or an empty picture), draw the scene
##    ourselves in a tiny hidden viewport.
## Finished pictures are cached by file path.

static var _cache: Dictionary = {}

# `rect` must already be inside the scene tree.
static func apply(rect: TextureRect, scene: PackedScene) -> void:
	if rect == null or scene == null or scene.resource_path == "":
		return
	var path := scene.resource_path
	if _cache.has(path):
		rect.texture = _cache[path]
		return
	var job := ThumbJob.new()
	job.rect = rect
	job.scene = scene
	rect.add_child(job) # the job lives and dies with the rect
	job.start()


class ThumbJob extends Node:
	var rect: TextureRect
	var scene: PackedScene
	var _rendering: bool = false

	func start() -> void:
		var previewer := EditorInterface.get_resource_previewer()
		previewer.queue_resource_preview(scene.resource_path, self, "_on_editor_preview", null)
		# Safety net: if the editor never answers, draw it ourselves.
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(rect) and rect.texture == null:
			_render_ourselves()

	func _on_editor_preview(_path: String, preview: Texture2D, _small: Texture2D, _user: Variant) -> void:
		if not is_instance_valid(rect):
			return
		if preview != null:
			var img := preview.get_image()
			if img != null and not img.is_invisible():
				_show(preview)
				return
		_render_ourselves()

	func _show(tex: Texture2D) -> void:
		AssetThumb._cache[scene.resource_path] = tex
		if is_instance_valid(rect):
			rect.texture = tex

	func _render_ourselves() -> void:
		if _rendering or not is_inside_tree():
			return
		_rendering = true
		var vp := SubViewport.new()
		vp.size = Vector2i(128, 128)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)

		var inst := scene.instantiate()
		vp.add_child(inst)

		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.7, 0.7, 0.7)
		var world_env := WorldEnvironment.new()
		world_env.environment = env
		vp.add_child(world_env)

		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
		vp.add_child(light)

		var box := _bounds(inst)
		var center := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.1)
		var cam := Camera3D.new()
		vp.add_child(cam)
		cam.fov = 40.0
		var from := center + Vector3(1.0, 0.8, 1.0).normalized() * radius * 3.0
		cam.look_at_from_position(from, center, Vector3.UP)
		cam.current = true

		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img != null and not img.is_invisible():
			_show(ImageTexture.create_from_image(img))
		vp.queue_free()

	# Box around every mesh in the scene.
	func _bounds(root: Node) -> AABB:
		var box := AABB()
		var first := true
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				var b: AABB = mi.global_transform * mi.get_aabb()
				if first:
					box = b
					first = false
				else:
					box = box.merge(b)
			stack.append_array(n.get_children())
		if first:
			box = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		return box
