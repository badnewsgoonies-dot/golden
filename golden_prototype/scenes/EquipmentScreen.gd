extends Control

# --- PROPERTIES ---
var selected_hero_index: int = 0
var selected_slot: String = "weapon" # one of weapon|armor|accessory

# --- NODE REFERENCES ---
@onready var party_list: ItemList = $HBoxContainer/VBoxContainer/PartyList
@onready var inventory_list: ItemList = $HBoxContainer/VBoxContainer3/InventoryList
@onready var btn_slot_weapon: Button = $HBoxContainer/VBoxContainer2/SlotWeapon
@onready var btn_slot_armor: Button = $HBoxContainer/VBoxContainer2/SlotArmor
@onready var btn_slot_accessory: Button = $HBoxContainer/VBoxContainer2/SlotAccessory
@onready var btn_equip: Button = $HBoxContainer2/BtnEquip
@onready var btn_unequip: Button = $HBoxContainer2/BtnUnequip

# --- LIFECYCLE ---
func _ready() -> void:
	call_deferred("_init_ui")

func _init_ui() -> void:
	party_list.item_selected.connect(_on_party_selected)
	btn_slot_weapon.pressed.connect(func(): _set_slot("weapon"))
	btn_slot_armor.pressed.connect(func(): _set_slot("armor"))
	btn_slot_accessory.pressed.connect(func(): _set_slot("accessory"))
	btn_equip.pressed.connect(_on_equip_pressed)
	btn_unequip.pressed.connect(_on_unequip_pressed)
	_refresh_all()

# --- UI REFRESH LOGIC ---
func _refresh_all() -> void:
	_refresh_party()
	_refresh_slot_buttons()
	_refresh_inventory_list()

func _refresh_party() -> void:
	party_list.clear()
	for i in range(4):
		var hero_name = "Hero %d" % (i + 1)
		# In a real game, you'd get this from RunManager or similar
		if DataRegistry.characters.has(str(i)):
			hero_name = DataRegistry.characters[str(i)].get("name", hero_name)
		party_list.add_item(hero_name)
	if party_list.item_count > 0:
		party_list.select(selected_hero_index)


func _refresh_slot_buttons() -> void:
	var equipped_weapon = _get_current_equipped(selected_hero_index, "weapon")
	var equipped_armor = _get_current_equipped(selected_hero_index, "armor")
	var equipped_accessory = _get_current_equipped(selected_hero_index, "accessory")

	btn_slot_weapon.text = "Weapon: %s" % (DataRegistry.items.get(equipped_weapon, {}).get("name", "(empty)"))
	btn_slot_armor.text = "Armor: %s" % (DataRegistry.items.get(equipped_armor, {}).get("name", "(empty)"))
	btn_slot_accessory.text = "Accessory: %s" % (DataRegistry.items.get(equipped_accessory, {}).get("name", "(empty)"))
	
	# Highlight the selected slot
	btn_slot_weapon.disabled = (selected_slot == "weapon")
	btn_slot_armor.disabled = (selected_slot == "armor")
	btn_slot_accessory.disabled = (selected_slot == "accessory")


func _refresh_inventory_list() -> void:
	inventory_list.clear()
	var equipment_defs = _get_equipment_defs_for_slot(selected_slot)
	for item_id in equipment_defs:
		var item_def = equipment_defs[item_id]
		var count = RunManager.inventory.get(item_id, 0)
		if count > 0:
			var item_text = "%s (x%d)" % [item_def.get("name", "Unknown"), count]
			inventory_list.add_item(item_text)
			inventory_list.set_item_metadata(inventory_list.get_item_count() - 1, item_id)

# --- SIGNAL HANDLERS ---
func _on_party_selected(index: int) -> void:
	selected_hero_index = index
	_refresh_all()

func _set_slot(slot: String) -> void:
	selected_slot = slot
	_refresh_all()

func _on_equip_pressed() -> void:
	var item_id = _selected_inventory_item_id()
	if item_id.is_empty():
		return
	_equip(selected_hero_index, selected_slot, item_id)
	_refresh_slot_buttons()
	_refresh_inventory_list()

func _on_unequip_pressed() -> void:
	_unequip(selected_hero_index, selected_slot)
	_refresh_slot_buttons()
	_refresh_inventory_list()

# --- HELPERS ---
func _is_equipment_item(def: Dictionary) -> bool:
	return def.has("slot") and def.slot in ["weapon", "armor", "accessory"]

func _get_equipment_defs_for_slot(slot: String) -> Dictionary:
	var result: Dictionary = {}
	for item_id in DataRegistry.items:
		var item_def = DataRegistry.items[item_id]
		if item_def.has("slot") and item_def.get("slot") == slot:
			result[item_id] = item_def
	return result

func _get_current_equipped(hero_idx: int, slot: String) -> String:
	if RunManager.hero_equipment.has(hero_idx) and RunManager.hero_equipment[hero_idx].has(slot):
		return RunManager.hero_equipment[hero_idx][slot]
	return ""

func _equip(hero_idx: int, slot: String, item_id: String) -> void:
	if !RunManager.hero_equipment.has(hero_idx):
		RunManager.hero_equipment[hero_idx] = {}

	# Unequip current item if one exists
	var current_item = _get_current_equipped(hero_idx, slot)
	if !current_item.is_empty():
		_unequip(hero_idx, slot)

	# Equip new item
	RunManager.hero_equipment[hero_idx][slot] = item_id
	RunManager.inventory[item_id] = int(RunManager.inventory.get(item_id, 0)) - 1
	if RunManager.inventory[item_id] <= 0:
		RunManager.inventory.erase(item_id)

func _unequip(hero_idx: int, slot: String) -> void:
	var current_item = _get_current_equipped(hero_idx, slot)
	if current_item.is_empty():
		return

	RunManager.inventory[current_item] = int(RunManager.inventory.get(current_item, 0)) + 1
	RunManager.hero_equipment[hero_idx][slot] = ""

func _selected_inventory_item_id() -> String:
	var selected_indices = inventory_list.get_selected_items()
	if selected_indices.size() > 0:
		return inventory_list.get_item_metadata(selected_indices[0])
	return ""
