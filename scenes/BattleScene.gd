extends Node2D

# POLISHED BATTLE SCENE - TARGET SELECTION SYSTEM v2.0
# ✅ Foolproof error handling
# ✅ Clear visual feedback
# ✅ Smooth turn transitions
# ✅ Button state management

# --- CONFIGURATION ---
var keyboard_end_turn_enabled := true

# --- ART ASSETS MAPPING ---
const CHARACTER_ART := {
	"barbarian": "barbarian",
	"cleric_blue": "cleric_blue",
	"mage_red": "mage_red",
	"werewolf": "werewolf",
}

# --- PRELOAD SCRIPT CLASSES ---
const EnemyAIScript = preload("res://battle/EnemyAI.gd")
const AnimatedFramesScript = preload("res://scripts/AnimatedFrames.gd")
const SelectorArrowScript = preload("res://scripts/SelectorArrow.gd")
const PortraitLoaderScript = preload("res://scripts/PortraitLoader.gd")

# --- CONSTANTS ---
const BATTLE_SCENE_PATH = "res://scenes/BattleScene.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/Main.tscn"
const EQUIPMENT_SCENE_PATH = "res://scenes/Equipment.tscn"

# --- UI NODE REFERENCES ---
@onready var hero_info_container: HBoxContainer = get_node_or_null("UI/HUD/TopRightAnchor/PartyPanel/PartyMargin/PartyHBox")
@onready var enemy_info_container: HBoxContainer = get_node_or_null("UI/HUD/TopLeftAnchor/EnemyPanel/EnemyMargin/EnemyHBox")
@onready var active_portrait: TextureRect = get_node_or_null("UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActivePortrait")
@onready var active_hp_label: Label = get_node_or_null("UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveHPLabel")
@onready var active_hp_bar: ProgressBar = get_node_or_null("UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveHPBar")
@onready var active_mp_label: Label = get_node_or_null("UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveMPLabel")
@onready var active_mp_bar: ProgressBar = get_node_or_null("UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveMPBar")

# Bottom HUD - Action Panel
@onready var btn_attack: Button = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Attack")
@onready var btn_spells: Button = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Spells")
@onready var btn_items: Button = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Items")
@onready var btn_defend: Button = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Defend")
@onready var spell_bubble: PanelContainer = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/SpellBubble")
@onready var item_bubble: PanelContainer = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/ItemBubble")

# Stage
@onready var hero_sprite_placeholder: Sprite2D = get_node_or_null("Stage/HeroSprite")
@onready var enemy_sprite_placeholder: Sprite2D = get_node_or_null("Stage/EnemySprite")
@onready var hero_shadow: Sprite2D = get_node_or_null("Stage/HeroShadow")
@onready var enemy_shadow: Sprite2D = get_node_or_null("Stage/EnemyShadow")

# FX / Overlay
@onready var fx_controller: Node = get_node_or_null("FX")
@onready var popups_container: Control = get_node_or_null("FX/Popups")
@onready var overlay_fade: ColorRect = get_node_or_null("Overlay/Fade")
@onready var overlay_title: Label = get_node_or_null("Overlay/CenterContainer/VBoxContainer/Label")
@onready var overlay_subtitle: Label = get_node_or_null("Overlay/CenterContainer/VBoxContainer/Label2")
@onready var overlay_vbox: VBoxContainer = get_node_or_null("Overlay/CenterContainer/VBoxContainer")

# --- DYNAMIC UI NODES ---
var victory_buttons_container: HBoxContainer
var btn_next_battle: Button
var btn_shop: Button
var btn_return_to_main: Button
var btn_equipment: Button

# Target Selector
var target_selector: TargetSelector

# Runtime objects
var hero_sprite: AnimatedFramesScript
var enemy_sprite: AnimatedFramesScript

var heroes: Array[Unit] = []
var enemies: Array[Unit] = []
var hero_sprites: Array[AnimatedFramesScript] = []
var enemy_sprites: Array[AnimatedFramesScript] = []
var hero_shadows: Array[Sprite2D] = []
var enemy_shadows: Array[Sprite2D] = []

var planned_actions: Array[Action] = []
var enemy_ai: EnemyAIScript
var turn_engine: TurnEngine
var potion_used := false
var battle_finished := false
var current_acting_hero_index := 0
var pending_action_type := ""
var pending_skill: Dictionary = {}
var is_selecting_target := false  # NEW: Track selection state
var buttons_enabled := true  # NEW: Track button state

var skill_slash: Dictionary = {}
var skill_fireball: Dictionary = {}

const POTION_HEAL_PCT := 0.30

# Formation positions
const HERO_POSITIONS := [
	Vector2(1088, 780),
	Vector2(1216, 720),
	Vector2(1344, 660),
	Vector2(1472, 600)
]

const ENEMY_POSITIONS := [
	Vector2(448, 600),
	Vector2(576, 540)
]

const HERO_SCALE := Vector2(0.36, 0.36)
const ENEMY_SCALE := Vector2(0.36, 0.36)
const HERO_SHADOW_SCALE := Vector2(0.18, 0.09)
const ENEMY_SHADOW_SCALE := Vector2(0.18, 0.09)

var status_icon_cache: Dictionary[String, Texture2D] = {}
var sfx_streams: Dictionary[String, AudioStream] = {}

# NEW: Spell buttons for clickable spell selection
var spell_button_container: VBoxContainer = null
var item_button_container: VBoxContainer = null

