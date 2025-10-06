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
	"goblin": "goblin",
	"water_slime": "water_slime",
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

var party: Array[Unit]
var enemies: Array[Unit]
var heroes: Array[Unit] = []  # Player party
var hero_sprites: Array[AnimatedFramesScript] = []
var enemy_sprites: Array[AnimatedFramesScript] = []
var hero_shadows: Array[Sprite2D] = []
var enemy_shadows: Array[Sprite2D] = []
var action_queue: Array[Action] = []  # For turn execution
var turn_order: Array[Unit]
var current_hero: Unit
var current_action: Action
var current_targets: Array[Unit]

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

# === Overlay & Victory UI: Self-instantiating scaffold ===

func _ensure_overlay_scaffold() -> void:
	# If polished overlay already exists, do nothing.
	if get_node_or_null("Overlay/CenterContainer/VBoxContainer"):
		return

	# Create a CanvasLayer Overlay compatible with the polished path.
	var overlay := get_node_or_null("Overlay") as CanvasLayer
	if overlay == null:
		overlay = CanvasLayer.new()
		overlay.name = "Overlay"
		overlay.layer = 100  # above gameplay
		add_child(overlay)

	# Fade layer
	var fade := overlay.get_node_or_null("Fade") as ColorRect
	if fade == null:
		fade = ColorRect.new()
		fade.name = "Fade"
		fade.color = Color(0, 0, 0, 0)  # we'll tween alpha later
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fade.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fade.anchor_left = 0; fade.anchor_top = 0; fade.anchor_right = 1; fade.anchor_bottom = 1
		overlay.add_child(fade)

	# Centered VBox for title, subtitle, and victory buttons
	var cc := overlay.get_node_or_null("CenterContainer") as CenterContainer
	if cc == null:
		cc = CenterContainer.new()
		cc.name = "CenterContainer"
		cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cc.anchor_left = 0; cc.anchor_top = 0; cc.anchor_right = 1; cc.anchor_bottom = 1
		overlay.add_child(cc)

	var vbox := cc.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
		vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
		vbox.custom_minimum_size = Vector2(400, 200)
		cc.add_child(vbox)

	# Title & subtitle labels (ensure exact names the script expects)
	if vbox.get_node_or_null("Label") == null:
		var title := Label.new()
		title.name = "Label"
		title.text = "Victory!"
		title.add_theme_font_size_override("font_size", 42)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title)

	if vbox.get_node_or_null("Label2") == null:
		var sub := Label.new()
		sub.name = "Label2"
		sub.text = "Loot & XP awarded"
		sub.add_theme_font_size_override("font_size", 18)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sub)

func _ready() -> void:
	if !has_node("Stage"):
		print("ERROR: BattleScene missing required Stage node!")
		return
	
	# Initialize Target Selector
	target_selector = TargetSelector.new()
	$UI.add_child(target_selector)
	target_selector.target_selected.connect(_on_target_selected)
	target_selector.selection_cancelled.connect(_on_selection_cancelled)
	
	# 1) Make sure an overlay exists (creates one if missing)
	_ensure_overlay_scaffold()

	# 2) Resolve references now that an overlay is guaranteed to exist
	overlay_fade = get_node_or_null("Overlay/Fade")
	overlay_title = get_node_or_null("Overlay/CenterContainer/VBoxContainer/Label")
	overlay_subtitle = get_node_or_null("Overlay/CenterContainer/VBoxContainer/Label2")
	overlay_vbox = get_node_or_null("Overlay/CenterContainer/VBoxContainer")

	# 3) Build victory buttons (idempotent; early-return if overlay_vbox is null)
	_create_post_battle_buttons()
	
	# Connect UI buttons
	if btn_attack:
		btn_attack.pressed.connect(_on_attack)
		btn_attack.visible = true
	if btn_spells:
		btn_spells.pressed.connect(_on_spells_pressed)
		btn_spells.visible = true
	if btn_items:
		btn_items.pressed.connect(_on_items_pressed)
		btn_items.visible = true
	if btn_defend:
		btn_defend.pressed.connect(_on_defend_pressed)
		btn_defend.visible = true
	
	# Ensure action panel and its containers are visible
	var action_panel = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel")
	if action_panel:
		action_panel.visible = true
		var action_vbox = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox")
		if action_vbox:
			action_vbox.visible = true
		var buttons_container = get_node_or_null("UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons")
		if buttons_container:
			buttons_container.visible = true
	
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
	var enemy_types := ["goblin", "water_slime"]
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
		return
	if victory_buttons_container:  # already built
		return
	
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_selecting_target:
			_on_selection_cancelled()
		elif spell_bubble and spell_bubble.visible:
			spell_bubble.hide()
		elif item_bubble and item_bubble.visible:
			item_bubble.hide()
	
	if keyboard_end_turn_enabled and event.is_action_pressed("ui_accept"):
		if battle_finished:
			return
		if planned_actions.size() == heroes.size():
			_execute_turn()

