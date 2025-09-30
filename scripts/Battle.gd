extends Node2D

# Minimal Golden Sunâ€“style battle with HP/MP bars (no skills/items yet).
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
var party: Array[Dictionary] = [
	{ "stats": {"name":"Adept","max_hp":100,"hp":100,"atk":24,"def":8,"spd":12,"max_mp":20,"mp":20},
	  "defending":false, "sprite": null, "art":"hero:hero",
	  "spells":[
		{"id":"fireball","name":"Fireball","type":"damage","power":2.0,"mp":6}
	  ]
	},
	{ "stats": {"name":"Rogue","max_hp":80,"hp":80,"atk":18,"def":7,"spd":16,"max_mp":0,"mp":0},
	  "defending":false, "sprite": null, "art":"hero:rogue", "spells":[]
	},
	{ "stats": {"name":"Cleric","max_hp":90,"hp":90,"atk":12,"def":9,"spd":10,"max_mp":18,"mp":18},
	  "defending":false, "sprite": null, "art":"healer:healer",
	  "spells":[
		{"id":"mend","name":"Mend","type":"heal","ratio":0.30,"mp":5}
	  ]
	},
	{ "stats": {"name":"Guard","max_hp":120,"hp":120,"atk":14,"def":14,"spd":8,"max_mp":0,"mp":0},
	  "defending":false, "sprite": null, "art":"mage:mage", "spells":[]
	}
]

