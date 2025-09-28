
extends Node

var stage: int = 1
var battle: int = 1
var victories: int = 0

func start_new_run(optional_seed: int = -1) -> void:
	var s: int = optional_seed if optional_seed != -1 else int(Time.get_unix_time_from_system())
	GameManager.set_seed(s)
	stage = 1
	battle = 1
	victories = 0

func register_victory() -> void:
	victories += 1
	battle += 1
	if battle % 8 == 0:
		stage += 1

func next_enemy() -> Dictionary:
	var base: Dictionary = {}
	# Guard in case DataRegistry hasn't loaded yet
	if Engine.is_editor_hint():
		pass
	if "enemies" in DataRegistry and DataRegistry.enemies.has("goblin"):
		base = DataRegistry.enemies["goblin"]
	if base.is_empty():
		base = {"name":"Goblin","max_hp":90,"atk":20,"def":6,"spd":10}
	var scale: float = 1.0 + float(victories) * 0.05
	return {
		"name": base.get("name", "Enemy"),
		"max_hp": int(ceil(base.get("max_hp", 80) * scale)),
		"hp": int(ceil(base.get("max_hp", 80) * scale)),
		"atk": int(ceil(base.get("atk", 15) * scale)),
		"def": int(ceil(base.get("def", 5) * scale)),
		"spd": int(ceil(base.get("spd", 8) * scale))
	}
