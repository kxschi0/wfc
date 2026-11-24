@tool
class_name PlacementCheck
extends RefCounted
## ONE job: compare the ground blocks that SHOULD be placed (the plan) with the blocks that ARE
## in the scene, and say why they differ. Changes nothing.
## Same shape as SceneValidator.check(): a list of problems, empty = every block is there.

# Set on a merged piece: how many blocks it covers. A normal tile has no meta and counts as 1.
const CELLS_META := "cells"

# plan: cell -> tile name (what GroundPlanner made). container: the node the tiles were put under.
static func check(container: Node, plan: Dictionary, catalog: TileCatalog) -> PackedStringArray:
	var problems := PackedStringArray()
	var expected: Dictionary = {} # folder -> blocks that should be there
	var no_scene: Dictionary = {} # folder -> {tile name: blocks} for tiles the catalog has no scene for
	for cell in plan:
		var tile_name: String = plan[cell]
		var folder := GroundPlacer.folder_for(tile_name)
		expected[folder] = int(expected.get(folder, 0)) + 1
		if catalog.scene_for(tile_name) == null:
			if not no_scene.has(folder):
				no_scene[folder] = {}
			no_scene[folder][tile_name] = int(no_scene[folder].get(tile_name, 0)) + 1

	for folder in expected:
		var placed := _count(container, folder)
		if placed == expected[folder]:
			continue
		problems.append("%s: %d blocks should be placed, %d are in the scene. %s" % [folder, expected[folder], placed, _cause(container, folder, placed > expected[folder], no_scene.get(folder, {}))])
	return problems

static func _cause(container: Node, folder: String, too_many: bool, no_scene: Dictionary) -> String:
	if too_many:
		return "Cause: blocks of an older city are still in the scene."
	if not no_scene.is_empty():
		var parts := PackedStringArray()
		for tile_name in no_scene:
			parts.append("'%s' (%d blocks)" % [tile_name, no_scene[tile_name]])
		return "Cause: no scene for " + ", ".join(parts) + ". Add it to TileCatalog.FLOORS."
	var node := container.get_node_or_null(folder)
	if node == null or node.is_queued_for_deletion():
		return "Cause: the '%s' folder was deleted while the city was being built." % folder
	return "Cause: some blocks were never created."

# Blocks inside one folder. A merged piece counts for all the blocks it covers.
static func _count(container: Node, folder: String) -> int:
	var node := container.get_node_or_null(folder)
	if node == null or node.is_queued_for_deletion():
		return 0
	var total := 0
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			total += int(child.get_meta(CELLS_META, 1))
	return total

# Buildings: every decided cell that has a model must be in the scene. wave: cell -> options, tiles: the tile list.
const BUILDING_FOLDERS := ["GroundFloors", "UpperFloors", "Roofs"]

static func check_buildings(container: Node, wave: Dictionary, tiles: Array) -> PackedStringArray:
	var problems := PackedStringArray()
	var expected := 0
	for cell in wave:
		var opts: Array = wave[cell]
		if opts.size() == 1 and tiles[opts[0]]["scene"] != null:
			expected += 1
	var placed := 0
	var folders_found := 0
	for folder in BUILDING_FOLDERS:
		var node := container.get_node_or_null(folder)
		if node == null or node.is_queued_for_deletion():
			continue
		folders_found += 1
		for child in node.get_children():
			if not child.is_queued_for_deletion():
				placed += 1
	if placed == expected:
		return problems
	var cause := "Cause: some buildings were never created."
	if placed > expected:
		cause = "Cause: buildings of an older city are still in the scene."
	elif folders_found == 0:
		cause = "Cause: the building folders were deleted while the city was being built."
	problems.append("Buildings: %d pieces should be placed, %d are in the scene. %s" % [expected, placed, cause])
	return problems
