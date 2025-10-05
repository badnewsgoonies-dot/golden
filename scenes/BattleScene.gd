extends Node2D

# UPDATED BATTLE SCENE WITH PROPER TARGET SELECTION
# Uses existing UI buttons instead of creating duplicates

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
const AnimatedFrames = preload("res://scripts/AnimatedFrames.gd")
const SelectorArrow = preload("res://scripts/SelectorArrow.gd")
const PortraitLoader = preload("res://scripts/PortraitLoader.gd")

# --- UI NODE REFERENCES ---
@onready var hero_info_container: HBoxContainer = $UI/HUD/TopRightAnchor/PartyPanel/PartyMargin/PartyHBox
@onready var enemy_info_container: HBoxContainer = $UI/HUD/TopLeftAnchor/EnemyPanel/EnemyMargin/EnemyHBox
@onready var active_portrait: TextureRect = $UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActivePortrait
@onready var active_hp_label: Label = $UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveHPLabel
@onready var active_hp_bar: ProgressBar = $UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveHPBar
@onready var active_mp_label: Label = $UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveMPLabel
@onready var active_mp_bar: ProgressBar = $UI/HUD/BottomLeftAnchor/ActiveCharacterPanel/ActiveMargin/ActiveHBox/ActiveStats/ActiveMPBar

# Bottom HUD - Action Panel (EXISTING UI BUTTONS)
@onready var btn_attack: Button = $UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Attack
@onready var btn_spells: Button = $UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Spells
@onready var btn_items: Button = $UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Items
@onready var btn_defend: Button = $UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/Buttons/Defend
@onready var spell_bubble: PanelContainer = $UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/SpellBubble
@onready var spell_list_label: Label = $UI/HUD/BottomRightAnchor/ActionPanel/ActionMargin/ActionVBox/SpellBubble/SpellMargin/SpellList/SpellLabel

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

# NEW: Target Selector (no duplicate CommandMenu!)
var target_selector: TargetSelector

# Runtime objects
var hero_sprite: AnimatedFrames
var enemy_sprite: AnimatedFrames

var heroes: Array[Unit] = []
var enemies: Array[Unit] = []
var hero_sprites: Array[AnimatedFrames] = []
var enemy_sprites: Array[AnimatedFrames] = []
var hero_shadows: Array[Sprite2D] = []
var enemy_shadows: Array[Sprite2D] = []

var planned_actions: Array[Action] = []
var turn_engine: TurnEngine
var potion_used := false
var battle_finished := false
var current_acting_hero_index := 0
var pending_action_type := ""  # "attack", "spell", or "item"
var pending_skill: Dictionary = {}

var skill_slash: Dictionary = {}
var skill_fireball: Dictionary = {}

const POTION_HEAL_PCT := 0.30

# Formation positions
const HERO_POSITIONS := [
	Vector2(1250, 420),
	Vector2(1400, 500),
	Vector2(1350, 650),
	Vector2(1550, 600)
]

const ENEMY_POSITIONS := [
	Vector2(450, 480),
	Vector2(500, 620)
]

const HERO_SCALE := Vector2(0.36, 0.36)
const ENEMY_SCALE := Vector2(0.36, 0.36)
const HERO_SHADOW_SCALE := Vector2(0.18, 0.09)
const ENEMY_SHADOW_SCALE := Vector2(0.18, 0.09)

var status_icon_cache: Dictionary[String, Texture2D] = {}
var sfx_streams: Dictionary[String, AudioStream] = {}

