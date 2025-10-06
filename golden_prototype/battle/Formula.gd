class_name Formula
extends RefCounted

const Unit := preload("res://battle/models/Unit.gd")

static func element_multiplier(attacker: Unit, target: Unit, skill: Dictionary) -> float:
	var element: String = String(skill.get("element", ""))
	if element.is_empty():
		return 1.0
	var mult: float = target.get_resist(element)
	return mult if mult > 0.0 else 1.0

static func element_tag(attacker: Unit, target: Unit, skill: Dictionary) -> String:
	var mult: float = element_multiplier(attacker, target, skill)
	if mult > 1.05:
		return "[WEAK]"
	elif mult < 0.95:
		return "[RESIST]"
	return ""

static func hit_chance(attacker: Unit, target: Unit, skill: Dictionary) -> float:
	var base: float = float(skill.get("acc", 1.0))
	var focus: float = attacker.get_stat("FOCUS")
	var evade: float = target.get_stat("AGI")
	var delta: float = 0.005 * (focus - evade)
	return clamp(base + delta, 0.5, 0.99)

static func crit_chance(skill: Dictionary) -> float:
	return clamp(float(skill.get("crit", 0.0)), 0.0, 1.0)

static func damage(attacker: Unit, target: Unit, skill: Dictionary, crit: bool, variance: float) -> int:
	var stat_name: String = String(skill.get("stat", "ATK"))
	var atk: float = attacker.get_stat(stat_name)
	var power: float = float(skill.get("power", 1.0))
	var defense: float = target.get_stat("DEF")
	var base: float = max(0.0, atk * power - defense)
	if crit:
		base *= 1.5
	base *= element_multiplier(attacker, target, skill)
	base *= variance
	return int(round(base))
