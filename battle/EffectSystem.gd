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

## Try to apply a single effect with all checks
func _try_apply_single_effect(effect_data: Dictionary, caster: Unit, target: Unit) -> Dictionary:
	var status_id: String = effect_data.get("id", "")
	var status_name: String = effect_data.get("name", status_id.capitalize())
	
	if status_id.is_empty():
		return {"success": false, "reason": "invalid"}
	
	# Check immunity
	if _is_immune(target, status_id):
		return {
			"success": false, 
			"reason": "immune",
			"effect_name": status_name
		}
	
	# Calculate final chance with resistance
	var base_chance: float = float(effect_data.get("chance", 1.0))
	var final_chance = _calculate_final_chance(base_chance, caster, target, status_id)
	
	# Apply global modifier
	final_chance *= global_effect_chance_modifier
	
	# Roll for application
	if rng.randf() > final_chance:
		return {
			"success": false,
			"reason": "chance",
			"effect_name": status_name
		}
	
	# Calculate duration with modifiers
	var base_duration: int = effect_data.get("duration", 1)
	var final_duration = _calculate_final_duration(base_duration, caster, target, status_id)
	
	# Create and apply the status
	var metadata: Dictionary = effect_data.get("metadata", {}).duplicate()
	
	# Add caster reference for scaling effects
	metadata["caster_id"] = caster.name
	metadata["applied_at_turn"] = 0  # Should be set by TurnEngine
	
	var new_status := Status.new(status_id, status_name, final_duration, null, metadata)
	
	# Handle stacking
	var existing = target.get_status(status_id)
	if existing:
		return _handle_stacking(target, existing, new_status)
	else:
		target.add_status(new_status)
		_track_effect_applied(caster, target, new_status)
		
		return {
			"success": true,
			"message": _get_application_message(target, new_status)
		}

## Handle status stacking based on stack type
func _handle_stacking(target: Unit, existing: Status, new_status: Status) -> Dictionary:
	match existing.stack_type:
		Status.StackType.NONE:
			return {
				"success": false,
				"reason": "no_stack",
				"effect_name": existing.name
			}
		
		Status.StackType.STACK:
			# Allow multiple instances - add as new
			target.add_status(new_status)
			return {
				"success": true,
				"message": "%s gains another stack of %s!" % [target.name, new_status.name]
			}
		
		Status.StackType.REFRESH:
			existing.duration_turns = existing.max_duration
			return {
				"success": true,
				"message": "%s's %s duration refreshed!" % [target.name, existing.name]
			}
		
		Status.StackType.INTENSITY:
			if existing.stack_count < existing.max_stacks:
				existing.stack_with(new_status)
				return {
					"success": true,
					"message": "%s intensifies! (%dx stacks)" % [existing.name, existing.stack_count]
				}
			else:
				return {
					"success": false,
					"reason": "max_stacks",
					"effect_name": existing.name
				}
		
		Status.StackType.EXTEND:
			existing.stack_with(new_status)
			return {
				"success": true,
				"message": "%s's %s extended to %d turns!" % [target.name, existing.name, existing.duration_turns]
			}
		
		_:
			return {"success": false, "reason": "unknown_stack_type"}

## Process end-of-round effects with priority sorting
func process_end_of_round_effects(units: Array[Unit]) -> Array[String]:
	var logs: Array[String] = []
	
	for unit in units:
		if not unit.is_alive():
			continue
		
		# Sort statuses by priority for proper execution order
		var sorted_statuses = unit.statuses.duplicate()
		sorted_statuses.sort_custom(_sort_by_priority)
		
		# Process each status effect
		for status in sorted_statuses:
			var effect_logs = _process_single_status(status, unit)
			logs.append_array(effect_logs)
		
		# Tick and remove expired statuses
		var expired_statuses: Array[Status] = unit.tick_statuses()
		for expired_status in expired_statuses:
			logs.append(_get_expiration_message(unit, expired_status))
			_track_effect_expired(unit, expired_status)
	
	return logs

## Process a single status effect
func _process_single_status(status: Status, unit: Unit) -> Array[String]:
	var logs: Array[String] = []
	
	match status.category:
		Status.Category.DOT:
			var damage = int(status.get_effect_value("damage"))
			if damage > 0:
				unit.take_damage(damage)
				status.total_value_dealt += damage
				status.times_triggered += 1
				logs.append(_get_dot_message(unit, status, damage))
		
		Status.Category.HOT:
			var healing = int(status.get_effect_value("healing"))
			if healing > 0:
				var healed = unit.heal(healing)
				status.total_value_dealt += healed
				status.times_triggered += 1
				logs.append(_get_hot_message(unit, status, healed))
		
		Status.Category.BUFF:
			# Buffs are typically handled elsewhere (stat calculations)
			pass
		
		Status.Category.DEBUFF:
			# Some debuffs might have per-turn effects
			if status.id == "curse":
				var mp_drain = int(status.get_effect_value("mp_drain"))
				if mp_drain > 0 and unit.stats.has("MP"):
					unit.stats["MP"] = max(0, unit.stats["MP"] - mp_drain)
					logs.append("%s loses %d MP from curse!" % [unit.name, mp_drain])
	
	return logs

