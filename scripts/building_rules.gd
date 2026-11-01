@tool
class_name BuildingRules
extends RefCounted
## ONE job: the adjacency rules. Can tile b sit next to tile a, in direction d?
## Open/closed: want different rules? Make a subclass that overrides fits().
## Liskov: any subclass must still answer "true/false" for any two tiles.

func fits(ta: Dictionary, tb: Dictionary, d: int) -> bool:
	match d:
		0:
			return ta["top"] == tb["bottom"]
		1:
			return tb["top"] == ta["bottom"]
		_:
			return side_ok(ta["sock"][d], tb["sock"][d ^ 1])

# A front must face "open" space. Everything else can touch anything.
func side_ok(a: String, b: String) -> bool:
	if a == "front":
		return b == "open"
	if b == "front":
		return a == "open"
	return true
