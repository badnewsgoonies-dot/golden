extends Node

var stage: int = 1
var battle: int = 1
var victories: int = 0
var inventory: Dictionary = {
	"potion": 3,
	"ether": 1
}
var hero_equipment: Dictionary = {
	0: {"weapon": "", "armor": "", "accessory": "", "quick_item_1": "", "quick_item_2": ""},
	1: {"weapon": "", "armor": "", "accessory": "", "quick_item_1": "", "quick_item_2": ""},
	2: {"weapon": "", "armor": "", "accessory": "", "quick_item_1": "", "quick_item_2": ""},
	3: {"weapon": "", "armor": "", "accessory": "", "quick_item_1": "", "quick_item_2": ""}
}

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

func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0

func add_item(id: String, amount: int = 1) -> void:
	if amount <= 0: return
	inventory[id] = inventory.get(id, 0) + amount

func use_item(id: String) -> bool:
	if !has_item(id): return false
	inventory[id] -= 1
	if inventory[id] <= 0:
		inventory.erase(id)
	return true

func get_hero_stats(hero_index: int) -> Dictionary:
	var hero_id = DataRegistry.get_party_member_id(hero_index)
	if !hero_id: return {}

	var base_stats = DataRegistry.characters.get(hero_id, {}).get("stats", {}).duplicate(true)
	var equipment = hero_equipment.get(hero_index, {})

	for slot in equipment:
		var item_id = equipment[slot]
		if item_id and !item_id.is_empty():
			var item_data = DataRegistry.items.get(item_id, {})
			if item_data.has("stats"):
				for stat_name in item_data["stats"]:
					base_stats[stat_name] = base_stats.get(stat_name, 0) + item_data["stats"][stat_name]
	
	return base_stats


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
