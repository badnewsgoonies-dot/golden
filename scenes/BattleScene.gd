extends Node2D

const Action := preload("res://battle/models/Action.gd")
const Unit := preload("res://battle/models/Unit.gd")
const Formula := preload("res://battle/Formula.gd")
const TurnEngine := preload("res://battle/TurnEngine.gd")
const SpriteFactory := preload("res://art/SpriteFactory.gd")
const AnimatedFrames := preload("res://scripts/AnimatedFrames.gd")
const PortraitLoader := preload("res://scripts/PortraitLoader.gd")
const CommandMenu := preload("res://ui/CommandMenu.gd")

const CHARACTER_ART := {
	"Pyro Adept": "hero",
	"Gale Rogue": "rogue",
	"Sunlit Cleric": "healer",
	"Cleric": "healer",
	"Iron Guard": "hero",
	"Guard": "hero",
	"Goblin": "goblin",
	"Slime": "slime"
}

@export var keyboard_end_turn_enabled: bool = true

# HUD
@onready var lbl_hero: Label = $UI/HUD/CommandPanel/Panel/Margin/VBox/HeaderRow/HeroInfo/HeroText/HeroLabel
@onready var hero_status_container: HBoxContainer = $UI/HUD/CommandPanel/Panel/Margin/VBox/HeaderRow/HeroInfo/HeroText/HeroStatus
@onready var hero_hp_bar: ProgressBar = $UI/HUD/CommandPanel/Panel/Margin/VBox/HeaderRow/HeroInfo/HeroText/HeroHPBar
@onready var hero_mp_bar: ProgressBar = $UI/HUD/CommandPanel/Panel/Margin/VBox/HeaderRow/HeroInfo/HeroText/HeroMPBar
@onready var lbl_enemy: Label = $UI/HUD/EnemyPanel/Margin/EnemyRow/EnemyInfo/EnemyLabel
@onready var enemy_status_container: HBoxContainer = $UI/HUD/EnemyPanel/Margin/EnemyRow/EnemyInfo/EnemyStatus
@onready var enemy_hp_bar: ProgressBar = $UI/HUD/EnemyPanel/Margin/EnemyRow/EnemyInfo/EnemyHPBar
@onready var hero_portrait_rect: TextureRect = $UI/HUD/CommandPanel/Panel/Margin/VBox/HeaderRow/HeroInfo/HeroPortraitFrame/HeroPortrait
@onready var enemy_portrait_rect: TextureRect = $UI/HUD/EnemyPanel/Margin/EnemyRow/EnemyInfo/EnemyPortrait
@onready var plan_label: Label = $UI/HUD/CommandPanel/Panel/Margin/VBox/PlanBubble/PlanMargin/PlanVBox/PlanLabel
@onready var lbl_queue: Label = $UI/HUD/CommandPanel/Panel/Margin/VBox/PlanBubble/PlanMargin/PlanVBox/TurnOrderLabel
@onready var log_view: RichTextLabel = $UI/HUD/CommandPanel/Panel/Margin/VBox/Log
@onready var buttons_row: HBoxContainer = $UI/HUD/CommandPanel/Panel/Margin/VBox/Buttons
@onready var btn_attack: Button = $UI/HUD/CommandPanel/Panel/Margin/VBox/Buttons/Attack
@onready var btn_fire: Button = $UI/HUD/CommandPanel/Panel/Margin/VBox/Buttons/Fireball
@onready var btn_potion: Button = $UI/HUD/CommandPanel/Panel/Margin/VBox/Buttons/Potion
@onready var btn_end: Button = $UI/HUD/CommandPanel/Panel/Margin/VBox/Buttons/EndTurn

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

