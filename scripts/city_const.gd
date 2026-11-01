@tool
class_name CityConst
extends RefCounted
## Shared constants only. No logic.

const CELL_SIZE := 1.0
const LEVEL_HEIGHT := 1.0
const FRONT_DIR := Vector3i(0, 0, 1) # the front of the models faces +Z

# 0 = up, 1 = down, 2 = +x, 3 = -x, 4 = +z, 5 = -z. (d ^ 1 is always the opposite side)
const WDIRS := [
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const NONE := Vector3i(-1, -1, -1)
