class_name TurnEngine
extends Node

const Action := preload("res://battle/models/Action.gd")
const Formula := preload("res://battle/Formula.gd")
const EffectSystem := preload("res://battle/EffectSystem.gd")

var rng := RandomNumberGenerator.new()
var effects := EffectSystem.new()

func _ready() -> void:
	rng.randomize()

func build_queue(actions: Array) -> Array:
	var order: Array = []
	for a in actions:
		var initiative := a.actor.get_stat("AGI")
		var variance := int(round(initiative * 0.25))
		var roll := rng.randi_range(0, max(1, variance))
		order.append({"action": a, "ini": initiative + roll})
	order.sort_custom(func(lhs, rhs):
		return lhs["ini"] > rhs["ini"]
	)
	var result: Array = []
	for entry in order:
		result.append(entry["action"])
	return result

func execute(action: Action) -> Dictionary:
	var result := {
		"hit": false,
		"damage": 0,
		"crit": false,
		"status_logs": []
	}
	if action.actor == null or action.target == null:
		return result
	if not action.actor.is_alive() or not action.target.is_alive():
		return result
	if action.actor.stunned:
		action.actor.stunned = false
		return result
	var chance := Formula.hit_chance(action.actor, action.target, action.skill)
	var roll := rng.randf()
	if roll > chance:
		return result
	result["hit"] = true
	var crit := rng.randf() < Formula.crit_chance(action.skill)
	result["crit"] = crit
	var variance := rng.randf_range(0.9, 1.1)
	var dmg := max(0, Formula.damage(action.actor, action.target, action.skill, crit, variance))
	var dealt := action.target.take_damage(dmg)
	result["damage"] = dealt
	if dealt > 0:
		result["status_logs"] = effects.apply_on_hit(action)
	return result

func end_of_round_tick(units: Array) -> Array[String]:
	return effects.tick_end_of_round(units)
