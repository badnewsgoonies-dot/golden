class_name TurnEngine
extends Node

const Action = preload("res://battle/models/Action.gd")
const Formula = preload("res://battle/Formula.gd")
const EffectSystem = preload("res://battle/EffectSystem.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var effect_system: EffectSystem = EffectSystem.new()

func _ready() -> void:
	rng.randomize()

## Builds the turn order queue based on unit agility.
func build_queue(actions: Array[Action]) -> Array[Action]:
	var order: Array = []
	for action in actions:
		# A unit cannot act if it is stunned.
		if action.actor.has_status("stun"):
			continue
			
		var initiative: float = float(action.actor.get_stat("AGI"))
		var variance: int = int(round(initiative * 0.25))
		var roll: int = rng.randi_range(0, max(1, variance))
		order.append({"action": action, "initiative": initiative + roll})
		
	order.sort_custom(func(a, b):
		return a.initiative > b.initiative
	)
	
	var result: Array[Action] = []
	for entry in order:
		result.append(entry.action)
		
	return result

## Executes a single action (e.g., an attack or skill).
func execute_action(action: Action) -> Dictionary:
	var result: Dictionary = {
		"hit": false,
		"damage": 0,
		"crit": false,
		"status_logs": []
	}
	
	if action.actor == null or action.target == null:
		return result
	if not action.actor.is_alive() or not action.target.is_alive():
		return result

	# --- Hit Calculation ---
	var chance: float = Formula.hit_chance(action.actor, action.target, action.skill)
	if rng.randf() > chance:
		return result # The attack missed.
	
	result["hit"] = true

	# --- Damage Calculation ---
	var is_crit: bool = rng.randf() < Formula.crit_chance(action.skill)
	result["crit"] = is_crit
	
	var variance: float = rng.randf_range(0.9, 1.1)
	var damage_dealt: int = max(0, Formula.damage(action.actor, action.target, action.skill, is_crit, variance))
	
	action.target.take_damage(damage_dealt)
	result["damage"] = damage_dealt

	# --- Apply Status Effects ---
	if damage_dealt > 0:
		var status_logs: Array[String] = effect_system.apply_effects_from_skill(action.skill, action.target)
		result["status_logs"] = status_logs
		
	return result

## Processes all end-of-round effects for all units.
func process_end_of_round(units: Array[Unit]) -> Array[String]:
	return effect_system.process_end_of_round_effects(units)