func _ready() -> void:
	if !has_node("Stage"):
		print("ERROR: BattleScene missing required Stage node!")
		return
	
	# Initialize Target Selector
	target_selector = TargetSelector.new()
	$UI.add_child(target_selector)
	target_selector.target_selected.connect(_on_target_selected)
	target_selector.selection_cancelled.connect(_on_selection_cancelled)
	
	# --- Create Post-Battle UI ---
	_create_post_battle_buttons()
	
	# Connect UI buttons
	if btn_attack:
		btn_attack.pressed.connect(_on_attack)
	if btn_spells:
		btn_spells.pressed.connect(_on_spells_pressed)
	if btn_items:
		btn_items.pressed.connect(_on_items_pressed)
	if btn_defend:
		btn_defend.pressed.connect(_on_defend_pressed)
	if spell_bubble:
		spell_bubble.visible = false
		_setup_spell_bubble()
	if item_bubble:
		item_bubble.visible = false
		_setup_item_bubble()
	
	# Data
	skill_slash = _fetch_skill("slash")
	skill_fireball = _fetch_skill("fireball")
	
	# Initialize heroes
	var hero_characters := ["barbarian", "cleric_blue", "mage_red", "barbarian"]
	for i in range(min(4, hero_characters.size())):
		var hero_id: String = hero_characters[i]
		var unit: Unit = _build_unit_from_character(hero_id, i) # Pass index here
		if unit:
			if hero_characters.count(hero_id) > 1:
				unit.name = unit.name + " " + String.chr(65 + i)
			heroes.append(unit)
	
	if GameManager.current_hero_unit == null and heroes.size() > 0:
		GameManager.current_hero_unit = heroes[0]
	
	# Initialize enemies
	var enemy_types := ["werewolf", "werewolf"]
	for i in range(min(2, enemy_types.size())):
		var enemy_id: String = enemy_types[i]
		var unit: Unit = _build_unit_from_enemy(enemy_id)
		if unit:
			unit.name = unit.name + " " + String.chr(65 + i)
			enemies.append(unit)
	
	# Engine
	turn_engine = TurnEngine.new()
	add_child(turn_engine)
	enemy_ai = EnemyAIScript.new()
	
	# Hide placeholders
	if hero_sprite_placeholder:
		hero_sprite_placeholder.visible = false
	if enemy_sprite_placeholder:
		enemy_sprite_placeholder.visible = false
	if hero_shadow:
		hero_shadow.visible = false
	if enemy_shadow:
		enemy_shadow.visible = false
	
	# Create hero sprites
	for i in range(heroes.size()):
		var pos: Vector2 = HERO_POSITIONS[min(i, HERO_POSITIONS.size() - 1)]
		var hero_id: String = hero_characters[i]
		var hero_folder: String = CHARACTER_ART.get(hero_id, hero_id)
		
		var sprite := AnimatedFramesScript.new()
		sprite.character = hero_folder
		sprite.set_facing_back(false)
		sprite.centered = true
		sprite.position = pos
		sprite.scale = HERO_SCALE
		sprite.visible = true
		sprite.z_index = 60 + i
		$Stage.add_child(sprite)
		hero_sprites.append(sprite)
		await get_tree().process_frame
		
		var shadow := Sprite2D.new()
		shadow.texture = SpriteFactory.make_shadow(80, 24)
		shadow.centered = true
		shadow.position = pos + Vector2(0, 20)
		shadow.scale = HERO_SHADOW_SCALE
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.z_index = 52 + i
		$Stage.add_child(shadow)
		hero_shadows.append(shadow)
	
	# Create enemy sprites
	for i in range(enemies.size()):
		var pos: Vector2 = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
		var enemy_id: String = enemy_types[i]
		var enemy_folder: String = CHARACTER_ART.get(enemy_id, enemy_id)
		
		var sprite := AnimatedFramesScript.new()
		sprite.character = enemy_folder
		sprite.set_facing_back(false)
		sprite.centered = true
		sprite.position = pos
		sprite.scale = ENEMY_SCALE
		sprite.visible = true
		sprite.z_index = 65 + i
		$Stage.add_child(sprite)
		enemy_sprites.append(sprite)
		await get_tree().process_frame
		
		var shadow := Sprite2D.new()
		shadow.texture = SpriteFactory.make_shadow(80, 24)
		shadow.centered = true
		shadow.position = pos + Vector2(0, 20)
		shadow.scale = ENEMY_SHADOW_SCALE
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.z_index = 52 + i
		$Stage.add_child(shadow)
		enemy_shadows.append(shadow)
	
	# Compatibility
	if hero_sprites.size() > 0:
		hero_sprite = hero_sprites[0]
	if enemy_sprites.size() > 0:
		enemy_sprite = enemy_sprites[0]
	
	# FX/overlay
	if has_node("Overlay"):
		$Overlay.visible = false
	if overlay_fade:
		overlay_fade.modulate.a = 0.0
	sfx_streams = {
		"hit": _make_tone(420.0,0.14,0.35),
		"crit": _make_tone(660.0,0.2,0.4),
		"miss": _make_tone(240.0,0.16,0.3)
	}
	
	_log("=== BATTLE START ===")
	_log("%d Heroes vs %d Enemies" % [heroes.size(), enemies.size()])
	_update_ui()
	_show_turn_start()

# NEW: Create and configure the post-battle buttons programmatically.
func _create_post_battle_buttons() -> void:
	if overlay_vbox == null:
		return  # keep as-is; we'll show a fallback elsewhere when needed
	
	# Create container for victory buttons
	victory_buttons_container = HBoxContainer.new()
	victory_buttons_container.alignment = HBoxContainer.ALIGNMENT_CENTER
	victory_buttons_container.add_theme_constant_override("separation", 20)
	victory_buttons_container.visible = false # Initially hidden
	
	# Create individual buttons
	btn_next_battle = _create_styled_button("Next Battle")
	btn_shop = _create_styled_button("Shop")
	btn_equipment = _create_styled_button("Equipment")
	btn_return_to_main = _create_styled_button("Return to Main Menu")
	
	# Add victory buttons to their container
	victory_buttons_container.add_child(btn_next_battle)
	victory_buttons_container.add_child(btn_shop)
	victory_buttons_container.add_child(btn_equipment)
	
	# Add all post-battle UI to the main overlay VBox
	overlay_vbox.add_child(victory_buttons_container)
	overlay_vbox.add_child(btn_return_to_main)
	
	# Connect signals
	btn_next_battle.pressed.connect(_on_next_battle_pressed)
	btn_shop.pressed.connect(_on_shop_pressed)
	btn_equipment.pressed.connect(_on_equipment_pressed)
	btn_return_to_main.pressed.connect(_on_return_to_main_pressed)

