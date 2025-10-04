extends Node2D

const Action := preload("res://battle/models/Action.gd")
const Unit := preload("res://battle/models/Unit.gd")
const Formula := preload("res://battle/Formula.gd")
const TurnEngine := preload("res://battle/TurnEngine.gd")
const SpriteFactory := preload("res://art/SpriteFactory.gd")
const AnimatedFrames := preload("res://scripts/AnimatedFrames.gd")
const PortraitLoader := preload("res://scripts/PortraitLoader.gd")
# CommandMenu removed - using built-in UI
const SelectorArrow := preload("res://scripts/SelectorArrow.gd")

const CHARACTER_ART := {
	# Playable characters with proper sprite mappings
	"Pyro Adept": "hero",
	"Gale Rogue": "rogue",
	"Sunlit Cleric": "healer",
	"Cleric": "healer",
	"Iron Guard": "hero_warrior",  # Using hero_warrior sprite for guard
	"Guard": "hero_warrior",
	"Hero Warrior": "hero_warrior",
	"Crimson Mage": "mage_red",
	"Azure Cleric": "cleric_blue",
	"Armored Knight": "knight_armored",
	"Forest Archer": "archer_green",
	"Elder Wizard": "wizard_elder",
	"Fierce Barbarian": "barbarian",
	"Primal Werewolf": "werewolf",
	# Enemy mappings
	"Goblin": "werewolf",
	"Slime": "werewolf",  # Using werewolf as slime sprite fallback
	"Water Slime": "werewolf"  # Using werewolf as water slime sprite fallback
}

@export var keyboard_end_turn_enabled: bool = true

# Top HUD - Party Panel (left)
@onready var lbl_hero: Label = $UI/HUD/PartyPanel/PartyMargin/PartyVBox/HeroLabel
@onready var hero_status_container: HBoxContainer = $UI/HUD/PartyPanel/PartyMargin/PartyVBox/HeroStatus
@onready var hero_hp_bar: ProgressBar = $UI/HUD/PartyPanel/PartyMargin/PartyVBox/HeroHPBar
@onready var hero_mp_bar: ProgressBar = $UI/HUD/PartyPanel/PartyMargin/PartyVBox/HeroMPBar
@onready var hero_portrait_rect: TextureRect = $UI/HUD/PartyPanel/PartyMargin/PartyVBox/HeroPortrait

# Top HUD - Enemy Panel (right)
@onready var lbl_enemy: Label = $UI/HUD/EnemyPanel/EnemyMargin/EnemyVBox/EnemyLabel
@onready var enemy_status_container: HBoxContainer = $UI/HUD/EnemyPanel/EnemyMargin/EnemyVBox/EnemyStatus
@onready var enemy_hp_bar: ProgressBar = $UI/HUD/EnemyPanel/EnemyMargin/EnemyVBox/EnemyHPBar
@onready var enemy_portrait_rect: TextureRect = $UI/HUD/EnemyPanel/EnemyMargin/EnemyVBox/EnemyPortrait

# Bottom HUD - Active Character Panel (left)
@onready var active_portrait: TextureRect = $UI/HUD/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActivePortrait
@onready var active_hp_label: Label = $UI/HUD/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveHPLabel
@onready var active_hp_bar: ProgressBar = $UI/HUD/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveHPBar
@onready var active_mp_label: Label = $UI/HUD/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveMPLabel
@onready var active_mp_bar: ProgressBar = $UI/HUD/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveMPBar

# Bottom HUD - Action Panel (right)
@onready var btn_attack: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Attack
@onready var btn_spells: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Spells
@onready var btn_items: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Items
@onready var btn_defend: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Defend
@onready var spell_bubble: PanelContainer = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/SpellBubble
@onready var spell_list_label: Label = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/SpellBubble/SpellMargin/SpellList/SpellLabel

# Stage
@onready var hero_sprite_placeholder: Sprite2D = $Stage/HeroSprite
@onready var enemy_sprite_placeholder: Sprite2D = $Stage/EnemySprite
@onready var hero_shadow: Sprite2D = $Stage/HeroShadow
@onready var enemy_shadow: Sprite2D = $Stage/EnemyShadow