# --- Enemies ---
var wave: Array[Dictionary] = [
	{ "stats": {"name":"Goblin A","max_hp":90,"hp":90,"atk":16,"def":7,"spd":10}, "defending":false, "sprite": null, "art":"goblin" },
	{ "stats": {"name":"Goblin B","max_hp":90,"hp":90,"atk":16,"def":7,"spd":9 },  "defending":false, "sprite": null, "art":"goblin" }
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
const SpriteFactory := preload("res://art/SpriteFactory.gd")
const SpriteAnimator := preload("res://fx/SpriteAnimator.gd")
const AnimatedFrames := preload("res://scripts/AnimatedFrames.gd")

@onready var cmd: CommandMenu = preload("res://ui/CommandMenu.gd").new()

# --- layout (tuned for 1152x648 window) ---
const ENEMY_SLOTS := [Vector2(420, 180), Vector2(730, 180)]
const PARTY_SLOTS := [Vector2(480, 460), Vector2(600, 460), Vector2(720, 460), Vector2(840, 460)]
const BAR_SIZE    := Vector2(110, 8)

# --- Command Menu layout ---
const MENU_POS := Vector2(780, 90)  # top-right position for 1152x648

# --- Multi-target modes used by spells/items ---
const TM_ENEMY_ALL := "enemy_all"
const TM_ALLY_ALL  := "ally_all"
const TM_ENEMY_ONE := "enemy_one"
const TM_ALLY_ONE  := "ally_one"
const TM_SELF      := "self"

# --- Background layer (behind units) ---
@onready var bg_layer: CanvasLayer = CanvasLayer.new()
var bg_root: Node2D = Node2D.new()
var bg_sky: TextureRect
var bg_floor: ColorRect
var bg_clouds_far: ParallaxLayer
var bg_clouds_near: ParallaxLayer

# Palettes per biome
const BIOMES := {
	"forest": {
		"top": Color(0.09, 0.11, 0.16),
		"bottom": Color(0.12, 0.16, 0.22),
		"floor": Color(0.06, 0.07, 0.10, 0.95),
		"cloud": Color(0.22, 0.28, 0.35, 0.25)
	},
	"cave": {
		"top": Color(0.06, 0.07, 0.09),
		"bottom": Color(0.09, 0.10, 0.12),
		"floor": Color(0.03, 0.03, 0.05, 0.98),
		"cloud": Color(0.18, 0.18, 0.22, 0.18)
	},
	"ruins": {
		"top": Color(0.12, 0.12, 0.16),
		"bottom": Color(0.16, 0.16, 0.20),
		"floor": Color(0.07, 0.07, 0.10, 0.96),
		"cloud": Color(0.35, 0.32, 0.28, 0.22)
	},
	"desert": {
		"top": Color(0.20, 0.18, 0.14),
		"bottom": Color(0.26, 0.22, 0.16),
		"floor": Color(0.15, 0.12, 0.09, 0.96),
		"cloud": Color(0.40, 0.36, 0.28, 0.18)
	}
}

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
var target_candidates: Array[Dictionary] = []
var pending_spell: Dictionary = {}
var pending_item: Dictionary = {}
var pending_mode: String = ""
var pending_caster_index: int = 0

# --- Items Menu ---
var items_root: Control = null
var items_list: VBoxContainer = null

# Simple party inventory
var inventory: Dictionary = {
	"potion": {"id":"potion","name":"Potion","type":"heal","amount":40,"qty":3},
	"ether":  {"id":"ether","name":"Ether","type":"mp","amount":10,"qty":2}
}

# --- Declare phase state ---
var declare_allies: Array[Dictionary] = []          # living party members this round
var planned_actions: Array[Dictionary] = []         # [{team, actor, action, target?}, ...]
var declare_index: int = 0              # which ally is being commanded (0..)

# --- Turn Queue Panel ---
var queue_root: Control = null
var queue_box: VBoxContainer = null
var queue_rows: Array[Label] = []

func _ready() -> void:
	randomize()

	var viewport_size := get_viewport_rect().size
	var W := viewport_size.x
	var H := viewport_size.y

	# Background (procedural)
	add_child(bg_layer)
	_build_background("forest")

	add_child(overlay)
	_layout_units()         # spawn sprites & overlays at the desired positions
	_update_all_overlays()  # set initial HP text/bars
	add_child(cmd_layer)
	_build_command_menu()
	_build_spells_menu()
	_build_target_menu()
	_build_items_menu()
	_build_queue_panel()

	# New command menu UI
	cmd.visible = false
	cmd.menu_action.connect(_on_cmd_action)
	cmd_layer.add_child(cmd)

	if "adept_pyro" in DataRegistry.characters:
		party[0].stats = DataRegistry.characters["adept_pyro"]["stats"]
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

	_log("Battle start! %s vs %s" % [party[0].stats["name"], wave[0].stats["name"]])
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
	# Use new CommandMenu UI
	var actor_name: String = String(a["stats"].get("name", "Adept"))
	var spells_arr: Array = a.get("spells", [])
	# Map to include mp_cost for display if missing
	var spells_for_menu: Array = []
	for s in spells_arr:
		var sd: Dictionary = (s as Dictionary).duplicate(true)
		if not sd.has("mp_cost") and sd.has("mp"):
			sd["mp_cost"] = int(sd.get("mp", 0))
		spells_for_menu.append(sd)
	var items_for_menu: Array = _menu_items_for_actor(a)
	cmd.show_for_actor(actor_name, spells_for_menu, items_for_menu)
	current_actor_index = party.find(a)

func _infer_target_mode(kind: String, payload: Dictionary) -> String:
	# If the payload (spell/item) declares an explicit target, honor it
	if payload.has("target"):
		var t := String(payload["target"])
		if t == TM_ENEMY_ALL or t == TM_ALLY_ALL or t == TM_ENEMY_ONE or t == TM_ALLY_ONE or t == TM_SELF:
			return t
	# Fallbacks by type
	if kind == "skill":
		var stype := String(payload.get("type", "damage"))
		return TM_ALLY_ONE if stype == "heal" else TM_ENEMY_ONE
	if kind == "item":
		var itype := String(payload.get("type", "heal"))
		match itype:
			"heal", "mp", "boost":
				return TM_ALLY_ONE
			"damage":
				return TM_ENEMY_ONE
			_:
				return TM_ALLY_ONE
	return TM_ENEMY_ONE

func _expand_multi_targets(actions: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in actions:
		# If target already set explicitly, keep as-is
		if a.has("target"):
			out.append(a)
			continue

		var act: Dictionary = (a.get("action", {}) as Dictionary)
		var kind: String = String(act.get("kind", "attack"))
		var team: String = String(a.get("team", "party"))

		# Only skills/items have multi-target; attack stays one
		if kind == "skill":
			var sp: Dictionary = (act.get("skill", {}) as Dictionary)
			var mode := _infer_target_mode("skill", sp)
			match mode:
				TM_ENEMY_ALL:
					var enemies: Array[Dictionary] = _alive(wave) if team == "party" else _alive(party)
					for t in enemies:
						var dup := a.duplicate(true)
						dup["target"] = t
						out.append(dup)
				TM_ALLY_ALL:
					var allies: Array[Dictionary] = _alive(party) if team == "party" else _alive(wave)
					for t in allies:
						var dup2 := a.duplicate(true)
						dup2["target"] = t
						out.append(dup2)
				TM_SELF:
					var dup3 := a.duplicate(true)
					dup3["target"] = a["actor"]
					out.append(dup3)
				_:
					out.append(a) # will set single target later
		elif kind == "item":
			var it: Dictionary = (act.get("item", {}) as Dictionary)
			var mode2 := _infer_target_mode("item", it)
			match mode2:
				TM_ENEMY_ALL:
					var enemies2: Array[Dictionary] = _alive(wave) if team == "party" else _alive(party)
					for t2 in enemies2:
						var idup := a.duplicate(true)
						idup["target"] = t2
						out.append(idup)
				TM_ALLY_ALL:
					var allies2: Array[Dictionary] = _alive(party) if team == "party" else _alive(wave)
					for t3 in allies2:
						var idup2 := a.duplicate(true)
						idup2["target"] = t3
						out.append(idup2)
				TM_SELF:
					var idup3 := a.duplicate(true)
					idup3["target"] = a["actor"]
					out.append(idup3)
				_:
					out.append(a)
		else:
			out.append(a)
	return out

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

func _build_items_menu() -> void:
	items_root = Control.new()
	items_root.visible = false
	items_root.position = MENU_POS + Vector2(-8, 230)
	items_root.size = Vector2(360, 220)
	cmd_layer.add_child(items_root)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.85, 0.85, 0.85, 0.95)
	panel.size = items_root.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel.color
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", sb)
	items_root.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	inner.size = items_root.size
	items_root.add_child(inner)

	var vbox := VBoxContainer.new()
	inner.add_child(vbox)

	var title := Label.new()
	title.text = "Items"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	items_list = VBoxContainer.new()
	items_list.add_theme_constant_override("separation", 6)
	vbox.add_child(items_list)

func _build_queue_panel() -> void:
	queue_root = Control.new()
	queue_root.visible = false
	queue_root.position = Vector2(24, 90)      # top-left
	queue_root.size = Vector2(240, 260)
	cmd_layer.add_child(queue_root)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.1, 0.65)
	panel.size = queue_root.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel.color
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", sb)
	queue_root.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 10)
	inner.add_theme_constant_override("margin_right", 10)
	inner.add_theme_constant_override("margin_top", 8)
	inner.add_theme_constant_override("margin_bottom", 8)
	inner.size = queue_root.size
	queue_root.add_child(inner)

	var vbox := VBoxContainer.new()
	inner.add_child(vbox)

	var title := Label.new()
	title.text = "Turn Queue"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var sep := ColorRect.new()
	sep.color = Color(1,1,1,0.15)
	sep.size = Vector2(999, 2)
	vbox.add_child(sep)

	queue_box = VBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 4)
	vbox.add_child(queue_box)

