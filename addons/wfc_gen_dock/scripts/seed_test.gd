@tool
extends EditorScript

func _run() -> void:
	seed(2775775666)
	var h := [1, 2, 3, 4, 5]
	h.shuffle()
	var v := [1, 2, 3, 4, 5]
	v.shuffle()
	print("horizontal start row: ", h[0])
	print("vertical start column: ", v[0])
	print("partial? ", randf() < 0.5)