# FX / Overlay
@onready var fx_controller: Node = $FX
@onready var popups_container: Control = $FX/Popups
@onready var overlay_fade: ColorRect = $Overlay/Fade
@onready var overlay_title: Label = $Overlay/CenterContainer/VBoxContainer/Label
@onready var overlay_subtitle: Label = $Overlay/CenterContainer/VBoxContainer/Label2

# Runtime objects
var hero_sprite: AnimatedFrames
var enemy_sprite: AnimatedFrames
# command_menu removed - using built-in UI
var selector_arrow: SelectorArrow

var heroes: Array[Unit] = []  # Support for multiple heroes
var enemies: Array[Unit] = []  # Support for multiple enemies
var hero_sprites: Array[AnimatedFrames] = []  # Sprites for all heroes
var enemy_sprites: Array[AnimatedFrames] = []  # Sprites for all enemies
var hero_shadows: Array[Sprite2D] = []  # Shadows for all heroes
var enemy_shadows: Array[Sprite2D] = []  # Shadows for all enemies

var planned_actions: Array[Action] = []
var turn_engine: TurnEngine
var potion_used := false
var battle_finished := false
var selecting_target := false
var selected_enemy_index := 0
var selected_hero_index := 0  # For when selecting hero targets
var current_acting_hero_index := 0  # Which hero is currently acting
var pending_skill: Dictionary = {}

var skill_slash: Dictionary = {}
var skill_fireball: Dictionary = {}

const POTION_HEAL_PCT := 0.30

# Formation positions - moved higher to avoid UI overlap
const HERO_POSITIONS := [
	Vector2(300, 280),  # Left-back
	Vector2(250, 350),  # Left-front
	Vector2(450, 280),  # Center-back
	Vector2(400, 350)   # Center-front
]

const ENEMY_POSITIONS := [
	Vector2(850, 280),  # Right-back
	Vector2(800, 350)   # Right-front
]

var status_icon_cache: Dictionary[String, Texture2D] = {}
var sfx_streams: Dictionary[String, AudioStream] = {}

