extends Node2D

const Action := preload("res://battle/models/Action.gd")
const Unit := preload("res://battle/models/Unit.gd")
const Formula := preload("res://battle/Formula.gd")
const TurnEngine := preload("res://battle/TurnEngine.gd")
const SpriteFactory := preload("res://art/SpriteFactory.gd")
const DAMAGE_POPUP := preload("res://ui/DamagePopup.tscn")

@export var keyboard_end_turn_enabled: bool = true

@onready var lbl_hero: Label = $UI/HUD/VBox/HeroRow/HeroLabel
@onready var hero_status_container: HBoxContainer = $UI/HUD/VBox/HeroRow/HeroStatus
@onready var lbl_enemy: Label = $UI/HUD/VBox/EnemyRow/EnemyLabel
@onready var enemy_status_container: HBoxContainer = $UI/HUD/VBox/EnemyRow/EnemyStatus
@onready var plan_label: Label = $UI/HUD/VBox/PlanLabel
@onready var btn_attack: Button = $UI/HUD/VBox/Buttons/Attack
@onready var btn_fire: Button = $UI/HUD/VBox/Buttons/Fireball
@onready var btn_potion: Button = $UI/HUD/VBox/Buttons/Potion
@onready var btn_end: Button = $UI/HUD/VBox/Buttons/EndTurn
@onready var lbl_queue: Label = $UI/HUD/VBox/TurnOrderLabel
@onready var log_view: RichTextLabel = $UI/HUD/VBox/Log
@onready var hero_sprite: Sprite2D = $Stage/HeroSprite
@onready var enemy_sprite: Sprite2D = $Stage/EnemySprite
@onready var hero_shadow: Sprite2D = $Stage/HeroShadow
@onready var enemy_shadow: Sprite2D = $Stage/EnemyShadow
@onready var popups_container: Control = $FX/Popups
@onready var overlay_fade: ColorRect = $Overlay/Fade
@onready var overlay_title: Label = $Overlay/CenterContainer/VBoxContainer/Label
@onready var overlay_subtitle: Label = $Overlay/CenterContainer/VBoxContainer/Label2

var hero: Unit
var enemy: Unit
var planned_actions: Array[Action] = []
var turn_engine: TurnEngine
var potion_used: bool = false
var battle_finished: bool = false

var skill_slash: Dictionary = {}
var skill_fireball: Dictionary = {}

const POTION_HEAL_PCT := 0.30

var hero_origin: Vector2 = Vector2.ZERO
var enemy_origin: Vector2 = Vector2.ZERO
var hero_shadow_base: Vector2 = Vector2.ONE
var enemy_shadow_base: Vector2 = Vector2.ONE
var status_icon_cache: Dictionary[String, Texture2D] = {}
var sfx_streams: Dictionary[String, AudioStream] = {}

func _ready() -> void:
	print("BattleScene _ready()")
	skill_slash = _fetch_skill("slash")
	skill_fireball = _fetch_skill("fireball")

	hero = _build_unit_from_character("adept_pyro")
	enemy = _build_unit_from_enemy("goblin")

	turn_engine = TurnEngine.new()
	add_child(turn_engine)

	hero_sprite.texture = SpriteFactory.make_humanoid("adept", 6)
	hero_sprite.centered = true
	hero_sprite.z_index = 1
	enemy_sprite.texture = SpriteFactory.make_monster("goblin", 6)
	enemy_sprite.centered = true
	enemy_sprite.flip_h = true
	enemy_sprite.z_index = 1

	hero_shadow.texture = SpriteFactory.make_shadow(64, 18)
	hero_shadow.centered = true
	hero_shadow.z_index = 0
	hero_shadow.scale = Vector2(1.25, 0.85)
	enemy_shadow.texture = SpriteFactory.make_shadow(64, 18)
	enemy_shadow.centered = true
	enemy_shadow.z_index = 0
	enemy_shadow.scale = Vector2(1.35, 0.9)

	hero_origin = hero_sprite.position
	enemy_origin = enemy_sprite.position
	hero_shadow_base = hero_shadow.scale
	enemy_shadow_base = enemy_shadow.scale

	_update_sprites()
	_refresh_plan_label()
	_refresh_end_turn_button()
	refresh_status_hud()
	$Overlay.visible = false
	overlay_fade.modulate.a = 0.0
	log_view.bbcode_enabled = true

	sfx_streams = {
		"hit": _make_tone(420.0, 0.14, 0.35),
		"crit": _make_tone(660.0, 0.2, 0.4),
		"miss": _make_tone(240.0, 0.16, 0.3)
	}

	btn_attack.tooltip_text = "Basic attack. No MP."
	btn_fire.tooltip_text = "Spell attack. Costs MP."
	btn_potion.tooltip_text = "Consume a potion to restore HP."
	btn_end.tooltip_text = "Resolve the queued actions."
	btn_end.disabled = true

	btn_attack.pressed.connect(_on_attack)
	btn_fire.pressed.connect(_on_fireball)
	btn_potion.pressed.connect(_on_potion)
	btn_end.pressed.connect(_on_end_turn)

	_log("Battle starts! Pyro Adept vs Goblin")
	_update_ui()
	_update_turn_order([])

