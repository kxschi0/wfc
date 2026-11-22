@tool
class_name BuildingRules
extends RefCounted

func fits(ta: Dictionary, tb: Dictionary, d: int) -> bool:
	match d:
		0:
			return stack_ok(ta["top"], tb["bottom"])
		1:
			return stack_ok(tb["top"], ta["bottom"])
		_:
			return side_ok(ta["sock"][d], tb["sock"][d ^ 1])


func stack_ok(top: String, bottom: String) -> bool:
	return top == bottom or (bottom == "floor*" and top.begins_with("floor"))

func side_ok(a: String, b: String) -> bool:
	if a == "front":
		return b == "open"
	if b == "front":
		return a == "open"
	return true
