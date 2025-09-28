extends Node2D

# Minimal Golden Sun–style battle with HP/MP bars (no skills/items yet).
# Keys: 1 = Attack, 2 = Defend

const START_PLAYER := {
	"name": "Adept",
	"max_hp": 100, "hp": 100,
	"max_mp": 30,  "mp": 30,
	"atk": 24, "def": 8, "spd": 12
}
const START_ENEMY := {
	"name": "Goblin",
	"max_hp": 90, "hp": 90,
	"atk": 20, "def": 6, "spd": 10
}

# --- Party (player controls index 0 only for now) ---
var party := [
	{ "stats": {"name":"Adept","max_hp":100,"hp":100,"atk":24,"def":8,"spd":12,"max_mp":20,"mp":20},
	  "defending":false, "sprite": null,
	  "spells":[
		{"id":"fireball","name":"Fireball","type":"damage","power":2.0,"mp":6}
	  ]
	},
	{ "stats": {"name":"Rogue","max_hp":80,"hp":80,"atk":18,"def":7,"spd":16,"max_mp":0,"mp":0},
	  "defending":false, "sprite": null, "spells":[]
	},
	{ "stats": {"name":"Cleric","max_hp":90,"hp":90,"atk":12,"def":9,"spd":10,"max_mp":18,"mp":18},
	  "defending":false, "sprite": null,
	  "spells":[
		{"id":"mend","name":"Mend","type":"heal","ratio":0.30,"mp":5}
	  ]
	},
	{ "stats": {"name":"Guard","max_hp":120,"hp":120,"atk":14,"def":14,"spd":8,"max_mp":0,"mp":0},
	  "defending":false, "sprite": null, "spells":[]
	}
]

# --- Enemies ---
var wave := [
	{ "stats": {"name":"Goblin A","max_hp":90,"hp":90,"atk":16,"def":7,"spd":10}, "defending":false, "sprite": null },
	{ "stats": {"name":"Goblin B","max_hp":90,"hp":90,"atk":16,"def":7,"spd":9 }, "defending":false, "sprite": null }
]

var awaiting_player := true
var round := 1

# UI
var log_label: Label
var menu_label: Label
var hp_bar_player: ColorRect
var mp_bar_player: ColorRect
var hp_bar_enemy: ColorRect
var _log_lines: Array[String] = []
const MAX_LOG := 8

@onready var formula = preload("res://scripts/Formula.gd").new()
@onready var ai = preload("res://scripts/AIController.gd").new()
@onready var overlay: CanvasLayer = CanvasLayer.new()
@onready var cmd_layer: CanvasLayer = CanvasLayer.new()

# --- layout (tuned for 1152x648 window) ---
const ENEMY_SLOTS := [Vector2(420, 180), Vector2(730, 180)]
const PARTY_SLOTS := [Vector2(480, 460), Vector2(600, 460), Vector2(720, 460), Vector2(840, 460)]
const BAR_SIZE    := Vector2(110, 8)

# --- Command Menu layout ---
const MENU_POS := Vector2(780, 90)  # top-right position for 1152x648

var cmd_root: Control = null
var cmd_title: Label = null
var cmd_char: Label = null
var btn_attack: Button = null
var btn_spells: Button = null
var btn_items:  Button = null
var btn_defend: Button = null
var menu_visible: bool = false

var spells_root: Control = null
var spells_list: VBoxContainer = null
var current_actor_index: int = 0

# --- Target Menu ---
var target_root: Control = null
var target_list: VBoxContainer = null
var target_candidates: Array = []
var pending_spell: Dictionary = {}
var pending_caster_index: int = 0

# --- Declare phase state ---
var declare_allies: Array = []          # living party members this round
var planned_actions: Array = []         # [{team, actor, action, target?}, ...]
var declare_index: int = 0              # which ally is being commanded (0..)

