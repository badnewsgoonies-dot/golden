class_name EnemyAI
extends RefCounted

## This class contains the logic for an enemy's decision-making process.
## It helps an enemy unit choose the best action and target based on the battle state.

const Action = preload("res://battle/models/Action.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init():
	_rng.randomize()

## The main entry point for the AI. It decides the best action for an enemy to take.
func choose_action(actor: Unit, living_heroes: Array[Unit]) -> Action:
	if actor == null or living_heroes.is_empty():
		return null

	# --- Step 1: Gather available skills and analyze targets ---
	var available_skills: Array[Dictionary] = []
	
	# Safety check: ensure actor has skills
	if actor.skills == null or actor.skills.is_empty():
		# Fall back to basic attack
		var fallback_skill = DataRegistry.get_skill("slash")
		var fallback_target = living_heroes[_rng.randi() % living_heroes.size()]
		return Action.new(actor, fallback_skill, fallback_target)
	
	for skill_id in actor.skills:
		var skill_data = DataRegistry.get_skill(skill_id)
		if actor.stats.get("MP", 0) >= skill_data.get("mp_cost", 0):
			available_skills.append(skill_data)

	# --- Step 2: Score potential actions ---
	var best_action: Action = null
	var best_score: float = -1.0

	for skill in available_skills:
		for target in living_heroes:
			var score = _score_action(actor, target, skill)
			if score > best_score:
				best_score = score
				best_action = Action.new(actor, skill, target)

	# If no good action was found, default to a basic attack.
	if best_action == null:
		var fallback_skill = DataRegistry.get_skill("slash")
		var fallback_target = living_heroes[_rng.randi() % living_heroes.size()]
		best_action = Action.new(actor, fallback_skill, fallback_target)
		
	return best_action

## Scores a potential action based on its utility.
## This is the core of the AI's "brain".
func _score_action(actor: Unit, target: Unit, skill: Dictionary) -> float:
	var score: float = 0.0
	
	# --- Base Score: Damage Potential ---
	# Prioritize skills that deal more damage.
	score += float(skill.get("power", 1.0)) * actor.stats.get(skill.get("stat", "ATK"), 10)

	# --- Target Prioritization: Low Health ---
	# Add a significant bonus for targeting low-health heroes.
	var max_hp = target.max_stats.get("HP", 1)
	if max_hp <= 0:
		max_hp = 1  # Prevent division by zero
	var health_percentage = float(target.stats.get("HP", 0)) / float(max_hp)
	if health_percentage < 0.5:
		score *= 1.5 # 50% score bonus for targets below half health

	# --- Strategic Modifiers: Status Effects ---
	var effects: Array = skill.get("effects", [])
	for effect in effects:
		var effect_id = effect.get("id")
		# Avoid wasting status effects. If the target already has the status, this action is less valuable.
		if target.has_status(effect_id):
			score *= 0.1 # Reduce score by 90% if status is already applied
		else:
			# Add a bonus for applying a useful status effect.
			score += 20.0 # Flat bonus for applying a new, useful status

	# --- Add Randomness ---
	# Add a small random factor to prevent the AI from being perfectly predictable.
	score *= _rng.randf_range(0.9, 1.1)

	return score
