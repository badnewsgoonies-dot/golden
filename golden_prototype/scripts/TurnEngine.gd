extends Node

func build_initiative(combatants: Array) -> Array:
	var entries: Array = []
	for c in combatants:
		var spd := int(c.get("spd", 10))
		var jitter := GameManager.randi_range(0, max(1, int(spd * 0.25)))
		entries.append({ "name": c.get("name","?"), "ref": c, "roll": spd + jitter })
	entries.sort_custom(func(a, b): return a["roll"] > b["roll"])
	return entries

func build_queue(actions: Array) -> Array:
	# Simple initiative calculation based on AGI stat
	for action in actions:
		if action.actor != null:
			var agi: int = int(action.actor.stats.get("AGI", 10))
			var jitter: int = randi() % 5
			action.initiative = agi + jitter
	
	# Sort by initiative (higher first)
	actions.sort_custom(func(a, b): return a.initiative > b.initiative)
	return actions

func execute(action) -> Dictionary:
	# Simple damage calculation
	var actor = action.actor
	var target = action.target
	var skill = action.skill
	
	if actor == null or target == null:
		return {"hit": false, "damage": 0}
	
	# Check if target is alive
	if not target.is_alive():
		return {"hit": false, "damage": 0}
	
	# Calculate hit chance
	var hit_chance: float = float(skill.get("acc", 0.95))
	var hit: bool = randf() < hit_chance
	
	if not hit:
		return {"hit": false, "damage": 0}
	
	# Calculate damage
	var atk: int = int(actor.stats.get("ATK", 10))
	var def: int = int(target.stats.get("DEF", 8))
	var power: float = float(skill.get("power", 1.0))
	
	# Check for critical hit
	var crit_chance: float = float(skill.get("crit", 0.05))
	var crit: bool = randf() < crit_chance
	
	if crit:
		power *= 2.0
	
	var base_damage: int = int((atk - def * 0.5) * power)
	var damage: int = max(1, base_damage + randi() % 5)
	
	# Apply damage
	target.take_damage(damage)
	
	return {
		"hit": true,
		"damage": damage,
		"crit": crit,
		"status_logs": []
	}

func end_of_round_tick(units: Array) -> Array[String]:
	var logs: Array[String] = []
	# For now, just return empty array
	# This would handle status effects like poison, burn, etc.
	return logs