func _ready() -> void:
	randomize()

	var viewport_size := get_viewport_rect().size
	var W := viewport_size.x
	var H := viewport_size.y

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10)
	bg.size = viewport_size
	add_child(bg)

	var floor := ColorRect.new()
	floor.color = Color(0.06, 0.07, 0.09)
	floor.size = Vector2(W, H * 0.4)
	floor.position = Vector2(0, H * 0.6)
	add_child(floor)

	add_child(overlay)
	_layout_units()         # spawn sprites & overlays at the desired positions
	_update_all_overlays()  # set initial HP text/bars
	add_child(cmd_layer)
	_build_command_menu()
	_build_spells_menu()
	_build_target_menu()

	if "adept" in DataRegistry.characters:
		party[0].stats = DataRegistry.characters["adept"]
		party[0].stats["hp"] = party[0].stats.get("max_hp", 100)

	# wave stats are now assigned in RunManager

	var ui := CanvasLayer.new(); add_child(ui)

	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 16)
	log_label.modulate = Color(0.87, 0.90, 0.96)
	log_label.size = Vector2(W - 24, H * 0.5)
	log_label.position = Vector2(12, 12)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	ui.add_child(log_label)

	menu_label = Label.new()
	menu_label.add_theme_font_size_override("font_size", 16)
	menu_label.modulate = Color(0.97, 0.91, 0.63)
	menu_label.position = Vector2(W - 12, H - 72)
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(menu_label)

	_log("Battle start! %s vs %s" % [party[0].stats.name, wave[0].stats.name])
	_start_round_declare()

func _start_round_declare() -> void:
	planned_actions.clear()
	declare_allies = _alive(party)
	declare_index = 0
	if declare_allies.is_empty():
		return
	_prompt_next_actor()

func _prompt_next_actor() -> void:
	if declare_index >= declare_allies.size():
		_commit_declare_phase()
		return
	var a: Dictionary = declare_allies[declare_index]
	_show_command_menu(String(a["stats"]["name"]))
	current_actor_index = party.find(a)

func _build_command_menu() -> void:
	# Root
	cmd_root = Control.new()
	cmd_root.visible = false
	cmd_root.position = MENU_POS
	cmd_root.size = Vector2(360, 230)
	cmd_layer.add_child(cmd_root)

	# Panel-ish background
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.85, 0.85, 0.85, 0.95)
	panel.size = cmd_root.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	cmd_root.add_child(panel)

	# Inner container
	var inner: MarginContainer = MarginContainer.new()
	inner.offset_left = 0
	inner.offset_top = 0
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_bottom", 12)
	inner.size = cmd_root.size
	cmd_root.add_child(inner)

	var vbox: VBoxContainer = VBoxContainer.new()
	inner.add_child(vbox)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	cmd_title = Label.new()
	cmd_title.text = "Actions"
	cmd_title.add_theme_font_size_override("font_size", 28)
	header.add_child(cmd_title)

	cmd_char = Label.new()
	cmd_char.text = "  Character"
	cmd_char.add_theme_color_override("font_color", Color(0.92, 0.72, 0.08))
	cmd_char.add_theme_font_size_override("font_size", 20)
	header.add_child(cmd_char)
	header.add_spacer(false)

	# Separator
	var sep: ColorRect = ColorRect.new()
	sep.color = Color(0,0,0,0.25)
	sep.size = Vector2(999, 2)
	vbox.add_child(sep)

	# Grid: 2x2
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.custom_minimum_size = Vector2(0, 150)
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 26)
	vbox.add_child(grid)

	btn_attack = Button.new()
	btn_attack.text = "Attack"
	btn_attack.add_theme_font_size_override("font_size", 22)
	btn_attack.pressed.connect(_on_menu_attack)
	grid.add_child(btn_attack)

	btn_items = Button.new()
	btn_items.text = "Items"
	btn_items.add_theme_font_size_override("font_size", 22)
	btn_items.pressed.connect(_on_menu_items)
	grid.add_child(btn_items)

	btn_spells = Button.new()
	btn_spells.text = "Spells"
	btn_spells.add_theme_font_size_override("font_size", 22)
	btn_spells.pressed.connect(_on_menu_spells)
	grid.add_child(btn_spells)

	btn_defend = Button.new()
	btn_defend.text = "Defend"
	btn_defend.add_theme_font_size_override("font_size", 22)
	btn_defend.pressed.connect(_on_menu_defend)
	grid.add_child(btn_defend)

	# Rounded corners look
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel.color
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", sb)

func _build_spells_menu() -> void:
	spells_root = Control.new()
	spells_root.visible = false
	spells_root.position = MENU_POS + Vector2(-8, 230)
	spells_root.size = Vector2(360, 220)
	cmd_layer.add_child(spells_root)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.85, 0.85, 0.85, 0.95)
	panel.size = spells_root.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel.color
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", sb)
	spells_root.add_child(panel)

	var inner: MarginContainer = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	inner.size = spells_root.size
	spells_root.add_child(inner)

	var vbox: VBoxContainer = VBoxContainer.new()
	inner.add_child(vbox)

	var title := Label.new()
	title.text = "Spells"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	spells_list = VBoxContainer.new()
	spells_list.add_theme_constant_override("separation", 6)
	vbox.add_child(spells_list)