# NEW: Helper function to create a styled button.
func _create_styled_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.visible = false # Initially hidden
	# Basic styling (can be enhanced with themes)
	btn.custom_minimum_size = Vector2(200, 50)
	# Add hover effect (example)
	btn.mouse_entered.connect(func(): btn.modulate = Color(1.2, 1.2, 1.2))
	btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
	return btn

# Check if a scene file exists
func _scene_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

# Create fallback popup menu for prototype (when no overlay exists)
func _ensure_fallback_post_battle_menu() -> void:
	if overlay_vbox != null: 
		return  # Overlay exists, use normal buttons
	if has_node("FallbackVictoryMenu"): 
		return  # Already created
	
	var pm := PopupMenu.new()
	pm.name = "FallbackVictoryMenu"
	add_child(pm)
	
	var id := 0
	pm.add_item("Next Battle", id)
	id += 1
	
	if _scene_exists("res://scenes/Shop.tscn"): 
		pm.add_item("Shop", id)
		id += 1
	
	if _scene_exists("res://scenes/EquipmentScreen.tscn"): 
		pm.add_item("Equipment", id)
		id += 1
	
	pm.add_separator()
	pm.add_item("Return to Main Menu", id)
	id += 1
	
	pm.id_pressed.connect(_on_fallback_victory_menu_id_pressed)

# Handle fallback menu selections
func _on_fallback_victory_menu_id_pressed(id: int) -> void:
	var pm := get_node("FallbackVictoryMenu") as PopupMenu
	var label := pm.get_item_text(pm.get_item_index(id))
	
	match label:
		"Next Battle":
			_on_next_battle_pressed()
		"Shop":
			_on_shop_pressed()
		"Equipment":
			_on_equipment_pressed()
		"Return to Main Menu":
			_on_return_to_main_pressed()

# NEW: Setup spell bubble with clickable buttons
func _setup_spell_bubble() -> void:
	if !spell_bubble:
		return
	
	# Find or create spell list container
	var spell_list = spell_bubble.find_child("SpellList", true, false)
	if spell_list and spell_list is VBoxContainer:
		spell_button_container = spell_list
		# Clear any existing content
		for child in spell_button_container.get_children():
			child.queue_free()

# NEW: Setup item bubble with clickable buttons
func _setup_item_bubble() -> void:
	if !item_bubble:
		return
	
	var item_list = item_bubble.find_child("ItemList", true, false)
	if item_list and item_list is VBoxContainer:
		item_button_container = item_list
		for child in item_button_container.get_children():
			child.queue_free()

# NEW: Show turn start message
func _show_turn_start() -> void:
	if current_acting_hero_index >= heroes.size() or battle_finished:
		return
	
	var current_hero: Unit = heroes[current_acting_hero_index]
	_log("\n>>> %s's Turn! <<<" % current_hero.name)
	_update_button_states()

# NEW: Update button enabled/disabled states
func _update_button_states() -> void:
	if battle_finished or is_selecting_target:
		_disable_all_buttons()
		return
	
	if current_acting_hero_index >= heroes.size():
		_disable_all_buttons()
		return
	
	var current_hero: Unit = heroes[current_acting_hero_index]
	
	# Enable all by default
	if btn_attack:
		btn_attack.disabled = false
	if btn_defend:
		btn_defend.disabled = false
	
	# Spells - disable if no MP
	if btn_spells:
		btn_spells.disabled = current_hero.stats.get("MP", 0) < 15  # Min spell cost
	
	# Items - disable if potion used
	if btn_items:
		btn_items.disabled = potion_used

# NEW: Disable all buttons
func _disable_all_buttons() -> void:
	if btn_attack:
		btn_attack.disabled = true
	if btn_spells:
		btn_spells.disabled = true
	if btn_items:
		btn_items.disabled = true
	if btn_defend:
		btn_defend.disabled = true

# NEW: Enable all buttons
func _enable_all_buttons() -> void:
	_update_button_states()

func _on_attack() -> void:
	if battle_finished or current_acting_hero_index >= heroes.size() or is_selecting_target:
		return
	
	_log("⚔️ Attack selected - choose target")
	pending_action_type = "attack"
	pending_skill = skill_slash.duplicate(true)
	_start_enemy_target_selection()

func _on_spells_pressed() -> void:
	if battle_finished or current_acting_hero_index >= heroes.size() or is_selecting_target:
		return
	
	if !spell_bubble:
		return
	
	# Toggle spell bubble
	spell_bubble.visible = !spell_bubble.visible
	
	if spell_bubble.visible:
		_populate_spell_bubble()

# NEW: Populate spell bubble with clickable spell buttons
func _populate_spell_bubble() -> void:
	if !spell_button_container or current_acting_hero_index >= heroes.size():
		return
	
	# Clear existing buttons
	for child in spell_button_container.get_children():
		child.queue_free()
	
	var current_hero: Unit = heroes[current_acting_hero_index]
	var mp: int = current_hero.stats.get("MP", 0)
	
	# --- Dynamically add buttons for all known skills ---
	# In a real game, you'd fetch these from the character's specific skill list.
	# For this test, we'll just show all the new skills we created.
	var available_skills = ["fireball", "poison_dart", "stun_bash"]
	var has_any_castable_spell = false

	for skill_id in available_skills:
		var skill_data = _fetch_skill(skill_id)
		var cost: int = int(skill_data.get("mp_cost", 0))
		
		var btn := Button.new()
		btn.text = "%s (%d MP)" % [skill_data.get("name", "Unknown"), cost]
		btn.disabled = mp < cost
		
		# Connect the button's pressed signal to a generic handler.
		# We pass the skill data directly to the handler.
		btn.pressed.connect(_on_skill_selected.bind(skill_data))
		
		spell_button_container.add_child(btn)
		
		if mp >= cost:
			has_any_castable_spell = true
	
	# Show a hint if the hero can't afford any of the spells.
	if not has_any_castable_spell:
		var hint := Label.new()
		hint.text = "Not enough MP!"
		hint.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		spell_button_container.add_child(hint)