func _on_attack() -> void:
	if battle_finished:
		return
	_queue_hero_action(skill_slash)

func _on_fireball() -> void:
	if battle_finished:
		return
	var cost: int = int(skill_fireball.get("mp_cost", 0))
	if int(hero.stats.get("MP", 0)) >= cost:
		_queue_hero_action(skill_fireball)
	else:
		_log("Not enough MP for Fireball!")

func _on_potion() -> void:
	if battle_finished:
		return
	if potion_used:
		_log("The potion bottle is empty.")
		return
	var current_hp: int = int(hero.stats.get("HP", 0))
	var max_hp: int = int(hero.max_stats.get("HP", current_hp))
	if current_hp >= max_hp:
		_log("HP is already full!")
		return
	var heal_amount: int = int(ceil(max_hp * POTION_HEAL_PCT))
	var restored: int = hero.heal(heal_amount)
	potion_used = true
	btn_potion.disabled = true
	_log("Hero uses Potion and heals %d HP." % restored)
	_update_ui()
	_refresh_end_turn_button()

func _queue_hero_action(skill: Dictionary) -> void:
	planned_actions.clear()
	var skill_copy: Dictionary = skill.duplicate(true)
	planned_actions.append(Action.new(hero, skill_copy, enemy))
	_log("Planned: %s" % skill_copy.get("name", "Action"))
	_refresh_plan_label()
	_refresh_end_turn_button()

func _on_end_turn() -> void:
	if battle_finished:
		return
	if !hero.is_alive() or !enemy.is_alive():
		return
	if planned_actions.is_empty():
		_log("No action planned; defaulting to Slash.")
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
			var mp_cost: int = int(a.skill.get("mp_cost", 0))
			if mp_cost > 0:
				hero.spend_mp(mp_cost)

	for a in actions:
		if a.actor == null or a.target == null:
			_log("Skipped action: missing actor/target")
			continue
		if !a.actor.is_alive():
			_log("%s is down and can't act." % a.actor.name)
			continue
		if !a.target.is_alive():
			_log("%s has no valid target." % a.actor.name)
			continue
		var tag: String = Formula.element_tag(a.actor, a.target, a.skill)
		var result: Dictionary = turn_engine.execute(a)
		if result.get("hit", false):
			var crit_text := " CRIT!" if result.get("crit", false) else ""
			var damage: int = int(result.get("damage", 0))
			var damage_color: Color = Color(1, 1, 1)
			if result.get("crit", false):
				damage_color = Color(1.0, 0.85, 0.2)
			if tag == "[WEAK]":
				damage_color = Color(1.0, 0.5, 0.25)
			elif tag == "[RESIST]":
				damage_color = Color(0.55, 0.75, 1.0)
			var damage_bbcode := "[color=%s]%d[/color]" % [damage_color.to_html(false), damage]
			var tag_bbcode := ""
			if not tag.is_empty():
				var tag_clean := tag.replace("[", "").replace("]", "")
				var tag_color := damage_color
				tag_bbcode = " [color=%s][%s][/color]" % [tag_color.to_html(false), tag_clean]
			var crit_bbcode := ""
			if result.get("crit", false):
				crit_bbcode = " [color=%s]CRIT![/color]" % Color(1.0, 0.85, 0.2).to_html(false)
			var skill_name := String(a.skill.get("name", "Skill"))
			var msg := "%s uses %s for %s%s%s" % [a.actor.name, skill_name, damage_bbcode, tag_bbcode, crit_bbcode]
			_log(msg, Color.WHITE, true)
		else:
			var miss_msg := "%s uses %s - [color=%s]Miss![/color]" % [
				a.actor.name,
				String(a.skill.get("name", "Skill")),
				Color(0.7, 0.7, 0.7).to_html(false)
			]
			_log(miss_msg, Color.WHITE, true)
		var target_sprite := _sprite_for_unit(a.target)
		if result.get("hit", false):
			var damage: int = int(result.get("damage", 0))
			var crit := bool(result.get("crit", false))
			play_sfx("crit" if crit else "hit")
			spawn_damage_popup(target_sprite, damage, crit, false)
		else:
			play_sfx("miss")
			spawn_damage_popup(target_sprite, 0, false, true)
		await _play_attack_animation(a, result)
		if result.get("hit", false):
			for status_line in result.get("status_logs", []):
				_log(status_line, Color(0.55, 0.8, 1.0))
		_update_ui()

	var tick_logs: Array[String] = turn_engine.end_of_round_tick([hero, enemy])
	for line in tick_logs:
		var tick_color: Color = Color(0.8, 0.8, 0.8)
		if line.find("burn") != -1:
			tick_color = Color(1.0, 0.5, 0.25)
		elif line.find("poison") != -1:
			tick_color = Color(0.6, 0.9, 0.4)
		_log(line, tick_color)

	planned_actions.clear()
	_check_end()
	_update_ui()
	_update_turn_order([])
	_refresh_plan_label()
	_refresh_end_turn_button()

