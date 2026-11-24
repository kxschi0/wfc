@tool
class_name TileCatalog
extends RefCounted
## DATA ONLY: which scenes exist, and which scenes may play which role.
## Open/closed: to add a tile, edit these two tables. No other file changes.

const FLOORS := {
	"floor": preload("res://addons/wfc_gen_dock/Assets/floor.tscn"),
	"sidewalk": preload("res://addons/wfc_gen_dock/Assets/sidewalk_nobevel.tscn"),
	"roadN": preload("res://addons/wfc_gen_dock/Assets/roadN.tscn"),
	"roadW": preload("res://addons/wfc_gen_dock/Assets/roadW.tscn"),
	"roadE": preload("res://addons/wfc_gen_dock/Assets/roadE.tscn"),
	"roadS": preload("res://addons/wfc_gen_dock/Assets/roadS.tscn"),
	"crossroadN": preload("res://addons/wfc_gen_dock/Assets/crossroadN.tscn"),
	"crossroadS": preload("res://addons/wfc_gen_dock/Assets/crossroadS.tscn"),
	"crossroadW": preload("res://addons/wfc_gen_dock/Assets/crossroadW.tscn"),
	"crossroadE": preload("res://addons/wfc_gen_dock/Assets/crossroadE.tscn"),
	"roadstripeN": preload("res://addons/wfc_gen_dock/Assets/roadstripeN.tscn"),
	"roadstripeE": preload("res://addons/wfc_gen_dock/Assets/roadstripeE.tscn"),
}

const ROLES := {
	"straight_ns": ["roadstripeN"],
	"straight_ew": ["roadstripeE"],
	"straight_plain": ["roadN"], # plain asphalt, no marking (the default look)
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