func _ready() -> void:
	# Safety check for required nodes
	if !has_node("Stage"):
		print("ERROR: BattleScene missing required Stage node!")
		return
		
	# Data
	skill_slash = _fetch_skill("slash")
	skill_fireball = _fetch_skill("fireball")
	
	# Initialize heroes - use available characters
	var hero_characters := ["adept_pyro", "gale_rogue", "cleric_blue", "knight_armored"]
	for i in range(min(4, hero_characters.size())):
		var hero_id: String = hero_characters[i]
		var unit: Unit = _build_unit_from_character(hero_id)
		if unit:
			heroes.append(unit)
		else:
			print("ERROR: Failed to create hero unit from character: %s" % hero_id)
	
	# Initialize main hero reference for compatibility
	if GameManager.current_hero_unit == null and heroes.size() > 0:
		GameManager.current_hero_unit = heroes[0]
		
	# Initialize enemies (positioned in front of heroes)
	var enemy_types := ["goblin", "water_slime"]
	for i in range(min(2, enemy_types.size())):
		var enemy_id: String = enemy_types[i]
		var unit: Unit = _build_unit_from_enemy(enemy_id)
		if unit:
			# Give them distinct names
			unit.name = unit.name + " " + String.chr(65 + i)  # A, B, C
			enemies.append(unit)
		else:
			print("ERROR: Failed to create enemy unit: %s" % enemy_id)

	# Engine
	turn_engine = TurnEngine.new()
	add_child(turn_engine)
	
	# Create selector arrow (initially hidden)
	print("DEBUG: Creating selector arrow")
	selector_arrow = SelectorArrow.new()
	# Prefer authored UI arrow asset; fallback to procedural if missing
	var ui_arrow_path := "res://Art Info/art/ui/selector_arrow.png"
	if FileAccess.file_exists(ui_arrow_path):
		selector_arrow.texture = load(ui_arrow_path)
	else:
		selector_arrow.texture = SpriteFactory.make_arrow(32, 24, Color(1.0, 1.0, 0.0))
	selector_arrow.visible = false
	selector_arrow.z_index = 1000
	selector_arrow.scale = Vector2(2.0, 2.0)
	if has_node("Stage"):
		$Stage.add_child(selector_arrow)
		print("DEBUG: Selector arrow created and added to Stage. Texture: ", selector_arrow.texture)
	else:
		print("ERROR: Stage node not found, cannot add selector arrow!")

	# Hide placeholder sprites
	if hero_sprite_placeholder:
		hero_sprite_placeholder.visible = false
	if enemy_sprite_placeholder:
		enemy_sprite_placeholder.visible = false
	if hero_shadow:
		hero_shadow.visible = false
	if enemy_shadow:
		enemy_shadow.visible = false
	
	# Create sprites for all heroes
	for i in range(heroes.size()):
		var unit: Unit = heroes[i]
		var pos: Vector2 = HERO_POSITIONS[min(i, HERO_POSITIONS.size() - 1)]
		
		# Create sprite
		var hero_folder: String = String(CHARACTER_ART.get(unit.name, unit.name.to_lower().replace(" ", "_")))
		var sprite := AnimatedFrames.new()
		sprite.centered = false
		sprite.character = hero_folder
		sprite.set_facing_back(false)  # Heroes face forward
		sprite._build_frames()
		sprite._apply_orientation()
		sprite.position = pos
		sprite.scale = Vector2(1.5, 1.5)  # Scale sprites to a reasonable size
		sprite.visible = true
		sprite.z_index = 10 + i
		$Stage.add_child(sprite)
		hero_sprites.append(sprite)
		
		# Debug logging
		print("Created hero sprite for %s using folder: %s" % [unit.name, hero_folder])
		
		# Create shadow
		var shadow := Sprite2D.new()
		shadow.texture = SpriteFactory.make_shadow(80, 24)
		shadow.centered = true
		shadow.position = pos + Vector2(24, 64)  # Adjusted for 1.5x scaled sprite
		shadow.scale = Vector2(1.2, 0.8)  # Scale shadow to match smaller sprite
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.z_index = 9
		$Stage.add_child(shadow)
		hero_shadows.append(shadow)
	
	# Create sprites for all enemies
	for i in range(enemies.size()):
		var unit: Unit = enemies[i]
		var pos: Vector2 = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
		
		# Create sprite
		var enemy_folder: String = String(CHARACTER_ART.get(unit.name.split(" ")[0], unit.name.split(" ")[0].to_lower()))
		var sprite := AnimatedFrames.new()
		sprite.centered = false
		sprite.character = enemy_folder
		sprite.set_facing_back(true)  # Enemies face back
		sprite._build_frames()
		sprite._apply_orientation()
		sprite.position = pos
		sprite.scale = Vector2(1.5, 1.5)  # Scale sprites to a reasonable size
		sprite.visible = true
		sprite.z_index = 5 + i
		$Stage.add_child(sprite)
		enemy_sprites.append(sprite)
		
		# Debug logging
		print("Created enemy sprite for %s using folder: %s" % [unit.name, enemy_folder])
		
		# Create shadow
		var shadow := Sprite2D.new()
		shadow.texture = SpriteFactory.make_shadow(80, 24)
		shadow.centered = true
		shadow.position = pos + Vector2(24, 64)  # Adjusted for 1.5x scaled sprite
		shadow.scale = Vector2(1.3, 0.8)  # Scale shadow to match smaller sprite
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.z_index = 4
		$Stage.add_child(shadow)
		enemy_shadows.append(shadow)
	
	# For compatibility, set single hero/enemy sprites
	if hero_sprites.size() > 0:
		hero_sprite = hero_sprites[0]
	if enemy_sprites.size() > 0:
		enemy_sprite = enemy_sprites[0]

	# FX/overlay
	if has_node("Overlay"):
		$Overlay.visible = false
	if overlay_fade:
		overlay_fade.modulate.a = 0.0
	sfx_streams = {"hit": _make_tone(420.0,0.14,0.35), "crit": _make_tone(660.0,0.2,0.4), "miss": _make_tone(240.0,0.16,0.3)}

	# Setup new UI buttons
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

	# Command menu removed - using built-in UI buttons

	_log("Battle starts! %d heroes vs %d enemies" % [heroes.size(), enemies.size()])
	_log("Heroes: " + ", ".join(heroes.map(func(h): return h.name)))
	_log("Enemies: " + ", ".join(enemies.map(func(e): return e.name)))
	_log("=== TARGET SELECTION SYSTEM LOADED ===")
	print("=== BATTLE SCENE WITH TARGET SELECTION LOADED ===")
	_update_ui()