func _build_target_menu() -> void:
	target_root = Control.new()
	target_root.visible = false
	target_root.position = MENU_POS + Vector2(-8, 230)  # stack below main menu
	target_root.size = Vector2(360, 220)
	cmd_layer.add_child(target_root)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.85, 0.85, 0.85, 0.95)
	panel.size = target_root.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel.color
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", sb)
	target_root.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	inner.size = target_root.size
	target_root.add_child(inner)

	var vbox := VBoxContainer.new()
	inner.add_child(vbox)

	var title := Label.new()
	title.text = "Choose Target"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	target_list = VBoxContainer.new()
	target_list.add_theme_constant_override("separation", 6)
	vbox.add_child(target_list)

func _input(event: InputEvent) -> void:
	# Allow canceling target menu with ESC even when main menu is hidden
	if target_root != null and target_root.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_hide_target_menu()
			_show_command_menu(String(party[current_actor_index]["stats"]["name"]))
			return
	if not menu_visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_on_menu_attack()
			KEY_2, KEY_KP_2:
				_on_menu_items()
			KEY_3, KEY_KP_3:
				_on_menu_spells()
			KEY_4, KEY_KP_4:
				_on_menu_defend()

func _alive(units:Array) -> Array:
	return units.filter(func(u): return int(u["stats"]["hp"]) > 0)

func _is_team_dead(units:Array) -> bool:
	return _alive(units).is_empty()

func _pick_random(arr:Array) -> Dictionary:
	return arr[randi() % arr.size()]

func _find_cleric() -> Dictionary:
	for u in party:
		if int(u["stats"]["hp"]) > 0 and String(u["stats"]["name"]) == "Cleric":
			return u
	return {}

func _lowest_hp_ally() -> Dictionary:
	var alive := _alive(party)
	if alive.is_empty(): return {}
	alive.sort_custom(func(a, b):
		var ra = float(a["stats"]["hp"]) / float(a["stats"]["max_hp"])
		var rb = float(b["stats"]["hp"]) / float(b["stats"]["max_hp"])
		return ra < rb
	)
	return alive[0]

func _do_turn(player0_action: Dictionary) -> void:
	var plans: Array = []

	# Which ally acts via menu? (we use index 0 for now)
	current_actor_index = 0

	var allies := _alive(party)
	if allies.size() > 0:
		plans.append({"team":"party","actor":allies[current_actor_index],"action":player0_action})

	# Cleric heuristic (keep your existing 50% heal logic if present)
	var cleric := _find_cleric()
	if cleric.size() > 0:
		var target := _lowest_hp_ally()
		if target.size() > 0:
			var ratio := float(target["stats"]["hp"]) / float(target["stats"]["max_hp"])
			if ratio <= 0.5:
				plans.append({"team":"party","actor":cleric,"action":{"kind":"skill","skill":{"id":"mend","name":"Mend","type":"heal","ratio":0.30,"mp":5}}, "target":target})

	# Other allies auto attack (skip those already planned)
	for a in allies:
		var already := false
		for p in plans:
			if p.get("actor") == a:
				already = true; break
		if already: continue
		plans.append({"team":"party","actor":a,"action":{"kind":"attack"}})

	# Enemies auto attack
	var foes := _alive(wave)
	for e in foes:
		plans.append({"team":"wave","actor":e,"action":{"kind":"attack"}})

	# Initiative
	for p in plans:
		var spd:int = int(p["actor"]["stats"].get("spd", 10))
		p["init"] = spd + randi_range(0, int(spd * 0.25))
	plans.sort_custom(func(a, b): return a["init"] > b["init"])

	# Resolve
	for p in plans:
		if p["team"] == "party" and not p.has("target"):
			var tp = _alive(wave)
			if tp.is_empty(): break
			p["target"] = _pick_random(tp)
		elif p["team"] == "wave" and not p.has("target"):
			var tp = _alive(party)
			if tp.is_empty(): break
			p["target"] = _pick_random(tp)
		_resolve_action_team(p)
		if _is_team_dead(party) or _is_team_dead(wave):
			break

	_end_round()