func _build_background(biome: String) -> void:
	var palette: Dictionary = BIOMES.get(biome, BIOMES["forest"])

	bg_layer.layer = -10
	bg_layer.add_child(bg_root)

	# Gradient sky
	bg_sky = TextureRect.new()
	bg_sky.size = get_viewport_rect().size
	bg_sky.texture = _make_vertical_gradient(
		Vector2i(int(bg_sky.size.x), int(bg_sky.size.y)),
		palette["top"], palette["bottom"]
	)
	bg_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg_sky)

	# Parallax clouds (no limits; use mirroring for seamless wrap)
	var parallax: ParallaxBackground = ParallaxBackground.new()
	parallax.scroll_base_offset = Vector2.ZERO
	parallax.scroll_base_scale = Vector2.ONE
	var vp_size: Vector2 = get_viewport_rect().size
	bg_layer.add_child(parallax)

	bg_clouds_far = ParallaxLayer.new()
	bg_clouds_far.motion_scale = Vector2(0.1, 0.0)
	bg_clouds_far.motion_mirroring = Vector2(vp_size.x, 0.0)
	bg_clouds_far.add_child(_make_cloud_band(palette["cloud"], 18, 0.5))
	parallax.add_child(bg_clouds_far)

	bg_clouds_near = ParallaxLayer.new()
	bg_clouds_near.motion_scale = Vector2(0.2, 0.0)
	bg_clouds_near.motion_mirroring = Vector2(vp_size.x, 0.0)
	bg_clouds_near.add_child(_make_cloud_band(palette["cloud"], 26, 0.8))
	parallax.add_child(bg_clouds_near)

	# Floor strip
	bg_floor = ColorRect.new()
	bg_floor.color = palette["floor"]
	var sz := get_viewport_rect().size
	bg_floor.size = Vector2(sz.x, sz.y * 0.24)
	bg_floor.position = Vector2(0, sz.y - bg_floor.size.y)
	bg_layer.add_child(bg_floor)

	# Vignette
	var vignette := TextureRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.size = sz
	vignette.material = _make_vignette_material()
	bg_layer.add_child(vignette)

func _input(event: InputEvent) -> void:
	# Allow canceling target menu with ESC even when main menu is hidden
	if target_root != null and target_root.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_hide_target_menu()
			# Return to new CommandMenu for the current actor
			if current_actor_index >= 0 and current_actor_index < party.size():
				var a: Dictionary = party[current_actor_index]
				var an: String = String(a["stats"].get("name", "Adept"))
				var spells_arr: Array = a.get("spells", [])
				var spells_for_menu: Array = []
				for s in spells_arr:
					var sd: Dictionary = (s as Dictionary).duplicate(true)
					if not sd.has("mp_cost") and sd.has("mp"):
						sd["mp_cost"] = int(sd.get("mp", 0))
					spells_for_menu.append(sd)
				cmd.show_for_actor(an, spells_for_menu, _menu_items_for_actor(a))
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

