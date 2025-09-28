class_name CommandMenu
extends Control

signal menu_action(kind: String, payload: Dictionary)

const PAD := 10.0

var _built := false
var _spells: Array = []
var _items: Array = []
var _actor_name: String = ""

# Chevron cursor next to focused command
var _cursor: Node2D
var _cursor_tween: Tween
var _cursor_outer: Polygon2D
var _cursor_inner: Polygon2D

# Submenu chevron + selection state
var _sub_cursor: Node2D
var _sub_cursor_tween: Tween
var _sub_index: int = 0
var _current_submenu: String = ""

var _panel      : PanelContainer
var _header     : HBoxContainer
var _header_title: Label
var _header_name : Label
var _grid       : VBoxContainer
var _btn_attack : Button
var _btn_spells : Button
var _btn_items  : Button
var _btn_defend : Button

var _bracket    : Control
var _sub_panel  : PanelContainer
var _sub_vbox   : VBoxContainer
var _sub_title  : Label

var _focused_idx: int = 0

func show_for_actor(actor_name: String, spells: Array, items: Array) -> void:
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
	if _built: return
	_built = true

	anchor_right = 1.0
	anchor_bottom = 1.0
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(520, 240)
	position = Vector2(-560, -260)

	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "MainPanel"
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.custom_minimum_size = Vector2(320, 220)
	_panel.theme = _make_theme()
	add_child(_panel)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 8)
	outer_margin.add_theme_constant_override("margin_right", 8)
	outer_margin.add_theme_constant_override("margin_top", 8)
	outer_margin.add_theme_constant_override("margin_bottom", 8)
	outer_margin.custom_minimum_size = _panel.custom_minimum_size
	_panel.add_child(outer_margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	outer_margin.add_child(outer)

	# Header
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 10)
	outer.add_child(_header)

	_header_title = Label.new()
	_header_title.text = "Actions"
	_header_title.add_theme_color_override("font_color", Color(0.95,0.95,0.95,1))
	_header_title.add_theme_font_size_override("font_size", 26)
	_header.add_child(_header_title)

	_header_name = Label.new()
	_header_name.text = ""
	_header_name.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25, 1))
	_header_name.add_theme_font_size_override("font_size", 20)
	_header.add_child(_header_name)
	_header.add_spacer()

	# Grid (vertical list of 4)
	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 8)
	_grid.add_theme_constant_override("margin_left", 14)
	outer.add_child(_grid)

	_btn_attack = _make_cmd_button("Attack")
	_btn_attack.pressed.connect(func(): _emit_main("attack"))
	_grid.add_child(_btn_attack)

	_btn_spells = _make_cmd_button("Spells")
	_btn_spells.pressed.connect(func(): _toggle_submenu("spells"))
	_grid.add_child(_btn_spells)

	_btn_items = _make_cmd_button("Items")
	_btn_items.pressed.connect(func(): _toggle_submenu("items"))
	_grid.add_child(_btn_items)

	_btn_defend = _make_cmd_button("Defend")
	_btn_defend.pressed.connect(func(): _emit_main("defend"))
	_grid.add_child(_btn_defend)

	# --- Cursor chevron next to focused command ---
	_cursor = Node2D.new()
	_cursor.name = "Cursor"
	_cursor_outer = Polygon2D.new(); _cursor_outer.color = Color(1,1,1)
	_cursor_inner = Polygon2D.new(); _cursor_inner.color = Color(0.12, 0.14, 0.18, 1.0)
	_cursor.add_child(_cursor_outer)
	_cursor.add_child(_cursor_inner)
	_panel.add_child(_cursor)

	# place it initially by Attack (after layout)
	await get_tree().process_frame
	_move_cursor_to(_btn_attack)

	# focus/hover hooks keep the cursor in sync
	for b in [_btn_attack, _btn_spells, _btn_items, _btn_defend]:
		b.focus_entered.connect(func(btn := b): _move_cursor_to(btn))
		b.mouse_entered.connect(func(btn := b): btn.grab_focus())

	# Bracket
	_bracket = Control.new()
	_bracket.custom_minimum_size = Vector2(40, 160)
	add_child(_bracket)
	# render with Line2D
	var w := _bracket.custom_minimum_size.x
	var h := _bracket.custom_minimum_size.y
	var c := Color(1,1,1,1)
	var l1 := Line2D.new(); l1.width = 3; l1.default_color = c
	l1.points = PackedVector2Array([Vector2(2,2), Vector2(w-8,h/2), Vector2(2,h-2)])
	_bracket.add_child(l1)
	var l2 := Line2D.new(); l2.width = 3; l2.default_color = c
	l2.points = PackedVector2Array([Vector2(10,8), Vector2(w-12,h/2), Vector2(10,h-8)])
	_bracket.add_child(l2)

	# Submenu panel
	_sub_panel = PanelContainer.new()
	_sub_panel.custom_minimum_size = Vector2(360, 220)
	_sub_panel.theme = _make_theme(true)
	add_child(_sub_panel)

	var sub_outer_margin := MarginContainer.new()
	sub_outer_margin.add_theme_constant_override("margin_left", 10)
	sub_outer_margin.add_theme_constant_override("margin_right", 10)
	sub_outer_margin.add_theme_constant_override("margin_top", 10)
	sub_outer_margin.add_theme_constant_override("margin_bottom", 10)
	_sub_panel.add_child(sub_outer_margin)

	var sub_outer := VBoxContainer.new()
	sub_outer.add_theme_constant_override("separation", 8)
	sub_outer_margin.add_child(sub_outer)

	_sub_title = Label.new()
	_sub_title.text = ""
	_sub_title.add_theme_font_size_override("font_size", 18)
	sub_outer.add_child(_sub_title)

	_sub_vbox = VBoxContainer.new()
	_sub_vbox.add_theme_constant_override("separation", 6)
	sub_outer.add_child(_sub_vbox)

	# Submenu cursor (hidden until submenu opens)
	_sub_cursor = Node2D.new()
	_sub_cursor.name = "SubCursor"
	_sub_cursor.visible = false
	_sub_panel.add_child(_sub_cursor)

	# Layout positions
	_panel.position = Vector2(0, 0)
	_bracket.position = _panel.position + Vector2(_panel.custom_minimum_size.x + 8, 26)
	_sub_panel.position = _bracket.position + Vector2(_bracket.custom_minimum_size.x + 8, -26)

	# Keyboard nav
	for b in [_btn_attack, _btn_spells, _btn_items, _btn_defend]:
		b.focus_mode = Control.FOCUS_ALL
		b.gui_input.connect(_nav_input)

