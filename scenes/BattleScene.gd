extends Node2D

const Unit          = preload("res://battle/models/Unit.gd")
const Action        = preload("res://battle/models/Action.gd")
const TurnEngine    = preload("res://battle/TurnEngine.gd")
const AnimatedFrames = preload("res://scripts/AnimatedFrames.gd")

const CHARACTER_ART := {
	"barbarian": "barbarian",
	"cleric_blue": "cleric_blue",
	"mage_red": "mage_red",
	"werewolf": "werewolf"
}

const HERO_POSITIONS  := [Vector2(320,760), Vector2(440,720), Vector2(560,780), Vector2(680,740)]
const ENEMY_POSITIONS := [Vector2(950,540), Vector2(1070,580), Vector2(1190,520), Vector2(1030,640)]
const HERO_SCALE  := Vector2(0.75,0.75)
const ENEMY_SCALE := Vector2(0.95,0.95)

@onready var hero_info_container: HBoxContainer  = $UI/HUD/PartyPanel/PartyMargin/PartyHBox
@onready var enemy_info_container: HBoxContainer = $UI/HUD/EnemyPanel/EnemyMargin/EnemyHBox
@onready var btn_attack: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Attack
@onready var btn_spells: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Spells
@onready var btn_items: Button  = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Items
@onready var btn_defend: Button = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/Buttons/Defend
@onready var spells_container: VBoxContainer = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/SpellsContainer
@onready var items_container: VBoxContainer  = $UI/HUD/ActionPanel/ActionMargin/ActionVBox/ItemsContainer
@onready var target_selector: Control = $UI/HUD/TargetSelector
@onready var overlay_fade: ColorRect = $Overlay/Fade
@onready var overlay_title: Label = $Overlay/CenterContainer/VBoxContainer/Label
@onready var overlay_subtitle: Label = $Overlay/CenterContainer/VBoxContainer/Label2

var heroes: Array[Unit] = []
var enemies: Array[Unit] = []
var hero_sprites: Array[AnimatedFrames] = []
var enemy_sprites: Array[AnimatedFrames] = []
var sprite_to_unit: Dictionary = {}
var planned_actions: Array[Action] = []
var turn_engine: TurnEngine
var current_hero_index := 0
var pending_skill: Dictionary = {}
var item_mode := false
var targeting_meta: Dictionary = {}
var battle_over := false

func _ready() -> void:
	turn_engine = TurnEngine.new()
	add_child(turn_engine)
	spells_container.hide()
	items_container.hide()
	target_selector.hide()
	_build_units()
	_build_sprites()
	_connect_buttons()
	_update_panels()
	_start_round()


func _build_units() -> void:
	var hero_ids = ["barbarian", "cleric_blue", "mage_red", "barbarian"]
	for i in range(hero_ids.size()):
		var def: Dictionary = DataRegistry.characters.get(hero_ids[i], {}) as Dictionary
		var u: Unit = _make_unit_from_def(def)
		if hero_ids.count(hero_ids[i]) > 1:
			u.name = "%s %s" % [u.name, String.chr(65 + i)]
		heroes.append(u)
	var enemy_ids = ["werewolf", "werewolf"]
	for i in range(enemy_ids.size()):
		var def_e: Dictionary = DataRegistry.enemies.get(enemy_ids[i], {}) as Dictionary
		var e: Unit = _make_unit_from_def(def_e)
		e.name = "%s %s" % [e.name, String.chr(65 + i)]
		enemies.append(e)

func _make_unit_from_def(def: Dictionary) -> Unit:
	if def.is_empty():
		def = {"name":"Unit","stats":{"max_hp":80,"max_mp":10,"atk":10,"def":8,"agi":10,"focus":8},"resist":{}}
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
		var spr := AnimatedFrames.new()
		spr.character = CHARACTER_ART.get("barbarian", "barbarian")
		spr.set_facing_back(true)
		stage.add_child(spr)
		spr.position = HERO_POSITIONS[min(i, HERO_POSITIONS.size()-1)]
		spr.scale = HERO_SCALE
		spr._build_frames(); spr._apply_orientation()
		spr.z_index = int(spr.position.y)
		hero_sprites.append(spr)
		sprite_to_unit[spr] = heroes[i]
	for i in range(enemies.size()):
		var spr_e := AnimatedFrames.new()
		spr_e.character = CHARACTER_ART.get("werewolf", "werewolf")
		spr_e.set_facing_back(false)
		stage.add_child(spr_e)
		spr_e.position = ENEMY_POSITIONS[min(i, ENEMY_POSITIONS.size()-1)]
		spr_e.scale = ENEMY_SCALE
		spr_e._build_frames(); spr_e._apply_orientation()
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

func _start_round() -> void:
	planned_actions.clear()
	current_hero_index = 0
	_show_action_ui_for_current()

func _show_action_ui_for_current() -> void:
	if current_hero_index >= heroes.size():
		_execute_round(); return
	if !heroes[current_hero_index].is_alive():
		current_hero_index += 1; _show_action_ui_for_current(); return
	spells_container.hide(); items_container.hide(); pending_skill = {}; item_mode = false