func _ready() -> void:
	# Safety check
	if !has_node("Stage"):
		print("ERROR: BattleScene missing required Stage node!")
		return
	
	# Initialize Target Selector (NO CommandMenu - use existing buttons!)
	target_selector = TargetSelector.new()
	$UI.add_child(target_selector)
	target_selector.target_selected.connect(_on_target_selected)
	target_selector.selection_cancelled.connect(_on_selection_cancelled)
	
	# Connect EXISTING UI buttons
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
	
	# Data
	skill_slash = _fetch_skill("slash")
	skill_fireball = _fetch_skill("fireball")
	
	# Initialize heroes
	var hero_characters := ["barbarian", "cleric_blue", "mage_red", "barbarian"]
	for i in range(min(4, hero_characters.size())):
		var hero_id: String = hero_characters[i]
		var unit: Unit = _build_unit_from_character(hero_id)
		if unit:
			if hero_characters.count(hero_id) > 1:
				unit.name = unit.name + " " + String.chr(65 + i)
			heroes.append(unit)
		else:
			print("ERROR: Failed to create hero unit from character: %s" % hero_id)
	
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
		else:
			print("ERROR: Failed to create enemy unit: %s" % enemy_id)
	
	# Engine
	turn_engine = TurnEngine.new()
	add_child(turn_engine)
	
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
		var hero_id: String = hero_characters[i]
		var hero_folder: String = CHARACTER_ART.get(hero_id, hero_id)
		
		var sprite := AnimatedFrames.new()
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
	
	# Create sprites for all enemies
	for i in range(enemies.size()):
		var unit: Unit = enemies[i]
		var pos: Vector2 = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
		var enemy_id: String = enemy_types[i]
		var enemy_folder: String = CHARACTER_ART.get(enemy_id, enemy_id)
		
		var sprite := AnimatedFrames.new()
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
	
	# For compatibility
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
	
	_log("Battle starts! %d heroes vs %d enemies" % [heroes.size(), enemies.size()])
	_log("Heroes: " + ", ".join(heroes.map(func(h): return h.name)))
	_log("Enemies: " + ", ".join(enemies.map(func(e): return e.name)))
	_log("=== TARGET SELECTION SYSTEM ACTIVE ===")
	_update_ui()

# ATTACK: Use existing button, trigger target selection
func _on_attack() -> void:
	if battle_finished or current_acting_hero_index >= heroes.size():
		return
	
	pending_action_type = "attack"
	pending_skill = skill_slash.duplicate(true)
	_start_enemy_target_selection()

# SPELLS: Show spell bubble (existing UI)
func _on_spells_pressed() -> void:
	if spell_bubble:
		spell_bubble.visible = !spell_bubble.visible
		
		# If opening, populate with available spells
		if spell_bubble.visible and current_acting_hero_index < heroes.size():
			var current_hero: Unit = heroes[current_acting_hero_index]
			var spell_text := ""
			
			# Check if can cast fireball
			if current_hero.stats.get("MP", 0) >= int(skill_fireball.get("mp_cost", 0)):
				spell_text = "Fireball (15 MP)"
			else:
				spell_text = "No MP for spells"
			
			if spell_list_label:
				spell_list_label.text = spell_text

# ITEMS: Check potion availability
func _on_items_pressed() -> void:
	if !potion_used:
		pending_action_type = "item"
		pending_skill = {"id": "potion", "name": "Potion", "type": "heal"}
		_start_ally_target_selection()
	else:
		_log("The potion bottle is empty.")

# DEFEND: Immediate action
func _on_defend_pressed() -> void:
	if current_acting_hero_index >= heroes.size():
		return
	var current_hero: Unit = heroes[current_acting_hero_index]
	_log("%s braces for impact (Defend)." % current_hero.name)
	var defend_skill := {"id": "defend", "name": "Defend", "type": "defend"}
	planned_actions.append(Action.new(current_hero, defend_skill, current_hero))
	_advance_to_next_hero()

# Handle spell selection from bubble (you'll need to wire this up in your UI)
func _on_fireball_selected() -> void:
	if battle_finished or current_acting_hero_index >= heroes.size():
		return
	var current_hero: Unit = heroes[current_acting_hero_index]
	var cost: int = int(skill_fireball.get("mp_cost", 0))
	if current_hero.stats.get("MP", 0) >= cost:
		pending_action_type = "spell"
		pending_skill = skill_fireball.duplicate(true)
		spell_bubble.visible = false
		_start_enemy_target_selection()
	else:
		_log("Not enough MP for Fireball!")

# NEW: Start target selection for enemies
func _start_enemy_target_selection() -> void:
	var alive_enemies: Array = []
	for i in range(enemies.size()):
		if enemies[i].is_alive():
			alive_enemies.append(enemy_sprites[i])
	
	if alive_enemies.is_empty():
		_log("No enemies to target!")
		return
	
	_log("[color=lime]→ Select your target! Arrow keys to choose, Enter to confirm, Esc to cancel.[/color]", Color.WHITE, true)
	target_selector.start_selection(alive_enemies)