# --- TURN LOGIC ---
func _show_turn_start() -> void:
	_log_turn_order()
	
	var tween := create_tween()
	tween.set_parallel(false)
	
	if overlay_title:
		overlay_title.text = "Player Turn"
		overlay_title.modulate.a = 0.0
	if overlay_subtitle:
		overlay_subtitle.text = ""
		overlay_subtitle.modulate.a = 0.0
	if has_node("Overlay"):
		$Overlay.visible = true
	
	if overlay_title:
		tween.tween_property(overlay_title, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.8)
		tween.tween_property(overlay_title, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func(): 
		if has_node("Overlay"):
			$Overlay.visible = false
		_start_hero_action_phase()
	)

func _start_hero_action_phase() -> void:
	current_acting_hero_index = 0
	planned_actions.clear()
	_prompt_next_hero_action()

func _prompt_next_hero_action() -> void:
	# Clear any leftover selections
	_reset_selection_state()
	
	# Find the next available hero
	while current_acting_hero_index < heroes.size():
		current_hero = heroes[current_acting_hero_index]
		if current_hero.is_alive():
			_log("Hero %s's turn." % current_hero.name)
			_update_ui()
			_enable_action_buttons(true)
			return
		current_acting_hero_index += 1
	
	# All heroes have acted, execute the turn
	_log("All available heroes have chosen actions.")
	_execute_turn()

func _execute_turn() -> void:
	_log("--- Executing Turn ---")
	_enable_action_buttons(false)
	
	# Enemies plan their actions
	var enemy_actions: Array[Action] = []
	for enemy in enemies:
		if enemy.is_alive():
			var action: Action = enemy_ai.choose_action(enemy, heroes.filter(func(h): return h.is_alive()))
			if action:
				enemy_actions.append(action)
	
	# Combine and sort all actions
	var all_actions: Array[Action] = planned_actions + enemy_actions
	action_queue = turn_engine.build_queue(all_actions)
	
	# Execute actions sequentially
	for action in action_queue:
		if !action.actor.is_alive():
			continue # Skip dead actors
		
		_log_action(action)
		
		var source_sprite: AnimatedFramesScript = _sprite_for(action.actor)
		var target_sprite: AnimatedFramesScript = _sprite_for(action.target)
		
		# Play actor's attack animation
		if source_sprite:
			source_sprite.play_anim("attack")
			await get_tree().create_timer(0.3).timeout
		
		# Execute the action logic
		var result: Dictionary = turn_engine.execute_action(action)
		
		# Show results (damage, miss, etc.)
		if target_sprite:
			if !result.hit:
				_show_popup_on_sprite(target_sprite, "Miss", Color.WHITE)
				AudioService.play_sfx("miss")
			elif result.crit:
				_show_popup_on_sprite(target_sprite, "CRIT! %d" % result.damage, Color.YELLOW)
				target_sprite.play_anim("hurt")
				AudioService.play_sfx("crit")
			else: # HIT
				_show_popup_on_sprite(target_sprite, str(result.damage), Color.WHITE)
				target_sprite.play_anim("hurt")
				AudioService.play_sfx("hit")
		
		_update_ui()
		await get_tree().create_timer(0.8).timeout
		
		# Check for battle end after each action
		if _check_battle_over():
			return
	
	# End of round processing (status effects, etc.)
	_end_of_round_processing()
	
	# Check for battle end again after status effects
	if _check_battle_over():
		return
	
	_log("--- Turn End ---")
	_show_turn_start()

