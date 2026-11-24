@tool
class_name WfcLogger
extends RefCounted
## The "logger contract". Every method does NOTHING here, so this class is also
## the silent logger. Subclasses (like WfcConsoleLogger) fill in the printing.
## Liskov: the solver can use ANY subclass without knowing which one it got.

var solver # the WfcSolver. Untyped on purpose (avoids a circular class reference).

func attach(p_solver) -> void:
	solver = p_solver

func setup(_building_tiles: BuildingTiles, _floor_count: int, _levels: int) -> void:
	pass

func wave_initialized(_attempt: int) -> void:
	pass

func after_first_ripple() -> void:
	pass

func initial_dead_end() -> void:
	pass

func cell_selected(_cell: Vector3i) -> void:
	pass

func collapsed(_opts: Array, _total: float, _roll: float, _choice: int) -> void:
	pass

func rippled(_dst: Vector3i, _before_n: int, _after_n: int) -> void:
	pass

func step_finished(_cell: Vector3i, _changed: Dictionary) -> void:
	pass

func dead_end(_cell: Vector3i) -> void:
	pass

func attempt_failed(_attempt: int) -> void:
	pass

func summary(_attempt: int) -> void:
	pass