func _alive(units: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in units:
		var st: Dictionary = u.get("stats", {})
		if int(st.get("hp", st.get("HP", 0))) > 0:
			out.append(u)
	return out

func _is_team_dead(units: Array[Dictionary]) -> bool:
	return _alive(units).is_empty()

func _pick_random(arr: Array[Dictionary]) -> Dictionary:
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

	# Pre-action anims
	if kind == "skill":
		await _anim_wait(actor, "cast")
		var sp_pre: Dictionary = act.get("skill", {})
		# Optional projectile for flavor
		var elem_col: Color = _element_color(String(sp_pre.get("element", "neutral")))
		await _cast_orb_from_to(actor, target, elem_col, int(actor.get("facing", 1)))
	else:
		var offensive := (kind == "attack")
		if kind == "item":
			var itk_pre: Dictionary = act.get("item", {})
			offensive = String(itk_pre.get("type", "heal")) == "damage"
		if offensive:
			await _anim_wait(actor, "attack")

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
			_anim(target, "hurt")
			if int(target["stats"]["hp"]) == 0:
				await _anim_wait(target, "die")
				_apply_death_visual(target)
			_update_all_overlays()
			return

	if kind == "item":
		var it: Dictionary = act.get("item", {})
		var itype: String = String(it.get("type", "heal"))
		var amount: int = int(it.get("amount", 0))
		var t: Dictionary = target
		if itype == "heal":
			var maxhp: int = int(t["stats"].get("max_hp", 1))
			var before: int = int(t["stats"].get("hp", 0))
			t["stats"]["hp"] = min(maxhp, before + amount)
			_log("%s uses %s on %s for +%d HP." % [actor["stats"]["name"], String(it.get("name","Item")), t["stats"]["name"], amount])
		elif itype == "mp":
			var maxmp: int = int(t["stats"].get("max_mp", 0))
			var before_mp: int = int(t["stats"].get("mp", 0))
			t["stats"]["mp"] = min(maxmp, before_mp + amount)
			_log("%s uses %s on %s for +%d MP." % [actor["stats"]["name"], String(it.get("name","Item")), t["stats"]["name"], amount])

		# decrement inventory
		var iid: String = String(it.get("id", ""))
		if inventory.has(iid):
			var entry: Dictionary = inventory[iid]
			entry["qty"] = max(0, int(entry.get("qty", 0)) - 1)
			inventory[iid] = entry
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
	_anim(target, "hurt")
	if int(target["stats"]["hp"]) == 0:
		await _anim_wait(target, "die")
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
		_log("Defeatâ€¦ your party falls.")
		get_tree().change_scene_to_file("res://scenes/Boot.tscn")
		return true

	return false

func _end_round() -> void:
	for p in party:
		p.defending = false
	for e in wave:
		e.defending = false
	round += 1
	# Relayout roots and reset pivot pose to avoid drift
	_layout_units()
	_start_round_declare()

	_update_all_overlays()

func _finish_battle(winner: String) -> void:
	if winner == "player":
		_log("Victory! Preparing next foeâ€¦")
		# +15% HP heal
		party[0]["stats"]["hp"] = min(int(party[0]["stats"]["max_hp"]), int(party[0]["stats"]["hp"]) + int(party[0]["stats"]["max_hp"] * 0.15))
		get_tree().change_scene_to_file("res://scenes/Fork.tscn")
		return

func _commit_declare_phase() -> void:
	# Allies done; add AI enemies
	var foes := _alive(wave)
	for e in foes:
		planned_actions.append({"team":"wave","actor":e,"action":{"kind":"attack"}})

	# EXPAND multi-targets (skills/items) into per-target actions
	var expanded: Array[Dictionary] = _expand_multi_targets(planned_actions)

	# Initiative
	for p in expanded:
		var spd := int(p["actor"]["stats"].get("spd", 10))
		p["init"] = spd + randi_range(0, int(spd * 0.25))
	expanded.sort_custom(func(a,b): return a["init"] > b["init"])

	# Fill any missing targets
	for p in expanded:
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

	# --- Show queue ---
	_show_queue(expanded)

	# Resolve with highlight
	for i in range(expanded.size()):
		var p = expanded[i]
		if _is_team_dead(party) or _is_team_dead(wave):
			break
		_highlight_queue_index(i)
		_resolve_action_team(p)

	# Done
	_hide_queue()
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

func _hide_items_menu() -> void:
	items_root.visible = false

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
func _show_target_menu(caster_idx: int, candidates: Array[Dictionary]) -> void:
	pending_caster_index = caster_idx
	target_candidates = candidates.duplicate()
	for c in target_list.get_children():
		c.queue_free()

	# Guard: if no valid targets, bounce back to the main menu
	if target_candidates.is_empty():
		_log("No valid targets.")
		_show_command_menu(String(party[current_actor_index]["stats"]["name"]))
		return

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
	pending_mode = ""
	pending_spell.clear()
	pending_item.clear()

# --- Menu callbacks ---
func _on_menu_attack() -> void:
	_hide_command_menu(); _hide_spells_menu(); _hide_items_menu();
	_queue_player_action({"kind":"attack"})

func _on_menu_defend() -> void:
	_hide_command_menu(); _hide_spells_menu(); _hide_items_menu();
	_queue_player_action({"kind":"defend"})

func _on_menu_spells() -> void:
	# Show spells for the current acting ally (set by _prompt_next_actor)
	var actor: Dictionary = party[current_actor_index]
	_populate_spells_for(actor)
	spells_root.visible = true

func _on_menu_items() -> void:
	# Show items from inventory
	_populate_items_list()
	items_root.visible = true

func _on_spell_chosen(sp: Dictionary) -> void:
	# Decide valid target mode, then either queue or prompt for targets
	pending_mode = "spell"
	pending_spell = sp.duplicate()
	_hide_command_menu(); spells_root.visible = false; _hide_items_menu()
	var mode := _infer_target_mode("skill", pending_spell)
	match mode:
		TM_ENEMY_ALL, TM_ALLY_ALL, TM_SELF:
			_queue_player_action({"kind":"skill", "skill": pending_spell})
		TM_ALLY_ONE:
			_show_target_menu(current_actor_index, _alive(party))
		TM_ENEMY_ONE:
			_show_target_menu(current_actor_index, _alive(wave))

func _on_item_chosen(it: Dictionary) -> void:
	_hide_command_menu(); _hide_spells_menu()
	pending_mode = "item"
	pending_item = it.duplicate()
	items_root.visible = false
	var mode := _infer_target_mode("item", pending_item)
	match mode:
		TM_ENEMY_ALL, TM_ALLY_ALL, TM_SELF:
			_queue_player_action({"kind":"item", "item": pending_item})
		TM_ALLY_ONE:
			_show_target_menu(current_actor_index, _alive(party))
		TM_ENEMY_ONE:
			_show_target_menu(current_actor_index, _alive(wave))

func _on_target_chosen(idx: int) -> void:
	# Guard: clicked after the list changed or empty
	if idx < 0 or idx >= target_candidates.size():
		_log("Target selection invalid.")
		_hide_target_menu()
		_show_command_menu(String(party[current_actor_index]["stats"]["name"]))
		return

	var tgt: Dictionary = target_candidates[idx]
	_hide_target_menu()
	match pending_mode:
		"spell":
			_queue_player_action({"kind":"skill", "skill": pending_spell, "target": tgt})
		"item":
			_queue_player_action({"kind":"item", "item": pending_item, "target": tgt})
		_:
			_queue_player_action({"kind":"attack"})

# --- New CommandMenu wiring ---
func _on_cmd_action(kind: String, id: String) -> void:
	match kind:
		"attack":
			cmd.hide_menu()
			_queue_player_action({"kind":"attack"})
		"defend":
			cmd.hide_menu()
			_queue_player_action({"kind":"defend"})
		"spells":
			# Find the spell by ID and handle it
			var actor: Dictionary = party[current_actor_index]
			var spells: Array = actor.get("spells", [])
			for spell in spells:
				if String(spell.get("id", "")).to_lower() == id.to_lower():
					_on_spell_chosen(spell)
					break
		"items":
			# Find the item by ID and handle it
			for item_id in inventory.keys():
				if item_id.to_lower() == id.to_lower():
					var item: Dictionary = inventory[item_id]
					_on_item_chosen(item)
					break
		_:
			pass

func _menu_items_for_actor(actor: Dictionary) -> Array:
	var out: Array = []
	for k in inventory.keys():
		var entry: Dictionary = inventory[k]
		var qty: int = int(entry.get("qty", 0))
		if qty <= 0:
			continue
		var d := entry.duplicate(true)
		d["id"] = k
		d["qty"] = qty
		out.append(d)
	return out

func _queue_player_action(act: Dictionary) -> void:
	var actor = declare_allies[declare_index]
	var entry := {"team":"party","actor":actor,"action":act}
	if act.has("target"):
		entry["target"] = act["target"]
	planned_actions.append(entry)
	declare_index += 1
	_prompt_next_actor()

func _populate_items_list() -> void:
	# Clear
	for c in items_list.get_children():
		c.queue_free()

	# Build a button per item with qty > 0
	var keys: Array = inventory.keys()
	keys.sort()  # deterministic order
	var any := false
	for k in keys:
		var entry: Dictionary = inventory[k]
		var qty: int = int(entry.get("qty", 0))
		if qty <= 0:
			continue
		any = true
		var nm: String = String(entry.get("name", k))
		var typ: String = String(entry.get("type", "heal"))
		var amt: int = int(entry.get("amount", 0))
		var btn := Button.new()
		var desc: String = "HP +%d" % amt if typ == "heal" else "MP +%d" % amt
		btn.text = "%s   x%d   (%s)" % [nm, qty, desc]
		btn.add_theme_font_size_override("font_size", 20)
		var it := entry.duplicate()
		btn.pressed.connect(func(): _on_item_chosen(it))
		items_list.add_child(btn)

	if not any:
		var lbl := Label.new()
		lbl.text = "No items"
		lbl.add_theme_font_size_override("font_size", 18)
		items_list.add_child(lbl)

func _show_queue(actions: Array[Dictionary]) -> void:
	# clear
	for c in queue_box.get_children():
		c.queue_free()
	queue_rows.clear()

	for a: Dictionary in actions:
		var actor: Dictionary = a["actor"]
		var nm: String = String(actor["stats"].get("name", "?"))
		var team: String = String(a.get("team", "?"))

		# Typed action
		var act: Dictionary = (a.get("action", {}) as Dictionary)
		var kind: String = String(act.get("kind", "attack"))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var icon := Label.new()
		var text := Label.new()

				# Icon by kind (ASCII-safe)
		if kind == "defend":
			icon.text = "[DEF]"
		elif kind == "skill":
			var sp: Dictionary = (act.get("skill", {}) as Dictionary)
			var stype: String = String(sp.get("type", "damage"))
			icon.text = "[HEAL]" if stype == "heal" else "[SPELL]"
		elif kind == "item":
			icon.text = "[ITEM]"
		else:
			icon.text = "[ATK]"

		icon.add_theme_font_size_override("font_size", 18)
		row.add_child(icon)

		# Label text
		if kind == "skill":
			var sp2: Dictionary = (act.get("skill", {}) as Dictionary)
			var sn: String = String(sp2.get("name", "Skill"))
			var mp_cost: int = int(sp2.get("mp", 0))
			text.text = "%s - %s (MP %d)" % [nm, sn, mp_cost]
		elif kind == "item":
			var it: Dictionary = (act.get("item", {}) as Dictionary)
			var iname: String = String(it.get("name", "Item"))
			text.text = "%s - %s" % [nm, iname]
		else:
			text.text = "%s - %s" % [nm, kind]

		text.add_theme_font_size_override("font_size", 16)
		text.add_theme_color_override(
			"font_color",
			Color(0.8, 1, 0.8) if team == "party" else Color(1, 0.8, 0.8)
		)
		row.add_child(text)

		queue_box.add_child(row)
		queue_rows.append(text)

	queue_root.visible = true

func _highlight_queue_index(i: int) -> void:
	for idx in range(queue_rows.size()):
		var lbl: Label = queue_rows[idx]
		if idx == i:
			lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
			lbl.add_theme_constant_override("shadow_offset_x", 1)
			lbl.add_theme_constant_override("shadow_offset_y", 1)
			lbl.add_theme_font_size_override("font_size", 18)
		else:
			lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.0))
			lbl.add_theme_font_size_override("font_size", 16)

