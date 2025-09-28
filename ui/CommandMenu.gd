# Godot 4.x
class_name CommandMenu
extends Control

signal menu_action(kind: String, payload: Dictionary)

var _built: bool = false
var _spells: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _actor_name: String = ""

@onready var _panel: PanelContainer = null
@onready var _header: HBoxContainer = null
@onready var _header_title: Label = null
@onready var _header_name: Label = null
@onready var _grid: VBoxContainer = null
@onready var _btn_attack: Button = null
@onready var _btn_spells: Button = null
@onready var _btn_items: Button = null
@onready var _btn_defend: Button = null
@onready var _bracket: Control = null
@onready var _sub_panel: PanelContainer = null
@onready var _sub_vbox: VBoxContainer = null
@onready var _sub_title: Label = null

var _focused_idx: int = 0
var _cursor: Control = null
var _cursor_tween: Tween = null

func show_for_actor(actor_name: String, spells: Array[Dictionary], items: Array[Dictionary]) -> void:
	_actor_name = actor_name
	_spells = spells
	_items = items
	_build_if_needed()
	_header_name.text = actor_name
	_show_submenu("")
	visible = true
	_grab_focus(0)

func hide_menu() -> void:
	visible = false

func _build_if_needed() -> void:
	if _built:
		return
	_built = true

	anchor_right = 1.0
	anchor_bottom = 1.0
	custom_minimum_size = Vector2(520, 240)
	position = Vector2(-560, -260)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 220)
	_panel.theme = _make_theme(false)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.padding_left = 8
	outer.padding_right = 8
	outer.padding_top = 8
	outer.padding_bottom = 8
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 10)
	outer.add_child(_header)

	_header_title = Label.new()
	_header_title.text = "Actions"
	_header_title.add_theme_font_size_override("font_size", 26)
	_header_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97, 1))
	_header.add_child(_header_title)

	_header_name = Label.new()
	_header_name.add_theme_font_size_override("font_size", 20)
	_header_name.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1))
	_header.add_child(_header_name)
	_header.add_spacer(16)

	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 8)
	_grid.add_theme_constant_override("margin_left", 14)
	outer.add_child(_grid)

	_btn_attack = _make_btn("Attack", func(): _emit_main("attack")) as Button
	_btn_spells = _make_btn("Spells", func(): _toggle_submenu("spells")) as Button
	_btn_items = _make_btn("Items", func(): _toggle_submenu("items")) as Button
	_btn_defend = _make_btn("Defend", func(): _emit_main("defend")) as Button
	var main_buttons: Array = [_btn_attack, _btn_spells, _btn_items, _btn_defend]
	for b in main_buttons:
		var btn: Button = b
		_grid.add_child(btn)
		btn.focus_mode = Control.FOCUS_ALL
		btn.gui_input.connect(_nav_input)
		btn.connect("mouse_entered", Callable(self, "_on_command_mouse_entered").bind(btn))
		btn.connect("focus_entered", Callable(self, "_on_command_focus_entered").bind(btn))

	_cursor = Control.new()
	_cursor.custom_minimum_size = Vector2(16, 24)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_draw_cursor)
	_panel.add_child(_cursor)

	_bracket = Control.new()
	_bracket.custom_minimum_size = Vector2(40, 160)
	_bracket.draw.connect(_draw_bracket)
	add_child(_bracket)

	_sub_panel = PanelContainer.new()
	_sub_panel.custom_minimum_size = Vector2(360, 220)
	_sub_panel.theme = _make_theme(true)
	add_child(_sub_panel)

	var sub_outer := VBoxContainer.new()
	sub_outer.padding_left = 10
	sub_outer.padding_right = 10
	sub_outer.padding_top = 10
	sub_outer.padding_bottom = 10
	sub_outer.add_theme_constant_override("separation", 8)
	_sub_panel.add_child(sub_outer)

	_sub_title = Label.new()
	_sub_title.add_theme_font_size_override("font_size", 18)
	sub_outer.add_child(_sub_title)

	_sub_vbox = VBoxContainer.new()
	_sub_vbox.add_theme_constant_override("separation", 6)
	sub_outer.add_child(_sub_vbox)

	_panel.position = Vector2(0, 0)
	_bracket.position = _panel.position + Vector2(_panel.custom_minimum_size.x + 8, 26)
	_sub_panel.position = _bracket.position + Vector2(_bracket.custom_minimum_size.x + 8, -26)

	await get_tree().process_frame
	_move_cursor_to(_btn_attack)

func _make_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 36)
	b.add_theme_font_size_override("font_size", 18)
	_apply_button_style(b, false)
	b.pressed.connect(cb)
	return b

func _make_list_row(left: String, right: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var btn := Button.new()
	btn.text = left
	btn.custom_minimum_size = Vector2(240, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_button_style(btn, true)
	row.add_child(btn)

	var cost := Label.new()
	cost.text = right
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90, 0.95))
	row.add_child(cost)
	row.add_spacer(8)

	return {"row": row, "btn": btn}