func _resolve_action_team(p:Dictionary) -> void:
	var actor: Dictionary  = p["actor"]
	var target: Dictionary = p["target"]
	var act: Dictionary    = p["action"]
	var kind: String = String(act.get("kind","attack"))

	if kind == "defend":
		actor["defending"] = true
		_log("%s braces to defend!" % actor["stats"]["name"])
		_update_all_overlays()
		return

	if kind == "skill":
		var sp: Dictionary = act.get("skill", {})
		var mp_cost: int   = int(sp.get("mp", 0))
		var cur_mp: int    = int(actor["stats"].get("mp", 0))
		if mp_cost > cur_mp:
			_log("%s tried %s but lacks MP." % [actor["stats"]["name"], String(sp.get("name","Spell"))])
			return
		# pay MP
		actor["stats"]["mp"] = max(0, cur_mp - mp_cost)

		var stype := String(sp.get("type","damage"))
		if stype == "heal":
			var t: Dictionary = p["target"] if p.has("target") else actor
			var maxhp: int = int(t["stats"]["max_hp"])
			var amount: int = int(ceil(maxhp * float(sp.get("ratio", 0.30))))
			t["stats"]["hp"] = min(maxhp, int(t["stats"]["hp"]) + amount)
			_log("%s casts %s and heals %s for %d." %
				[actor["stats"]["name"], String(sp.get("name","Spell")), t["stats"]["name"], amount])
			_update_all_overlays()
			return
		else:
			# damage spell: use higher power
			var atk:int = int(actor["stats"].get("atk", 10))
			var dfn:int = int(target["stats"].get("def", 10))
			var weak := false
			var crit := false
			var tgt_def := bool(target.get("defending", false))
			var power: float = float(sp.get("power", 2.0))
			var dmg:int = formula.damage(atk, dfn, power, crit, weak, tgt_def)
			target["stats"]["hp"] = max(0, int(target["stats"]["hp"]) - dmg)
			_log("%s casts %s! %s takes %d." %
				[actor["stats"]["name"], String(sp.get("name","Spell")), target["stats"]["name"], dmg])
			if int(target["stats"]["hp"]) == 0:
				_apply_death_visual(target)
			_update_all_overlays()
			return

	# default = basic attack
	var atk:int = int(actor["stats"].get("atk", 10))
	var dfn:int = int(target["stats"].get("def", 10))
	var weak := false
	var crit := false
	var tgt_def := bool(target.get("defending", false))
	var dmg:int = formula.damage(atk, dfn, 2.0, crit, weak, tgt_def)
	target["stats"]["hp"] = max(0, int(target["stats"]["hp"]) - dmg)
	_log("%s attacks! %s takes %d damage." % [actor["stats"]["name"], target["stats"]["name"], dmg])
	if int(target["stats"]["hp"]) == 0:
		_apply_death_visual(target)
	_update_all_overlays()

func _check_end() -> bool:
	if _is_team_dead(wave):
		_log("Victory! All foes defeated.")
		# heal +15% party
		for u in party:
			u["stats"]["hp"] = min(int(u["stats"]["max_hp"]),
				int(u["stats"]["hp"]) + int(u["stats"]["max_hp"] * 0.15))
		get_tree().change_scene_to_file("res://scenes/Fork.tscn")
		return true

	if _is_team_dead(party):
		_log("Defeat… your party falls.")
		get_tree().change_scene_to_file("res://scenes/Boot.tscn")
		return true

	return false

func _end_round() -> void:
    for p in party:
        p.defending = false
    for e in wave:
        e.defending = false
    round += 1
    _start_round_declare()

    _update_all_overlays()

func _finish_battle(winner: String) -> void:
	if winner == "player":
		_log("Victory! Preparing next foe…")
		# +15% HP heal
		party[0]["stats"]["hp"] = min(int(party[0]["stats"]["max_hp"]), int(party[0]["stats"]["hp"]) + int(party[0]["stats"]["max_hp"] * 0.15))
		get_tree().change_scene_to_file("res://scenes/Fork.tscn")
		return

func _commit_declare_phase() -> void:
    # Allies done; add AI enemies
    var foes := _alive(wave)
    for e in foes:
        planned_actions.append({"team":"wave","actor":e,"action":{"kind":"attack"}})

    # Initiative
    for p in planned_actions:
        var spd := int(p["actor"]["stats"].get("spd", 10))
        p["init"] = spd + randi_range(0, int(spd * 0.25))
    planned_actions.sort_custom(func(a,b): return a["init"] > b["init"])

    # Fill any missing targets
    for p in planned_actions:
        if not p.has("target"):
            if p["team"] == "party":
                var tp := _alive(wave)
                if tp.is_empty():
                    break
                p["target"] = _pick_random(tp)
            else:
                var tp := _alive(party)
                if tp.is_empty():
                    break
                p["target"] = _pick_random(tp)

    # Resolve
    for p in planned_actions:
        if _is_team_dead(party) or _is_team_dead(wave):
            break
        _resolve_action_team(p)

    _end_round()