func _on_items_pressed() -> void:
	if battle_finished or current_acting_hero_index >= heroes.size() or is_selecting_target:
		return
	
	if !item_bubble:
		return
		
	item_bubble.visible = !item_bubble.visible
	
	if item_bubble.visible:
		_populate_item_bubble()

func _populate_item_bubble() -> void:
	if !item_button_container or current_acting_hero_index >= heroes.size():
		return
		
	for child in item_button_container.get_children():
		child.queue_free()
		
	var current_hero_idx = current_acting_hero_index
	var equipment = RunManager.hero_equipment.get(current_hero_idx, {})
	var quick_items = [equipment.get("quick_item_1"), equipment.get("quick_item_2")]
	
	var has_items = false
	for item_id in quick_items:
		if item_id and !item_id.is_empty():
			var item_data = DataRegistry.items.get(item_id, {})
			var item_name = item_data.get("name", "Unknown Item")
			
			var btn := Button.new()
			btn.text = item_name
			btn.pressed.connect(_on_quick_item_selected.bind(item_id, current_hero_idx))
			item_button_container.add_child(btn)
			has_items = true
			
	if !has_items:
		var label = Label.new()
		label.text = "No quick items equipped."
		item_button_container.add_child(label)

func _on_quick_item_selected(item_id: String, hero_idx: int):
	item_bubble.visible = false
	var item_data = DataRegistry.items.get(item_id, {})
	
	# For now, assume all quick items are like potions
	_log("🧪 Using %s - select ally to heal" % item_data.get("name", "Item"))
	pending_action_type = "item"
	pending_skill = {"id": item_id, "name": item_data.get("name"), "type": "heal", "slot": "quick_item_1" if RunManager.hero_equipment[hero_idx]["quick_item_1"] == item_id else "quick_item_2"}
	_start_ally_target_selection()


func _on_defend_pressed() -> void:
	if current_acting_hero_index >= heroes.size() or is_selecting_target:
		return
	
	var current_hero: Unit = heroes[current_acting_hero_index]
	_log("🛡️ %s defends!" % current_hero.name)
	var defend_skill := {"id": "defend", "name": "Defend", "type": "defend"}
	planned_actions.append(Action.new(current_hero, defend_skill, current_hero))
	_advance_to_next_hero()

## Generic handler for when any skill button is pressed from the spell bubble.
func _on_skill_selected(skill_data: Dictionary) -> void:
	if battle_finished or current_acting_hero_index >= heroes.size():
		return

	var current_hero: Unit = heroes[current_acting_hero_index]
	var cost: int = int(skill_data.get("mp_cost", 0))

	if current_hero.stats.get("MP", 0) < cost:
		_log("❌ Not enough MP for %s!" % skill_data.get("name"))
		return

	_log("✨ %s selected - choose target" % skill_data.get("name"))
	pending_action_type = "spell"
	pending_skill = skill_data.duplicate(true)
	spell_bubble.visible = false
	_start_enemy_target_selection()


func _on_fireball_selected() -> void:
	# This function is now deprecated and replaced by _on_skill_selected.
	# We can remove it in a future cleanup pass.
	var fireball_skill = _fetch_skill("fireball")
	_on_skill_selected(fireball_skill)


func _start_enemy_target_selection() -> void:
	var alive_enemies: Array = []
	for i in range(enemies.size()):
		if enemies[i].is_alive():
			alive_enemies.append(enemy_sprites[i])
	
	if alive_enemies.is_empty():
		_log("❌ No enemies to target!")
		_enable_all_buttons()
		return
	
	is_selecting_target = true
	_disable_all_buttons()
	_log("👉 Use ← → to select, ENTER to confirm, ESC to cancel")
	target_selector.start_selection(alive_enemies)

func _start_ally_target_selection() -> void:
	var alive_heroes: Array = []
	for i in range(heroes.size()):
		if heroes[i].is_alive():
			alive_heroes.append(hero_sprites[i])
	
	if alive_heroes.is_empty():
		_log("❌ No allies to target!")
		_enable_all_buttons()
		return
	
	is_selecting_target = true
	_disable_all_buttons()
	_log("👉 Use ← → to select ally, ENTER to confirm, ESC to cancel")
	target_selector.start_selection(alive_heroes)