func _toggle_submenu(which: String) -> void:
	if _sub_panel.visible and _sub_title.text.to_lower() == which:
		_show_submenu("")
	else:
		_show_submenu(which)

func _emit_main(kind: String) -> void:
	_show_submenu("")
	menu_action.emit(kind, {"actor": _actor_name})

func _show_submenu(which: String) -> void:
	var show := which != ""
	_sub_panel.visible = show
	_bracket.visible = show
	if not show:
		return

	_sub_title.text = which.capitalize()
	for c in _sub_vbox.get_children():
		c.queue_free()

	if which == "spells":
		for s in _spells:
			var line := _make_list_row(String(s.get("name", "Spell")), "MP %d" % int(s.get("mp_cost", 0)))
			(line["btn"] as Button).pressed.connect(func(spell := s):
				menu_action.emit("spell_pick", {"actor": _actor_name, "skill": spell})
				_show_submenu("")
			)
			_sub_vbox.add_child(line["row"])
	elif which == "items":
		for it in _items:
			var qty: int = int(it.get("qty", 1))
			var right := ""
			if int(it.get("mp_cost", 0)) > 0:
				right += "MP %d  " % int(it["mp_cost"])
			if qty > 1:
				right += "x%d" % qty
			var line2 := _make_list_row(String(it.get("name", "Item")), right.strip_edges())
			(line2["btn"] as Button).pressed.connect(func(item := it):
				menu_action.emit("item_pick", {"actor": _actor_name, "item": item})
				_show_submenu("")
			)
			_sub_vbox.add_child(line2["row"])

func _make_theme(light: bool) -> Theme:
	var t := Theme.new()
	var sb := StyleBoxFlat.new()
	if light:
		sb.bg_color = Color(0.86, 0.86, 0.88, 1)
		sb.border_color = Color(0.15, 0.17, 0.20, 0.85)
	else:
		sb.bg_color = Color(0.12, 0.14, 0.18, 0.94)
		sb.border_color = Color(0.40, 0.42, 0.50, 0.90)
	sb.border_width_all = 2
	sb.set_corner_radius_all(8)
	t.set_stylebox("panel", "PanelContainer", sb)
	return t

func _apply_button_style(b: Button, small: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.28, 0.30, 0.35)
	normal.set_corner_radius_all(6)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.38, 0.41, 0.48)
	hover.set_corner_radius_all(6)
	var press := StyleBoxFlat.new()
	press.bg_color = Color(0.22, 0.24, 0.28)
	press.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	b.add_theme_font_size_override("font_size", 16 if small else 18)

func _draw_bracket() -> void:
	var w: float = size.x
	var h: float = size.y
	var c := Color(1, 1, 1, 1)
	draw_polyline(PackedVector2Array([Vector2(2, 2), Vector2(w - 8.0, h / 2.0), Vector2(2, h - 2)]), c, 3.0)
	draw_polyline(PackedVector2Array([Vector2(10, 8), Vector2(w - 12.0, h / 2.0), Vector2(10, h - 8)]), c, 3.0)

func _draw_cursor() -> void:
	var w: float = 16.0
	var h: float = max(20.0, float(size.y))
	var mid: float = h * 0.5
	var c := Color(1, 1, 1, 1)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, mid), Vector2(0, h)]), PackedColorArray([c]))
	var notch_col := Color(0.12, 0.14, 0.18, 1.0)
	draw_polygon(PackedVector2Array([Vector2(5, 3), Vector2(w - 3.0, mid), Vector2(5, h - 3.0)]), PackedColorArray([notch_col]))

func _move_cursor_to(btn: Button) -> void:
	if btn == null:
		return
	var top_left: Vector2 = _panel.to_local(btn.get_global_position())
	var y: float = top_left.y + (btn.size.y - _cursor.custom_minimum_size.y) * 0.5
	var x: float = 6.0
	if is_instance_valid(_cursor_tween):
		_cursor_tween.kill()
	_cursor_tween = create_tween()
	_cursor_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cursor_tween.tween_property(_cursor, "position", Vector2(x, y), 0.08)
	_cursor.custom_minimum_size = Vector2(16, max(20.0, btn.size.y * 0.65))
	_cursor.queue_redraw()

func _on_command_mouse_entered(btn: Button) -> void:
	if btn != null:
		btn.grab_focus()

func _on_command_focus_entered(btn: Button) -> void:
	_move_cursor_to(btn)

func _nav_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_UP or k == KEY_W:
			_grab_focus(max(_focused_idx - 1, 0))
		elif k == KEY_DOWN or k == KEY_S:
			_grab_focus(min(_focused_idx + 1, 3))
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			var btns: Array = [_btn_attack, _btn_spells, _btn_items, _btn_defend]
			(btns[_focused_idx] as Button).emit_signal("pressed")
		elif k == KEY_ESCAPE:
			_show_submenu("")

func _grab_focus(idx: int) -> void:
	_focused_idx = idx
	var btns: Array = [_btn_attack, _btn_spells, _btn_items, _btn_defend]
	(btns[_focused_idx] as Button).grab_focus()
	_move_cursor_to(btns[_focused_idx] as Button)