# NEW: Start target selection for allies
func _start_ally_target_selection() -> void:
	var alive_heroes: Array = []
	for i in range(heroes.size()):
		if heroes[i].is_alive():
			alive_heroes.append(hero_sprites[i])
	
	if alive_heroes.is_empty():
		_log("No allies to target!")
		return
	
	_log("[color=lime]→ Select target ally! Arrow keys to choose, Enter to confirm, Esc to cancel.[/color]", Color.WHITE, true)
	target_selector.start_selection(alive_heroes)

# NEW: Handle target selection confirmation
func _on_target_selected(target_sprite: Node2D) -> void:
	if battle_finished or current_acting_hero_index >= heroes.size():
		return
	
	var current_hero: Unit = heroes[current_acting_hero_index]
	var target_unit: Unit = null
	
	# Find which unit was targeted
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
		_log("Invalid target!")
		return
	
	# Handle different action types
	if pending_action_type == "attack":
		planned_actions.append(Action.new(current_hero, pending_skill, target_unit))
		_log("Planned: %s will attack %s" % [current_hero.name, target_unit.name])
		_advance_to_next_hero()
	
	elif pending_action_type == "spell":
		var mp_cost: int = int(pending_skill.get("mp_cost", 0))
		if current_hero.stats.get("MP", 0) >= mp_cost:
			planned_actions.append(Action.new(current_hero, pending_skill, target_unit))
			_log("Planned: %s will cast %s on %s" % [current_hero.name, pending_skill.get("name", "spell"), target_unit.name])
			_advance_to_next_hero()
		else:
			_log("Not enough MP!")
	
	elif pending_action_type == "item":
		if pending_skill.get("id") == "potion":
			var cur: int = int(target_unit.stats.get("HP",0))
			var max: int = int(target_unit.max_stats.get("HP",cur))
			if cur >= max:
				_log("%s's HP is already full!" % target_unit.name)
				return
			
			var healed: int = target_unit.heal(int(ceil(max * POTION_HEAL_PCT)))
			potion_used = true
			_log("%s uses Potion on %s and heals %d HP." % [current_hero.name, target_unit.name, healed])
			_update_ui()
			_advance_to_next_hero()
	
	# Clear pending action
	pending_action_type = ""
	pending_skill = {}

# NEW: Handle target selection cancellation
func _on_selection_cancelled() -> void:
	pending_action_type = ""
	pending_skill = {}

# NEW: Advance to next hero or end turn
func _advance_to_next_hero() -> void:
	current_acting_hero_index += 1
	if current_acting_hero_index >= heroes.size():
		_on_end_turn()
	else:
		_update_ui()

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
			var target: Unit = enemies_alive[randi() % enemies_alive.size()]
			planned_actions.append(Action.new(h, skill_slash.duplicate(true), target))
	
	# Add enemy actions
	for e in enemies:
		if e.is_alive():
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
	current_acting_hero_index = 0
	_check_end()
	_update_ui()

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
			active_portrait.texture = PortraitLoader.get_portrait_for(current_hero.name)
	
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
			print("Warning: Not enough UI containers for all units.")
			break
		
		var unit: Unit = unit_list[i]
		var unit_box: VBoxContainer = container.get_child(i) as VBoxContainer
		if not unit_box:
			print("Error: UI element for unit %d is not a VBoxContainer." % i)
			continue
		unit_box.visible = true
		
		var name_label: Label = unit_box.get_node_or_null("HeroLabel" + str(i+1)) if label_prefix == "Hero" else unit_box.get_node_or_null("EnemyLabel" + str(i+1))
		var hp_bar: ProgressBar = unit_box.get_node_or_null("HeroHPBar" + str(i+1)) if label_prefix == "Hero" else unit_box.get_node_or_null("EnemyHPBar" + str(i+1))
		var mp_bar: ProgressBar = unit_box.get_node_or_null("HeroMPBar" + str(i+1))
		
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

var battle_victory: bool = false

func show_battle_result(victory: bool, xp:=0, loot: Array[String]=[]) -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_victory = victory
	planned_actions.clear()
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
	var heroes_alive := heroes.filter(func(h): return h.is_alive())
	if !heroes_alive.is_empty():
		get_tree().change_scene_to_file("res://scenes/UpgradeSelection.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