func _make_cmd_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 36)
	b.add_theme_font_size_override("font_size", 18)
	_apply_button_style(b)
	return b

func _toggle_submenu(which: String) -> void:
	if _sub_panel.visible and _sub_title.text.to_lower() == which:
		_show_submenu("")
	else:
		_show_submenu(which)

func _emit_main(kind: String) -> void:
	_show_submenu("")
	menu_action.emit(kind, {"actor": _actor_name})

func _set_cursor_shape(h: float, main: bool) -> void:
	var w := 16.0
	var mid := h * 0.5
	var outer := PackedVector2Array([
		Vector2(0, 0),
		Vector2(w, mid),
		Vector2(0, h)
	])
	var notch := PackedVector2Array([
		Vector2(5, 3),
		Vector2(w - 3, mid),
		Vector2(5, h - 3)
	])
	if main:
		_cursor_outer.polygon = outer
		_cursor_inner.polygon = notch
	else:
		# For submenu, reuse _cursor nodes on _sub_cursor by creating children on demand
		if _sub_cursor.get_child_count() == 0:
			var sc_outer := Polygon2D.new(); sc_outer.color = Color(1,1,1)
			var sc_inner := Polygon2D.new(); sc_inner.color = Color(0.12,0.14,0.18,1.0)
			_sub_cursor.add_child(sc_outer)
			_sub_cursor.add_child(sc_inner)
		(_sub_cursor.get_child(0) as Polygon2D).polygon = outer
		(_sub_cursor.get_child(1) as Polygon2D).polygon = notch

