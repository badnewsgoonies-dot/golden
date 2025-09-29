extends Node2D

const Action := preload("res://battle/models/Action.gd")
const Unit := preload("res://battle/models/Unit.gd")
const Formula := preload("res://battle/Formula.gd")
const TurnEngine := preload("res://battle/TurnEngine.gd")

@onready var lbl_hero: Label = $UI/Root/VBox/HeroLabel
@onready var lbl_enemy: Label = $UI/Root/VBox/EnemyLabel
@onready var btn_attack: Button = $UI/Root/VBox/Buttons/BtnAttack
@onready var btn_fire: Button = $UI/Root/VBox/Buttons/BtnFireball
@onready var btn_potion: Button = $UI/Root/VBox/Buttons/BtnPotion
@onready var btn_end: Button = $UI/Root/VBox/Buttons/BtnEndTurn
@onready var lbl_queue: Label = $UI/Root/VBox/TurnOrder
@onready var log_view: RichTextLabel = $UI/Root/VBox/Log

var hero: Unit
var enemy: Unit
var planned_actions: Array[Action] = []
var turn_engine: TurnEngine
var potion_used: bool = false

var SKILL_SLASH := {
	"id": "slash",
	"name": "Slash",
	"type": "damage",
	"stat": "ATK",
	"power": 1.2,
	"acc": 0.95,
	"crit": 0.05,
	"element": "earth",
	"mp_cost": 0,
	"target": "enemy_one",
	"effects": []
}

var SKILL_FIREBALL := {
	"id": "fireball",
	"name": "Fireball",
	"type": "damage",
	"stat": "FOCUS",
	"power": 2.0,
	"acc": 0.95,
	"crit": 0.05,
	"element": "fire",
	"mp_cost": 6,
	"target": "enemy_one",
	"effects": [{"apply": "burn", "duration": 3, "chance": 1.0}]
}

const POTION_HEAL_PCT := 0.30

func _ready() -> void:
	hero = Unit.new()
	hero.name = "Pyro Adept"
	hero.stats = {"HP": 90, "MP": 40, "ATK": 10, "DEF": 8, "AGI": 12, "FOCUS": 16}
	hero.max_stats = {"HP": 90, "MP": 40}
	hero.resist = {"fire": 0.5, "water": 1.5, "earth": 1.0, "air": 1.0}

	enemy = Unit.new()
	enemy.name = "Goblin"
	enemy.stats = {"HP": 70, "MP": 0, "ATK": 12, "DEF": 6, "AGI": 10, "FOCUS": 6}
	enemy.max_stats = {"HP": 70, "MP": 0}
	enemy.resist = {"fire": 1.0, "water": 1.0, "earth": 1.0, "air": 1.0}

	turn_engine = TurnEngine.new()
	add_child(turn_engine)

	btn_attack.pressed.connect(_on_attack)
	btn_fire.pressed.connect(_on_fireball)
	btn_potion.pressed.connect(_on_potion)
	btn_end.pressed.connect(_on_end_turn)

	_log("Battle starts! Pyro Adept vs Goblin")
	_update_ui()
	_update_turn_order([])

func _on_attack() -> void:
	_queue_hero_action(SKILL_SLASH)

func _on_fireball() -> void:
	var cost := int(SKILL_FIREBALL.get("mp_cost", 0))
	if int(hero.stats.get("MP", 0)) >= cost:
		_queue_hero_action(SKILL_FIREBALL)
	else:
		_log("Not enough MP for Fireball!")

func _on_potion() -> void:
	if potion_used:
		_log("The potion bottle is empty.")
		return
	var current_hp: int = int(hero.stats.get("HP", 0))
	var max_hp: int = int(hero.max_stats.get("HP", current_hp))
	if current_hp >= max_hp:
		_log("HP is already full!")
		return
	var heal_amount := int(ceil(max_hp * POTION_HEAL_PCT))
	var restored := hero.heal(heal_amount)
	potion_used = true
	btn_potion.disabled = true
	_log("Hero uses Potion and heals %d HP." % restored)
	_update_ui()

func _queue_hero_action(skill: Dictionary) -> void:
	planned_actions.clear()
	planned_actions.append(Action.new(hero, skill, enemy))
	_log("Planned: %s" % skill.get("name", "Action"))

func _on_end_turn() -> void:
	if !hero.is_alive() or !enemy.is_alive():
		return
	if planned_actions.is_empty():
		planned_actions.append(Action.new(hero, SKILL_SLASH, enemy))

	var enemy_action := Action.new(enemy, SKILL_SLASH, hero)
	var actions: Array = planned_actions.duplicate()
	actions.append(enemy_action)
	actions = turn_engine.build_queue(actions)
	_update_turn_order(actions)

	for a in actions:
		if a.actor == hero:
			var mp_cost := int(a.skill.get("mp_cost", 0))
			if mp_cost > 0:
				hero.spend_mp(mp_cost)

	for a in actions:
		if !a.actor.is_alive() or !a.target.is_alive():
			continue
		var tag := Formula.element_tag(a.actor, a.target, a.skill)
		var result := turn_engine.execute(a)
		if result.get("hit", false):
			var crit_text := " CRIT!" if result.get("crit", false) else ""
			_log("%s uses %s for %d %s%s" % [a.actor.name, a.skill.get("name", "Skill"), result.get("damage", 0), tag, crit_text])
			for status_line in result.get("status_logs", []):
				_log(status_line)
		else:
			_log("%s uses %s — Miss!" % [a.actor.name, a.skill.get("name", "Skill")])

	var tick_logs := turn_engine.end_of_round_tick([hero, enemy])
	for line in tick_logs:
		_log(line)

	planned_actions.clear()
	_check_end()
	_update_ui()
	_update_turn_order([])

func _check_end() -> void:
	if !enemy.is_alive():
		_log("Victory! Goblin is defeated.")
		_disable_inputs()
	elif !hero.is_alive():
		_log("Defeat… The hero falls.")
		_disable_inputs()

func _disable_inputs() -> void:
	btn_attack.disabled = true
	btn_fire.disabled = true
	btn_potion.disabled = true
	btn_end.disabled = true

func _update_ui() -> void:
	lbl_hero.text = "Hero: %s  HP %d/%d  MP %d/%d" % [
		hero.name,
		hero.stats.get("HP", 0),
		hero.max_stats.get("HP", 0),
		hero.stats.get("MP", 0),
		hero.max_stats.get("MP", 0)
	]
	lbl_enemy.text = "Enemy: %s  HP %d/%d" % [
		enemy.name,
		enemy.stats.get("HP", 0),
		enemy.max_stats.get("HP", 0)
	]

func _log(msg: String) -> void:
	log_view.append_text(msg + "\n")
	log_view.scroll_following = true
	print(msg)

func _update_turn_order(actions: Array) -> void:
	if actions.is_empty():
		lbl_queue.text = "Turn order: --"
		return
	var parts: Array[String] = []
	for item in actions:
		var act := item as Action
		if act == null:
			continue
		var actor_name := act.actor.name if act.actor != null else "?"
		var skill_name := String(act.skill.get("name", "Action"))
		parts.append("%s (%s)" % [actor_name, skill_name])
	lbl_queue.text = "Turn order: " + " → ".join(parts)
