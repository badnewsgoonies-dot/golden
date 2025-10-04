extends Node2D

# It manages character and enemy units, their sprites, UI elements, and the turn-based logic.

# --- CONFIGURATION ---
# Set to true to allow ending the turn with a keyboard key (e.g., 'E')
var keyboard_end_turn_enabled := true

# --- ART ASSETS MAPPING ---
# Maps character/enemy IDs to their corresponding folder names in `art/battlers/`
# This allows using different art for units with the same name (e.g., color variations).
const CHARACTER_ART := {
	"barbarian": "barbarian",
	"cleric_blue": "cleric_blue",
	"mage_red": "mage_red",
	"werewolf": "werewolf",
	# Add other character mappings here
}

# --- PRELOAD SCRIPT CLASSES ---
const Unit = preload("res://battle/models/Unit.gd")
const AnimatedFrames = preload("res://scripts/AnimatedFrames.gd")
const SelectorArrow = preload("res://scripts/SelectorArrow.gd")
const Action = preload("res://battle/models/Action.gd")
const TurnEngine = preload("res://battle/TurnEngine.gd")
const SpriteFactory = preload("res://art/SpriteFactory.gd")
const PortraitLoader = preload("res://scripts/PortraitLoader.gd")

# --- UI NODE REFERENCES ---
# `@onready` ensures the nodes are fetched from the scene tree when the script is ready.

# Top HUD - Party Panel (top right)
@onready var hero_info_container: HBoxContainer = $UI/HUD/PartyPanel/PartyMargin/PartyHBox

# Top HUD - Enemy Panel (top left)
@onready var enemy_info_container: HBoxContainer = $UI/HUD/EnemyPanel/EnemyMargin/EnemyHBox

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

# Formation positions - JRPG style side-view
const HERO_POSITIONS := [
	Vector2(320, 760),
	Vector2(440, 720),
	Vector2(560, 780),
	Vector2(680, 740)
]

const ENEMY_POSITIONS := [
	Vector2(950, 540),
	Vector2(1070, 580),
	Vector2(1190, 520),
	Vector2(1030, 640)
]

const HERO_SCALE := Vector2(0.75, 0.75)
const ENEMY_SCALE := Vector2(0.95, 0.95)
const HERO_SHADOW_SCALE := Vector2(0.46, 0.24)
const ENEMY_SHADOW_SCALE := Vector2(0.6, 0.3)