func _move_cursor_to(btn: Control) -> void:
	if _cursor == null or btn == null:
		return
	# Convert button top-left into panel space
	var btn_top_left: Vector2 = _panel.to_local(btn.global_position)
	var h := max(20.0, btn.size.y * 0.65)
	var y := btn_top_left.y + (btn.size.y - h) * 0.5
	var x := 6.0
	# Animate
	if is_instance_valid(_cursor_tween):
		_cursor_tween.kill()
	_cursor_tween = create_tween()
	_cursor_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cursor_tween.tween_property(_cursor, "position", Vector2(x, y), 0.08)
	# Adjust polygon size
	_set_cursor_shape(h, true)

func _move_sub_cursor_to(btn: Control) -> void:
	if _sub_cursor == null or btn == null:
		return
	var btn_top_left: Vector2 = _sub_panel.to_local(btn.global_position)
	var h := max(18.0, btn.size.y * 0.65)
	var y := btn_top_left.y + (btn.size.y - h) * 0.5
	var x := 10.0
	if is_instance_valid(_sub_cursor_tween):
		_sub_cursor_tween.kill()
	_sub_cursor_tween = create_tween()
	_sub_cursor_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sub_cursor_tween.tween_property(_sub_cursor, "position", Vector2(x, y), 0.08)
	_set_cursor_shape(h, false)
	_sub_cursor.visible = true

func _show_submenu(which: String) -> void:
	_sub_panel.visible = (which != "")
	_bracket.visible = _sub_panel.visible
	if not _sub_panel.visible:
		if _sub_cursor != null:
			_sub_cursor.visible = false
		return
	_current_submenu = which
	_sub_title.text = which.capitalize()
	for c in _sub_vbox.get_children():
		c.queue_free()

	# Build entries with focus/hover + keyboard navigation
	_sub_index = 0
	var list_size := 0
	if which == "spells":
		for i in _spells.size():
			var s = _spells[i]
			var mp_cost := int((s as Dictionary).get("mp_cost", (s as Dictionary).get("mp", 0)))
			var line := _make_list_row(String((s as Dictionary).get("name", "Spell")), mp_cost > 0 ? "MP %d" % mp_cost : "")
			var b: Button = line["btn"]
			b.focus_mode = Control.FOCUS_ALL
			var idx := i
			b.gui_input.connect(_sub_nav_input)
			b.focus_entered.connect(func(btn := b): _sub_index = idx; _move_sub_cursor_to(btn))
			b.mouse_entered.connect(func(btn := b): btn.grab_focus())
			b.pressed.connect(func(spell := s):
				menu_action.emit("spell_pick", {"actor": _actor_name, "skill": spell})
				_show_submenu("")
			)
			_sub_vbox.add_child(line["row"])
			list_size += 1
	elif which == "items":
		for i in _items.size():
			var it = _items[i]
			var qty := int((it as Dictionary).get("qty", 1))
			var right := qty > 1 ? "x%d" % qty : ""
			var line2 := _make_list_row(String((it as Dictionary).get("name", "Item")), right)
			var b2: Button = line2["btn"]
			b2.focus_mode = Control.FOCUS_ALL
			var idx2 := i
			b2.gui_input.connect(_sub_nav_input)
			b2.focus_entered.connect(func(btn := b2): _sub_index = idx2; _move_sub_cursor_to(btn))
			b2.mouse_entered.connect(func(btn := b2): btn.grab_focus())
			b2.pressed.connect(func(item := it):
				menu_action.emit("item_pick", {"actor": _actor_name, "item": item})
				_show_submenu("")
			)
			_sub_vbox.add_child(line2["row"])
			list_size += 1

	await get_tree().process_frame
	if list_size > 0:
		_sub_index = clamp(_sub_index, 0, list_size - 1)
		var btn0 := _get_sub_button_at(_sub_index)
		if btn0 != null:
			btn0.grab_focus()