func _on_spells_pressed() -> void:
	if spell_bubble:
		spell_bubble.visible = !spell_bubble.visible

func _on_items_pressed() -> void:
	if !potion_used:
		_on_potion()
	else:
		_log("The potion bottle is empty.")

func _on_defend_pressed() -> void:
	if current_acting_hero_index >= heroes.size():
		return
	var current_hero: Unit = heroes[current_acting_hero_index]
	_log("%s braces for impact (Defend)." % current_hero.name)
	# Queue defend action
	var defend_skill := {"id": "defend", "name": "Defend", "type": "defend"}
	planned_actions.append(Action.new(current_hero, defend_skill, current_hero))
	# Move to next hero
	current_acting_hero_index += 1
	if current_acting_hero_index >= heroes.size():
		_on_end_turn()
	else:
		_log("Now selecting action for %s" % heroes[current_acting_hero_index].name)
		_update_ui()

func _on_attack() -> void:
	if !battle_finished and current_acting_hero_index < heroes.size() and !selecting_target:
		pending_skill = skill_slash
		_start_target_selection()

func _on_fireball() -> void:
	if battle_finished or current_acting_hero_index >= heroes.size() or selecting_target:
		return
	var current_hero: Unit = heroes[current_acting_hero_index]
	var cost: int = int(skill_fireball.get("mp_cost", 0))
	if int(current_hero.stats.get("MP",0)) >= cost:
		pending_skill = skill_fireball
		_start_target_selection()
	else:
		_log("Not enough MP for Fireball!")

func _on_potion() -> void:
	if battle_finished or current_acting_hero_index >= heroes.size():
		return
	if potion_used:
		_log("The potion bottle is empty.")
		return
	var current_hero: Unit = heroes[current_acting_hero_index]
	var cur: int = int(current_hero.stats.get("HP",0))
	var max: int = int(current_hero.max_stats.get("HP",cur))
	if cur >= max:
		_log("HP is already full!")
		return
	var healed: int = current_hero.heal(int(ceil(max * POTION_HEAL_PCT)))
	potion_used = true
	_log("%s uses Potion and heals %d HP." % [current_hero.name, healed])
	_update_ui()
	# Move to next hero
	current_acting_hero_index += 1
	if current_acting_hero_index >= heroes.size():
		_on_end_turn()

func _queue_hero_action(skill: Dictionary, target: Unit) -> void:
	if current_acting_hero_index >= heroes.size():
		return
	var current_hero: Unit = heroes[current_acting_hero_index]
	planned_actions.append(Action.new(current_hero, skill.duplicate(true), target))
	_log("Planned: %s uses %s on %s" % [current_hero.name, String(skill.get("name","Action")), target.name])

