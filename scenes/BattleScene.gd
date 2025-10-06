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
const SelectorArrowScript = preload("res://ui/SelectorArrow.gd")
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

var party: Array[UnitScript]
var enemies: Array[UnitScript]
var turn_order: Array[UnitScript]
var current_hero: UnitScript
var current_action: Action
var current_targets: Array[UnitScript]

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
	
	pm.id_pressed.connect(_on_fallback_victory_menu_id_pressed)

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

# Check if a scene file exists
func _scene_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

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

var party: Array[UnitScript]
var enemies: Array[UnitScript]
var turn_order: Array[UnitScript]
var current_hero: UnitScript
var current_action: Action
var current_targets: Array[UnitScript]

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
	
	pm.id_pressed.connect(_on_fallback_victory_menu_id_pressed)

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

var party: Array[UnitScript]
var enemies: Array[UnitScript]
var turn_order: Array[UnitScript]
var current_hero: UnitScript
var current_action: Action
var current_targets: Array[UnitScript]

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
	
	pm.id_pressed.connect(_on_fallback_victory_menu_id_pressed)

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

var party: Array[UnitScript]
var enemies: Array[UnitScript]
var turn_order: Array[UnitScript]
var current_hero: UnitScript
var current_action: Action
var current_targets: Array[UnitScript]

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
	
	pm.id_pressed.connect(_on_fallback_victory_menu_id_pressed)

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

# Check if a scene file exists
func _scene_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

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

var party: Array[UnitScript]
var enemies: Array[UnitScript]
var turn_order: Array[UnitScript]
var current_hero: UnitScript
var current_action: Action
var current_targets: Array[UnitScript]

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
	
	pm.id_pressed.connect(_on_fallback_victory_menu_id_pressed)

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

var party: Array[UnitScript]
var enemies: Array[UnitScript]
var turn_order: Array[UnitScript]
var current_hero: UnitScript
var current_action: Action
var current_targets: Array[UnitScript]

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
	
	pm.id_pressed.connect(_on_fallback_victory_menu_id_pressed)

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

# Check if a scene file exists
func _scene_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

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

var party: Array[UnitScript]
var enemies: Array[UnitScript]
var turn_order: Array[UnitScript]
var current_hero: UnitScript
var current_action: Action
var current_targets: Array[UnitScript]

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
		var enemy_id: String = enemy_types