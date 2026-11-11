@tool
class_name SceneValidator
extends RefCounted
## ONE job: check a finished generation against the rules (UC-05).
## Returns a list of problems. Empty list = the city is valid.
## Reads the data the generator keeps in `last_result`. Changes nothing.

const MAX_LISTED := 12

static func check(result: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if result.is_empty():
		problems.append("Nothing to check yet. Press Generate first.")
		return problems
	if result.has("streets_only"):
		return problems # no buildings were requested, nothing to break

	var tiles: Array = result["tiles"]
	var wave: Dictionary = result["wave"]
	var floor_cells: Dictionary = result["floor_cells"]
	var rules: BuildingRules = result["rules"]
	var levels: int = result["levels"]
	var found := 0

	for cell in wave:
		var opts: Array = wave[cell]
		if opts.size() != 1:
			found += 1
			_add(problems, found, "Cell %s was never decided." % str(cell))
			continue
		var a: Dictionary = tiles[opts[0]]

		if a["solid"] and not floor_cells.has(Vector2i(cell.x, cell.z)):
			found += 1
			_add(problems, found, "%s at %s is not on a building lot." % [a["name"], str(cell)])
		if cell.y == 0 and a["bottom"] != "ground":
			found += 1
			_add(problems, found, "%s at %s doesn't stand on the ground." % [a["name"], str(cell)])
		if cell.y == levels - 1 and a["top"] != "sky":
			found += 1
			_add(problems, found, "%s at %s has nothing closing its top." % [a["name"], str(cell)])

		# Look up, +x and +z only, so every pair is checked once.
		for d in [0, 2, 4]:
			var n: Vector3i = cell + CityConst.WDIRS[d]
			if not wave.has(n):
				continue
			var n_opts: Array = wave[n]
			if n_opts.size() != 1:
				continue
			var b: Dictionary = tiles[n_opts[0]]
			if not rules.fits(a, b, d):
				found += 1
				_add(problems, found, "%s at %s doesn't fit next to %s at %s." % [a["name"], str(cell), b["name"], str(n)])

	if found > MAX_LISTED:
		problems.append("...and %d more." % (found - MAX_LISTED))
	return problems

static func _add(problems: PackedStringArray, count: int, text: String) -> void:
	if count <= MAX_LISTED:
		problems.append(text)
