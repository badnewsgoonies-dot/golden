extends Control

const SLOT_ORDER := ["weapon", "armor", "accessory"]
const SLOT_LABELS := {
	"weapon": "Weapon",
	"armor": "Armor",
	"accessory": "Accessory"
}

@onready var _party_list: ItemList = %PartyList
@onready var _slot_buttons := {
	"weapon": %SlotWeapon,
	"armor": %SlotArmor,
	"accessory": %SlotAccessory
}
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _inventory_list: ItemList = %InventoryList
@onready var _item_description: RichTextLabel = %ItemDescription
@onready var _equip_button: Button = %EquipButton
@onready var _unequip_button: Button = %UnequipButton
@onready var _close_button: Button = %CloseButton
@onready var _gold_label: Label = %GoldLabel

var _hero_ids: Array = []
var _selected_hero_index: int = -1
var _selected_slot: String = "weapon"
var _selected_item_id: String = ""
var _equipment_defs: Dictionary = {}

func _ready() -> void:
	_equipment_defs = _collect_equipment_defs()
	_hero_ids = DataRegistry.get_party_member_ids().duplicate()
	_prepare_hero_equipment()
	_refresh_gold_label()
	_populate_party_list()
	_connect_signals()
	_select_initial_hero()
	_refresh_inventory_list()
	_update_item_description("")
	_update_buttons_state()

func _collect_equipment_defs() -> Dictionary:
	var defs: Dictionary = {}
	for id in DataRegistry.items.keys():
		var data: Dictionary = DataRegistry.items[id]
		if data.has("slot"):
			defs[id] = data
	return defs

func _connect_signals() -> void:
	_party_list.item_selected.connect(_on_party_selected)
	_inventory_list.item_selected.connect(_on_inventory_item_selected)
	_inventory_list.item_activated.connect(_on_inventory_item_activated)
	_equip_button.pressed.connect(_on_equip_pressed)
	_unequip_button.pressed.connect(_on_unequip_pressed)
	_close_button.pressed.connect(_on_close_button_pressed)
	for slot in SLOT_ORDER:
		var btn: Button = _slot_buttons[slot]
		var capture := slot
		btn.pressed.connect(func() -> void:
			_set_selected_slot(capture, true)
		)

func _prepare_hero_equipment() -> void:
	for idx in range(_hero_ids.size()):
		_ensure_hero_equipment(idx)

func _populate_party_list() -> void:
	_party_list.clear()
	for idx in range(_hero_ids.size()):
		var hero_id: String = _hero_ids[idx]
		var hero_def: Dictionary = DataRegistry.characters.get(hero_id, {})
		var name := hero_def.get("name", hero_id.capitalize())
		var row: int = _party_list.add_item(name)
		_party_list.set_item_metadata(row, idx)

func _select_initial_hero() -> void:
	if _party_list.get_item_count() > 0:
		_party_list.select(0)
		_on_party_selected(0)

func _on_party_selected(row: int) -> void:
	if row < 0:
		_selected_hero_index = -1
		_refresh_all_for_hero()
		return

	_selected_hero_index = _party_list.get_item_metadata(row)
	_set_selected_slot(_selected_slot, true)
	_refresh_all_for_hero()

func _refresh_all_for_hero() -> void:
	_refresh_slot_buttons()
	_refresh_stats()
	_refresh_inventory_list()
	_update_buttons_state()

func _set_selected_slot(slot: String, show_equipped: bool) -> void:
	if !SLOT_LABELS.has(slot):
		slot = SLOT_ORDER[0]
	_selected_slot = slot
	for key in SLOT_ORDER:
		_slot_buttons[key].button_pressed = (key == slot)
	_refresh_inventory_list()
	if show_equipped:
		_show_equipped_item(slot)
	else:
		_update_buttons_state()

func _show_equipped_item(slot: String) -> void:
	var equipped_id := _get_equipped_item(slot)
	_selected_item_id = ""
	if equipped_id.is_empty():
		_update_item_description("")
	else:
		_update_item_description(equipped_id, true)
	_update_buttons_state()

func _on_inventory_item_selected(row: int) -> void:
	if row < 0:
		_selected_item_id = ""
		_update_item_description("")
		_update_buttons_state()
		return
	var item_id: String = _inventory_list.get_item_metadata(row)
	if item_id == null:
		return
	_selected_item_id = item_id
	var slot: String = _equipment_defs.get(item_id, {}).get("slot", _selected_slot)
	_set_selected_slot(slot, false)
	_update_item_description(item_id)
	_update_buttons_state()

func _on_inventory_item_activated(row: int) -> void:
	_on_inventory_item_selected(row)
	_on_equip_pressed()

func _refresh_slot_buttons() -> void:
	for slot in SLOT_ORDER:
		var btn: Button = _slot_buttons[slot]
		var equipped_id := _get_equipped_item(slot)
		var label := SLOT_LABELS.get(slot, slot.capitalize())
		if _selected_hero_index < 0:
			btn.text = "%s: --" % label
			btn.disabled = true
		else:
			btn.disabled = false
			var equipped_name := "--"
			if !equipped_id.is_empty():
				var item_def := _equipment_defs.get(equipped_id, DataRegistry.items.get(equipped_id, {}))
				equipped_name = item_def.get("name", equipped_id.capitalize())
			btn.text = "%s: %s" % [label, equipped_name]