func _on_end_turn() -> void:
	if battle_finished:
		return
	
	# Check if any units are still alive
	var heroes_alive := heroes.filter(func(h): return h.is_alive())
	var enemies_alive := enemies.filter(func(e): return e.is_alive())
	if heroes_alive.is_empty() or enemies_alive.is_empty():
		_check_end()
		return
	
	# Fill in any missing hero actions with basic attacks
	for i in range(heroes.size()):
		var h: Unit = heroes[i]
		if h.is_alive() and not planned_actions.any(func(a): return a.actor == h):
			# Default to attacking a random enemy
			var target: Unit = enemies_alive[randi() % enemies_alive.size()]
			planned_actions.append(Action.new(h, skill_slash.duplicate(true), target))
	
	# Add enemy actions
	for e in enemies:
		if e.is_alive():
			# Enemies target random alive heroes
			var target: Unit = heroes_alive[randi() % heroes_alive.size()]
			planned_actions.append(Action.new(e, skill_slash.duplicate(true), target))
	
	# Build and execute turn queue
	var actions: Array = turn_engine.build_queue(planned_actions)
	
	# Deduct MP costs
	for a in actions:
		if a.actor in heroes:
			var mp: int = int(a.skill.get("mp_cost", 0))
			if mp > 0:
				a.actor.spend_mp(mp)
	
	# Execute actions
	for a in actions:
		if a.actor == null or a.target == null:
			print("WARNING: Action has null actor or target, skipping")
			continue
		if !a.actor.is_alive() or !a.target.is_alive():
			continue
		var res: Dictionary = turn_engine.execute(a)
		if res.get("hit", false):
			var dmg: int = int(res.get("damage", 0))
			var crit: bool = bool(res.get("crit", false))
			play_sfx("crit" if crit else "hit")
			var target_sprite = _sprite_for_unit(a.target)
			if target_sprite:
				spawn_damage_popup(target_sprite, dmg, crit, false)
				if target_sprite is AnimatedFrames:
					(target_sprite as AnimatedFrames).play_hit()
		else:
			play_sfx("miss")
			var target_sprite = _sprite_for_unit(a.target)
			if target_sprite:
				spawn_damage_popup(target_sprite, 0, false, true)
		await _play_attack_animation(a, res)
		_update_ui()
		
	# End of round
	var all_units: Array = []
	all_units.append_array(heroes)
	all_units.append_array(enemies)
	for line in turn_engine.end_of_round_tick(all_units):
		_log(line)
		
	planned_actions.clear()
	current_acting_hero_index = 0  # Reset for next round
	_check_end()
	_update_ui()

func _unhandled_input(e: InputEvent) -> void:
	if battle_finished:
		return
	
	# Handle target selection input
	if selecting_target:
		if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_up"):
			_change_target_selection(-1)
			get_viewport().set_input_as_handled()
		elif e.is_action_pressed("ui_right") or e.is_action_pressed("ui_down"):
			_change_target_selection(1)
			get_viewport().set_input_as_handled()
		elif e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_action_1"):
			_confirm_target_selection()
			get_viewport().set_input_as_handled()
		elif e.is_action_pressed("ui_cancel"):
			_cancel_target_selection()
			get_viewport().set_input_as_handled()
		return
	
	# Normal input handling when not selecting target
	if e.is_action_pressed("ui_action_1"):
		_on_attack()
	elif e.is_action_pressed("ui_action_2"):
		_on_fireball()
	elif e.is_action_pressed("ui_action_3"):
		_on_potion()
	elif e.is_action_pressed("ui_action_4") and keyboard_end_turn_enabled:
		_on_end_turn()

func _start_target_selection() -> void:
	print("DEBUG: _start_target_selection called")
	_log("[color=lime]→ Select your target! Use arrow keys, press Enter to confirm.[/color]", Color.WHITE, true)
	# Command menu handling removed - using built-in UI
	
	# Filter out dead enemies
	var alive_enemies: Array[Unit] = []
	for e in enemies:
		if e.is_alive():
			alive_enemies.append(e)
	
	print("DEBUG: Alive enemies count: ", alive_enemies.size())
	
	if alive_enemies.is_empty():
		_log("No targets available!")
		# Show built-in UI buttons instead
		return
	
	selecting_target = true
	selected_enemy_index = 0
	print("DEBUG: Target selection started. selecting_target = ", selecting_target)
	_update_selector_arrow()

func _change_target_selection(direction: int) -> void:
	if !selecting_target:
		return
	
	var alive_enemies: Array[Unit] = []
	for e in enemies:
		if e.is_alive():
			alive_enemies.append(e)
	
	if alive_enemies.is_empty():
		return
	
	selected_enemy_index = (selected_enemy_index + direction) % alive_enemies.size()
	if selected_enemy_index < 0:
		selected_enemy_index = alive_enemies.size() - 1
	
	_update_selector_arrow()

