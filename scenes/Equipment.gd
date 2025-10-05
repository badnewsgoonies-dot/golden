extends Control

@onready var inventory_list = $VBoxContainer/HSplitContainer/InventoryPanel/VBoxContainer/ItemList
@onready var hero_grid = $VBoxContainer/HSplitContainer/PartyPanel/VBoxContainer/HeroGrid

var heroes = []

func _ready():
	# In a real game, you'd get this from a GameManager or similar
	var hero_characters = ["barbarian", "cleric_blue", "mage_red", "barbarian"]
	for i in range(hero_characters.size()):
		var hero_id = hero_characters[i]
		var unit_def = DataRegistry.characters.get(hero_id, {}).duplicate(true)
		unit_def["id"] = hero_id
		var unit = Unit._make_unit_from_def(unit_def)
		if hero_characters.count(hero_id) > 1:
			unit.name += " " + String.chr(65 + i)
		
		heroes.append(unit)

	_build_heroes()
	populate_inventory()
	populate_hero_equipment()

func _build_heroes():
	var party_ids = DataRegistry.get_party_member_ids()
	for i in range(party_ids.size()):
		var hero_id = party_ids[i]
		var hero_def = DataRegistry.characters.get(hero_id, {})
		
		# Calculate bonus stats from equipment
		var equipment_stats = {}
		var equipment = RunManager.hero_equipment.get(i, {})
		for slot in equipment:
			var item_id = equipment[slot]
			if item_id and !item_id.is_empty():
				var item_data = DataRegistry.items.get(item_id, {})
				if item_data.has("stats"):
					for stat_name in item_data["stats"]:
						equipment_stats[stat_name] = equipment_stats.get(stat_name, 0) + item_data["stats"][stat_name]

		var hero_unit = Unit._make_unit_from_def(hero_def, equipment_stats)
		heroes.append(hero_unit)


func populate_inventory():
	# Clear previous inventory
	for child in inventory_list.get_children():
		child.queue_free()

	for item_id in RunManager.inventory:
		var count = RunManager.inventory[item_id]
		if count <= 0: continue

		var item_data = DataRegistry.items.get(item_id, {})
		var item_name = item_data.get("name", "Unknown Item")
		
		var item_entry = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = "%s x%d" % [item_name, count]
		item_entry.add_child(name_label)
		
		var equip_button = Button.new()
		equip_button.text = "Equip"
		equip_button.pressed.connect(_on_equip_item.bind(item_id))
		item_entry.add_child(equip_button)
		
		inventory_list.add_child(item_entry)

func populate_hero_equipment():
	# Clear previous hero cards
	for child in hero_grid.get_children():
		child.queue_free()
		
	for i in range(heroes.size()):
		var hero = heroes[i]
		var hero_card = PanelContainer.new()
		var vbox = VBoxContainer.new()
		hero_card.add_child(vbox)
		
		var name_label = Label.new()
		name_label.text = hero.name
		vbox.add_child(name_label)
		
		# Recalculate stats based on equipment
		var current_stats = hero.stats
		
		var stats_label = Label.new()
		stats_label.text = "ATK: %d, DEF: %d" % [current_stats.ATK, current_stats.DEF]
		vbox.add_child(stats_label)
		
		var equipment = RunManager.hero_equipment[i]
			var item_name = "Empty"
			if item_id and !item_id.is_empty():
				item_name = DataRegistry.items.get(item_id, {}).get("name", "Unknown")
			
			var slot_hbox = HBoxContainer.new()
			var slot_label = Label.new()
			slot_label.text = "%s: %s" % [slot.capitalize(), item_name]
			slot_hbox.add_child(slot_label)

			if item_id and !item_id.is_empty():
				var unequip_button = Button.new()
				unequip_button.text = "X"
				unequip_button.pressed.connect(_on_unequip_item.bind(i, slot))
				slot_hbox.add_child(unequip_button)

			vbox.add_child(slot_hbox)
			
		hero_grid.add_child(hero_card)

func _on_equip_item(item_id: String):
	var item_data = DataRegistry.items.get(item_id, {})
	var item_type = item_data.get("type")

	# Simple logic: equip to the first hero
	var hero_index = 0 
	var target_slot = ""

	match item_type:
		"weapon":
			target_slot = "weapon"
		"armor":
			target_slot = "armor"
		"accessory":
			target_slot = "accessory"
		"consumable":
			# Find an empty quick slot
			if RunManager.hero_equipment[hero_index]["quick_item_1"].is_empty():
				target_slot = "quick_item_1"
			else:
				target_slot = "quick_item_2"

	if target_slot.is_empty():
		print("No available slot for this item type.")
		return

	# Unequip old item if any
	var old_item_id = RunManager.hero_equipment[hero_index][target_slot]
	if !old_item_id.is_empty():
		RunManager.add_item(old_item_id, 1)

	# Equip new item
	RunManager.hero_equipment[hero_index][target_slot] = item_id
	RunManager.use_item(item_id)

	# Refresh UI
	populate_inventory()
	populate_hero_equipment()

func _on_unequip_item(hero_index: int, slot: String):
	var item_id = RunManager.hero_equipment[hero_index][slot]
	if item_id.is_empty():
		return

	# Remove from slot and add back to inventory
	RunManager.hero_equipment[hero_index][slot] = ""
	RunManager.add_item(item_id, 1)

	# Refresh UI
	populate_inventory()
	populate_hero_equipment()



func _on_return_to_victory_pressed():
	# This will be implemented later to return to the battle scene's victory screen.
	# For now, it will go back to the main menu for testing.
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