func _hide_queue() -> void:
	queue_root.visible = false

func set_biome(biome: String) -> void:
	var palette: Dictionary = BIOMES.get(biome, BIOMES["forest"])
	if bg_sky != null:
		bg_sky.texture = _make_vertical_gradient(
			Vector2i(int(bg_sky.size.x), int(bg_sky.size.y)),
			palette["top"], palette["bottom"]
		)
	if bg_floor != null:
		bg_floor.color = palette["floor"]
	if bg_clouds_far != null:
		_recolor_clouds(bg_clouds_far, palette["cloud"])
	if bg_clouds_near != null:
		_recolor_clouds(bg_clouds_near, palette["cloud"])

 

func _prompt_player() -> void:
	awaiting_player = true
	_log("Round %d: Choose an action (1: Attack, 2: Defend)" % round)
	_show_command_menu(String(party[0]["stats"]["name"]))

func _log(msg: String) -> void:
	_log_lines.append(msg)
	while _log_lines.size() > MAX_LOG:
		_log_lines.pop_front()
	log_label.text = "\n".join(_log_lines)

func _anim(u: Dictionary, name: String) -> void:
	var ap: AnimationPlayer = u.get("anim", null)
	if ap != null:
		SpriteAnimator.play(ap, name)

func _anim_wait(u: Dictionary, name: String) -> void:
	var ap: AnimationPlayer = u.get("anim", null)
	if ap != null:
		await SpriteAnimator.play_and_wait(ap, name)