func _end_of_round_processing() -> void:
	_log("--- End of Round Status Effects ---")
	var all_units: Array[Unit] = heroes + enemies
	var logs = turn_engine.process_end_of_round(all_units)
	for log in logs:
		_log(log)
	_update_ui()
	await get_tree().create_timer(0.5).timeout

# --- BATTLE END LOGIC ---
func _check_battle_over() -> bool:
	var all_heroes_dead := true
	for hero in heroes:
		if hero.is_alive():
			all_heroes_dead = false
			break
	
	var all_enemies_dead := true
	for enemy in enemies:
		if enemy.is_alive():
			all_enemies_dead = false
			break
	
	if all_heroes_dead:
		show_battle_result(false)
		return true
	elif all_enemies_dead:
		show_battle_result(true)
		return true
	
	return false

func show_battle_result(victory: bool) -> void:
	if battle_finished:
		return
	battle_finished = true
	
	_log("Battle finished. Victory: %s" % victory)
	
	# Make sure our overlay + buttons exist even in prototype
	_ensure_overlay_scaffold()
	if victory_buttons_container == null:
		_create_post_battle_buttons()
	
	# Standard UI flow
	overlay_title.text = "Victory!" if victory else "Defeat"
	overlay_subtitle.text = "You gained 100 EXP and 50 Gold." if victory else "Your journey ends here."
	
	# Toggle which controls to show
	if overlay_vbox:
		# hide all first
		if victory_buttons_container: victory_buttons_container.visible = false
		if btn_next_battle: btn_next_battle.visible = false
		if btn_shop: btn_shop.visible = false
		if btn_equipment: btn_equipment.visible = false
		if btn_return_to_main: btn_return_to_main.visible = false

		# show relevant set
		if victory:
			if victory_buttons_container: victory_buttons_container.visible = true
			if btn_next_battle: btn_next_battle.visible = true
			if btn_shop: btn_shop.visible = true  # allowed even if scene may be missing (handler guards)
			if btn_equipment: btn_equipment.visible = true
		else:
			if btn_return_to_main: btn_return_to_main.visible = true
	
	# Fade in the overlay
	var tween := create_tween()
	if has_node("Overlay"):
		$Overlay.visible = true
	if overlay_fade:
		tween.tween_property(overlay_fade, "modulate:a", 0.7, 0.5)

	# If the polished overlay isn't present in this prototype, show a simple fallback menu
	if overlay_vbox == null:
		_ensure_fallback_post_battle_menu()
		var pm := get_node_or_null("FallbackVictoryMenu") as PopupMenu
		if pm:
			pm.popup_centered(Vector2(300, 200))
			print("[Victory] Fallback menu displayed")

# --- UI BUTTON HANDLERS ---
func _on_attack() -> void:
	if !buttons_enabled: return
	_log("Attack button pressed.")
	pending_action_type = "attack"
	pending_skill = skill_slash
	_start_target_selection(skill_slash.target_type)

func _on_spells_pressed() -> void:
	if !buttons_enabled: return
	_log("Spells button pressed.")
	if item_bubble: item_bubble.hide()
	if spell_bubble: spell_bubble.show()

func _on_items_pressed() -> void:
	if !buttons_enabled: return
	_log("Items button pressed.")
	if spell_bubble: spell_bubble.hide()
	if item_bubble: item_bubble.show()

func _on_defend_pressed() -> void:
	if !buttons_enabled: return
	_log("Defend button pressed.")
	var action := Action.new(current_hero, {"name": "Defend"}, current_hero)
	_add_planned_action(action)

