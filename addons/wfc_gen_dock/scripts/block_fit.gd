@tool
class_name BlockFit
extends RefCounted
## ONE job: work out how to scale and shift a model so it fits one grid block.
## It MEASURES the model, so it works for any size (0.123, 5.231, ...).
##
## The maths, for each axis:  scale = block size / model size
## Then the model is moved so the middle of its box sits in the middle of the block.

# FILL: stretch X, Y and Z to the block. Floors then stack with no gaps. (ground / middle assets)
# SLAB: stretch X and Z to the block, keep the thickness in proportion, sit on the bottom
#       of the block. (the roof, which is a thin plate on top of the building)
const FILL := 0
const SLAB := 1

# A model thinner than this on one axis is not stretched on that axis (avoids dividing by ~0).
const MIN_SIZE := 0.0001

# The size of one block: one cell wide, one level tall, one cell deep.
static func block_size() -> Vector3:
	return Vector3(CityConst.CELL_SIZE, CityConst.LEVEL_HEIGHT, CityConst.CELL_SIZE)

# The transform to give the model (inside its body) so it fits one block.
# The block is centred on the tile's origin, which is where WfcView puts the tile.
static func model_transform(scene: PackedScene, mode: int) -> Transform3D:
	var model := scene.instantiate() as Node3D
	if model == null:
		return Transform3D.IDENTITY
	var own: Transform3D = model.transform # the transform the scene already has (flips, imported scale...)
	var box: AABB = TileBody.measure(model) # the box around every mesh, with `own` included
	model.free()
	if not box.has_surface():
		return own # nothing to measure

	var block := block_size()
	var s := Vector3(
		block.x / box.size.x if box.size.x > MIN_SIZE else 1.0,
		block.y / box.size.y if box.size.y > MIN_SIZE else 1.0,
		block.z / box.size.z if box.size.z > MIN_SIZE else 1.0)
	if mode == SLAB:
		s.y = (s.x + s.z) * 0.5 # thickness follows the footprint, so a thin plate stays thin

	# Move the middle of the scaled box to the middle of the block (the origin).
	var shift: Vector3 = -s * box.get_center()
	if mode == SLAB:
		# Bottom of the plate on the bottom of the block.
		shift.y = -block.y * 0.5 - s.y * box.position.y

	var fit := Transform3D(Basis.from_scale(s), shift)
	return fit * own
