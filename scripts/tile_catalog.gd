@tool
class_name TileCatalog
extends RefCounted
## DATA ONLY: which scenes exist, and which scenes may play which role.
## Open/closed: to add a tile, edit these two tables. No other file changes.

const FLOORS := {
	"floor": preload("res://Assets/floor.tscn"),
	"sidewalk": preload("res://Assets/sidewalk_nobevel.tscn"),
	"roadN": preload("res://Assets/roadN.tscn"),
	"roadS": preload("res://Assets/roadS.tscn"),
	"roadW": preload("res://Assets/roadW.tscn"),
	"roadE": preload("res://Assets/roadE.tscn"),
	"crossroadN": preload("res://Assets/crossroadN.tscn"),
	"crossroadS": preload("res://Assets/crossroadS.tscn"),
	"crossroadW": preload("res://Assets/crossroadW.tscn"),
	"crossroadE": preload("res://Assets/crossroadE.tscn"),
	"roadstripeN": preload("res://Assets/roadstripeN.tscn"),
	"roadstripeE": preload("res://Assets/roadstripeE.tscn"),
}

const ROLES := {
	"straight_ns": ["roadstripeN"],
	"straight_ew": ["roadstripeE"],
	"cross4": ["roadN"],
	"tee_N": ["roadN"],
	"tee_S": ["roadS"],
	"tee_E": ["roadE"],
	"tee_W": ["roadW"],
	"crosswalk_N": ["crossroadE"],
	"crosswalk_S": ["crossroadW"],
	"crosswalk_E": ["crossroadN"],
	"crosswalk_W": ["crossroadS"],
	"sidewalk": ["sidewalk"],
	"floor": ["floor"],
}

func scene_for(tile_name: String) -> PackedScene:
	return FLOORS.get(tile_name)

func pick(role: String) -> String:
	var options: Array = ROLES.get(role, [])
	if options.is_empty():
		push_warning("No tile set for role '%s' - using floor" % role)
		return "floor"
	return options.pick_random()

func check() -> void:
	for role in ROLES:
		for t in ROLES[role]:
			if not FLOORS.has(t):
				push_warning("ROLES['%s'] uses unknown tile '%s'" % [role, t])