func _unhandled_input(event: InputEvent) -> void:
	if battle_finished:
		return
	if event.is_action_pressed("ui_action_1"):
		_on_attack()
	elif event.is_action_pressed("ui_action_2"):
		_on_fireball()
	elif event.is_action_pressed("ui_action_3"):
		_on_potion()
	elif event.is_action_pressed("ui_action_4") and keyboard_end_turn_enabled:
		_on_end_turn()

func _check_end() -> void:
	if battle_finished:
		return
	if !enemy.is_alive():
		_log("Victory! Goblin is defeated.")
		show_battle_result(true, 0, [])
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
	lbl_hero.text = "Hero: %s  HP %d/%d  MP %d/%d" % [
		hero.name,
		hero.stats.get("HP", 0),
		hero.max_stats.get("HP", 0),
		hero.stats.get("MP", 0),
		hero.max_stats.get("MP", 0)
	]
	lbl_enemy.text = "Enemy: %s  HP %d/%d" % [
		enemy.name,
		enemy.stats.get("HP", 0),
		enemy.max_stats.get("HP", 0)
	]
	_update_sprites()
	refresh_status_hud()
	_refresh_plan_label()
	_refresh_end_turn_button()

func _log(msg: String, color: Color = Color(1, 1, 1), rich: bool = false) -> void:
	var line := msg
	if not rich and color != Color(1, 1, 1):
		line = "[color=%s]%s[/color]" % [color.to_html(false), msg]
	log_view.append_text(line + "\n")
	log_view.scroll_following = true
	print(msg)

func _update_turn_order(actions: Array) -> void:
	if actions.is_empty():
		lbl_queue.text = "Turn order: --"
		return
	var parts: Array[String] = []
	for item in actions:
		var act: Action = item as Action
		if act == null:
			continue
		var actor_name: String = act.actor.name if act.actor != null else "?"
		var skill_name := String(act.skill.get("name", "Action"))
		parts.append("%s (%s)" % [actor_name, skill_name])
	lbl_queue.text = "Turn order: " + " -> ".join(parts)

func _fetch_skill(id: String) -> Dictionary:
	if DataRegistry.skills.has(id):
		return DataRegistry.skills[id].duplicate(true)
	return {
		"id": id,
		"name": id.capitalize(),
		"type": "damage",
		"stat": "ATK",
		"power": 1.0,
		"acc": 0.95,
		"crit": 0.05,
		"element": "earth",
		"mp_cost": 0,
		"effects": []
	}

func _build_unit_from_character(id: String) -> Unit:
	var def: Dictionary = DataRegistry.characters.get(id, {})
	if def.is_empty():
		def = {
			"name": "Pyro Adept",
			"stats": {"max_hp": 90, "max_mp": 40, "atk": 10, "def": 8, "agi": 12, "focus": 16},
			"resist": {"fire": 0.5, "water": 1.5, "earth": 1.0, "air": 1.0}
		}
	return _build_unit(def)