func _show_command_menu(for_name: String) -> void:
	cmd_char.text = "  %s" % for_name
	cmd_root.visible = true
	menu_visible = true
	# focus default button
	btn_attack.grab_focus()

func _hide_command_menu() -> void:
	cmd_root.visible = false
	menu_visible = false

func _hide_spells_menu() -> void:
	spells_root.visible = false

func _populate_spells_for(actor: Dictionary) -> void:
	# Clear old buttons
	for c in spells_list.get_children():
		c.queue_free()

	var spells: Array = actor.get("spells", [])
	for i in spells.size():
		var sp: Dictionary = spells[i]
		var nm: String = String(sp.get("name", "Spell"))
		var mp_cost: int = int(sp.get("mp", 0))
		var btn := Button.new()
		btn.text = "%s   MP %d" % [nm, mp_cost]
		btn.add_theme_font_size_override("font_size", 20)
		var s := sp  # capture
		btn.pressed.connect(func(): _on_spell_chosen(s))
		spells_list.add_child(btn)

# --- Target helpers ---
func _show_target_menu(caster_idx: int, candidates: Array) -> void:
	pending_caster_index = caster_idx
	target_candidates = candidates.duplicate()
	for c in target_list.get_children():
		c.queue_free()

	# Build a button per candidate
	for i in target_candidates.size():
		var u: Dictionary = target_candidates[i]
		var name: String = String(u["stats"].get("name","?"))
		var hp: int = int(u["stats"].get("hp",0))
		var max_hp: int = int(u["stats"].get("max_hp",1))
		var btn := Button.new()
		btn.text = "%s   HP %d/%d" % [name, hp, max_hp]
		btn.add_theme_font_size_override("font_size", 20)
		var idx := i  # capture
		btn.pressed.connect(func(): _on_target_chosen(idx))
		target_list.add_child(btn)

	target_root.visible = true

func _hide_target_menu() -> void:
	target_root.visible = false
	target_candidates.clear()
	pending_spell.clear()

# --- Menu callbacks ---
func _on_menu_attack() -> void:
    _hide_command_menu(); _hide_spells_menu();
    _queue_player_action({"kind":"attack"})

func _on_menu_defend() -> void:
    _hide_command_menu(); _hide_spells_menu();
    _queue_player_action({"kind":"defend"})

func _on_menu_spells() -> void:
    # Show spells for the current acting ally (set by _prompt_next_actor)
    var actor: Dictionary = party[current_actor_index]
    _populate_spells_for(actor)
    spells_root.visible = true

func _on_spell_chosen(sp: Dictionary) -> void:
    # Decide valid target team based on spell type, then prompt targets
    _hide_command_menu(); spells_root.visible = false
    var stype: String = String(sp.get("type","damage"))
    if stype == "heal":
        _show_target_menu(current_actor_index, _alive(party))
    else:
        _show_target_menu(current_actor_index, _alive(wave))
    pending_spell = sp.duplicate()

func _on_target_chosen(idx: int) -> void:
    _hide_target_menu()
    var tgt: Dictionary = target_candidates[idx]
    _queue_player_action({"kind":"skill", "skill": pending_spell, "target": tgt})

func _queue_player_action(act: Dictionary) -> void:
    var actor = declare_allies[declare_index]
    var entry := {"team":"party","actor":actor,"action":act}
    if act.has("target"):
        entry["target"] = act["target"]
    planned_actions.append(entry)
    declare_index += 1
    _prompt_next_actor()

func _on_menu_items() -> void:
	# Placeholder for now; keep menu open
	_log("Items: not implemented yet.")

func _prompt_player() -> void:
	awaiting_player = true
	_log("Round %d: Choose an action (1: Attack, 2: Defend)" % round)
	_show_command_menu(String(party[0]["stats"]["name"]))

func _log(msg: String) -> void:
	_log_lines.append(msg)
	while _log_lines.size() > MAX_LOG:
		_log_lines.pop_front()
	log_label.text = "\n".join(_log_lines)

