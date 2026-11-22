@tool
class_name BuildingRules
extends RefCounted
## ONE job: the adjacency rules. Can tile b sit next to tile a, in direction d?
## Open/closed: want different rules? Make a subclass that overrides fits().
## Liskov: any subclass must still answer "true/false" for any two tiles.

func fits(ta: Dictionary, tb: Dictionary, d: int) -> bool:
	match d:
		0:
			return stack_ok(ta["top"], tb["bottom"])
		1:
			return stack_ok(tb["top"], ta["bottom"])
		_:
			return side_ok(ta["sock"][d], tb["sock"][d ^ 1])

# Can a piece whose top is `top` carry a piece whose bottom is `bottom`?
# Floors carry a style ("floor_A"): only the same style stacks. The roof's "floor*" takes any.
func stack_ok(top: String, bottom: String) -> bool:
	return top == bottom or (bottom == "floor*" and top.begins_with("floor"))

# A front must face "open" space. Everything else can touch anything.
func side_ok(a: String, b: String) -> bool:
	if a == "front":
		return b == "open"
	if b == "front":
		return a == "open"
	return true