func _advance_to_next_hero() -> void:
	current_hero_index += 1
	_show_action_ui_for_current()

func _on_attack_pressed() -> void:
	if _hero_invalid(): return
	pending_skill = _get_skill("slash")
	_begin_target_selection(enemies.filter(func(e): return e.is_alive()))

func _on_spells_pressed() -> void:
	if _hero_invalid(): return
	if spells_container.visible:
		spells_container.hide(); return
	for c in spells_container.get_children(): c.queue_free()
	for k in DataRegistry.skills.keys():
		if k == "slash": continue
		var d := _get_skill(k)
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
		var count := int(RunManager.inventory[item_id])
		if count <= 0: continue
		var data := DataRegistry.get_item(item_id)
		if data.is_empty(): continue
		var b := Button.new()
		b.text = "%s (%d)" % [data.get("name", item_id), count]
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
	var defend := {"name":"Defend","power":0.0,"stat":"ATK","target":"self","acc":1.0,"crit":0.0}
	planned_actions.append(Action.new(hero, defend, hero))
	_log("%s defends." % hero.name)
	_advance_to_next_hero()

func _hero_invalid() -> bool:
	return battle_over or current_hero_index >= heroes.size() or !heroes[current_hero_index].is_alive()

func _begin_target_selection(units: Array[Unit]) -> void:
	var sprites: Array = []
	for u in units:
		var spr := _sprite_for(u)
		if spr: sprites.append(spr)
	if sprites.is_empty():
		_log("No valid targets."); return
	target_selector.start_selection(sprites)

func _on_target_confirmed(sprite: Node2D) -> void:
	var target: Unit = sprite_to_unit.get(sprite, null)
	if target == null: return
	var hero := heroes[current_hero_index]
	if item_mode:
		_apply_item(hero, target)
	else:
		_queue_skill_action(hero, target)
	_on_target_cancelled()
	_advance_to_next_hero()

func _on_target_cancelled() -> void:
	item_mode = false
	pending_skill = {}
	targeting_meta.clear()

func _queue_skill_action(hero: Unit, target: Unit) -> void:
	if pending_skill.is_empty():
		pending_skill = _get_skill("slash")
	planned_actions.append(Action.new(hero, pending_skill.duplicate(true), target))
	_log("%s prepares %s on %s" % [hero.name, pending_skill.get("name","Action"), target.name])

func _apply_item(hero: Unit, target: Unit) -> void:
	var data: Dictionary = targeting_meta.get("data", {})
	if data.is_empty(): return
	var item_type := String(data.get("type",""))
	if item_type == "healing":
		var pct := float(data.get("heal_percent", 0.0))
		var amt := int(target.max_stats.get("HP",0) * pct)
		var healed := target.heal(amt)
		_log("%s uses %s on %s (+%d HP)" % [hero.name, data.get("name","Item"), target.name, healed])
	elif item_type == "mana":
		var pctm := float(data.get("restore_percent", 0.0))
		var amtm := int(target.max_stats.get("MP",0) * pctm)
		var restored := target.restore_mp(amtm)
		_log("%s uses %s on %s (+%d MP)" % [hero.name, data.get("name","Item"), target.name, restored])
	RunManager.use_item(targeting_meta.get("item_id",""))

func _skill_targets(skill: Dictionary) -> Array[Unit]:
	var t := String(skill.get("target","enemy"))
	match t:
		"enemy":
			return enemies.filter(func(u): return u.is_alive())
		"hero":
			return heroes.filter(func(u): return u.is_alive())
		"self":
			return [heroes[current_hero_index]]
		_:
			return enemies.filter(func(u): return u.is_alive())

func _item_targets(data: Dictionary) -> Array[Unit]:
	return heroes.filter(func(u): return u.is_alive())

func _execute_round() -> void:
	for e in enemies:
		if !e.is_alive(): continue
		var living := heroes.filter(func(h): return h.is_alive())
		if living.is_empty(): break
		var target: Unit = living.pick_random()
		var slash := _get_skill("slash")
		planned_actions.append(Action.new(e, slash.duplicate(true), target))
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
	if container == null: return
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

func _check_battle_end() -> bool:
	var heroes_alive := heroes.any(func(h): return h.is_alive())
	var enemies_alive := enemies.any(func(e): return e.is_alive())
	if !heroes_alive or !enemies_alive:
		battle_over = true
		_show_result(heroes_alive)
		return true
	return false

func _show_result(victory: bool) -> void:
	$Overlay.visible = true
	overlay_fade.modulate.a = 0.6
	overlay_title.text = "Victory!" if victory else "Defeat"
	overlay_subtitle.text = ("XP +0\nLoot: --" if victory else "You fall in battle.")
	_log("Battle concluded: %s" % ("Victory" if victory else "Defeat"))

func _log(msg: String) -> void:
	print(msg)
