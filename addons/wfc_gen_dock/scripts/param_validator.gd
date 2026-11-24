@tool
class_name ParamValidator
extends RefCounted
## ONE job: check the settings BEFORE generating.
## Every function returns a list of plain-language messages. Empty = all good.

const MIN_GRIDSIZE := 4
const MAX_GRIDSIZE := 32 # bigger grids can make the editor unresponsive
const MIN_LEVELS := 2
const MAX_LEVELS := 6
const MAX_STREETS := 6
const MIN_ROAD_WIDTH := 1
const MAX_ROAD_WIDTH := 3

# Numbers only (used by the panel on every edit).
static func validate_numbers(gridsize: int, levels: int, blocks: int, horizontal_streets: int, vertical_streets: int, build_buildings: bool, tile_size: float, density: float, road_width: int = 1) -> PackedStringArray:
	var errors := PackedStringArray()

	if gridsize < MIN_GRIDSIZE or gridsize > MAX_GRIDSIZE:
		errors.append("Grid size must be between %d and %d (it is %d)." % [MIN_GRIDSIZE, MAX_GRIDSIZE, gridsize])
	if blocks < 1:
		errors.append("Block size must be at least 1 (it is %d)." % blocks)
	if horizontal_streets < 0 or vertical_streets < 0:
		errors.append("Street counts can't be negative.")
	if horizontal_streets > MAX_STREETS or vertical_streets > MAX_STREETS:
		errors.append("Use at most %d streets in each direction." % MAX_STREETS)

	if road_width < MIN_ROAD_WIDTH or road_width > MAX_ROAD_WIDTH:
		errors.append("Road width must be between %d and %d (it is %d)." % [MIN_ROAD_WIDTH, MAX_ROAD_WIDTH, road_width])

	if blocks >= 1 and gridsize >= MIN_GRIDSIZE and road_width >= MIN_ROAD_WIDTH:
		var fit := _max_streets(gridsize, blocks, road_width)
		if fit == 0 and (horizontal_streets > 0 or vertical_streets > 0):
			errors.append("Block size (%d) and road width (%d) are too big for grid size (%d): no room for a street." % [blocks, road_width, gridsize])
		else:
			if horizontal_streets > fit:
				errors.append("Only %d horizontal street(s) fit in grid size %d with block size %d (you asked for %d)." % [fit, gridsize, blocks, horizontal_streets])
			if vertical_streets > fit:
				errors.append("Only %d vertical street(s) fit in grid size %d with block size %d (you asked for %d)." % [fit, gridsize, blocks, vertical_streets])

	if build_buildings and (levels < MIN_LEVELS or levels > MAX_LEVELS):
		errors.append("Max floors must be between %d and %d (it is %d)." % [MIN_LEVELS, MAX_LEVELS, levels])
	if tile_size <= 0.0:
		errors.append("Tile size must be greater than 0.")
	if density < 0.0 or density > 1.0:
		errors.append("Building density must be between 0% and 100%.")
	return errors

# The asset library.
static func validate_tileset(build_buildings: bool, roof_scene: PackedScene, ground_buildings: Array[PackedScene], middle_buildings: Array[PackedScene]) -> PackedStringArray:
	var errors := PackedStringArray()
	if not build_buildings:
		return errors
	if not _has_scene(ground_buildings):
		errors.append("Add at least one Ground asset.")
	if not _has_scene(middle_buildings):
		errors.append("Add at least one Middle asset.")
	if roof_scene == null:
		errors.append("Set a Roof asset.")
	return errors

# Both together (used right before generating).
static func validate(gridsize: int, levels: int, blocks: int, horizontal_streets: int, vertical_streets: int, build_buildings: bool, roof_scene: PackedScene, ground_buildings: Array[PackedScene], middle_buildings: Array[PackedScene], tile_size: float = 1.0, density: float = 0.5, road_width: int = 1) -> PackedStringArray:
	var errors := validate_numbers(gridsize, levels, blocks, horizontal_streets, vertical_streets, build_buildings, tile_size, density, road_width)
	errors.append_array(validate_tileset(build_buildings, roof_scene, ground_buildings, middle_buildings))
	return errors

# After planning: tells you if fewer streets were placed than you asked for.
# Returns "" when everything was placed.
static func street_warning(streets: StreetPlanner) -> String:
	var parts := PackedStringArray()
	if streets.row_count < streets.requested_horizontal:
		parts.append("horizontal %d of %d" % [streets.row_count, streets.requested_horizontal])
	if streets.col_count < streets.requested_vertical:
		parts.append("vertical %d of %d" % [streets.col_count, streets.requested_vertical])
	if parts.is_empty():
		return ""
	return "Placed fewer streets than requested (" + ", ".join(parts) + "). Try a bigger grid or a smaller block size."

# How many streets can ever fit in one direction.
static func _max_streets(gridsize: int, blocks: int, road_width: int = 1) -> int:
	var b := maxi(blocks, 0)
	var w := maxi(road_width, 1)
	# Start positions a street band can take, and the spacing between two bands.
	var positions := gridsize - 2 * b - w + 1
	if positions <= 0:
		return 0
	return floori(float(positions - 1) / float(b + w)) + 1

static func _has_scene(list: Array[PackedScene]) -> bool:
	for s in list:
		if s != null:
			return true
	return false
