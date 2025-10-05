class_name EffectSystem
extends RefCounted

## Enhanced effect system with resistance, immunities, and better mechanics

const Status = preload("res://battle/models/Status.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Track all applied effects for statistics
var effect_history: Array[Dictionary] = []

# Effect modifiers (can be modified by game difficulty, items, etc)
var global_effect_chance_modifier: float = 1.0
var global_effect_duration_modifier: float = 1.0

func _init() -> void:
	rng.randomize()

## Apply effects with resistance checks and proper stacking
func apply_effects_from_skill(skill: Dictionary, caster: Unit, target: Unit) -> Array[String]:
	var logs: Array[String] = []
	var effects_to_apply: Array = skill.get("effects", [])
	
	if effects_to_apply.is_empty():
		return logs
	
	for effect_data in effects_to_apply:
		var result = _try_apply_single_effect(effect_data, caster, target)
		if not result.success:
			if result.reason == "resisted":
				logs.append("%s resisted %s!" % [target.name, result.effect_name])
			elif result.reason == "immune":
				logs.append("%s is immune to %s!" % [target.name, result.effect_name])
			# Silent fail for chance-based misses
		else:
			logs.append(result.message)
	
	return logs