func _on_target_selected(target_sprite: Node2D) -> void:
	if battle_finished or current_acting_hero_index >= heroes.size():
		return
	
	is_selecting_target = false
	
	var current_hero: Unit = heroes[current_acting_hero_index]
	var target_unit: Unit = null
	
	# Find target unit
	for i in range(enemy_sprites.size()):
		if enemy_sprites[i] == target_sprite:
			target_unit = enemies[i]
			break
	
	if target_unit == null:
		for i in range(hero_sprites.size()):
			if hero_sprites[i] == target_sprite:
				target_unit = heroes[i]
				break
	
	if target_unit == null or !target_unit.is_alive():
		_log("❌ Invalid target!")
		_enable_all_buttons()
		return
	
	# Process action based on type
	if pending_action_type == "attack":
		planned_actions.append(Action.new(current_hero, pending_skill, target_unit))
		_log("✓ %s will attack %s" % [current_hero.name, target_unit.name])
		_advance_to_next_hero()
	
	elif pending_action_type == "spell":
		var mp_cost: int = int(pending_skill.get("mp_cost", 0))
		if current_hero.stats.get("MP", 0) >= mp_cost:
			planned_actions.append(Action.new(current_hero, pending_skill, target_unit))
			_log("✓ %s will cast %s on %s" % [current_hero.name, pending_skill.get("name"), target_unit.name])
			_advance_to_next_hero()
		else:
			_log("❌ Not enough MP!")
			_enable_all_buttons()
	
	elif pending_action_type == "item":
		var item_id = pending_skill.get("id")
		var item_data = DataRegistry.items.get(item_id, {})
		var heal_percent = item_data.get("power", 0.3) # Default to 30% if not specified

		var cur: int = int(target_unit.stats.get("HP",0))
		var max: int = int(target_unit.max_stats.get("HP",cur))
		if cur >= max:
			_log("❌ %s's HP is already full!" % target_unit.name)
			_enable_all_buttons()
			return
		
		var healed: int = target_unit.heal(int(ceil(max * heal_percent)))
		
		# Consume the item from the hero's quick slot
		var hero_idx = current_acting_hero_index
		var slot = pending_skill.get("slot")
		RunManager.hero_equipment[hero_idx][slot] = ""
		
		_log("✓ %s used %s on %s for %d HP!" % [current_hero.name, item_data.get("name"), target_unit.name, healed])
		_update_ui()
		_advance_to_next_hero()
	
	# Clear pending
	pending_action_type = ""
	pending_skill = {}

func _on_selection_cancelled() -> void:
	_log("❌ Selection cancelled")
	is_selecting_target = false
	pending_action_type = ""
	pending_skill = {}
	spell_bubble.visible = false
	_enable_all_buttons()

func _advance_to_next_hero() -> void:
	current_acting_hero_index += 1
	
	if current_acting_hero_index >= heroes.size():
		_log("\n=== All heroes acted - resolving turn ===")
		_on_end_turn()
	else:
		_update_ui()
		await get_tree().create_timer(0.5).timeout
		_show_turn_start()

func _on_end_turn() -> void:
	if battle_finished:
		return
	
	_disable_all_buttons()
	
	var heroes_alive := heroes.filter(func(h): return h.is_alive())
	var enemies_alive := enemies.filter(func(e): return e.is_alive())
	
	if heroes_alive.is_empty() or enemies_alive.is_empty():
		_check_end()
		return
	
	# Fill missing actions
	for i in range(heroes.size()):
		var h: Unit = heroes[i]
		if h.is_alive() and not planned_actions.any(func(a): return a.actor == h):
			var target: Unit = enemies_alive[randi() % enemies_alive.size()]
			planned_actions.append(Action.new(h, skill_slash.duplicate(true), target))
	
	# Add enemy actions
	for e in enemies:
		if e.is_alive():
			var action = enemy_ai.choose_action(e, heroes_alive)
			if action:
				planned_actions.append(action)
			else: # Fallback if AI fails
				var target: Unit = heroes_alive[randi() % heroes_alive.size()]
				planned_actions.append(Action.new(e, skill_slash.duplicate(true), target))
	
	# Execute turn
	var actions: Array = turn_engine.build_queue(planned_actions)
	
	_log("\n--- Turn Execution ---")
	for a in actions:
		if a.actor in heroes:
			var mp: int = int(a.skill.get("mp_cost", 0))
			if mp > 0:
				a.actor.spend_mp(mp)
	
	for a in actions:
		if a.actor == null or a.target == null:
			continue
		if !a.actor.is_alive() or !a.target.is_alive():
			continue
			
		_log("%s uses %s on %s" % [a.actor.name, a.skill.get("name", "an ability"), a.target.name])
		
		var res: Dictionary = turn_engine.execute_action(a)
		if res.get("hit", false):
			var dmg: int = int(res.get("damage", 0))
			var crit: bool = bool(res.get("crit", false))
			play_sfx("crit" if crit else "hit")
			var target_sprite = _sprite_for_unit(a.target)
			if target_sprite:
				spawn_damage_popup(target_sprite, dmg, crit, false)
				if target_sprite is AnimatedFramesScript:
					(target_sprite as AnimatedFramesScript).play_hit()
			
			# Log any status effects that were applied
			for status_log in res.get("status_logs", []):
				_log(status_log)
		else:
			play_sfx("miss")
			var target_sprite = _sprite_for_unit(a.target)
			if target_sprite:
				spawn_damage_popup(target_sprite, 0, false, true)
		
		await _play_attack_animation(a, res)
		_update_ui()
	
	# End of round
	var all_units: Array[Unit] = []
	all_units.append_array(heroes)
	all_units.append_array(enemies)
	for line in turn_engine.process_end_of_round(all_units):
		_log(line)
	
	planned_actions.clear()
	current_acting_hero_index = 0
	_check_end()
	_update_ui()
	
	if !battle_finished:
		await get_tree().create_timer(1.0).timeout
		_log("\n=== NEW ROUND ===")
		_show_turn_start()

func _check_end() -> void:
	if battle_finished:
		return
	
	var heroes_alive := heroes.filter(func(h): return h.is_alive())
	var enemies_alive := enemies.filter(func(e): return e.is_alive())
	
	if enemies_alive.is_empty():
		_log("\n🎉 VICTORY! All enemies defeated!")
		var gold_reward = 50 # Example gold reward
		GameManager.gold += gold_reward
		show_battle_result(true, 100, ["Goblin Ear", "Rusty Dagger"]) # Example XP and loot
		battle_finished = true
	elif heroes_alive.is_empty():
		_log("\n💀 DEFEAT... All heroes have fallen.")
		show_battle_result(false)
		battle_finished = true