func _on_spell_selected(skill: Dictionary) -> void:
	if !buttons_enabled: return
	_log("Spell selected: %s" % skill.name)
	if spell_bubble: spell_bubble.hide()
	
	if current_hero.stats.get("MP", 0) < skill.cost:
		_log("Not enough MP for %s" % skill.name)
		_show_popup_on_sprite(_sprite_for(current_hero), "Not enough MP!", Color.CYAN)
		return
	
	pending_action_type = "skill"
	pending_skill = skill
	_start_target_selection(skill.target_type)

func _on_item_selected(item_id: String) -> void:
	if !buttons_enabled: return
	_log("Item selected: %s" % item_id)
	if item_bubble: item_bubble.hide()
	
	var item_data: Dictionary = DataRegistry.items.get(item_id, {})
	if item_data.is_empty():
		_log("ERROR: Item data not found for %s" % item_id)
		return
	
	# For now, assume all items are like potions
	pending_action_type = "item"
	pending_skill = {
		"name": item_data.get("name", "Item"),
		"target_type": "ally",
		"item_id": item_id
	}
	_start_target_selection("ally")

# --- TARGET SELECTION LOGIC ---
func _start_target_selection(target_type: String) -> void:
	_log("Starting target selection for type: %s" % target_type)
	is_selecting_target = true
	_enable_action_buttons(false, false) # Keep menu buttons active
	
	var valid_targets: Array[Unit]
	var target_sprites: Array[AnimatedFramesScript]
	
	if target_type == "enemy":
		valid_targets = enemies.filter(func(u): return u.is_alive())
	elif target_type == "ally":
		valid_targets = heroes.filter(func(u): return u.is_alive())
	else: # "self" or other types
		valid_targets = [current_hero]
	
	for unit in valid_targets:
		target_sprites.append(_sprite_for(unit))
	
	if target_sprites.is_empty():
		_log("No valid targets found.")
		_reset_selection_state()
		return
	
	target_selector.start_selection(target_sprites)

func _unit_for_sprite(sprite_node: Node2D) -> Unit:
	# Find the unit that corresponds to this sprite
	for i in range(hero_sprites.size()):
		if hero_sprites[i] == sprite_node:
			return heroes[i]
	
	for i in range(enemy_sprites.size()):
		if enemy_sprites[i] == sprite_node:
			return enemies[i]
	
	return null

func _on_target_selected(target_sprite: Node2D) -> void:
	var target_unit: Unit = _unit_for_sprite(target_sprite)
	if !target_unit:
		_log("Target unit not found for sprite: %s" % target_sprite.name)
		_reset_selection_state()
		return

	var action := Action.new(current_hero, pending_skill, target_unit)
	_add_planned_action(action)
	_reset_selection_state()

func _on_selection_cancelled() -> void:
	if !is_selecting_target: return
	_log("Target selection cancelled.")
	_reset_selection_state()

func _reset_selection_state() -> void:
	is_selecting_target = false
	target_selector.end_selection()
	pending_action_type = ""
	pending_skill = {}
	current_targets = []
	_enable_action_buttons(true) # Re-enable main action buttons

func _add_planned_action(action: Action) -> void:
	planned_actions.append(action)
	_log("Action planned: %s by %s on %s" % [action.type, action.actor.name, action.targets[0].name])
	
	# Move to the next hero
	current_acting_hero_index += 1
	_prompt_next_hero_action()

# --- POST-BATTLE NAVIGATION ---
func _on_next_battle_pressed() -> void:
	# Disable buttons to prevent double-clicks
	if btn_next_battle: btn_next_battle.disabled = true
	if btn_shop: btn_shop.disabled = true
	if btn_equipment: btn_equipment.disabled = true
	
	print("[Victory] Starting next battle...")
	
	# Try using BATTLE_SCENE_PATH constant if it exists, otherwise use hardcoded path
	var battle_path := "res://scenes/BattleScene.tscn"
	if "BATTLE_SCENE_PATH" in self and BATTLE_SCENE_PATH:
		battle_path = BATTLE_SCENE_PATH
	
	get_tree().change_scene_to_file(battle_path)