# Battle floor (blue diamond) configuration
const FLOOR_POINTS := [
	Vector2(220, 840),
	Vector2(1200, 840),
	Vector2(1080, 440),
	Vector2(360, 440)
]
const FLOOR_COLOR := Color(0.25, 0.5, 0.9, 0.92)

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
	var hero_characters := ["barbarian", "cleric_blue", "mage_red", "barbarian"] # Changed to 4 heroes
	for i in range(min(4, hero_characters.size())): # Changed to 4
		var hero_id: String = hero_characters[i]
		var unit: Unit = _build_unit_from_character(hero_id)
		if unit:
			# Give them distinct names if they are the same type
			if hero_characters.count(hero_id) > 1:
				unit.name = unit.name + " " + String.chr(65 + i)
			heroes.append(unit)
		else:
			print("ERROR: Failed to create hero unit from character: %s" % hero_id)
	extends Node2D

	# -----------------------------------------------------------------------------
	# CLEAN SIMPLIFIED BATTLE CONTROLLER
	# Rewritten to remove broken signal-based flow and align with the new UI layout.
	# -----------------------------------------------------------------------------

	const Unit        = preload("res://battle/models/Unit.gd")
	const Action      = preload("res://battle/models/Action.gd")
	const TurnEngine  = preload("res://battle/TurnEngine.gd")
	const AnimatedFrames = preload("res://scripts/AnimatedFrames.gd")
	const SpriteFactory  = preload("res://art/SpriteFactory.gd")
	const PortraitLoader = preload("res://scripts/PortraitLoader.gd")

	# Basic mapping id -> art folder
	const CHARACTER_ART := {
		"barbarian": "barbarian",
		"cleric_blue": "cleric_blue",
		"mage_red": "mage_red",
		"werewolf": "werewolf"
	}

	# Formation (kept simple – adjust later if desired)
	const HERO_POSITIONS  := [Vector2(320,760), Vector2(440,720), Vector2(560,780), Vector2(680,740)]
	const ENEMY_POSITIONS := [Vector2(950,540), Vector2(1070,580), Vector2(1190,520), Vector2(1030,640)]
	const HERO_SCALE  := Vector2(0.75,0.75)
	const ENEMY_SCALE := Vector2(0.95,0.95)

	# UI references
	@onready var hero_info_container: HBoxContainer  = $UI/HUD/PartyPanel/PartyMargin/PartyHBox
	@onready var enemy_info_container: HBoxContainer = $UI/HUD/EnemyPanel/EnemyMargin/EnemyHBox
	@onready var btn_attack: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Attack
	@onready var btn_spells: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Spells
	@onready var btn_items: Button  = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Items
	@onready var btn_defend: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Defend
	@onready var spells_container: VBoxContainer = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/SpellsContainer
	@onready var items_container: VBoxContainer  = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/ItemsContainer
	@onready var battle_log: RichTextLabel = $UI/HUD/BattleLog
	@onready var target_selector: Control = $UI/HUD/TargetSelector
	@onready var overlay_fade: ColorRect = $Overlay/Fade
	@onready var overlay_title: Label = $Overlay/CenterContainer/VBoxContainer/Label
	@onready var overlay_subtitle: Label = $Overlay/CenterContainer/VBoxContainer/Label2

	# Runtime collections
	var heroes: Array[Unit] = []
	var enemies: Array[Unit] = []
	var hero_sprites: Array[AnimatedFrames] = []
	var enemy_sprites: Array[AnimatedFrames] = []
	var sprite_to_unit: Dictionary = {}  # Node2D -> Unit

	var planned_actions: Array[Action] = []
	var turn_engine: TurnEngine
	var round_active: bool = false
	var current_hero_index: int = 0
	var pending_skill: Dictionary = {}
	var selected_skill_id: String = ""
	var item_mode: bool = false
	var targeting_meta: Dictionary = {}   # For item usage, etc.
	var battle_over: bool = false

	func _ready() -> void:
		turn_engine = TurnEngine.new()
		add_child(turn_engine)
		spells_container.hide()
		items_container.hide()
		target_selector.hide()
		_overlay_reset()
		_build_units()
		_build_sprites()
		_connect_buttons()
		_update_panels()
		_start_round()
		_log("Battle started: %d heroes vs %d enemies" % [heroes.size(), enemies.size()])

	# -----------------------------------------------------------------------------
	# Setup
	# -----------------------------------------------------------------------------
	func _build_units() -> void:
		var hero_ids := ["barbarian", "cleric_blue", "mage_red", "barbarian"]
		for i in range(hero_ids.size()):
			var u := _make_unit_from_def(DataRegistry.get_character(hero_ids[i]))
			if hero_ids.count(hero_ids[i]) > 1:
				u.name = "%s %s" % [u.name, String.chr(65 + i)]
			heroes.append(u)

		var enemy_ids := ["werewolf", "werewolf"]
		for i in range(enemy_ids.size()):
			var u := _make_unit_from_def(DataRegistry.get_enemy(enemy_ids[i]))
			u.name = "%s %s" % [u.name, String.chr(65 + i)]
			enemies.append(u)

	func _make_unit_from_def(def: Dictionary) -> Unit:
		var fallback := {"name":"Unit","stats":{"max_hp":80,"max_mp":10,"atk":10,"def":8,"agi":10,"focus":8},"resist":{}}
		if def.is_empty():
			def = fallback
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

	func _build_sprites() -> void:
		if !has_node("Stage"): return
		var stage := $Stage
		for i in range(heroes.size()):
			var art_id := CHARACTER_ART.get("barbarian" if i>=len(CHARACTER_ART) else heroes[i].name.split(" ")[0].to_lower(), "barbarian")
			var spr := AnimatedFrames.new()
			spr.character = art_id
			spr.set_facing_back(true)
			stage.add_child(spr)
			spr.position = HERO_POSITIONS[min(i, HERO_POSITIONS.size()-1)]
			spr.scale = HERO_SCALE
			spr._build_frames()
			spr._apply_orientation()
			spr.z_index = int(spr.position.y)
			hero_sprites.append(spr)
			sprite_to_unit[spr] = heroes[i]
		for i in range(enemies.size()):
			var art_e := CHARACTER_ART.get("werewolf", "werewolf")
			var spr_e := AnimatedFrames.new()
			spr_e.character = art_e
			spr_e.set_facing_back(false)
			stage.add_child(spr_e)
			spr_e.position = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size()-1)]
			spr_e.scale = ENEMY_SCALE
			spr_e._build_frames()
			spr_e._apply_orientation()
			spr_e.z_index = int(spr_e.position.y)
			enemy_sprites.append(spr_e)
			sprite_to_unit[spr_e] = enemies[i]

	func _connect_buttons() -> void:
		btn_attack.pressed.connect(_on_attack_pressed)
		btn_spells.pressed.connect(_on_spells_pressed)
		btn_items.pressed.connect(_on_items_pressed)
		btn_defend.pressed.connect(_on_defend_pressed)
		target_selector.target_selected.connect(_on_target_confirmed)
		target_selector.selection_cancelled.connect(_on_target_cancelled)

	# -----------------------------------------------------------------------------
	# Round / Turn Flow
	# -----------------------------------------------------------------------------
	func _start_round() -> void:
		planned_actions.clear()
		current_hero_index = 0
		round_active = true
		_show_action_ui_for_current()
		_log("-- New Round --")

	func _show_action_ui_for_current() -> void:
		if current_hero_index >= heroes.size():
			_execute_round()
			return
		if !heroes[current_hero_index].is_alive():
			current_hero_index += 1
			_show_action_ui_for_current()
			return
		spells_container.hide()
		items_container.hide()
		selected_skill_id = ""

	func _advance_to_next_hero() -> void:
		current_hero_index += 1
		_show_action_ui_for_current()

	# -----------------------------------------------------------------------------
	# UI Button Handlers
	# -----------------------------------------------------------------------------
	func _on_attack_pressed() -> void:
		if _hero_invalid(): return
		var slash := _get_skill("slash")
		pending_skill = slash
		_begin_target_selection(enemies.filter(func(e): return e.is_alive()))

	func _on_spells_pressed() -> void:
		if _hero_invalid(): return
		if spells_container.visible:
			spells_container.hide()
			return
		spells_container.hide()
		for c in spells_container.get_children(): c.queue_free()
		# Demo: list every skill in DataRegistry.skills except slash
		for k in DataRegistry.skills.keys():
			if k == "slash": continue
			var d: Dictionary = DataRegistry.get_skill(k)
			var b := Button.new()
			b.text = d.get("name", k.capitalize())
			b.pressed.connect(func():
				pending_skill = d
				spells_container.hide()
				_begin_target_selection(_skill_targets(d))
			)
			spells_container.add_child(b)
		spells_container.show()

	func _on_items_pressed() -> void:
		if _hero_invalid(): return
		if items_container.visible:
			items_container.hide(); return
		for c in items_container.get_children(): c.queue_free()
		for item_id in RunManager.inventory:
			var cnt = int(RunManager.inventory[item_id])
			if cnt <= 0: continue
			var data := DataRegistry.get_item(item_id)
			if data.is_empty(): continue
			var b := Button.new()
			b.text = "%s (%d)" % [data.get("name", item_id), cnt]
			b.pressed.connect(func():
				item_mode = true
				targeting_meta = {"item_id": item_id, "data": data}
				items_container.hide()
				_begin_target_selection(_item_targets(data))
			)
			items_container.add_child(b)
		items_container.show()

	func _on_defend_pressed() -> void:
		if _hero_invalid(): return
		var hero := heroes[current_hero_index]
		# Represent defend as a zero-power action (no damage) for log ordering.
		var defend_skill := {"name":"Defend","power":0.0,"stat":"ATK","target":"self"}
		var act := Action.new(hero, defend_skill, hero)
		planned_actions.append(act)
		_log("%s defends." % hero.name)
		_advance_to_next_hero()

	func _hero_invalid() -> bool:
		return battle_over or current_hero_index >= heroes.size() or !heroes[current_hero_index].is_alive()

	# -----------------------------------------------------------------------------
	# Target Selection
	# -----------------------------------------------------------------------------
	func _begin_target_selection(unit_list: Array[Unit]) -> void:
		if unit_list.is_empty():
			_log("No valid targets.")
			return
		var sprites: Array = []
		for u in unit_list:
			var spr := _sprite_for(u)
			if spr: sprites.append(spr)
		target_selector.start_selection(sprites)

	func _on_target_confirmed(sprite: Node2D) -> void:
		var target := sprite_to_unit.get(sprite, null)
		if target == null:
			_log("Internal error: target sprite missing mapping")
			return
		var hero := heroes[current_hero_index]
		if item_mode:
			_apply_item(hero, target)
		else:
			_queue_skill_action(hero, target)
		_on_target_cancelled()  # ensure cleanup
		_advance_to_next_hero()

	func _on_target_cancelled() -> void:
		item_mode = false
		pending_skill = {}
		selected_skill_id = ""

	func _queue_skill_action(hero: Unit, target: Unit) -> void:
		if pending_skill.is_empty():
			pending_skill = _get_skill("slash")
		var skill_copy := pending_skill.duplicate(true)
		var act := Action.new(hero, skill_copy, target)
		planned_actions.append(act)
		_log("%s prepares %s on %s" % [hero.name, skill_copy.get("name","Action"), target.name])

	func _apply_item(hero: Unit, target: Unit) -> void:
		var data: Dictionary = targeting_meta.get("data", {})
		if data.is_empty(): return
		var effect: Dictionary = data.get("effect", {})
		var stat: String = effect.get("stat", "HP")
		var amount: int = int(effect.get("amount", 0))
		if stat == "HP":
			var before = int(target.stats.get("HP",0))
			var healed = target.heal(amount)
			_log("%s uses %s on %s (+%d HP)" % [hero.name, data.get("name","Item"), target.name, healed])
		elif stat == "MP":
			var mp_before = int(target.stats.get("MP",0))
			var restored = target.restore_mp(amount)
			_log("%s uses %s on %s (+%d MP)" % [hero.name, data.get("name","Item"), target.name, restored])
		RunManager.use_item(targeting_meta.get("item_id",""))

	func _skill_targets(skill: Dictionary) -> Array[Unit]:
		var t := String(skill.get("target","enemy"))
		match t:
			"enemy": return enemies.filter(func(u): return u.is_alive())
			"hero": return heroes.filter(func(u): return u.is_alive())
			"self": return [heroes[current_hero_index]]
			_: return enemies.filter(func(u): return u.is_alive())

	func _item_targets(data: Dictionary) -> Array[Unit]:
		var t := String(data.get("target","hero"))
		return heroes.filter(func(u): return u.is_alive()) if t == "hero" else heroes

	# -----------------------------------------------------------------------------
	# Execute Round
	# -----------------------------------------------------------------------------
	func _execute_round() -> void:
		# Add enemy AI actions
		for e in enemies:
			if !e.is_alive(): continue
			var living_heroes = heroes.filter(func(h): return h.is_alive())
			if living_heroes.is_empty(): break
			var target := living_heroes.pick_random()
			var skill := _get_skill("slash")
			planned_actions.append(Action.new(e, skill.duplicate(true), target))

		# Sort via TurnEngine helper (initiative simulation)
		var queue := turn_engine.build_queue(planned_actions)
		for act: Action in queue:
			if battle_over: break
			if act.actor == null or act.target == null: continue
			if !act.actor.is_alive() or !act.target.is_alive(): continue
			var res := turn_engine.execute(act)
			if res.get("hit",false):
				_log("%s hits %s for %d%s" % [act.actor.name, act.target.name, int(res.get("damage",0)), " CRIT" if res.get("crit",false) else ""]) 
			else:
				_log("%s misses %s" % [act.actor.name, act.target.name])
			_update_panels()
			if _check_battle_end(): break

		if !battle_over:
			_start_round()

	# -----------------------------------------------------------------------------
	# Helpers
	# -----------------------------------------------------------------------------
	func _get_skill(id: String) -> Dictionary:
		var d := DataRegistry.get_skill(id)
		if d.is_empty():
			return {"id":id,"name":id.capitalize(),"power":1.0,"stat":"ATK","target":"enemy","acc":0.95,"crit":0.05}
		return d

	func _sprite_for(u: Unit) -> AnimatedFrames:
		var i := heroes.find(u)
		if i >= 0 and i < hero_sprites.size(): return hero_sprites[i]
		i = enemies.find(u)
		if i >= 0 and i < enemy_sprites.size(): return enemy_sprites[i]
		return null

	func _update_panels() -> void:
		_update_panel(hero_info_container, heroes, "Hero")
		_update_panel(enemy_info_container, enemies, "Enemy")

	func _update_panel(container: HBoxContainer, list: Array[Unit], prefix: String) -> void:
		if !container: return
		for i in range(container.get_child_count()):
			var box := container.get_child(i)
			if i >= list.size():
				box.visible = false
				continue
			var u: Unit = list[i]
			box.visible = true
			var name_label: Label = box.get_node_or_null("%sLabel%d" % [prefix, i+1])
			var hp_bar: ProgressBar = box.get_node_or_null("%sHPBar%d" % [prefix, i+1])
			if name_label: name_label.text = u.name
			if hp_bar:
				hp_bar.max_value = u.max_stats.get("HP",1)
				hp_bar.value = u.stats.get("HP",0)
			# Portraits (optional)
			var portrait: TextureRect = box.get_node_or_null("%sPortrait%d" % [prefix, i+1])
			if portrait:
				portrait.texture = PortraitLoader.get_portrait_for(u.name) if Engine.has_singleton("PortraitLoader") else null

	func _check_battle_end() -> bool:
		var heroes_alive = heroes.any(func(h): return h.is_alive())
		var enemies_alive = enemies.any(func(e): return e.is_alive())
		if !heroes_alive or !enemies_alive:
			battle_over = true
			_show_result(heroes_alive)
			return true
		return false

	func _show_result(victory: bool) -> void:
		$Overlay.visible = true
		overlay_fade.modulate.a = 0.6
		overlay_title.text = victory ? "Victory!" : "Defeat"
		overlay_subtitle.text = victory ? "XP +0\nLoot: --" : "You fall in battle." 
		_log("Battle concluded: %s" % ("Victory" if victory else "Defeat"))

	func _overlay_reset() -> void:
		if $Overlay:
			$Overlay.visible = false
			if overlay_fade:
				overlay_fade.modulate.a = 0.0

	func _log(msg: String) -> void:
		print(msg)
		if battle_log:
			battle_log.append_text(msg + "\n")

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
			var pos = HERO_POSITIONS[min(i, HERO_POSITIONS.size() - 1)]
			hero_sprites[i].position = pos
			hero_sprites[i].z_index = int(pos.y)
			hero_sprites[i].scale = HERO_SCALE
			hero_sprites[i].set_facing_back(true)  # Heroes face away
		if i < hero_shadows.size() and hero_shadows[i]:
			hero_shadows[i].modulate = _shadow_color_for(heroes[i])
			var pos = HERO_POSITIONS[min(i, HERO_POSITIONS.size() - 1)]
			hero_shadows[i].position = pos + Vector2(0, 20)
			hero_shadows[i].z_index = int(pos.y) - 1
			hero_shadows[i].scale = HERO_SHADOW_SCALE
			
	# Update all enemy sprites
	for i in range(enemies.size()):
		if i < enemy_sprites.size() and enemy_sprites[i]:
			enemy_sprites[i].modulate = _base_modulate_for(enemies[i])
			var pos = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
			enemy_sprites[i].position = pos
			enemy_sprites[i].z_index = int(pos.y)
			enemy_sprites[i].scale = ENEMY_SCALE
			enemy_sprites[i].set_facing_back(false)  # Enemies face camera
		if i < enemy_shadows.size() and enemy_shadows[i]:
			enemy_shadows[i].modulate = _shadow_color_for(enemies[i])
			var pos = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size() - 1)]
			enemy_shadows[i].position = pos + Vector2(0, 20)
			enemy_shadows[i].z_index = int(pos.y) - 1
			enemy_shadows[i].scale = ENEMY_SHADOW_SCALE
	
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
	a.scale = old_sprite.scale if old_sprite.scale != Vector2.ONE else Vector2(1.0, 1.0)
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
	var shadow_sprite = _shadow_for_unit(u)
	if shadow_sprite:
		return shadow_sprite.scale
	return Vector2(0.4, 0.2) # Fallback to default scale

func _attack_offset(u: Unit) -> Vector2:
	# Adjust offsets for new formation scale
	return Vector2(-66, -12) if u in heroes else Vector2(70, -10) if u in enemies else Vector2.ZERO

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
	# This function is now deprecated in favor of _update_info_panel
	pass

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
	# refresh_status_hud() # Deprecated
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
	if !heroes_alive.is_empty(): # If victory, go to upgrade selection
		get_tree().change_scene_to_file("res://scenes/UpgradeSelection.tscn")
	else: # If defeat, go back to main menu or game over screen
		get_tree().change_scene_to_file("res://scenes/Main.tscn") # Or a dedicated game over scene