func _update_ui() -> void:
	var current_hero: Unit = null
	if current_acting_hero_index < heroes.size():
		current_hero = heroes[current_acting_hero_index]
	elif heroes.size() > 0:
		current_hero = heroes[0]
	
	_update_info_panel(hero_info_container, heroes, "Hero")
	_update_info_panel(enemy_info_container, enemies, "Enemy")
	
	if current_hero:
		if active_hp_label:
			active_hp_label.text = "HP: %d/%d" % [current_hero.stats.get("HP",0), current_hero.max_stats.get("HP",0)]
		if active_mp_label:
			active_mp_label.text = "MP: %d/%d" % [current_hero.stats.get("MP",0), current_hero.max_stats.get("MP",0)]
		if active_hp_bar:
			active_hp_bar.max_value = current_hero.max_stats.get("HP",0)
			active_hp_bar.value = current_hero.stats.get("HP",0)
		if active_mp_bar:
			active_mp_bar.max_value = current_hero.max_stats.get("MP",0)
			active_mp_bar.value = current_hero.stats.get("MP",0)
		if active_portrait:
			active_portrait.texture = PortraitLoaderScript.get_portrait_for(current_hero.name)
	
	_update_sprites()

func _update_info_panel(container: HBoxContainer, unit_list: Array[Unit], label_prefix: String) -> void:
	if !container:
		return
	
	var child_count = container.get_child_count()
	
	for i in range(max(child_count, unit_list.size())):
		if i >= unit_list.size():
			if i < child_count:
				container.get_child(i).visible = false
			continue
		
		if i >= child_count:
			break
		
		var unit: Unit = unit_list[i]
		var unit_box: VBoxContainer = container.get_child(i) as VBoxContainer
		if not unit_box:
			continue
		unit_box.visible = true
		
		var name_label: Label = unit_box.get_node_or_null("HeroLabel" + str(i+1)) if label_prefix == "Hero" else unit_box.get_node_or_null("EnemyLabel" + str(i+1))
		var hp_bar: ProgressBar = unit_box.get_node_or_null("HeroHPBar" + str(i+1)) if label_prefix == "Hero" else unit_box.get_node_or_null("EnemyHPBar" + str(i+1))
		var mp_bar: ProgressBar = unit_box.get_node_or_null("HeroMPBar" + str(i+1)) if label_prefix == "Hero" else unit_box.get_node_or_null("EnemyMPBar" + str(i+1))
		
		if name_label:
			name_label.text = unit.name
		if hp_bar:
			hp_bar.max_value = unit.max_stats.get("HP", 1)
			hp_bar.value = unit.stats.get("HP", 0)
		
		if mp_bar:
			if unit.max_stats.get("MP", 0) > 0:
				mp_bar.visible = true
				mp_bar.max_value = unit.max_stats.get("MP", 1)
				mp_bar.value = unit.stats.get("MP", 0)
			else:
				mp_bar.visible = false

func _log(msg: String, color: Color = Color(1,1,1), rich := false) -> void:
	print(msg)

func _fetch_skill(id: String) -> Dictionary:
	if DataRegistry.skills.has(id):
		return DataRegistry.skills[id].duplicate(true)
	return {"id":id,"name":id.capitalize(),"type":"damage","stat":"ATK","power":1.0,"acc":0.95,"crit":0.05,"element":"earth","mp_cost":0,"effects":[]}

func _build_unit_from_character(id: String, hero_index: int) -> Unit:
	var def: Dictionary = DataRegistry.characters.get(id, {})
	if def.is_empty():
		def = {"name":"Default Hero","stats":{"max_hp":100,"max_mp":20,"atk":12,"def":8,"agi":10,"focus":10}}
	
	var u := Unit.new()
	u.character_id = id
	u.name = String(def.get("name", "Unit"))
	
	# Get stats with equipment bonuses from RunManager
	var final_stats = RunManager.get_hero_stats(hero_index)

	# Set stats and max_stats
	var max_hp: int = int(final_stats.get("max_hp", 100))
	var max_mp: int = int(final_stats.get("max_mp", 20))
	u.max_stats = {"HP": max_hp, "MP": max_mp}
	
	u.stats = {
		"HP": max_hp,
		"MP": max_mp,
		"ATK": int(final_stats.get("atk", 10)),
		"DEF": int(final_stats.get("def", 10)),
		"AGI": int(final_stats.get("agi", 10)),
		"FOCUS": int(final_stats.get("focus", 10))
	}

	var r: Dictionary = def.get("resist", {})
	u.resist = {"fire":float(r.get("fire",1.0)),"water":float(r.get("water",1.0)),"earth":float(r.get("earth",1.0)),"air":float(r.get("air",1.0))}
	
	var skill_list: Array = def.get("skills", [])
	u.skills.assign(skill_list)
	
	return u

func _build_unit_from_enemy(id: String) -> Unit:
	var def: Dictionary = DataRegistry.enemies.get(id, {})
	if def.is_empty():
		def = {"name":"Goblin","stats":{"max_hp":70,"max_mp":0,"atk":12,"def":6,"agi":10,"focus":6},"resist":{"fire":1.0,"water":1.0,"earth":1.0,"air":1.0}}
	return _build_unit(def)

func _build_unit(def: Dictionary) -> Unit:
	var u := Unit.new()
	u.name = String(def.get("name","Unit"))
	var s: Dictionary = def.get("stats", {})
	var max_hp: int = int(s.get("max_hp",80))
	var max_mp: int = int(s.get("max_mp",0))
	u.max_stats = {"HP":max_hp,"MP":max_mp}
	u.stats = {"HP":max_hp,"MP":max_mp,"ATK":int(s.get("atk",10)),"DEF":int(s.get("def",8)),"AGI":int(s.get("agi",10)),"FOCUS":int(s.get("focus",8))}
	var r: Dictionary = def.get("resist", {})
	u.resist = {"fire":float(r.get("fire",1.0)),"water":float(r.get("water",1.0)),"earth":float(r.get("earth",1.0)),"air":float(r.get("air",1.0))}
	var skill_list: Array = def.get("skills", [])
	u.skills.assign(skill_list)
	return u