var hero: Unit
var enemy: Unit
var planned_actions: Array[Action] = []
var turn_engine: TurnEngine
var potion_used := false
var battle_finished := false

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
	hero = _build_unit_from_character("adept_pyro")
	enemy = _build_unit_from_enemy("goblin")

	# Engine
	turn_engine = TurnEngine.new()
	add_child(turn_engine)

	# Swap to AnimatedFrames
	var hero_pos: Vector2 = Vector2(780, 396)
	var enemy_pos: Vector2 = Vector2(420, 310)
	if hero_sprite_placeholder:
		hero_pos = hero_sprite_placeholder.position
	if enemy_sprite_placeholder:
		enemy_pos = enemy_sprite_placeholder.position
	var hero_folder: String = String(CHARACTER_ART.get(hero.name, hero.name.to_lower().replace(" ", "_")))
	hero_sprite = _swap_for_animated_sprite(hero_sprite_placeholder, hero_folder, true)
	var enemy_folder: String = String(CHARACTER_ART.get(enemy.name, enemy.name.to_lower().replace(" ", "_")))
	enemy_sprite = _swap_for_animated_sprite(enemy_sprite_placeholder, enemy_folder, false)
	if enemy_sprite:
		enemy_sprite.flip_h = true

	# Shadows
	if hero_shadow:
		hero_shadow.texture = SpriteFactory.make_shadow(64, 18)
		hero_shadow.centered = true
		hero_shadow.scale = Vector2(1.25, 0.85)
	if enemy_shadow:
		enemy_shadow.texture = SpriteFactory.make_shadow(64, 18)
		enemy_shadow.centered = true
		enemy_shadow.scale = Vector2(1.35, 0.9)
	
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
	if log_view:
		log_view.bbcode_enabled = true
	sfx_streams = {"hit": _make_tone(420.0,0.14,0.35), "crit": _make_tone(660.0,0.2,0.4), "miss": _make_tone(240.0,0.16,0.3)}

	# Debug buttons (hidden)
	if buttons_row:
		buttons_row.visible = false
	if btn_attack:
		btn_attack.pressed.connect(_on_attack)
	if btn_fire:
		btn_fire.pressed.connect(_on_fireball)
	if btn_potion:
		btn_potion.pressed.connect(_on_potion)
	if btn_end:
		btn_end.pressed.connect(_on_end_turn)
		btn_end.disabled = true

	# Command menu
	command_menu = CommandMenu.new()
	$UI.add_child(command_menu)
	command_menu.menu_action.connect(_on_menu_action)
	_show_command_menu()

	_log("Battle starts! %s vs %s" % [hero.name, enemy.name])
	_update_ui()
	_update_turn_order([])

func _show_command_menu() -> void:
	var spells: Array[Dictionary] = []
	spells.append({"id":"fireball","name":String(skill_fireball.get("name","Fireball")),"mp_cost":int(skill_fireball.get("mp_cost",0))})
	var items: Array[Dictionary] = []
	if !potion_used:
		items.append({"id":"potion","name":"Potion"})
	command_menu.show_for_actor(hero.name, spells, items)

func _on_menu_action(kind: String, id: String) -> void:
	if battle_finished:
		return
	match kind:
		"attack":
			_queue_hero_action(skill_slash)
		"spells":
			if id == "fireball":
				_on_fireball()
			else:
				_log("Unknown spell: %s" % id)
		"items":
			if id == "potion":
				_on_potion()
			else:
				_log("Unknown item: %s" % id)
		"defend":
			_log("%s braces for impact (Defend)." % hero.name)
			planned_actions.clear()
			_refresh_plan_label()
			_refresh_end_turn_button()
			return
	_refresh_end_turn_button()

func _on_attack() -> void:
	if !battle_finished:
		_queue_hero_action(skill_slash)

func _on_fireball() -> void:
	if battle_finished:
		return
	var cost: int = int(skill_fireball.get("mp_cost", 0))
	if int(hero.stats.get("MP",0)) >= cost:
		_queue_hero_action(skill_fireball)
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
	_refresh_end_turn_button()
	_show_command_menu()

func _queue_hero_action(skill: Dictionary) -> void:
	planned_actions.clear()
	planned_actions.append(Action.new(hero, skill.duplicate(true), enemy))
	_log("Planned: %s" % String(skill.get("name","Action")))
	_refresh_plan_label()
	_refresh_end_turn_button()

func _on_end_turn() -> void:
	if battle_finished or !hero.is_alive() or !enemy.is_alive():
		return
	if planned_actions.is_empty():
		planned_actions.append(Action.new(hero, skill_slash, enemy))
	_refresh_plan_label()
	_refresh_end_turn_button()
	var enemy_action: Action = Action.new(enemy, skill_slash.duplicate(true), hero)
	var actions: Array = planned_actions.duplicate()
	actions.append(enemy_action)
	actions = turn_engine.build_queue(actions)
	_update_turn_order(actions)
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
	_update_turn_order([])
	_refresh_plan_label()
	_refresh_end_turn_button()
	if !battle_finished:
		_show_command_menu()

