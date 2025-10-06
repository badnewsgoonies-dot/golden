extends Control

# --- UI Node References ---
@onready var _hero_grid = $VBoxContainer/HSplitContainer/PartyPanel/VBoxContainer/HeroGrid
@onready var _item_list = $VBoxContainer/HSplitContainer/InventoryPanel/VBoxContainer/ItemList
@onready var _item_description_label = $VBoxContainer/HSplitContainer/InventoryPanel/VBoxContainer/ItemDescription
@onready var _stats_grid = $VBoxContainer/HSplitContainer/PartyPanel/VBoxContainer/StatsGrid
@onready var _equip_button = $VBoxContainer/HSplitContainer/InventoryPanel/VBoxContainer/EquipButton
@onready var _unequip_button = $VBoxContainer/HSplitContainer/InventoryPanel/VBoxContainer/UnequipButton
@onready var _close_button = $VBoxContainer/CloseButton

# --- State Variables ---
var _selected_hero_index: int = -1
var _selected_item_id: String = ""
var _selected_slot: String = "" # Used for unequipping from a specific slot

# --- Initialization ---
func _ready():
	# Clear any design-time placeholders
	for c in _hero_grid.get_children(): c.queue_free()
	for c in _stats_grid.get_children(): c.queue_free()
	_item_list.clear()

	# Populate UI
	_populate_hero_grid()
	_populate_item_list()
	
	# Connect signals
	_equip_button.pressed.connect(_on_equip_button_pressed)
	_unequip_button.pressed.connect(_on_unequip_button_pressed)
	_item_list.item_selected.connect(_on_item_list_item_selected)
	_close_button.pressed.connect(_on_close_button_pressed)
	
	# Select the first hero by default
	if _hero_grid.get_child_count() > 0:
		_on_hero_selected(0)
	
	# Initial UI state
	_item_description_label.text = "Select an item to see its details."
	_equip_button.disabled = true
	_unequip_button.disabled = true

# --- UI Population ---
func _populate_hero_grid():
	for i in range(4): # Assuming 4 heroes
		var hero_button = Button.new()
		var party_ids = DataRegistry.get_party_member_ids()
		if i >= party_ids.size(): continue
		
		var hero_id = party_ids[i]
		var hero_def = DataRegistry.characters.get(hero_id, {})
		hero_button.text = hero_def.get("name", "Hero " + str(i+1))
		hero_button.pressed.connect(_on_hero_selected.bind(i))
		_hero_grid.add_child(hero_button)

func _populate_item_list():
	_item_list.clear()
	for item_id in RunManager.inventory:
		var count = RunManager.inventory[item_id]
		if count > 0:
			var item_data = DataRegistry.items.get(item_id, {})
			var item_name = item_data.get("name", "Unknown Item")
			_item_list.add_item("%s x%d" % [item_name, count])
			_item_list.set_item_metadata(_item_list.get_item_count() - 1, item_id)

# --- UI Updates ---
func _update_character_equipment_display(hero_index: int):
	# This function is responsible for showing what the hero has equipped.
	# For now, we'll just call the stats display update.
	_update_stats_display(hero_index)

func _update_stats_display(hero_index: int):
	for c in _stats_grid.get_children():
		c.queue_free()

	if hero_index < 0: return
	
	var stats = RunManager.get_hero_stats(hero_index)
	for stat_name in ["max_hp", "atk", "def", "spd"]: # Key stats to display
		var stat_label = Label.new()
		stat_label.text = "%s: %d" % [stat_name.capitalize(), stats.get(stat_name, 0)]
		_stats_grid.add_child(stat_label)

func _update_item_description(item_id: String):
	_selected_item_id = item_id
	var item_data = DataRegistry.items.get(item_id, {})
	if item_data.is_empty():
		_item_description_label.text = "Select an item to see its details."
		_equip_button.disabled = true
		return

	var description = item_data.get("description", "No description.")
	var stats_text = ""
	if item_data.has("stats"):
		for stat_name in item_data["stats"]:
			stats_text += "\n%s: %+d" % [stat_name.capitalize(), item_data["stats"][stat_name]]
	
	_item_description_label.text = description + stats_text
	_equip_button.disabled = false
	_unequip_button.disabled = true # Unequip is handled by selecting equipped items, not from the list

# --- Helpers ---
func _get_item_id_from_list(index: int) -> String:
	if index < 0 or index >= _item_list.get_item_count():
		return ""
	return _item_list.get_item_metadata(index)

# --- Signal Handlers ---
func _on_hero_selected(hero_index: int):
	_selected_hero_index = hero_index
	_update_character_equipment_display(hero_index)
	# You could also add code here to highlight the selected hero button

func _on_item_list_item_selected(index: int):
	var item_id = _get_item_id_from_list(index)
	if item_id:
		_update_item_description(item_id)

func _on_equip_button_pressed():
	if _selected_hero_index < 0 or _selected_item_id.is_empty():
		return
	
	var item_data = DataRegistry.items.get(_selected_item_id, {})
	var slot = item_data.get("slot", "")
	if slot.is_empty():
		return
		
	# Unequip old item if any
	var old_item_id = RunManager.hero_equipment[_selected_hero_index][slot]
	if old_item_id and not old_item_id.is_empty():
		RunManager.add_item(old_item_id, 1)

	# Equip new item
	RunManager.hero_equipment[_selected_hero_index][slot] = _selected_item_id
	RunManager.use_item(_selected_item_id)
	
	# Refresh UI
	_populate_item_list()
	_update_character_equipment_display(_selected_hero_index)
	_update_item_description(_selected_item_id)
	
func _on_unequip_button_pressed():
	# This button is currently not wired to a specific slot selection,
	# so it's disabled by default. A more complex UI would be needed
	# to select an equipped item to unequip.
	if _selected_hero_index < 0 or _selected_slot.is_empty():
		return
		
	var item_to_unequip = RunManager.hero_equipment[_selected_hero_index][_selected_slot]
	
	if item_to_unequip and not item_to_unequip.is_empty():
		RunManager.hero_equipment[_selected_hero_index][_selected_slot] = ""
		RunManager.add_item(item_to_unequip, 1)
		
		_populate_item_list()
		_update_character_equipment_display(_selected_hero_index)
		
		# Clear description
		_selected_item_id = ""
		_item_description_label.text = "Select an item to see its details."
		_equip_button.disabled = true
		_unequip_button.disabled = true
			
func _on_close_button_pressed():
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