func _update_sprites() -> void:
	for i in range(heroes.size()):
		if i < hero_sprites.size() and hero_sprites[i]:
			hero_sprites[i].modulate = _base_modulate_for(heroes[i])
			var pos = HERO_POSITIONS[min(i, HERO_POSITIONS.size() - 1)]
			hero_sprites[i].position = pos
			hero_sprites[i].z_index = 100 + i
			hero_sprites[i].scale = HERO_SCALE
			hero_sprites[i].set_facing_back(true)
		if i < hero_shadows.size() and hero_shadows[i]:
			hero_shadows[i].modulate = _shadow_color_for(heroes[i])
			var pos = HERO_POSITIONS[min(i, HERO_POSITIONS.size() - 1)]
			hero_shadows[i].position = pos + Vector2(0, 20)
			hero_shadows[i].z_index = 100 + i - 1
			hero_shadows[i].scale = HERO_SHADOW_SCALE
	
	for i in range(enemies.size()):
		if i < enemy_sprites.size() and enemy_sprites[i]:
			enemy_sprites[i].modulate = _base_modulate_for(enemies[i])
			var pos = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
			enemy_sprites[i].position = pos
			enemy_sprites[i].z_index = 200 + i
			enemy_sprites[i].scale = ENEMY_SCALE
			enemy_sprites[i].set_facing_back(false)
		if i < enemy_shadows.size() and enemy_shadows[i]:
			enemy_shadows[i].modulate = _shadow_color_for(enemies[i])
			var pos = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
			enemy_shadows[i].position = pos + Vector2(0, 20)
			enemy_shadows[i].z_index = 200 + i - 1
			enemy_shadows[i].scale = ENEMY_SHADOW_SCALE
	
	if hero_sprite and heroes.size() > 0:
		hero_sprite.modulate = _base_modulate_for(heroes[0])
	if enemy_sprite and enemies.size() > 0:
		enemy_sprite.modulate = _base_modulate_for(enemies[0])

func _sprite_for_unit(u: Unit) -> AnimatedFrames:
	var idx: int = heroes.find(u)
	if idx >= 0 and idx < hero_sprites.size():
		return hero_sprites[idx]
	
	idx = enemies.find(u)
	if idx >= 0 and idx < enemy_sprites.size():
		return enemy_sprites[idx]
	
	return hero_sprite if u in heroes else enemy_sprite if u in enemies else null

func _shadow_for_unit(u: Unit) -> Sprite2D:
	var idx: int = heroes.find(u)
	if idx >= 0 and idx < hero_shadows.size():
		return hero_shadows[idx]
	
	idx = enemies.find(u)
	if idx >= 0 and idx < enemy_shadows.size():
		return enemy_shadows[idx]
	
	return null

func _origin_for_unit(u: Unit) -> Vector2:
	var sprite: AnimatedFrames = _sprite_for_unit(u)
	if sprite:
		var idx: int = heroes.find(u)
		if idx >= 0 and idx < HERO_POSITIONS.size():
			return HERO_POSITIONS[idx]
		idx = enemies.find(u)
		if idx >= 0 and idx < ENEMY_POSITIONS.size():
			return ENEMY_POSITIONS[idx]
	return Vector2.ZERO

func _shadow_base_scale(u: Unit) -> Vector2:
	var shadow_sprite = _shadow_for_unit(u)
	if shadow_sprite:
		return shadow_sprite.scale
	return Vector2(0.4, 0.2)

func _attack_offset(u: Unit) -> Vector2:
	return Vector2(-50, 0) if u in heroes else Vector2(50, 0) if u in enemies else Vector2.ZERO

func _base_modulate_for(u: Unit) -> Color:
	if u==null:
		return Color.WHITE
	return Color.WHITE if u.is_alive() else Color(0.5,0.5,0.5,0.6)

func _shadow_color_for(u: Unit) -> Color:
	if u==null:
		return Color(0,0,0,0.3)
	return Color(0,0,0,0.7) if u.is_alive() else Color(0,0,0,0.3)

