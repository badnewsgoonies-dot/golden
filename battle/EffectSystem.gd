class_name EffectSystem
extends RefCounted

const Status = preload("res://battle/models/Status.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

## Applies status effects from a skill to a target unit.
## This is called when a skill hits its target.
func apply_effects_from_skill(skill: Dictionary, target: Unit) -> Array[String]:
	var logs: Array[String] = []
	var effects_to_apply: Array = skill.get("effects", [])
	
	if effects_to_apply.is_empty():
		return logs

	for effect_data in effects_to_apply:
		var chance: float = float(effect_data.get("chance", 1.0))
		
		# Check if the effect successfully lands based on its chance.
		if rng.randf() > chance:
			continue

		# Create a new Status object from the data defined in skills.json.
		var status_id: String = effect_data.get("id", "")
		if status_id.is_empty():
			continue
			
		var status_name: String = effect_data.get("name", status_id.capitalize())
		var duration: int = effect_data.get("duration", 1)
		var metadata: Dictionary = effect_data.get("metadata", {})
		
		var new_status := Status.new(status_id, status_name, duration, null, metadata)
		
		target.add_status(new_status)
		logs.append("%s is now %s!" % [target.name, status_name])
		
	return logs


## Processes all end-of-round effects for a list of units.
## This is where effects like poison and burn deal their damage.
func process_end_of_round_effects(units: Array[Unit]) -> Array[String]:
	var logs: Array[String] = []
	
	for unit in units:
		if not unit.is_alive():
			continue
			
		# Process damage-over-time effects first.
		for status in unit.statuses:
			match status.id:
				"poison":
					# The damage value is stored in the status's metadata.
					var damage: int = status.metadata.get("damage", 5)
					unit.take_damage(damage)
					logs.append("%s takes %d damage from poison." % [unit.name, damage])

		# Then, tick down the duration of all statuses and remove expired ones.
		var expired_statuses: Array[Status] = unit.tick_statuses()
		for expired_status in expired_statuses:
			logs.append("%s is no longer %s." % [unit.name, expired_status.name])
			
	return logs