func _jab(sprite: Sprite2D, dir: int) -> void:
	var t := create_tween()
	t.tween_property(sprite, "position:x", sprite.position.x + 10.0 * dir, 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(sprite, "position:x", sprite.position.x, 0.08).set_trans(Tween.TRANS_SINE)
	await t.finished

func _slash_effect(pos: Vector2, dir: float) -> void:
	var s := Sprite2D.new()
	s.texture = _make_rect_tex(24, 6, Color.WHITE)
	s.rotation = deg_to_rad(15.0 * dir)
	s.global_position = pos + Vector2(-12.0 * dir, -28.0)
	s.modulate.a = 0.0
	add_child(s)
	var t := create_tween()
	t.tween_property(s, "modulate:a", 1.0, 0.06)
	t.tween_property(s, "modulate:a", 0.0, 0.06)
	await t.finished
	s.queue_free()

func _shake(duration: float, magnitude: float) -> void:
	var t := create_tween()
	var orig := position
	t.tween_property(self, "position", orig + Vector2(GameManager.randf()*magnitude, GameManager.randf()*magnitude), duration)
	t.tween_property(self, "position", orig, duration * 0.5)
	await t.finished

func _make_rect_tex(w: int, h: int, color: Color) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	return tex

# ---------- overlays (label + bar) ----------
func _make_square_texture(color: Color) -> Texture2D:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _spawn_unit_sprite(u: Dictionary, pos: Vector2, color: Color) -> void:
	var s: Sprite2D = u.get("sprite", null)
	if s == null or not is_instance_valid(s):
		s = Sprite2D.new()
		s.texture = _make_square_texture(color)
		add_child(s)
		u["sprite"] = s
	s.position = pos
	s.z_index = 0

	# Create HUD once
	if u.get("hud", null) == null:
		_create_unit_overlay(u)

func _layout_units() -> void:
	# enemies (top)
	for i in ENEMY_SLOTS.size():
		if i < wave.size():
			_spawn_unit_sprite(wave[i], ENEMY_SLOTS[i], Color(1.0, 0.45, 0.45))
	# party (bottom)
	for i in PARTY_SLOTS.size():
		if i < party.size():
			_spawn_unit_sprite(party[i], PARTY_SLOTS[i], Color(0.35, 0.95, 0.35))

# ---------- Overlays (HP label + bar) ----------
func _create_unit_overlay(u: Dictionary) -> void:
	var root: Control = Control.new()
	root.name = "HUD"
	root.size = Vector2(BAR_SIZE.x, 24)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = BAR_SIZE
	bg.position = Vector2(0, 16)
	root.add_child(bg)

	var fg: ColorRect = ColorRect.new()
	fg.name = "FG"
	fg.color = Color(0.3, 1.0, 0.3)
	fg.size = BAR_SIZE
	fg.position = Vector2(0, 16)
	root.add_child(fg)

	var lbl: Label = Label.new()
	lbl.name = "LBL"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size = Vector2(BAR_SIZE.x, 16)
	root.add_child(lbl)

	overlay.add_child(root)
	u["hud"] = root

func _update_unit_overlay(u: Dictionary) -> void:
	var s: Sprite2D = u.get("sprite", null)
	var hud: Control = u.get("hud", null)
	if s == null or hud == null:
		return

	# place HUD above the sprite (nudge up)
	hud.global_position = s.global_position + Vector2(-BAR_SIZE.x * 0.5, -60)

	# explicit types (avoid Variant warnings)
	var hp: int      = int(u["stats"].get("hp", 0))
	var max_hp: int  = int(u["stats"].get("max_hp", 1))
	var nm: String   = String(u["stats"].get("name", ""))
	var ratio: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)

	var lbl: Label = (hud.get_node("LBL") as Label)
	lbl.text = "%s  HP %d/%d" % [nm, hp, max_hp]

	var fg: ColorRect = (hud.get_node("FG") as ColorRect)
	fg.size = Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)

func _update_all_overlays() -> void:
	for u in party:
		_update_unit_overlay(u)
	for u in wave:
		_update_unit_overlay(u)

# Optional: gray out a dead unit
func _apply_death_visual(u: Dictionary) -> void:
	var s: Sprite2D = u.get("sprite", null)
	var hud: Control = u.get("hud", null)
	if s != null: s.modulate = Color(0.6, 0.6, 0.6, 0.9)
	if hud != null: hud.modulate = Color(0.7, 0.7, 0.7, 0.9)
