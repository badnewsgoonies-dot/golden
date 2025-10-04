class_name EffectSystem
extends RefCounted

const Action := preload("res://battle/models/Action.gd")
const Status := preload("res://battle/models/Status.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func apply_on_hit(action: Action) -> Array[String]:
	var logs: Array[String] = []
	var effects: Array = action.skill.get("effects", [])
	if effects.is_empty():
		return logs
	for eff_data in effects:
		var eff: Dictionary = eff_data
		var chance: float = float(eff.get("chance", 1.0))
		if rng.randf() > chance:
			continue
		var status: Status = Status.new({
			"type": eff.get("apply", ""),
			"duration": eff.get("duration", 0),
			"value": eff.get("value", 0.0)
		})
		if status.type.is_empty():
			continue
		action.target.add_status(status)
		if status.type == "stun":
			action.target.stunned = true
		logs.append("%s is %s" % [action.target.name, status.type.capitalize()])
	return logs

func tick_end_of_round(units: Array) -> Array[String]:
	var logs: Array[String] = []
	for unit in units:
		if unit == null or not unit.is_alive():
			continue
		var to_remove: Array[Status] = []
		for st in unit.statuses:
			match st.type:
				"burn":
					var dmg: int = int(ceil(float(unit.max_stats.get("HP", unit.stats.get("HP", 0))) * 0.05))
					var actual: int = int(unit.take_damage(dmg))
					logs.append("%s suffers %d burn" % [unit.name, actual])
				"poison":
					var dmg2: int = int(ceil(float(unit.max_stats.get("HP", unit.stats.get("HP", 0))) * 0.07))
					var actual2: int = int(unit.take_damage(dmg2))
					logs.append("%s takes %d poison" % [unit.name, actual2])
				"stun":
					pass
			st.duration -= 1
			if st.duration <= 0:
				if st.type == "stun":
					unit.stunned = false
				to_remove.append(st)
		for st in to_remove:
			unit.statuses.erase(st)
	return logs