func _on_shop_pressed() -> void:
	# Disable buttons to prevent double-clicks
	if btn_next_battle: btn_next_battle.disabled = true
	if btn_shop: btn_shop.disabled = true
	if btn_equipment: btn_equipment.disabled = true
	
	if _scene_exists("res://scenes/Shop.tscn"):
		print("[Victory] Opening shop...")
		get_tree().change_scene_to_file("res://scenes/Shop.tscn")
	else:
		push_warning("Shop scene missing; starting next battle instead.")
		print("[Victory] Shop not found, falling back to next battle")
		_on_next_battle_pressed()

func _on_equipment_pressed() -> void:
	# Disable buttons to prevent double-clicks
	if btn_next_battle: btn_next_battle.disabled = true
	if btn_shop: btn_shop.disabled = true
	if btn_equipment: btn_equipment.disabled = true
	
	if _scene_exists("res://scenes/EquipmentScreen.tscn"):
		print("[Victory] Opening equipment screen...")
		get_tree().change_scene_to_file("res://scenes/EquipmentScreen.tscn")
	else:
		push_warning("Equipment screen missing; starting next battle instead.")
		print("[Victory] Equipment not found, falling back to next battle")
		_on_next_battle_pressed()

func _on_return_to_main_pressed() -> void:
	# Disable buttons to prevent double-clicks
	if btn_next_battle: btn_next_battle.disabled = true
	if btn_shop: btn_shop.disabled = true
	if btn_equipment: btn_equipment.disabled = true
	
	if _scene_exists("res://scenes/Main.tscn"):
		print("[Victory] Returning to main menu...")
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		push_warning("Main menu missing; restarting battle instead.")
		print("[Victory] Main menu not found, falling back to next battle")
		_on_next_battle_pressed()

func _fade_to_scene(scene_path: String) -> void:
	if !ResourceLoader.exists(scene_path):
		_log("ERROR: Scene path does not exist: %s" % scene_path)
		# Optionally, show an error to the user
		if overlay_subtitle:
			overlay_subtitle.text = "Error: Next screen not found."
		return
		
	var tween := create_tween()
	if overlay_fade:
		tween.tween_property(overlay_fade, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))

# --- UI UPDATES & HELPERS ---
func _update_ui() -> void:
	if !is_instance_valid(self): return
	
	# Update hero panels
	if hero_info_container:
		for i in range(hero_info_container.get_child_count()):
			var panel: Panel = hero_info_container.get_child(i)
			if i < heroes.size():
				_update_unit_panel(panel, heroes[i])
				panel.visible = true
			else:
				panel.visible = false
	
	# Update enemy panels
	if enemy_info_container:
		for i in range(enemy_info_container.get_child_count()):
			var panel: Panel = enemy_info_container.get_child(i)
			if i < enemies.size():
				_update_unit_panel(panel, enemies[i])
				panel.visible = true
			else:
				panel.visible = false
	
	# Update active character panel
	if current_hero and current_hero.is_alive():
		if active_portrait:
			var portrait_loader = PortraitLoaderScript.new()
			var tex = portrait_loader.get_portrait_for_unit(current_hero)
			active_portrait.texture = tex
		if active_hp_label:
			active_hp_label.text = "HP: %d/%d" % [current_hero.stats.get("HP", 0), current_hero.max_stats.get("HP", 100)]
		if active_hp_bar:
			active_hp_bar.max_value = current_hero.max_stats.get("HP", 100)
			active_hp_bar.value = current_hero.stats.get("HP", 0)
		if active_mp_label:
			active_mp_label.text = "MP: %d/%d" % [current_hero.stats.get("MP", 0), current_hero.max_stats.get("MP", 50)]
		if active_mp_bar:
			active_mp_bar.max_value = current_hero.max_stats.get("MP", 50)
			active_mp_bar.value = current_hero.stats.get("MP", 0)