func _update_selector_arrow() -> void:
	if !selector_arrow:
		print("DEBUG: selector_arrow is null!")
		return
	
	var alive_enemies: Array[Unit] = []
	for e in enemies:
		if e.is_alive():
			alive_enemies.append(e)
	
	print("DEBUG: _update_selector_arrow - alive enemies: ", alive_enemies.size())
	
	if alive_enemies.is_empty() or selected_enemy_index >= alive_enemies.size():
		selector_arrow.visible = false
		print("DEBUG: Hiding arrow - no enemies or invalid index")
		return
	
	var target_enemy: Unit = alive_enemies[selected_enemy_index]
	var target_sprite: AnimatedFrames = _sprite_for_unit(target_enemy)
	
	print("DEBUG: Target enemy: ", target_enemy.name if target_enemy else "null")
	print("DEBUG: Target sprite: ", target_sprite)
	
	if target_sprite:
		selector_arrow.visible = true
		selector_arrow.position = target_sprite.position + Vector2(0, -80)
		print("DEBUG: Arrow positioned at: ", selector_arrow.position, " visible: ", selector_arrow.visible)
		_log("[color=yellow]Targeting: %s[/color]" % target_enemy.name, Color.WHITE, true)
	else:
		selector_arrow.visible = false
		print("DEBUG: No target sprite found - hiding arrow")

func _confirm_target_selection() -> void:
	print("DEBUG: _confirm_target_selection called, selecting_target = ", selecting_target)
	if !selecting_target:
		return
	
	var alive_enemies: Array[Unit] = []
	for e in enemies:
		if e.is_alive():
			alive_enemies.append(e)
	
	if alive_enemies.is_empty() or selected_enemy_index >= alive_enemies.size():
		print("DEBUG: No valid targets, canceling selection")
		_cancel_target_selection()
		return
	
	var target_enemy: Unit = alive_enemies[selected_enemy_index]
	print("DEBUG: Confirming target selection for: ", target_enemy.name)
	selecting_target = false
	selector_arrow.visible = false
	
	# Queue the action with the selected target
	_queue_hero_action(pending_skill, target_enemy)
	
	# Move to next hero or end turn
	current_acting_hero_index += 1
	if current_acting_hero_index >= heroes.size():
		_on_end_turn()
	else:
		_log("Now selecting action for %s" % heroes[current_acting_hero_index].name)
		_update_ui()

func _cancel_target_selection() -> void:
	selecting_target = false
	selector_arrow.visible = false
	pending_skill = {}

func _check_end() -> void:
	if battle_finished:
		return
	
	var heroes_alive := heroes.filter(func(h): return h.is_alive())
	var enemies_alive := enemies.filter(func(e): return e.is_alive())
	
	if enemies_alive.is_empty():
		_log("Victory! All enemies defeated.")
		show_battle_result(true, 0, [])
		battle_finished = true
	elif heroes_alive.is_empty():
		_log("Defeat... All heroes have fallen.")
		show_battle_result(false)
		battle_finished = true

func _update_ui() -> void:
	# Show current hero in active character panel
	var current_hero: Unit = null
	if current_acting_hero_index < heroes.size():
		current_hero = heroes[current_acting_hero_index]
	elif heroes.size() > 0:
		current_hero = heroes[0]
		
	# Update top panels - show all heroes summary
	if lbl_hero:
		var heroes_text := "Heroes: "
		for h in heroes:
			if h.is_alive():
				heroes_text += "%s (%d/%d) " % [h.name, h.stats.get("HP",0), h.max_stats.get("HP",0)]
		lbl_hero.text = heroes_text
		
	if lbl_enemy:
		var enemies_text := "Enemies: "
		for e in enemies:
			if e.is_alive():
				enemies_text += "%s (%d/%d) " % [e.name, e.stats.get("HP",0), e.max_stats.get("HP",0)]
		lbl_enemy.text = enemies_text
	
	# Update bottom-left active character panel
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
			active_portrait.texture = PortraitLoader.get_portrait_for(current_hero.name)
			
	# Update portraits with first alive hero/enemy
	var first_hero = heroes.filter(func(h): return h.is_alive()).front()
	var first_enemy = enemies.filter(func(e): return e.is_alive()).front()
	
	if hero_portrait_rect and first_hero:
		hero_portrait_rect.texture = PortraitLoader.get_portrait_for(first_hero.name)
	if enemy_portrait_rect and first_enemy:
		enemy_portrait_rect.texture = PortraitLoader.get_portrait_for(first_enemy.name)
	_update_sprites()
	refresh_status_hud()