func _play_attack_animation(a: Action, res: Dictionary) -> void:
	var s: AnimatedFrames = _sprite_for_unit(a.actor)
	if s==null:
		return
	var sh: Sprite2D = _shadow_for_unit(a.actor)
	var o: Vector2 = _origin_for_unit(a.actor)
	var sb: Vector2 = _shadow_base_scale(a.actor)
	var dash: Vector2 = o + _attack_offset(a.actor)
	var t: Tween = create_tween()
	t.tween_property(s, "position", dash, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if sh:
		t.parallel().tween_property(sh, "scale", sb*Vector2(1.2,0.75), 0.12)
	t.tween_property(s, "position", o, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if sh:
		t.parallel().tween_property(sh, "scale", sb, 0.16)
	await t.finished
	if res.get("hit",false) and res.get("damage",0) > 0:
		await _shake_sprite(a.target)
	if res.get("hit",false):
		await _flash_sprite(a.target)

func _flash_sprite(u: Unit) -> void:
	var s: AnimatedFrames = _sprite_for_unit(u)
	if s==null:
		return
	var base: Color = _base_modulate_for(u)
	var t: Tween = create_tween()
	t.tween_property(s, "modulate", Color(1.0,0.6,0.6,1.0), 0.08)
	t.tween_property(s, "modulate", base, 0.12)
	await t.finished

func _shake_sprite(u: Unit) -> void:
	var s: AnimatedFrames = _sprite_for_unit(u)
	if s==null:
		return
	var o: Vector2 = _origin_for_unit(u)
	var off: Vector2 = Vector2(12,0)
	if u in enemies:
		off.x = -off.x
	var t: Tween = create_tween()
	t.tween_property(s, "position", o+off, 0.05)
	t.tween_property(s, "position", o-off*0.6, 0.07)
	t.tween_property(s, "position", o, 0.08)
	await t.finished

func spawn_damage_popup(node: Node2D, amount: int, crit:=false, miss:=false) -> void:
	if node==null or popups_container==null or fx_controller==null:
		return
	var p: Vector2 = node.get_global_transform_with_canvas().origin + Vector2(-8,-16)
	fx_controller.spawn_damage_number(popups_container, p, amount, crit, miss)

func play_sfx(kind: String) -> void:
	var s: AudioStream = sfx_streams.get(kind, null) as AudioStream
	if s==null:
		s = sfx_streams.get("hit", null) as AudioStream
	if s==null:
		return
	var pl: AudioStreamPlayer = get_node_or_null("SFX")
	if pl == null:
		return
	pl.stream = s
	pl.play()

func _make_tone(freq: float, duration: float, volume: float = 0.35) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 44100
	w.stereo = false
	var n: int = max(1, int(duration*w.mix_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(n*2)
	for i in range(n):
		var t: float = float(i)/w.mix_rate
		var fi: float = min(1.0, t/0.02)
		var fo: float = min(1.0, (duration-t)/0.06)
		var env: float = min(fi, fo)
		var v := int(sin(TAU*freq*t)*volume*env*32767.0)
		v = clamp(v, -32768, 32767)
		data[i*2] = v & 0xFF
		data[i*2+1] = (v>>8) & 0xFF
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return w

var battle_victory: bool = false

func show_battle_result(victory: bool, xp:=0, loot: Array[String]=[]) -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_victory = victory
	planned_actions.clear()
	
	# Disable battle UI
	_disable_all_buttons()
	keyboard_end_turn_enabled = false
	
	# If no overlay exists, show fallback popup menu
	if overlay_vbox == null:
		_ensure_fallback_post_battle_menu()
		var pm := get_node("FallbackVictoryMenu") as PopupMenu
		# Center the popup with a reasonable size
		pm.popup_centered(Vector2(300, 200))
		return
	
	if has_node("Overlay"):
		$Overlay.visible = true
	if overlay_fade:
		overlay_fade.modulate.a = 0.0
	if overlay_title:
		overlay_title.text = "Victory!" if victory else "Defeat"
	
	# Format loot text
	var loot_text: String = "—"
	if loot.size() > 0:
		var names: PackedStringArray = PackedStringArray()
		for e in loot:
			names.append(str(e))
		loot_text = ", ".join(names)
	
	if overlay_subtitle:
		overlay_subtitle.text = ("XP +%d\nLoot: %s" % [xp, loot_text]) if victory else "You fall in battle."
	
	var t: Tween = create_tween()
	if overlay_fade:
		t.tween_property(overlay_fade, "modulate:a", 0.6, 0.4)
	t.tween_interval(0.1)
	t.finished.connect(_on_battle_result_shown)

func _on_battle_result_shown() -> void:
	if overlay_vbox == null:
		return  # Fallback menu is already shown
	
	# Hide all post-battle buttons first
	if victory_buttons_container:
		victory_buttons_container.visible = false
	if btn_next_battle:
		btn_next_battle.visible = false
	if btn_shop:
		btn_shop.visible = false
	if btn_equipment:
		btn_equipment.visible = false
	if btn_return_to_main:
		btn_return_to_main.visible = false
	
	# Show appropriate buttons based on victory/defeat
	if battle_victory:
		if victory_buttons_container:
			victory_buttons_container.visible = true
		if btn_next_battle:
			btn_next_battle.visible = true
		if btn_shop:
			btn_shop.visible = true
		if btn_equipment:
			btn_equipment.visible = true
	else:
		if btn_return_to_main:
			btn_return_to_main.visible = true

# NEW: Button handlers for post-battle choices
func _on_next_battle_pressed() -> void:
	# Disable all buttons to prevent double-clicks
	if btn_next_battle: 
		btn_next_battle.disabled = true
	if btn_shop: 
		btn_shop.disabled = true
	if btn_equipment: 
		btn_equipment.disabled = true
	
	# Always reload battle scene
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _on_shop_pressed() -> void:
	# Disable all buttons to prevent double-clicks
	if btn_next_battle: 
		btn_next_battle.disabled = true
	if btn_shop: 
		btn_shop.disabled = true
	if btn_equipment: 
		btn_equipment.disabled = true
	
	# Try to open shop; fall back to next battle if missing
	if _scene_exists("res://scenes/Shop.tscn"):
		get_tree().change_scene_to_file("res://scenes/Shop.tscn")
	else:
		push_warning("Shop scene missing; starting next battle instead.")
		_on_next_battle_pressed()

func _on_equipment_pressed() -> void:
	# Disable all buttons to prevent double-clicks
	if btn_next_battle: 
		btn_next_battle.disabled = true
	if btn_shop: 
		btn_shop.disabled = true
	if btn_equipment: 
		btn_equipment.disabled = true
	
	# Try to open equipment screen; fall back to next battle if missing
	if _scene_exists("res://scenes/EquipmentScreen.tscn"):
		get_tree().change_scene_to_file("res://scenes/EquipmentScreen.tscn")
	else:
		push_warning("Equipment screen missing; starting next battle instead.")
		_on_next_battle_pressed()

func _on_return_to_main_pressed() -> void:
	# Disable all buttons
	if btn_next_battle: 
		btn_next_battle.disabled = true
	if btn_shop: 
		btn_shop.disabled = true
	if btn_equipment: 
		btn_equipment.disabled = true
	if btn_return_to_main:
		btn_return_to_main.disabled = true
	
	# Return to main menu (adjust path if needed)
	if _scene_exists("res://scenes/Main.tscn"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		push_warning("Main menu scene missing; restarting battle instead.")
		_on_next_battle_pressed()
