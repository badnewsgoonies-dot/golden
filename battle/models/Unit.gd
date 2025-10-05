class_name Unit
extends RefCounted

const Status := preload("res://battle/models/Status.gd")

var name: String = ""
var character_id: String = ""  # Added to track the original character/enemy ID for sprite mapping
var stats: Dictionary = {}
var max_stats: Dictionary = {}
var resist: Dictionary = {}
var statuses: Array[Status] = [] # This will hold active status effects.

# DEPRECATED: The 'buffs' dictionary and 'stunned' boolean will be replaced by the new Status system.
# We leave them for now to ensure the project still runs, and will remove them in a later step.
var buffs: Dictionary = {
	"ATK": 1.0,
	"DEF": 1.0,
	"AGI": 1.0,
	"FOCUS": 1.0
}
var stunned: bool = false
var skills: Array[String] = []

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

## Adds a new status effect to the unit.
## If the unit already has a status with the same ID, it will be removed and replaced.
## This prevents stacking the same effect (e.g., being poisoned twice).
func add_status(new_status: Status) -> void:
	# First, remove any existing status with the same ID to prevent duplicates.
	remove_status(new_status.id)
	statuses.append(new_status)

## Checks if the unit currently has a status with the given ID.
func has_status(status_id: String) -> bool:
	for s in statuses:
		if s.id == status_id:
			return true
	return false

## Removes a status effect from the unit by its ID.
func remove_status(status_id: String) -> void:
	statuses = statuses.filter(func(s: Status):
		return s.id != status_id
	)

## Processes all active statuses at the end of a turn.
## It calls the 'tick' method on each status, which decrements its duration.
## If a status expires, it is removed from the unit.
func tick_statuses() -> Array[Status]:
	var expired: Array[Status] = []
	var remaining_statuses: Array[Status] = []
	
	for s in statuses:
		# The tick() method returns true if the status has expired.
		if s.tick():
			expired.append(s)
		else:
			remaining_statuses.append(s)
			
	statuses = remaining_statuses
	return expired

## Returns an array of all active status effect IDs.
func get_status_ids() -> Array[String]:
	var ids: Array[String] = []
	for s in statuses:
		if s != null and not s.id.is_empty():
			ids.append(s.id)
	return ids

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