func _make_vertical_gradient(size: Vector2i, top: Color, bottom: Color) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(size.y):
		var t := float(y) / float(max(1, size.y - 1))
		var c := top.lerp(bottom, t)
		for x in range(size.x):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _make_cloud_band(color: Color, blob_h: int, alpha_mult: float) -> Node2D:
	var root := Node2D.new()
	var sz := get_viewport_rect().size
	var tex := _make_cloud_texture(int(sz.x), blob_h, color, alpha_mult)

	var top := Sprite2D.new()
	top.texture = tex
	top.position = Vector2(sz.x * 0.5, sz.y * 0.28)
	root.add_child(top)

	var mid := Sprite2D.new()
	mid.texture = tex
	mid.position = Vector2(sz.x * 0.5 - 240.0, sz.y * 0.36)
	mid.modulate = Color(1, 1, 1, 0.8 * alpha_mult)
	root.add_child(mid)

	return root

func _make_cloud_texture(width: int, height: int, color: Color, alpha_mult: float) -> Texture2D:
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(10):
		var w: int = randi_range(120, 260)
		var x: int = randi_range(-40, width - 40)
		var y: int = randi_range(0, height - 1)
		var c: Color = Color(color.r, color.g, color.b, clamp(color.a * alpha_mult, 0.0, 1.0))
		_paint_soft_blob(img, Vector2i(x, y), w, int(w * 0.4), c)
	return ImageTexture.create_from_image(img)