func _make_list_row(left: String, right: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var btn := Button.new()
	btn.text = left
	btn.custom_minimum_size = Vector2(240, 32)
	btn.text_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_button_style(btn, true)
	row.add_child(btn)
	var cost := Label.new()
	cost.text = right
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90, 0.95))
	row.add_child(cost)
	row.add_spacer()
	return {"row": row, "btn": btn}

func _make_theme(light: bool = false) -> Theme:
	var t := Theme.new()
	var bg := StyleBoxFlat.new()
	if light:
		bg.bg_color = Color(0.86,0.86,0.88,1)
		bg.border_color = Color(0.15,0.17,0.2,0.85)
	else:
		bg.bg_color = Color(0.12,0.14,0.18,0.94)
		bg.border_color = Color(0.4,0.42,0.50,0.9)
	bg.set_corner_radius_all(8)
	bg.border_width_all = 2
	bg.expand_margin_left = 6
	bg.expand_margin_top = 6
	bg.expand_margin_right = 6
	bg.expand_margin_bottom = 6
	t.set_stylebox("panel", "PanelContainer", bg)
	return t

func _apply_button_style(b: Button, small: bool = false) -> void:
	var base := Color(0.28,0.30,0.35,1)
	var hov := Color(0.38,0.41,0.48,1)
	var pr := Color(0.22,0.24,0.28,1)
	var text := Color(0.92,0.94,0.96,1)
	var s1 := StyleBoxFlat.new(); s1.bg_color = base; s1.set_corner_radius_all(6)
	var s2 := StyleBoxFlat.new(); s2.bg_color = hov; s2.set_corner_radius_all(6)
	var s3 := StyleBoxFlat.new(); s3.bg_color = pr; s3.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", s1)
	b.add_theme_stylebox_override("hover", s2)
	b.add_theme_stylebox_override("pressed", s3)
	b.add_theme_color_override("font_color", text)
	b.add_theme_font_size_override("font_size", small ? 16 : 18)

func _nav_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ek := event as InputEventKey
		match ek.keycode:
			KEY_UP, KEY_W:
				_grab_focus(max(_focused_idx - 1, 0))
			KEY_DOWN, KEY_S:
				_grab_focus(min(_focused_idx + 1, 3))
			KEY_ESCAPE:
				_show_submenu("")
			KEY_ENTER, KEY_KP_ENTER:
				match _focused_idx:
					0: _btn_attack.emit_signal("pressed")
					1: _btn_spells.emit_signal("pressed")
					2: _btn_items.emit_signal("pressed")
					3: _btn_defend.emit_signal("pressed")

func _grab_focus(idx: int) -> void:
	_focused_idx = idx
	match idx:
		0: _btn_attack.grab_focus()
		1: _btn_spells.grab_focus()
		2: _btn_items.grab_focus()
		3: _btn_defend.grab_focus()
	# Slide cursor to focused button
	_move_cursor_to([_btn_attack, _btn_spells, _btn_items, _btn_defend][_focused_idx])

func _get_sub_button_at(idx: int) -> Button:
	if idx < 0 or idx >= _sub_vbox.get_child_count():
		return null
	var row := _sub_vbox.get_child(idx)
	for c in row.get_children():
		if c is Button:
			return c as Button
	return null

func _sub_nav_input(event: InputEvent) -> void:
	if not _sub_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ek := event as InputEventKey
		match ek.keycode:
			KEY_UP, KEY_W:
				_sub_index = max(0, _sub_index - 1)
				var b := _get_sub_button_at(_sub_index)
				if b != null: b.grab_focus()
			KEY_DOWN, KEY_S:
				_sub_index = min(_sub_vbox.get_child_count() - 1, _sub_index + 1)
				var b2 := _get_sub_button_at(_sub_index)
				if b2 != null: b2.grab_focus()
			KEY_ESCAPE:
				_show_submenu("")
				if _current_submenu == "spells":
					_btn_spells.grab_focus()
				elif _current_submenu == "items":
					_btn_items.grab_focus()
			KEY_ENTER, KEY_KP_ENTER:
				var b3 := _get_sub_button_at(_sub_index)
				if b3 != null:
					b3.emit_signal("pressed")

