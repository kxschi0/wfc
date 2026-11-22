@tool
class_name BuildingTiles
extends RefCounted

const STYLE_NAMES := ["Any", "A", "B", "C", "D"]

var street_weight: float = 0.5 # set by build(); the panel's density slider changes it

var rules: BuildingRules
var tiles: Array = []
var compat: Array = []
var ground_count: int = 0
var middle_count: int = 0
var roof_count: int = 0

func _init(p_rules: BuildingRules = null) -> void:
	rules = p_rules if p_rules != null else BuildingRules.new()

func build(ground: Array[PackedScene], middle: Array[PackedScene], roof_scene: PackedScene, roof_weight: float, empty_weight: float, p_street_weight: float = 0.5, ground_styles: Array = [], middle_styles: Array = []) -> void:
	street_weight = p_street_weight
	tiles.clear()
	ground_count = 0
	middle_count = 0
	roof_count = 0
	var styles := _styles_in_use(ground_styles, middle_styles)
	for i in range(ground.size()):
		var s := ground[i]
		if s != null:
			ground_count += 1
		# A ground building of style "Any" is offered once per style (its weight is shared).
		var own := _style_at(ground_styles, i)
		var variants: Array = styles if own == 0 else [own]
		for v in variants:
			_add_rotated(s, "ground", _floor_socket(v), v, 1.0 / float(variants.size()))
	for i in range(middle.size()):
		var s := middle[i]
		if s != null:
			middle_count += 1
		var own := _style_at(middle_styles, i)
		var variants: Array = styles if own == 0 else [own]
		for v in variants:
			_add_rotated(s, _floor_socket(v), _floor_socket(v), v, 1.0)
	if roof_scene != null:
		roof_count = 1
		# The roof closes a building of any style ("floor*" matches every floor socket).
		_add_fixed("roof", roof_scene, "floor*", "sky", roof_weight, "side", true)
	_add_fixed("air", null, "sky", "sky", empty_weight, "open", false)
	_add_fixed("street", null, "ground", "sky", street_weight, "open", false)
	_build_compat()

# The styles a stack can have. Only the styles that are really used (1 to 4); [0] when none is.
func _styles_in_use(ground_styles: Array, middle_styles: Array) -> Array:
	var used: Array = []
	for list in [ground_styles, middle_styles]:
		for v in list:
			if int(v) > 0 and int(v) < STYLE_NAMES.size() and not used.has(int(v)):
				used.append(int(v))
	used.sort()
	return used if not used.is_empty() else [0]

func _style_at(list: Array, index: int) -> int:
	if index < 0 or index >= list.size():
		return 0
	return clampi(int(list[index]), 0, STYLE_NAMES.size() - 1)

func _floor_socket(style: int) -> String:
	return "floor" if style == 0 else "floor_" + STYLE_NAMES[style]

func _add_rotated(scene: PackedScene, bottom: String, top: String, style: int = 0, weight: float = 1.0) -> void:
	if scene == null:
		return
	var level_name := "ground" if bottom == "ground" else "floor"
	var tag: String = "" if style == 0 else "_" + STYLE_NAMES[style]
	for rot in range(4):
		var t: Dictionary = {
			"name": scene.resource_path.get_file().get_basename() + "_" + level_name + tag + "_r" + str(rot),
			"scene": scene, "rot": rot, "bottom": bottom, "top": top,
			"weight": weight, "solid": true, "sock": {},
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