func _unhandled_input(e: InputEvent) -> void:
	if battle_finished:
		return
	if e.is_action_pressed("ui_action_1"):
		_on_attack()
	elif e.is_action_pressed("ui_action_2"):
		_on_fireball()
	elif e.is_action_pressed("ui_action_3"):
		_on_potion()
	elif e.is_action_pressed("ui_action_4") and keyboard_end_turn_enabled:
		_on_end_turn()

func _check_end() -> void:
	if battle_finished:
		return
	if !enemy.is_alive():
		_log("Victory! %s is defeated." % enemy.name)
		show_battle_result(true,0,[])
	elif !hero.is_alive():
		_log("Defeat... The hero falls.")
		show_battle_result(false)

func _disable_inputs() -> void:
	btn_attack.disabled = true
	btn_fire.disabled = true
	btn_potion.disabled = true
	btn_end.disabled = true
	battle_finished = true

func _update_ui() -> void:
	if lbl_hero and hero:
		lbl_hero.text = "%s\nHP %d/%d   MP %d/%d" % [hero.name, hero.stats.get("HP",0), hero.max_stats.get("HP",0), hero.stats.get("MP",0), hero.max_stats.get("MP",0)]
		if hero_hp_bar:
			hero_hp_bar.max_value = hero.max_stats.get("HP",0)
			hero_hp_bar.value = hero.stats.get("HP",0)
		if hero_mp_bar:
			hero_mp_bar.max_value = hero.max_stats.get("MP",0)
			hero_mp_bar.value = hero.stats.get("MP",0)
	if lbl_enemy and enemy:
		lbl_enemy.text = "%s\nHP %d/%d" % [enemy.name, enemy.stats.get("HP",0), enemy.max_stats.get("HP",0)]
		if enemy_hp_bar:
			enemy_hp_bar.max_value = enemy.max_stats.get("HP",0)
			enemy_hp_bar.value = enemy.stats.get("HP",0)
	if hero_portrait_rect and hero:
		hero_portrait_rect.texture = PortraitLoader.get_portrait_for(hero.name)
	if enemy_portrait_rect and enemy:
		enemy_portrait_rect.texture = PortraitLoader.get_portrait_for(enemy.name)
	_update_sprites()
	refresh_status_hud()
	_refresh_plan_label()
	_refresh_end_turn_button()

func _log(msg: String, color: Color = Color(1,1,1), rich := false) -> void:
	var line: String = msg
	if !rich and color != Color(1,1,1):
		line = "[color=%s]%s[/color]" % [color.to_html(false), msg]
	log_view.append_text(line+"\n")
	log_view.scroll_following = true
	print(msg)

func _update_turn_order(actions: Array) -> void:
	if actions.is_empty():
		lbl_queue.text = "Turn order: --"
		return
	var parts: Array[String] = []
	for item in actions:
		var act: Action = item as Action
		if act==null:
			continue
		var actor_name: String = act.actor.name if act.actor else "?"
		var skill_name: String = String(act.skill.get("name","Action"))
		parts.append("%s (%s)" % [actor_name, skill_name])
	lbl_queue.text = "Turn order: "+" -> ".join(parts)

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
		hero_sprite.z_index = 1
		hero_sprite.set_facing_back(true)
	if enemy_sprite:
		enemy_sprite.modulate = _base_modulate_for(enemy)
		enemy_sprite.position = enemy_origin
		enemy_sprite.z_index = 1
		enemy_sprite.set_facing_back(false)
	if hero_shadow:
		hero_shadow.modulate = _shadow_color_for(hero)
		hero_shadow.scale = hero_shadow_base
	if enemy_shadow:
		enemy_shadow.modulate = _shadow_color_for(enemy)
		enemy_shadow.scale = enemy_shadow_base

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
		return Color(0,0,0,0.2)
	return Color(0,0,0,0.45) if u.is_alive() else Color(0,0,0,0.2)

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

func _refresh_plan_label() -> void:
	if plan_label==null:
		return
	plan_label.text = "Planned: --" if battle_finished or planned_actions.is_empty() else "Planned: %s" % String(planned_actions[0].skill.get("name","Action"))

func _refresh_end_turn_button() -> void:
	if btn_end:
		btn_end.disabled = battle_finished or planned_actions.is_empty()

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
	_disable_inputs()
	planned_actions.clear()
	_refresh_plan_label()
	_refresh_end_turn_button()
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
	t.finished.connect(_lock_input_after_battle)

func _lock_input_after_battle() -> void:
	keyboard_end_turn_enabled = false