func _build_unit_from_enemy(id: String) -> Unit:
	var def: Dictionary = DataRegistry.enemies.get(id, {})
	if def.is_empty():
		def = {
			"name": "Goblin",
			"stats": {"max_hp": 70, "max_mp": 0, "atk": 12, "def": 6, "agi": 10, "focus": 6},
			"resist": {"fire": 1.0, "water": 1.0, "earth": 1.0, "air": 1.0}
		}
	return _build_unit(def)

func _build_unit(def: Dictionary) -> Unit:
	var unit: Unit = Unit.new()
	unit.name = String(def.get("name", "Unit"))
	var stats_dict: Dictionary = def.get("stats", {})
	var max_hp: int = int(stats_dict.get("max_hp", 80))
	var max_mp: int = int(stats_dict.get("max_mp", 0))
	unit.max_stats = {"HP": max_hp, "MP": max_mp}
	unit.stats = {
		"HP": max_hp,
		"MP": max_mp,
		"ATK": int(stats_dict.get("atk", 10)),
		"DEF": int(stats_dict.get("def", 8)),
		"AGI": int(stats_dict.get("agi", 10)),
		"FOCUS": int(stats_dict.get("focus", 8))
	}
	var resist_dict: Dictionary = def.get("resist", {})
	unit.resist = {
		"fire": float(resist_dict.get("fire", 1.0)),
		"water": float(resist_dict.get("water", 1.0)),
		"earth": float(resist_dict.get("earth", 1.0)),
		"air": float(resist_dict.get("air", 1.0))
	}
	return unit

func _update_sprites() -> void:
	hero_sprite.modulate = _base_modulate_for(hero)
	enemy_sprite.modulate = _base_modulate_for(enemy)
	hero_shadow.modulate = _shadow_color_for(hero)
	enemy_shadow.modulate = _shadow_color_for(enemy)
	hero_shadow.scale = hero_shadow_base
	enemy_shadow.scale = enemy_shadow_base
	hero_sprite.position = hero_origin
	enemy_sprite.position = enemy_origin

func _sprite_for_unit(unit: Unit) -> Sprite2D:
	if unit == hero:
		return hero_sprite
	if unit == enemy:
		return enemy_sprite
	return null

func _shadow_for_unit(unit: Unit) -> Sprite2D:
	if unit == hero:
		return hero_shadow
	if unit == enemy:
		return enemy_shadow
	return null

func _origin_for_unit(unit: Unit) -> Vector2:
	if unit == hero:
		return hero_origin
	if unit == enemy:
		return enemy_origin
	return Vector2.ZERO

func _shadow_base_scale(unit: Unit) -> Vector2:
	if unit == hero:
		return hero_shadow_base
	if unit == enemy:
		return enemy_shadow_base
	return Vector2.ONE

func _attack_offset(unit: Unit) -> Vector2:
	if unit == hero:
		return Vector2(90, -18)
	if unit == enemy:
		return Vector2(-90, -12)
	return Vector2.ZERO

func _base_modulate_for(unit: Unit) -> Color:
	if unit == null:
		return Color.WHITE
	return Color.WHITE if unit.is_alive() else Color(0.5, 0.5, 0.5, 0.6)

func _shadow_color_for(unit: Unit) -> Color:
	if unit == null:
		return Color(0, 0, 0, 0.2)
	return Color(0, 0, 0, 0.45) if unit.is_alive() else Color(0, 0, 0, 0.2)

func _play_attack_animation(action: Action, result: Dictionary) -> void:
	var actor_sprite := _sprite_for_unit(action.actor)
	if actor_sprite == null:
		return
	var actor_shadow := _shadow_for_unit(action.actor)
	var actor_origin := _origin_for_unit(action.actor)
	var shadow_base := _shadow_base_scale(action.actor)
	var dash_target := actor_origin + _attack_offset(action.actor)
	var tween := create_tween()
	tween.tween_property(actor_sprite, "position", dash_target, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if actor_shadow != null:
		tween.parallel().tween_property(actor_shadow, "scale", shadow_base * Vector2(1.2, 0.75), 0.12)
	tween.tween_property(actor_sprite, "position", actor_origin, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if actor_shadow != null:
		tween.parallel().tween_property(actor_shadow, "scale", shadow_base, 0.16)
	await tween.finished
	if result.get("hit", false) and result.get("damage", 0) > 0:
		await _shake_sprite(action.target)
	if result.get("hit", false):
		await _flash_sprite(action.target)

func _flash_sprite(unit: Unit) -> void:
	var sprite := _sprite_for_unit(unit)
	if sprite == null:
		return
	var base := _base_modulate_for(unit)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.6, 0.6, 1.0), 0.08)
	tween.tween_property(sprite, "modulate", base, 0.12)
	await tween.finished