func _paint_soft_blob(img: Image, center: Vector2i, w: int, h: int, c: Color) -> void:
	var half_w: int = w / 2
	var half_h: int = h / 2
	for yy in range(center.y - half_h, center.y + half_h):
		if yy < 0 or yy >= img.get_height():
			continue
		for xx in range(center.x - half_w, center.x + half_w):
			if xx < 0 or xx >= img.get_width():
				continue
			var dx: float = float(xx - center.x) / float(half_w)
			var dy: float = float(yy - center.y) / float(half_h)
			var d: float = clamp(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			var a: float = pow(d, 2.0) * c.a
			var base: Color = img.get_pixel(xx, yy)
			var out: Color = Color(
				c.r * a + base.r * (1.0 - a),
				c.g * a + base.g * (1.0 - a),
				c.b * a + base.b * (1.0 - a),
				min(1.0, a + base.a)
			)
			img.set_pixel(xx, yy, out)

func _recolor_clouds(layer: ParallaxLayer, new_color: Color) -> void:
	for child in layer.get_children():
		if child is Sprite2D:
			var s := child as Sprite2D
			var tex := s.texture
			if tex == null or not (tex is ImageTexture):
				continue
			var img := (tex as ImageTexture).get_image()
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					var p := img.get_pixel(x, y)
					if p.a > 0.01:
						img.set_pixel(x, y, Color(new_color.r, new_color.g, new_color.b, p.a))
			s.texture = ImageTexture.create_from_image(img)
		elif child is Node2D:
			for grand in (child as Node2D).get_children():
				if grand is Sprite2D:
					var s2 := grand as Sprite2D
					var tex2 := s2.texture
					if tex2 == null or not (tex2 is ImageTexture):
						continue
					var img2 := (tex2 as ImageTexture).get_image()
					for y2 in range(img2.get_height()):
						for x2 in range(img2.get_width()):
							var p2 := img2.get_pixel(x2, y2)
							if p2.a > 0.01:
								img2.set_pixel(x2, y2, Color(new_color.r, new_color.g, new_color.b, p2.a))
					s2.texture = ImageTexture.create_from_image(img2)

func _make_vignette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
        shader_type canvas_item;
        uniform float strength = 0.45;
        void fragment() {
            vec2 uv = SCREEN_UV * 2.0 - 1.0;
            float d = length(uv);
            float v = smoothstep(0.7, 1.0, d);
            vec4 col = texture(SCREEN_TEXTURE, SCREEN_UV);
            COLOR = mix(col, vec4(0.0, 0.0, 0.0, 1.0), v * strength);
        }
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _jab(sprite: CanvasItem, dir: int) -> void:
	if sprite == null:
		return
	# Nudge the zero-based pivot if available; fallback to sprite
	var target: Node2D = sprite as Node2D
	if target == null:
		return
	var parent := target.get_parent()
	if parent != null and parent is Node2D:
		target = parent as Node2D
	var t := create_tween()
	var x0: float = target.position.x
	t.tween_property(target, "position:x", x0 + 10.0 * dir, 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(target, "position:x", x0, 0.08).set_trans(Tween.TRANS_SINE)
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

func _make_spell_orb_texture(size_px: int, tint: Color) -> Texture2D:
	var img: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var c: Vector2i = Vector2i(size_px / 2, size_px / 2)
	var r: float = float(size_px) * 0.5
	for y in range(size_px):
		for x in range(size_px):
			var d: float = Vector2(float(x - c.x), float(y - c.y)).length() / r
			var t: float = clamp(1.0 - d, 0.0, 1.0)
			var a: float = pow(t, 1.9) * tint.a
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, a))
	return ImageTexture.create_from_image(img)

func _element_color(elem: String) -> Color:
	match elem:
		"fire":
			return Color(1.0, 0.5, 0.2, 1.0)
		"water":
			return Color(0.3, 0.7, 1.0, 1.0)
		"earth":
			return Color(0.6, 0.5, 0.3, 1.0)
		"air":
			return Color(0.8, 0.9, 1.0, 1.0)
		_:
			return Color(0.9, 0.9, 1.0, 1.0)

