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
	var base := float(stats.get(stat_name, 0))
	var mult := float(buffs.get(stat_name, 1.0))
	return base * mult

func get_resist(element: String) -> float:
	return float(resist.get(element, 1.0))

func take_damage(amount: int) -> int:
	var hp: int = int(stats.get("HP", 0))
	var dmg := clamp(amount, 0, hp)
	stats["HP"] = max(0, hp - dmg)
	return dmg

func heal(amount: int) -> int:
	var hp: int = int(stats.get("HP", 0))
	var max_hp: int = int(max_stats.get("HP", hp))
	var healed := clamp(amount, 0, max_hp - hp)
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
	var restored := clamp(amount, 0, max_mp - mp)
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
