@tool
class_name BuildingTiles
extends RefCounted
## ONE job: build the list of WFC tiles (rotations included) and the
## compatibility table. The rules themselves live in BuildingRules.

var street_weight: float = 0.5 # set by build(); the panel's density slider changes it

var rules: BuildingRules
var tiles: Array = []
var compat: Array = []
var ground_count: int = 0
var middle_count: int = 0
var roof_count: int = 0

func _init(p_rules: BuildingRules = null) -> void:
	rules = p_rules if p_rules != null else BuildingRules.new()

func build(ground: Array[PackedScene], middle: Array[PackedScene], roof_scene: PackedScene, roof_weight: float, empty_weight: float, p_street_weight: float = 0.5) -> void:
	street_weight = p_street_weight
	tiles.clear()
	ground_count = 0
	middle_count = 0
	roof_count = 0
	for s in ground:
		if s != null:
			ground_count += 1
		_add_rotated(s, "ground", "floor")
	for s in middle:
		if s != null:
			middle_count += 1
		_add_rotated(s, "floor", "floor")
	if roof_scene != null:
		roof_count = 1
		_add_fixed("roof", roof_scene, "floor", "sky", roof_weight, "side", true)
	_add_fixed("air", null, "sky", "sky", empty_weight, "open", false)
	_add_fixed("street", null, "ground", "sky", street_weight, "open", false)
	_build_compat()

# One building model becomes 4 tiles (turned 0, 90, 180, 270 degrees).
func _add_rotated(scene: PackedScene, bottom: String, top: String) -> void:
	if scene == null:
		return
	for rot in range(4):
		var t: Dictionary = {
			"name": scene.resource_path.get_file().get_basename() + "_" + bottom + "_r" + str(rot),
			"scene": scene, "rot": rot, "bottom": bottom, "top": top,
			"weight": 1.0, "solid": true, "sock": {},
		}
		for d in range(2, 6):
			# Which side of the UNROTATED model ends up facing world direction d?
			var local: Vector3 = Vector3(CityConst.WDIRS[d]).rotated(Vector3.UP, deg_to_rad(-90.0 * rot))
			var li := Vector3i(roundi(local.x), 0, roundi(local.z))
			var kind := "side"
			if li == CityConst.FRONT_DIR:
				kind = "front"
			elif li == -CityConst.FRONT_DIR:
				kind = "back"
			t["sock"][d] = kind
		tiles.append(t)

func _add_fixed(nm: String, scene: PackedScene, bottom: String, top: String, weight: float, side_kind: String, solid: bool) -> void:
	var t: Dictionary = {
		"name": nm, "scene": scene, "rot": 0, "bottom": bottom, "top": top,
		"weight": maxf(weight, 0.001), "solid": solid, "sock": {},
	}
	for d in range(2, 6):
		t["sock"][d] = side_kind
	tiles.append(t)

func _build_compat() -> void:
	compat.clear()
	for d in range(6):
		var per_tile: Array = []
		for a in range(tiles.size()):
			var ok := PackedInt32Array()
			for b in range(tiles.size()):
				if rules.fits(tiles[a], tiles[b], d):
					ok.append(b)
			per_tile.append(ok)
		compat.append(per_tile)