## Check if target is immune to an effect
func _is_immune(target: Unit, effect_id: String) -> bool:
	# Check for immunity status
	if target.has_status("immunity"):
		return true
	
	# Check for specific immunities
	var immunities: Array = target.metadata.get("immunities", [])
	if effect_id in immunities:
		return true
	
	# Bosses might be immune to certain control effects
	if target.metadata.get("is_boss", false) and effect_id in ["stun", "freeze", "sleep"]:
		return true
	
	return false

## Calculate final application chance with resistance
func _calculate_final_chance(base_chance: float, caster: Unit, target: Unit, effect_id: String) -> float:
	var chance = base_chance
	
	# Apply caster's effect accuracy bonus
	var effect_acc = caster.metadata.get("effect_accuracy", 1.0)
	chance *= effect_acc
	
	# Apply target's resistance
	var resistance = target.metadata.get("status_resist", {})
	var specific_resist = resistance.get(effect_id, 0.0)
	var general_resist = resistance.get("all", 0.0)
	
	chance *= (1.0 - max(specific_resist, general_resist))
	
	# Level difference modifier (if applicable)
	var caster_level = caster.metadata.get("level", 1)
	var target_level = target.metadata.get("level", 1)
	if target_level > caster_level:
		chance *= 0.9 ** (target_level - caster_level)  # 10% reduction per level
	
	return clamp(chance, 0.05, 0.95)  # Always at least 5% chance, max 95%

## Calculate final duration with modifiers
func _calculate_final_duration(base_duration: int, caster: Unit, target: Unit, effect_id: String) -> int:
	var duration = float(base_duration)
	
	# Apply caster's effect duration bonus
	var effect_duration = caster.metadata.get("effect_duration", 1.0)
	duration *= effect_duration
	
	# Apply global modifier
	duration *= global_effect_duration_modifier
	
	# Apply target's duration reduction
	var duration_reduction = target.metadata.get("status_duration_reduction", 0.0)
	duration *= (1.0 - duration_reduction)
	
	return max(1, int(duration))  # Minimum 1 turn

## Sort statuses by priority
func _sort_by_priority(a: Status, b: Status) -> bool:
	return a.priority < b.priority

## Get application message based on effect type
func _get_application_message(target: Unit, status: Status) -> String:
	match status.category:
		Status.Category.DOT:
			return "%s is afflicted with %s!" % [target.name, status.name]
		Status.Category.CONTROL:
			return "%s has been %s!" % [target.name, status.name.to_lower()]
		Status.Category.BUFF:
			return "%s gains %s!" % [target.name, status.name]
		Status.Category.DEBUFF:
			return "%s is weakened by %s!" % [target.name, status.name]
		_:
			return "%s is affected by %s!" % [target.name, status.name]

## Get damage over time message
func _get_dot_message(unit: Unit, status: Status, damage: int) -> String:
	match status.id:
		"poison":
			return "%s takes %d poison damage!" % [unit.name, damage]
		"burn":
			return "%s burns for %d damage!" % [unit.name, damage]
		"bleed":
			return "%s bleeds for %d damage!" % [unit.name, damage]
		_:
			return "%s takes %d damage from %s!" % [unit.name, damage, status.name]

## Get heal over time message
func _get_hot_message(unit: Unit, status: Status, healing: int) -> String:
	match status.id:
		"regen":
			return "%s regenerates %d HP!" % [unit.name, healing]
		"healing_aura":
			return "%s is healed for %d by the aura!" % [unit.name, healing]
		_:
			return "%s heals %d HP from %s!" % [unit.name, healing, status.name]

## Get expiration message
func _get_expiration_message(unit: Unit, status: Status) -> String:
	if status.is_beneficial():
		return "%s's %s wears off." % [unit.name, status.name]
	else:
		return "%s recovers from %s!" % [unit.name, status.name]

## Track effect application for statistics
func _track_effect_applied(caster: Unit, target: Unit, status: Status) -> void:
	effect_history.append({
		"timestamp": Time.get_ticks_msec(),
		"caster": caster.name,
		"target": target.name,
		"effect": status.id,
		"category": status.category,
		"duration": status.duration_turns
	})

## Track effect expiration for statistics
func _track_effect_expired(unit: Unit, status: Status) -> void:
	# Could log total damage dealt, times triggered, etc.
	if status.total_value_dealt > 0:
		print("Effect %s on %s dealt total: %d" % [status.name, unit.name, status.total_value_dealt])

## Clear specific categories of effects (for cleanse abilities)
func cleanse_effects(target: Unit, categories: Array[Status.Category]) -> Array[String]:
	var logs: Array[String] = []
	var removed: Array[String] = []
	
	target.statuses = target.statuses.filter(func(s: Status):
		if s.category in categories:
			removed.append(s.name)
			return false
		return true
	)
	
	if not removed.is_empty():
		logs.append("%s is cleansed of: %s!" % [target.name, ", ".join(removed)])
	
	return logs

## Get all effects of a specific category on a unit
func get_effects_by_category(unit: Unit, category: Status.Category) -> Array[Status]:
	return unit.statuses.filter(func(s: Status):
		return s.category == category
	)