func _update_unit_panel(panel: Panel, unit: Unit) -> void:
	var name_label: Label = panel.get_node_or_null("Margin/VBox/NameLabel")
	var hp_bar: ProgressBar = panel.get_node_or_null("Margin/VBox/HPBar")
	var status_container: HBoxContainer = panel.get_node_or_null("Margin/VBox/StatusIcons")
	
	if name_label:
		name_label.text = unit.name
	if hp_bar:
		hp_bar.max_value = unit.max_stats.get("HP", 100)
		hp_bar.value = unit.stats.get("HP", 0)
	
	if status_container:
		# Clear old icons
		for child in status_container.get_children():
			child.queue_free()
		# Add current status icons
		for status in unit.active_statuses:
			var icon := TextureRect.new()
			icon.texture = _get_status_icon(status.id)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(24, 24)
			status_container.add_child(icon)
	
	# Dim panel if unit is dead
	panel.modulate.a = 0.5 if !unit.is_alive() else 1.0

func _enable_action_buttons(enable: bool, affect_menu_buttons: bool = true) -> void:
	buttons_enabled = enable
	
	# Make buttons visible and set their enabled state
	if btn_attack: 
		btn_attack.visible = true
		btn_attack.disabled = !enable
	if btn_defend: 
		btn_defend.visible = true
		btn_defend.disabled = !enable
	
	if affect_menu_buttons:
		if btn_spells:
			btn_spells.visible = true
			btn_spells.disabled = !enable or (current_hero and current_hero.skills.is_empty())
		if btn_items:
			btn_items.visible = true
			btn_items.disabled = !enable or RunManager.inventory.is_empty()
	
	# Hide bubbles if disabling actions
	if !enable:
		if spell_bubble: spell_bubble.hide()
		if item_bubble: item_bubble.hide()

func _setup_spell_bubble() -> void:
	if !spell_bubble: return
	# Clear previous buttons
	if spell_button_container and is_instance_valid(spell_button_container):
		spell_button_container.queue_free()
	
	spell_button_container = VBoxContainer.new()
	spell_bubble.get_node("Margin").add_child(spell_button_container)
	
	if current_hero:
		for skill_id in current_hero.skills:
			var skill_data: Dictionary = DataRegistry.get_skill(skill_id)
			if skill_data.is_empty(): continue
			
			var btn := Button.new()
			btn.text = "%s (%d MP)" % [skill_data.name, skill_data.cost]
			btn.pressed.connect(_on_spell_selected.bind(skill_data))
			spell_button_container.add_child(btn)

func _setup_item_bubble() -> void:
	if !item_bubble: return
	# Clear previous buttons
	if item_button_container and is_instance_valid(item_button_container):
		item_button_container.queue_free()
	
	item_button_container = VBoxContainer.new()
	item_bubble.get_node("Margin").add_child(item_button_container)
	
	for item_id in RunManager.inventory:
		var item_data: Dictionary = DataRegistry.items.get(item_id, {})
		if item_data.is_empty(): continue
		
		var count: int = RunManager.inventory[item_id]
		var btn := Button.new()
		btn.text = "%s (x%d)" % [item_data.name, count]
		btn.pressed.connect(_on_item_selected.bind(item_id))
		item_button_container.add_child(btn)

