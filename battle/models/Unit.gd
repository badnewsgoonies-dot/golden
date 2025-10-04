class_name Unit
extends RefCounted

const Status := preload("res://battle/models/Status.gd")

var name: String = ""
var stats: Dictionary = {}
var max_stats: Dictionary = {}
var resist: Dictionary = {}
var statuses: Array[Status] = []
var buffs: Dictionary = {
	"ATK": 1.0,
	"DEF": 1.0,
	"AGI": 1.0,
	"FOCUS": 1.0
}
var stunned: bool = false

func is_alive() -> bool:
	return int(stats.get("HP", 0)) > 0

func get_stat(stat_name: String) -> float:
	var base: float = float(stats.get(stat_name, 0))
	var mult: float = float(buffs.get(stat_name, 1.0))
	return base * mult

func get_resist(element: String) -> float:
	return float(resist.get(element, 1.0))

func take_damage(amount: int) -> int:
	var hp: int = int(stats.get("HP", 0))
	var dmg: int = int(clamp(amount, 0, hp))
	stats["HP"] = max(0, hp - dmg)
	return dmg

func heal(amount: int) -> int:
	var hp: int = int(stats.get("HP", 0))
	var max_hp: int = int(max_stats.get("HP", hp))
	var healed: int = int(clamp(amount, 0, max_hp - hp))
	stats["HP"] = min(max_hp, hp + healed)
	return healed

func spend_mp(amount: int) -> bool:
	var mp: int = int(stats.get("MP", 0))
	if mp < amount:
		return false
	stats["MP"] = mp - amount
	return true

func restore_mp(amount: int) -> int:
	var mp: int = int(stats.get("MP", 0))
	var max_mp: int = int(max_stats.get("MP", mp))
	var restored: int = int(clamp(amount, 0, max_mp - mp))
	stats["MP"] = min(max_mp, mp + restored)
	return restored

func add_status(status: Status) -> void:
	statuses.append(status)

func has_status(status_type: String) -> bool:
	for st in statuses:
		if st.type == status_type:
			return true
	return false

func remove_status(status_type: String) -> void:
	statuses = statuses.filter(func(st: Status):
		return st.type != status_type
	)

func tick_statuses() -> Array[Status]:
	var expired: Array[Status] = []
	for st in statuses.duplicate():
		if not st.tick():
			expired.append(st)
			statuses.erase(st)
	return expired

func get_status_types() -> Array[String]:
	var types: Array[String] = []
	for st in statuses:
		if st == null:
			continue
		if st.type.is_empty():
			continue
		types.append(st.type)
	return types

func apply_upgrade(upgrade_data: Dictionary) -> void:
	var type: String = upgrade_data.get("type", "")
	match type:
		"stat_boost":
			var stat_name: String = upgrade_data.get("stat", "")
			var value: float = upgrade_data.get("value", 0.0)
			if stat_name.is_empty() or value == 0.0:
				return

			if stats.has(stat_name):
				var current_value = float(stats[stat_name])
				stats[stat_name] = int(current_value * (1.0 + value))
			if max_stats.has(stat_name):
				var current_max_value = float(max_stats[stat_name])
				max_stats[stat_name] = int(current_max_value * (1.0 + value))
			
			# If HP is boosted, also heal the unit for the increased amount
			if stat_name == "HP":
				var old_hp = int(stats.get("HP", 0))
				var new_max_hp = int(max_stats.get("HP", 0))
				stats["HP"] = new_max_hp # Fully heal on HP upgrade