func _log(msg: String, color: Color = Color(1,1,1), rich := false) -> void:
	# Log to console only since we removed the log view
	print(msg)

func _fetch_skill(id: String) -> Dictionary:
	if DataRegistry.skills.has(id):
		return DataRegistry.skills[id].duplicate(true)
	return {"id":id,"name":id.capitalize(),"type":"damage","stat":"ATK","power":1.0,"acc":0.95,"crit":0.05,"element":"earth","mp_cost":0,"effects":[]}

func _build_unit_from_character(id: String) -> Unit:
	var def: Dictionary = DataRegistry.characters.get(id, {})
	if def.is_empty():
		def = {"name":"Pyro Adept","stats":{"max_hp":90,"max_mp":40,"atk":10,"def":8,"agi":12,"focus":16},"resist":{"fire":0.5,"water":1.5,"earth":1.0,"air":1.0}}
	return _build_unit(def)

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
	return u

func _update_sprites() -> void:
	# Update all hero sprites
	for i in range(heroes.size()):
		if i < hero_sprites.size() and hero_sprites[i]:
			hero_sprites[i].modulate = _base_modulate_for(heroes[i])
			hero_sprites[i].position = HERO_POSITIONS[min(i, HERO_POSITIONS.size() - 1)]
			hero_sprites[i].z_index = 10 + i
			hero_sprites[i].set_facing_back(false)  # Heroes face forward
		if i < hero_shadows.size() and hero_shadows[i]:
			hero_shadows[i].modulate = _shadow_color_for(heroes[i])
			hero_shadows[i].scale = Vector2(1.2, 0.8)  # Adjusted for smaller sprites
			hero_shadows[i].z_index = 9
			
	# Update all enemy sprites
	for i in range(enemies.size()):
		if i < enemy_sprites.size() and enemy_sprites[i]:
			enemy_sprites[i].modulate = _base_modulate_for(enemies[i])
			enemy_sprites[i].position = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
			enemy_sprites[i].z_index = 5 + i
			enemy_sprites[i].set_facing_back(true)  # Enemies face back
		if i < enemy_shadows.size() and enemy_shadows[i]:
			enemy_shadows[i].modulate = _shadow_color_for(enemies[i])
			enemy_shadows[i].scale = Vector2(1.3, 0.8)  # Adjusted for smaller sprites
			enemy_shadows[i].z_index = 4
	
	# Legacy single sprite support
	if hero_sprite and heroes.size() > 0:
		hero_sprite.modulate = _base_modulate_for(heroes[0])
	if enemy_sprite and enemies.size() > 0:
		enemy_sprite.modulate = _base_modulate_for(enemies[0])

func _swap_for_animated_sprite(old_sprite: Sprite2D, character: String, facing_back: bool) -> AnimatedFrames:
	if old_sprite == null:
		return null
	var parent: Node = old_sprite.get_parent()
	var idx: int = -1
	if parent:
		idx = parent.get_children().find(old_sprite)
	var a: AnimatedFrames = AnimatedFrames.new()
	a.centered = old_sprite.centered
	a.position = old_sprite.position
	# Apply sprite scale if old sprite doesn't have custom scale
	a.scale = old_sprite.scale if old_sprite.scale != Vector2.ONE else Vector2(1.5, 1.5)
	a.z_index = old_sprite.z_index
	a.flip_h = old_sprite.flip_h
	a.character = character
	a.set_facing_back(facing_back)
	if parent:
		parent.add_child(a)
		if idx>=0:
			parent.move_child(a, idx)
	old_sprite.queue_free()
	return a