func _shake_sprite(unit: Unit) -> void:
	var sprite := _sprite_for_unit(unit)
	if sprite == null:
		return
	var origin := _origin_for_unit(unit)
	var offset := Vector2(12, 0)
	if unit == enemy:
		offset.x = -offset.x
	var tween := create_tween()
	tween.tween_property(sprite, "position", origin + offset, 0.05)
	tween.tween_property(sprite, "position", origin - offset * 0.6, 0.07)
	tween.tween_property(sprite, "position", origin, 0.08)
	await tween.finished

func _refresh_plan_label() -> void:
	if plan_label == null:
		return
	if battle_finished or planned_actions.is_empty():
		plan_label.text = "Planned: --"
		return
	var next_action: Action = planned_actions[0]
	var skill_name := str(next_action.skill.get("name", "Action"))
	plan_label.text = "Planned: %s" % skill_name

func _refresh_end_turn_button() -> void:
	if btn_end == null:
		return
	btn_end.disabled = battle_finished or planned_actions.is_empty()

func refresh_status_hud() -> void:
	_populate_status_container(hero_status_container, hero)
	_populate_status_container(enemy_status_container, enemy)

func _populate_status_container(container: HBoxContainer, unit: Unit) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	if unit == null:
		return
	var seen: Dictionary = {}
	for status_name in unit.get_status_types():
		var key := String(status_name).to_lower()
		if seen.has(key):
			continue
		seen[key] = true
		var icon := TextureRect.new()
		icon.texture = _get_status_icon(key)
		icon.custom_min_size = Vector2(18, 18)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(icon)

func _get_status_icon(status_name: String) -> Texture2D:
	var key := status_name.to_lower()
	if not status_icon_cache.has(key):
		status_icon_cache[key] = SpriteFactory.make_status_icon(key)
	return status_icon_cache[key]

func spawn_damage_popup(node: Node2D, amount: int, crit: bool = false, miss: bool = false) -> void:
	if node == null or popups_container == null:
		return
	var popup_label: Label = DAMAGE_POPUP.instantiate() as Label
	if popup_label == null:
		return
	var world_pos: Vector2 = node.get_global_transform_with_canvas().origin
	var local_pos: Vector2 = popups_container.to_local(world_pos)
	var text: String
	if miss:
		text = "Miss"
	elif crit:
		text = "%d!" % amount
	else:
		text = str(amount)
	var color: Color
	if miss:
		color = Color(0.7, 0.7, 0.7)
	elif crit:
		color = Color(1.0, 0.85, 0.2)
	else:
		color = Color(1, 1, 1)
	popups_container.add_child(popup_label)
	popup_label.popup(local_pos + Vector2(-8, -16), text, color)

func play_sfx(kind: String) -> void:
	var stream: AudioStream = sfx_streams.get(kind, null) as AudioStream
	if stream == null:
		stream = sfx_streams.get("hit", null) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = $SFX
	player.stream = stream
	player.play()

func _make_tone(freq: float, duration: float, volume: float = 0.35) -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 44100
	sample.stereo = false
	var frame_count: int = max(1, int(duration * sample.mix_rate))
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for i in range(frame_count):
		var t: float = float(i) / sample.mix_rate
		var fade_in: float = min(1.0, t / 0.02)
		var fade_out: float = min(1.0, (duration - t) / 0.06)
		var env: float = min(fade_in, fade_out)
		var value := int(sin(TAU * freq * t) * volume * env * 32767.0)
		value = clamp(value, -32768, 32767)
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	sample.data = data
	sample.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return sample

func show_battle_result(victory: bool, xp: int = 0, loot: Array[String] = []) -> void:
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
	var loot_names: PackedStringArray = PackedStringArray()
	for entry in loot:
		loot_names.append(str(entry))
	var loot_text := "—" if loot_names.is_empty() else ", ".join(loot_names)
	overlay_subtitle.text = "XP +%d\nLoot: %s" % [xp, loot_text] if victory else "You fall in battle…"
	var tween := create_tween()
	tween.tween_property(overlay_fade, "modulate:a", 0.6, 0.4)
	tween.tween_interval(0.1)
	tween.finished.connect(_lock_input_after_battle)

func _lock_input_after_battle() -> void:
	keyboard_end_turn_enabled = false