func _cast_orb_from_to(caster: Dictionary, target: Dictionary, tint: Color, facing: int) -> void:
	var s_from := caster.get("sprite", null) as Node2D
	var s_to := target.get("sprite", null) as Node2D
	if s_from == null or s_to == null:
		return
	var tex: Texture2D = _make_spell_orb_texture(18, tint)
	var orb: Sprite2D = Sprite2D.new()
	orb.texture = tex
	orb.centered = true
	orb.modulate = Color(1, 1, 1, 0.0)
	orb.scale = Vector2.ONE
	add_child(orb)
	var src: Vector2 = s_from.global_position + Vector2(12.0 * float(facing), -12.0)
	var dst: Vector2 = s_to.global_position + Vector2(0.0, -8.0)
	orb.global_position = src
	var tw: Tween = create_tween()
	tw.tween_property(orb, "modulate:a", 1.0, 0.06)
	tw.parallel().tween_property(orb, "global_position", dst, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(orb, "scale", Vector2(1.2, 1.2), 0.18)
	await tw.finished
	var tw2: Tween = create_tween()
	tw2.tween_property(orb, "modulate:a", 0.0, 0.10)
	tw2.parallel().tween_property(orb, "scale", Vector2(1.7, 1.7), 0.10)
	await tw2.finished
	orb.queue_free()

# ---------- overlays (label + bar) ----------
func _make_square_texture(color: Color) -> Texture2D:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

var _bg_t: float = 0.0

func _process(delta: float) -> void:
	_bg_t += delta
	if bg_clouds_far != null:
		bg_clouds_far.motion_offset.x = _bg_t * 8.0
	if bg_clouds_near != null:
		bg_clouds_near.motion_offset.x = _bg_t * 16.0

func _spawn_unit_sprite(u: Dictionary, pos: Vector2, facing: int) -> void:
	var root: Node2D = u.get("root", null)
	var pivot: Node2D = u.get("pivot", null)
	var s: CanvasItem = u.get("sprite", null)

	# Build the Root→Pivot→Sprite (+Arm) structure if missing
	if root == null or not is_instance_valid(root):
		root = Node2D.new()
		root.name = "UnitRoot"
		root.position = pos
		add_child(root)
		u["root"] = root
		u["facing"] = facing

		pivot = Node2D.new()
		pivot.name = "Pivot"
		root.add_child(pivot)
		u["pivot"] = pivot

		var kind: String = String(u.get("art", ""))
		var character := ""
		if kind.begins_with("hero:"):
			character = String(kind.split(":")[1])
		elif kind.begins_with("healer:"):
			character = "healer"
		elif kind.begins_with("mage:"):
			character = "mage"
		elif kind.begins_with("rogue:"):
			character = "rogue"
		else:
			character = kind

		var animated: AnimatedFrames = AnimatedFrames.new()
		animated.centered = false
		animated.character = character
		animated.set_facing_back(facing > 0)
		pivot.add_child(animated)
		u["sprite"] = animated

		if not animated.has_frames():
			pivot.remove_child(animated)
			animated.queue_free()
			var sprite := Sprite2D.new()
			sprite.centered = false
			if kind.begins_with("hero:") or kind.begins_with("healer:") or kind.begins_with("mage:") or kind.begins_with("rogue:"):
				var role: String = "adept"  # default role
				if kind.begins_with("hero:"):
					role = String(kind.split(":")[1])
				elif kind.begins_with("healer:"):
					role = "cleric"
				elif kind.begins_with("mage:"):
					role = "guard"
				elif kind.begins_with("rogue:"):
					role = "rogue"
				var layers: Dictionary = SpriteFactory.make_humanoid_with_arm(role, 3)
				sprite.texture = layers.get("body")
				pivot.add_child(sprite)
				u["sprite"] = sprite
				var arm := Sprite2D.new()
				arm.name = "Arm"
				arm.centered = false
				arm.texture = layers.get("arm")
				arm.position = layers.get("arm_pivot_local", Vector2.ZERO)
				pivot.add_child(arm)
				u["arm"] = arm
			else:
				var tex: Texture2D = SpriteFactory.make_monster(kind, 3) if kind != "" else SpriteFactory.make_humanoid("rogue", 3)
				sprite.texture = tex
				pivot.add_child(sprite)
				u["sprite"] = sprite
		else:
			u.erase("arm")

		var ap: AnimationPlayer = SpriteAnimator.attach_to_pivot(pivot, facing)
		u["anim"] = ap
	else:
		# Already spawned: only relayout the root
		u["facing"] = facing
		if is_instance_valid(root):
			root.position = pos
		# Recreate/attach pivot if somehow missing
		if pivot == null or not is_instance_valid(pivot):
			pivot = Node2D.new()
			pivot.name = "Pivot"
			root.add_child(pivot)
			u["pivot"] = pivot
			# Ensure sprite is under pivot
			if s != null and is_instance_valid(s) and s.get_parent() != pivot:
				var old_parent := s.get_parent()
				if old_parent != null:
					old_parent.remove_child(s)
				pivot.add_child(s)
			var ap2: AnimationPlayer = SpriteAnimator.attach_to_pivot(pivot, facing)
			u["anim"] = ap2

	if s is AnimatedFrames:
		(s as AnimatedFrames).set_facing_back(facing > 0)

	s = u.get("sprite", null)

	if s != null and is_instance_valid(s):
		s.z_index = 0

	if u.get("hud", null) == null:
		_create_unit_overlay(u)

func _layout_units() -> void:
	# enemies (top)
	for i in ENEMY_SLOTS.size():
		if i < wave.size():
			_spawn_unit_sprite(wave[i], ENEMY_SLOTS[i], -1)
			_reset_pose(wave[i])
	# party (bottom)
	for i in PARTY_SLOTS.size():
		if i < party.size():
			_spawn_unit_sprite(party[i], PARTY_SLOTS[i], +1)
			_reset_pose(party[i])

func _reset_pose(u: Dictionary) -> void:
	var pivot: Node2D = u.get("pivot", null)
	if pivot != null and is_instance_valid(pivot):
		pivot.position = Vector2.ZERO
		pivot.rotation = 0.0
		pivot.scale = Vector2.ONE
	var s: CanvasItem = u.get("sprite", null)
	if s != null and is_instance_valid(s):
		s.modulate = Color(1,1,1,1)

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

	var stats_dict: Dictionary = u.get("stats", {})
	var unit_name: String = String(stats_dict.get("name", "")).to_lower()
	if unit_name != "":
		var portrait_rect := TextureRect.new()
		portrait_rect.name = "POR"
		portrait_rect.size = Vector2(52, 52)
		portrait_rect.position = Vector2(-60, -4)
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.z_index = -1
		# Map character names to portrait names
		var portrait_name: String = unit_name
		match unit_name:
			"adept":
				portrait_name = "hero"
			"cleric":
				portrait_name = "healer"
			"guard":
				portrait_name = "mage"
		var portrait_path := "res://art/portraits/%s_portrait_96.png" % portrait_name
		var portrait_tex: Texture2D = load(portrait_path)
		if portrait_tex is Texture2D:
			portrait_rect.texture = portrait_tex
			root.add_child(portrait_rect)

	overlay.add_child(root)
	u["hud"] = root

func _update_unit_overlay(u: Dictionary) -> void:
	var s: CanvasItem = u.get("sprite", null)
	var root: Node2D = u.get("root", null)
	var hud: Control = u.get("hud", null)
	if hud == null:
		return

	# place HUD above the unit root (stable; does not bob with animations)
	var anchor_pos: Vector2 = Vector2.ZERO
	if root != null and is_instance_valid(root):
		anchor_pos = root.global_position
	elif s != null and is_instance_valid(s):
		anchor_pos = s.global_position
	hud.global_position = anchor_pos + Vector2(-BAR_SIZE.x * 0.5, -60)

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
