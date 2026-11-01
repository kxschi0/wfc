@tool
class_name ConsoleFormat
extends RefCounted
## Print layout helpers shared by every reporter.

static func header(title: String) -> void:
	print("")
	print("=== ", title, " ===")

# "label       : text"
static func row(label: String, text: String) -> void:
	print("  ", label.rpad(20), ": ", text)

# a second line under a row
static func more(text: String) -> void:
	print("  ", "".rpad(20), "  ", text)