func _show_popup_on_sprite(sprite: AnimatedFramesScript, text: String, color: Color) -> void:
	if !is_instance_valid(sprite) or !popups_container:
		return
	
	var popup_label := Label.new()
	popup_label.text = text
	popup_label.add_theme_color_override("font_color", color)
	popup_label.add_theme_font_size_override("font_size", 48)
	popup_label.position = sprite.position - Vector2(popup_label.size.x / 2, 150)
	popups_container.add_child(popup_label)
	
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(popup_label, "position:y", popup_label.position.y - 80, 1.2).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(popup_label, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(popup_label.queue_free)

# --- DATA & OBJECT HELPERS ---
func _build_unit_from_character(id: String, index: int) -> Unit:
	var unit_def: Dictionary = DataRegistry.characters.get(id, {})
	if unit_def.is_empty():
		_log("ERROR: Character definition not found for '%s'" % id)
		return null
	
	var unit := Unit.new()
	# is_player_team property doesn't exist in Unit, we'll track this via the heroes array
	unit.character_id = id
	unit.stats = unit_def.get("stats", {})
	var skills_array = unit_def.get("skills", [])
	unit.skills.clear()
	for skill in skills_array:
		unit.skills.append(str(skill))
	unit.name = unit_def.get("name", "Hero " + str(index + 1))
	unit.max_stats = unit.stats.duplicate()
	unit.stats["HP"] = unit.stats.get("HP", 100)
	unit.stats["MP"] = unit.stats.get("MP", 50)
	return unit

func _build_unit_from_enemy(id: String) -> Unit:
	var unit_def: Dictionary = DataRegistry.enemies.get(id, {})
	if unit_def.is_empty():
		_log("ERROR: Enemy definition not found for '%s'" % id)
		return null
	
	var unit := Unit.new()
	# is_player_team property doesn't exist in Unit, we'll track this via the enemies array
	unit.character_id = id
	unit.stats = unit_def.get("stats", {})
	var skills_array = unit_def.get("skills", [])
	unit.skills.clear()
	for skill in skills_array:
		unit.skills.append(str(skill))
	unit.name = unit_def.get("name", "Enemy")
	unit.max_stats = unit.stats.duplicate()
	unit.stats["HP"] = unit.stats.get("HP", 100)
	unit.stats["MP"] = unit.stats.get("MP", 50)
	return unit

func _sprite_for(unit: Unit) -> AnimatedFramesScript:
	# Check if unit is in heroes array
	var hero_index: int = heroes.find(unit)
	if hero_index != -1 and hero_index < hero_sprites.size():
		return hero_sprites[hero_index]
	
	# Check if unit is in enemies array
	var enemy_index: int = enemies.find(unit)
	if enemy_index != -1 and enemy_index < enemy_sprites.size():
		return enemy_sprites[enemy_index]
	
	return null

func _fetch_skill(id: String) -> Dictionary:
	var skill: Dictionary = DataRegistry.get_skill(id)
	if skill.is_empty():
		_log("WARN: Skill '%s' not found in DataRegistry. Using fallback." % id)
		return {
			"id": id, "name": id.capitalize(), "cost": 0, "power": 10,
			"target_type": "enemy", "effect": ""
		}
	return skill

func _get_status_icon(status_id: String) -> Texture2D:
	if status_icon_cache.has(status_id):
		return status_icon_cache[status_id]
	
	var tex: Texture2D = load("res://art/ui/status_%s.png" % status_id)
	status_icon_cache[status_id] = tex
	return tex

# --- LOGGING & DEBUG ---
func _log(message: String) -> void:
	print("[BattleScene] " + message)

func _log_turn_order() -> void:
	var names: Array[String] = []
	for action in action_queue:
		names.append(action.actor.name)
	_log("Turn order: " + ", ".join(names))

func _log_action(action: Action) -> void:
	var target_names: Array[String] = []
	for t in action.targets:
		target_names.append(t.name)
	_log("%s uses %s on %s" % [action.actor.name, action.get_name(), ", ".join(target_names)])

# --- AUDIO FACTORY ---
func _make_tone(hz: float, duration: float, volume_db: float = 0.0) -> AudioStream:
	var sample_rate := 44100
	var num_samples := int(duration * sample_rate)
	var samples := PackedVector2Array()
	samples.resize(num_samples)
	
	var phase := 0.0
	var increment := hz / sample_rate
	var amplitude := db_to_linear(volume_db)
	
	for i in range(num_samples):
		samples[i] = Vector2.ONE * sin(phase * TAU) * amplitude
		phase = fmod(phase + increment, 1.0)
	
	var stream := AudioStreamPolyphonic.new()
	# This part is tricky; direct generation is complex.
	# For real games, use pre-made AudioStreamGenerator or load files.
	# This is a placeholder for simple feedback.
	return null