func _sprite_for_unit(u: Unit) -> AnimatedFrames:
	# Find sprite for this unit
	var idx: int = heroes.find(u)
	if idx >= 0 and idx < hero_sprites.size():
		return hero_sprites[idx]
	
	idx = enemies.find(u)
	if idx >= 0 and idx < enemy_sprites.size():
		return enemy_sprites[idx]
	
	# Fallback for compatibility
	return hero_sprite if u in heroes else enemy_sprite if u in enemies else null

func _shadow_for_unit(u: Unit) -> Sprite2D:
	# Find shadow for this unit
	var idx: int = heroes.find(u)
	if idx >= 0 and idx < hero_shadows.size():
		return hero_shadows[idx]
	
	idx = enemies.find(u)
	if idx >= 0 and idx < enemy_shadows.size():
		return enemy_shadows[idx]
		
	return null

func _origin_for_unit(u: Unit) -> Vector2:
	# Get original position for this unit
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
	return Vector2(1.2, 0.8) if u in heroes else Vector2(1.3, 0.8) if u in enemies else Vector2.ONE

func _attack_offset(u: Unit) -> Vector2:
	# Adjusted offsets for 1.5x scaled sprites
	return Vector2(135, -27) if u in heroes else Vector2(-135, -18) if u in enemies else Vector2.ZERO

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

func refresh_status_hud() -> void:
	# Show status for first alive hero/enemy
	var first_hero = heroes.filter(func(h): return h.is_alive()).front()
	var first_enemy = enemies.filter(func(e): return e.is_alive()).front()
	
	if first_hero:
		_populate_status_container(hero_status_container, first_hero)
	if first_enemy:
		_populate_status_container(enemy_status_container, first_enemy)

func _populate_status_container(container: HBoxContainer, unit: Unit) -> void:
	if container==null:
		return
	for c in container.get_children():
		c.queue_free()
	if unit==null:
		return
	var seen: Dictionary = {}
	for name in unit.get_status_types():
		var key: String = String(name).to_lower()
		if seen.has(key):
			continue
		seen[key] = true
		var r: TextureRect = TextureRect.new()
		r.texture = _get_status_icon(key)
		r.size = Vector2(18,18)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(r)

func _get_status_icon(status_name: String) -> Texture2D:
	var key: String = status_name.to_lower()
	if !status_icon_cache.has(key):
		status_icon_cache[key] = SpriteFactory.make_status_icon(key)
	return status_icon_cache[key]

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
	var pl: AudioStreamPlayer = $SFX
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

var battle_victory: bool = false  # Store victory state

func show_battle_result(victory: bool, xp:=0, loot: Array[String]=[]) -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_victory = victory  # Store the victory state
	planned_actions.clear()
	refresh_status_hud()
	$Overlay.visible = true
	overlay_fade.modulate.a = 0.0
	overlay_title.text = "Victory!" if victory else "Defeat"
	var names: PackedStringArray = PackedStringArray()
	for e in loot:
		names.append(str(e))
	var loot_text: String = "—" if names.is_empty() else ", ".join(names)
	overlay_subtitle.text = ("XP +%d\nLoot: %s" % [xp, loot_text]) if victory else "You fall in battle."
	var t: Tween = create_tween()
	t.tween_property(overlay_fade, "modulate:a", 0.6, 0.4)
	t.tween_interval(0.1)
	t.finished.connect(_on_battle_result_shown)

func _on_battle_result_shown() -> void:
	keyboard_end_turn_enabled = false
	if battle_victory and heroes.any(func(h): return h.is_alive()): # If victory and any hero alive, go to upgrade selection
		get_tree().change_scene_to_file("res://scenes/UpgradeSelection.tscn")
	else: # If defeat or all heroes dead, go back to main menu or game over screen
		get_tree().change_scene_to_file("res://scenes/Boot.tscn")