func _refresh_stats() -> void:
	for child in _stats_grid.get_children():
		child.queue_free()
	if _selected_hero_index < 0:
		return
	var stats: Dictionary = RunManager.get_hero_stats(_selected_hero_index)
	var stat_order := ["max_hp", "atk", "def", "spd"]
	for stat in stat_order:
		var name_label := Label.new()
		name_label.text = "%s:" % stat.capitalize()
		_stats_grid.add_child(name_label)
		var value_label := Label.new()
		value_label.text = str(stats.get(stat, 0))
		_stats_grid.add_child(value_label)

func _refresh_inventory_list() -> void:
	_inventory_list.clear()
	_inventory_list.unselect_all()
	_selected_item_id = ""
	if _selected_hero_index < 0:
		_inventory_list.add_item("(Select a hero)")
		_inventory_list.set_item_disabled(0, true)
		return

	var slot := _selected_slot
	var added: bool = false
	for item_id in RunManager.inventory.keys():
		var count: int = RunManager.inventory[item_id]
		if count <= 0:
			continue
		if !_equipment_defs.has(item_id):
			continue
		var item_def: Dictionary = _equipment_defs[item_id]
		if item_def.get("slot", "") != slot:
			continue
		var label := "%s  x%d" % [_display_name(item_id), count]
		var row: int = _inventory_list.add_item(label)
		_inventory_list.set_item_metadata(row, item_id)
		added = true
	if !added:
		_inventory_list.add_item("(No equipment for this slot)")
		_inventory_list.set_item_disabled(_inventory_list.get_item_count() - 1, true)

func _update_item_description(item_id: String, equipped: bool = false) -> void:
	if item_id.is_empty() or !_equipment_defs.has(item_id):
		_item_description.text = "Select an item to see its details."
		return
	var data: Dictionary = _equipment_defs[item_id]
	var text := "[b]%s[/b]\n%s" % [data.get("name", item_id.capitalize()), data.get("description", "")]
	if data.has("stats"):
		for stat_name in data["stats"].keys():
			var delta := int(data["stats"][stat_name])
			var prefix := "+" if delta >= 0 else ""
			text += "\n%s %s%d" % [stat_name.capitalize(), prefix, delta]
	if equipped:
		text += "\n[italic]Currently equipped[/i]"
	_item_description.text = text

func _update_buttons_state() -> void:
	var hero_ready := _selected_hero_index >= 0
	var slot_has_item := false
	if hero_ready:
		slot_has_item = !_get_equipped_item(_selected_slot).is_empty()
	_equip_button.disabled = !hero_ready or _selected_item_id.is_empty()
	_unequip_button.disabled = !hero_ready or !slot_has_item

func _on_equip_pressed() -> void:
	if _selected_hero_index < 0 or _selected_item_id.is_empty():
		return
	if !_equipment_defs.has(_selected_item_id):
		return
	var item_def: Dictionary = _equipment_defs[_selected_item_id]
	var slot: String = item_def.get("slot", "")
	if slot.is_empty():
		return
	var hero_equipment := _ensure_hero_equipment(_selected_hero_index)
	var previous_id := hero_equipment.get(slot, "")
	if previous_id == _selected_item_id:
		return
	if !RunManager.use_item(_selected_item_id):
		return
	if !previous_id.is_empty():
		RunManager.add_item(previous_id, 1)
	hero_equipment[slot] = _selected_item_id
	_selected_item_id = ""
	_set_selected_slot(slot, true)
	_refresh_all_for_hero()
	_persist_state()

func _on_unequip_pressed() -> void:
	if _selected_hero_index < 0:
		return
	var hero_equipment := _ensure_hero_equipment(_selected_hero_index)
	var current_id := hero_equipment.get(_selected_slot, "")
	if current_id.is_empty():
		return
	hero_equipment[_selected_slot] = ""
	RunManager.add_item(current_id, 1)
	_set_selected_slot(_selected_slot, true)
	_refresh_all_for_hero()
	_persist_state()

func _persist_state() -> void:
	if SaveService.has_method("save_snapshot"):
		var snapshot := {
			"inventory": RunManager.inventory,
			"hero_equipment": RunManager.hero_equipment,
			"stage": RunManager.stage,
			"battle": RunManager.battle,
			"victories": RunManager.victories,
			"gold": GameManager.gold
		}
		SaveService.save_snapshot(snapshot)

func _ensure_hero_equipment(hero_index: int) -> Dictionary:
	if !RunManager.hero_equipment.has(hero_index):
		RunManager.hero_equipment[hero_index] = {
			"weapon": "",
			"armor": "",
			"accessory": "",
			"quick_item_1": "",
			"quick_item_2": ""
		}
	return RunManager.hero_equipment[hero_index]

func _get_equipped_item(slot: String) -> String:
	if _selected_hero_index < 0:
		return ""
	var hero_equipment := _ensure_hero_equipment(_selected_hero_index)
	return hero_equipment.get(slot, "")

func _display_name(item_id: String) -> String:
	var data: Dictionary = _equipment_defs.get(item_id, DataRegistry.items.get(item_id, {}))
	return data.get("name", item_id.capitalize())

func _refresh_gold_label() -> void:
	if is_instance_valid(GameManager):
		_gold_label.text = "Gold: %d" % GameManager.gold
	else:
		_gold_label.text = "Gold: 0"

func _on_close_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
