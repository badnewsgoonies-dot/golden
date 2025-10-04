class_name Status
extends RefCounted

var id: String = ""
var type: String = ""
var value: float = 0.0
var duration: int = 0
var source: String = ""

func _init(data: Dictionary = {}) -> void:
	id = String(data.get("id", data.get("type", "")))
	type = String(data.get("type", ""))
	value = float(data.get("value", 0.0))
	duration = int(data.get("duration", 0))
	source = String(data.get("source", ""))

func tick() -> bool:
	if duration > 0:
		duration -= 1
	return duration != 0
