extends Node2D

const Action := preload("res://battle/models/Action.gd")
const Unit := preload("res://battle/models/Unit.gd")
const Formula := preload("res://battle/Formula.gd")
const TurnEngine := preload("res://battle/TurnEngine.gd")
const SpriteFactory := preload("res://art/SpriteFactory.gd")
const AnimatedFrames := preload("res://scripts/AnimatedFrames.gd")
const PortraitLoader := preload("res://scripts/PortraitLoader.gd")
const CommandMenu := preload("res://ui/CommandMenu.gd")
const SelectorArrow := preload("res://scripts/SelectorArrow.gd")

const CHARACTER_ART := {
	# Playable characters with proper sprite mappings
	"Pyro Adept": "hero",
	"Gale Rogue": "rogue",
	"Sunlit Cleric": "healer",
	"Cleric": "healer",
	"Iron Guard": "hero",
	"Guard": "hero",
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
	"Slime": "slime"
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
var command_menu: CommandMenu
var selector_arrow: SelectorArrow

var hero: Unit
var enemy: Unit
var enemies: Array[Unit] = []  # Support for multiple enemies
var planned_actions: Array[Action] = []
var turn_engine: TurnEngine
var potion_used := false
var battle_finished := false
var selecting_target := false
var selected_enemy_index := 0
var pending_skill: Dictionary = {}

var skill_slash: Dictionary = {}
var skill_fireball: Dictionary = {}

const POTION_HEAL_PCT := 0.30

var hero_origin := Vector2.ZERO
var enemy_origin := Vector2.ZERO
var hero_shadow_base := Vector2.ONE
var enemy_shadow_base := Vector2.ONE
var status_icon_cache: Dictionary[String, Texture2D] = {}
var sfx_streams: Dictionary[String, AudioStream] = {}

func _ready() -> void:
	# Data
	skill_slash = _fetch_skill("slash")
	skill_fireball = _fetch_skill("fireball")
	
	if GameManager.current_hero_unit == null:
		hero = _build_unit_from_character("adept_pyro")
		GameManager.current_hero_unit = hero
	else:
		hero = GameManager.current_hero_unit
		
	enemy = _build_unit_from_enemy("goblin")
	enemies.append(enemy)  # Add the enemy to the enemies array

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
	$Stage.add_child(selector_arrow)
	print("DEBUG: Selector arrow created and added to Stage. Texture: ", selector_arrow.texture)

	# Swap to AnimatedFrames - positions swapped: enemies in back, allies in front
	var hero_pos: Vector2 = Vector2(400, 420)  # Allies in front
	var enemy_pos: Vector2 = Vector2(800, 340)  # Enemies in back
	if hero_sprite_placeholder:
		hero_pos = hero_sprite_placeholder.position
	if enemy_sprite_placeholder:
		enemy_pos = enemy_sprite_placeholder.position
	var hero_folder: String = String(CHARACTER_ART.get(hero.name, hero.name.to_lower().replace(" ", "_")))
	hero_sprite = _swap_for_animated_sprite(hero_sprite_placeholder, hero_folder, false)  # Allies face forward
	var enemy_folder: String = String(CHARACTER_ART.get(enemy.name, enemy.name.to_lower().replace(" ", "_")))
	enemy_sprite = _swap_for_animated_sprite(enemy_sprite_placeholder, enemy_folder, true)  # Enemies face back
	if enemy_sprite:
		enemy_sprite.flip_h = false  # Don't flip enemies

	# Shadows
	if hero_shadow:
		hero_shadow.texture = SpriteFactory.make_shadow(80, 24)
		hero_shadow.centered = true
		hero_shadow.scale = Vector2(1.5, 1.0)
		hero_shadow.modulate = Color(0, 0, 0, 0.7)
		hero_shadow.z_index = 9  # Just below hero sprite
	if enemy_shadow:
		enemy_shadow.texture = SpriteFactory.make_shadow(80, 24)
		enemy_shadow.centered = true
		enemy_shadow.scale = Vector2(1.6, 1.0)
		enemy_shadow.modulate = Color(0, 0, 0, 0.7)
		enemy_shadow.z_index = 0  # Just below enemy sprite
	
	# Origins
	hero_origin = hero_sprite.position if hero_sprite else hero_pos
	enemy_origin = enemy_sprite.position if enemy_sprite else enemy_pos
	hero_shadow_base = hero_shadow.scale if hero_shadow else Vector2.ONE
	enemy_shadow_base = enemy_shadow.scale if enemy_shadow else Vector2.ONE

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

	# Command menu
	command_menu = CommandMenu.new()
	$UI.add_child(command_menu)
	command_menu.menu_action.connect(_on_menu_action)
	command_menu.hide_menu()  # Hide it initially since we're using the new UI

	_log("Battle starts! %s vs %s" % [hero.name, enemy.name])
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
	_log("%s braces for impact (Defend)." % hero.name)
	planned_actions.clear()
	_on_end_turn()

func _on_attack() -> void:
	if !battle_finished:
		pending_skill = skill_slash
		_start_target_selection()

func _on_fireball() -> void:
	if battle_finished:
		return
	var cost: int = int(skill_fireball.get("mp_cost", 0))
	if int(hero.stats.get("MP",0)) >= cost:
		pending_skill = skill_fireball
		_start_target_selection()
	else:
		_log("Not enough MP for Fireball!")

func _on_potion() -> void:
	if battle_finished:
		return
	if potion_used:
		_log("The potion bottle is empty.")
		return
	var cur: int = int(hero.stats.get("HP",0))
	var max: int = int(hero.max_stats.get("HP",cur))
	if cur >= max:
		_log("HP is already full!")
		return
	var healed: int = hero.heal(int(ceil(max * POTION_HEAL_PCT)))
	potion_used = true
	_log("Hero uses Potion and heals %d HP." % healed)
	_update_ui()

func _queue_hero_action(skill: Dictionary) -> void:
	planned_actions.clear()
	planned_actions.append(Action.new(hero, skill.duplicate(true), enemy))
	_log("Planned: %s" % String(skill.get("name","Action")))

func _on_end_turn() -> void:
	if battle_finished or !hero.is_alive() or !enemy.is_alive():
		return
	if planned_actions.is_empty():
		planned_actions.append(Action.new(hero, skill_slash, enemy))
	var enemy_action: Action = Action.new(enemy, skill_slash.duplicate(true), hero)
	var actions: Array = planned_actions.duplicate()
	actions.append(enemy_action)
	actions = turn_engine.build_queue(actions)
	for a in actions:
		if a.actor == hero:
			var mp: int = int(a.skill.get("mp_cost",0))
			if mp>0:
				hero.spend_mp(mp)
	for a in actions:
		if a.actor==null or a.target==null or !a.actor.is_alive():
			continue
		var res: Dictionary = turn_engine.execute(a)
		if res.get("hit", false):
			var dmg: int = int(res.get("damage",0))
			var crit: bool = bool(res.get("crit",false))
			play_sfx("crit" if crit else "hit")
			spawn_damage_popup(_sprite_for_unit(a.target), dmg, crit, false)
			if _sprite_for_unit(a.target) is AnimatedFrames:
				(_sprite_for_unit(a.target) as AnimatedFrames).play_hit()
		else:
			play_sfx("miss")
			spawn_damage_popup(_sprite_for_unit(a.target), 0, false, true)
		await _play_attack_animation(a, res)
		_update_ui()
	for line in turn_engine.end_of_round_tick([hero, enemy]):
		_log(line)
	planned_actions.clear()
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
	# Hide the command menu
	if command_menu:
		command_menu.hide_menu()
		print("DEBUG: Command menu hidden")
	
	# Filter out dead enemies
	var alive_enemies: Array[Unit] = []
	for e in enemies:
		if e.is_alive():
			alive_enemies.append(e)
	
	print("DEBUG: Alive enemies count: ", alive_enemies.size())
	
	if alive_enemies.is_empty():
		_log("No targets available!")
		_show_command_menu()
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
	if !selecting_target:
		return
	
	var alive_enemies: Array[Unit] = []
	for e in enemies:
		if e.is_alive():
			alive_enemies.append(e)
	
	if alive_enemies.is_empty() or selected_enemy_index >= alive_enemies.size():
		_cancel_target_selection()
		return
	
	var target_enemy: Unit = alive_enemies[selected_enemy_index]
	selecting_target = false
	selector_arrow.visible = false
	
	# Queue the action with the selected target
	planned_actions.clear()
	planned_actions.append(Action.new(hero, pending_skill.duplicate(true), target_enemy))
	_log("Planned: %s → %s" % [String(pending_skill.get("name","Action")), target_enemy.name])
	
	# Automatically end turn after selecting target
	_on_end_turn()

func _cancel_target_selection() -> void:
	selecting_target = false
	selector_arrow.visible = false
	pending_skill = {}

func _check_end() -> void:
	if battle_finished:
		return
	if !enemy.is_alive():
		_log("Victory! %s is defeated." % enemy.name)
		show_battle_result(true,0,[])
	elif !hero.is_alive():
		_log("Defeat... The hero falls.")
		show_battle_result(false)

func _update_ui() -> void:
	# Update top panels
	if lbl_hero and hero:
		lbl_hero.text = "HP: %d/%d" % [hero.stats.get("HP",0), hero.max_stats.get("HP",0)]
		if hero_hp_bar:
			hero_hp_bar.max_value = hero.max_stats.get("HP",0)
			hero_hp_bar.value = hero.stats.get("HP",0)
		if hero_mp_bar:
			hero_mp_bar.max_value = hero.max_stats.get("MP",0)
			hero_mp_bar.value = hero.stats.get("MP",0)
	if lbl_enemy and enemy:
		lbl_enemy.text = "HP: %d/%d" % [enemy.stats.get("HP",0), enemy.max_stats.get("HP",0)]
		if enemy_hp_bar:
			enemy_hp_bar.max_value = enemy.max_stats.get("HP",0)
			enemy_hp_bar.value = enemy.stats.get("HP",0)
	
	# Update bottom-left active character panel
	if active_hp_label and hero:
		active_hp_label.text = "HP: %d/%d" % [hero.stats.get("HP",0), hero.max_stats.get("HP",0)]
	if active_mp_label and hero:
		active_mp_label.text = "MP: %d/%d" % [hero.stats.get("MP",0), hero.max_stats.get("MP",0)]
	if active_hp_bar and hero:
		active_hp_bar.max_value = hero.max_stats.get("HP",0)
		active_hp_bar.value = hero.stats.get("HP",0)
	if active_mp_bar and hero:
		active_mp_bar.max_value = hero.max_stats.get("MP",0)
		active_mp_bar.value = hero.stats.get("MP",0)
	if active_portrait and hero:
		active_portrait.texture = PortraitLoader.get_portrait_for(hero.name)
	
	# Update portraits
	if hero_portrait_rect and hero:
		hero_portrait_rect.texture = PortraitLoader.get_portrait_for(hero.name)
	if enemy_portrait_rect and enemy:
		enemy_portrait_rect.texture = PortraitLoader.get_portrait_for(enemy.name)
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
	if hero_sprite:
		hero_sprite.modulate = _base_modulate_for(hero)
		hero_sprite.position = hero_origin
		hero_sprite.z_index = 10  # Higher z-index for allies (front)
		hero_sprite.set_facing_back(false)  # Allies face forward
	if enemy_sprite:
		enemy_sprite.modulate = _base_modulate_for(enemy)
		enemy_sprite.position = enemy_origin
		enemy_sprite.z_index = 1  # Lower z-index for enemies (back)
		enemy_sprite.set_facing_back(true)  # Enemies face backward
	if hero_shadow:
		hero_shadow.modulate = _shadow_color_for(hero)
		hero_shadow.scale = hero_shadow_base
		hero_shadow.z_index = 9  # Maintain z-index
	if enemy_shadow:
		enemy_shadow.modulate = _shadow_color_for(enemy)
		enemy_shadow.scale = enemy_shadow_base
		enemy_shadow.z_index = 0  # Maintain z-index

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
	a.scale = old_sprite.scale
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
	return hero_sprite if u==hero else enemy_sprite if u==enemy else null

func _shadow_for_unit(u: Unit) -> Sprite2D:
	return hero_shadow if u==hero else enemy_shadow if u==enemy else null

func _origin_for_unit(u: Unit) -> Vector2:
	return hero_origin if u==hero else enemy_origin if u==enemy else Vector2.ZERO

func _shadow_base_scale(u: Unit) -> Vector2:
	return hero_shadow_base if u==hero else enemy_shadow_base if u==enemy else Vector2.ONE

func _attack_offset(u: Unit) -> Vector2:
	return Vector2(90,-18) if u==hero else Vector2(-90,-12) if u==enemy else Vector2.ZERO

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
	if u==enemy:
		off.x = -off.x
	var t: Tween = create_tween()
	t.tween_property(s, "position", o+off, 0.05)
	t.tween_property(s, "position", o-off*0.6, 0.07)
	t.tween_property(s, "position", o, 0.08)
	await t.finished

func refresh_status_hud() -> void:
	_populate_status_container(hero_status_container, hero)
	_populate_status_container(enemy_status_container, enemy)

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

func show_battle_result(victory: bool, xp:=0, loot: Array[String]=[]) -> void:
	if battle_finished:
		return
	battle_finished = true
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
	if hero.is_alive(): # If victory, go to upgrade selection
		get_tree().change_scene_to_file("res://scenes/UpgradeSelection.tscn")
	else: # If defeat, go back to main menu or game over screen
		get_tree().change_scene_to_file("res://scenes/Main.tscn") # Or a dedicated game over scene
