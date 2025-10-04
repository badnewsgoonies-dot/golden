extends Control
class_name CommandMenu

signal menu_action(kind: String, id: String)

var _spells: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _actor_name: String = ""

var _root: Control
var _main_row: HBoxContainer
var _sub_panel: Panel
var _sub_vbox: VBoxContainer
var _cursor_idx := 0
var _main_buttons: Array[Button] = []
var _sub_mode := ""
var _tail: Control
const TailScene := preload("res://ui/TriangleTail.gd")

const COL_BTN := Color(1.0, 0.9, 0.4) # warm yellow
const COL_BTN_HOVER := Color(1.0, 0.95, 0.55)
const COL_BTN_PRESSED := Color(0.95, 0.85, 0.35)
const COL_BORDER := Color(0,0,0)
const COL_BUBBLE := Color(0.98, 0.93, 0.70)

func _ready() -> void:
	name = "CommandMenu"
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -680  # Position on the right side
	offset_right = -20
	offset_top = -100
	offset_bottom = -20
	_root = Control.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_root)

	# Bottom button strip (Attack / Spells / Items / Defend)
	_main_row = HBoxContainer.new()
	_main_row.anchor_left = 0.0
	_main_row.anchor_right = 1.0
	_main_row.anchor_top = 1.0
	_main_row.anchor_bottom = 1.0
	_main_row.offset_left = 0
	_main_row.offset_right = 0
	_main_row.offset_top = -64
	_main_row.offset_bottom = 0
	_main_row.add_theme_constant_override("separation", 8)
	_root.add_child(_main_row)

	# Submenu bubble (appears above the buttons) - styled as yellow speech bubble
	_sub_panel = Panel.new()
	_sub_panel.visible = false
	_sub_panel.anchor_left = 1.0
	_sub_panel.anchor_right = 1.0
	_sub_panel.anchor_top = 1.0
	_sub_panel.anchor_bottom = 1.0
	_sub_panel.offset_left = -440
	_sub_panel.offset_right = -20
	_sub_panel.offset_top = -320
	_sub_panel.offset_bottom = -100
	_style_bubble(_sub_panel)
	_root.add_child(_sub_panel)

	var sub_margin: MarginContainer = MarginContainer.new()
	sub_margin.add_theme_constant_override("margin_left", 24)
	sub_margin.add_theme_constant_override("margin_top", 18)
	sub_margin.add_theme_constant_override("margin_right", 24)
	sub_margin.add_theme_constant_override("margin_bottom", 18)
	_sub_panel.add_child(sub_margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_margin.add_child(scroll)
	_sub_vbox = VBoxContainer.new()
	_sub_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_sub_vbox)
	_tail = TailScene.new()
	_tail.visible = false
	_tail.anchor_left = 0.0
	_tail.anchor_right = 0.0
	_tail.anchor_top = 1.0
	_tail.anchor_bottom = 1.0
	_tail.offset_left = 20
	_tail.offset_right = 80
	_tail.offset_top = -16
	_tail.offset_bottom = 4
	_root.add_child(_tail)

	_create_main_button("Attack", func(): _emit_main("attack", "slash"))
	_create_main_button("Spells", func(): _open_submenu("spells"))
	_create_main_button("Items", func(): _open_submenu("items"))
	_create_main_button("Defend", func(): _emit_main("defend", "defend"))
	_update_cursor(0)

func _create_main_button(text: String, on_press: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	_style_button(b)
	b.pressed.connect(on_press)
	_main_row.add_child(b)
	_main_buttons.append(b)

func show_for_actor(actor_name: String, spells: Array, items: Array) -> void:
	_actor_name = actor_name
	_spells = []
	_items = []
	for s in spells:
		if typeof(s) == TYPE_DICTIONARY:
			_spells.append((s as Dictionary).duplicate(true))
	for it in items:
		if typeof(it) == TYPE_DICTIONARY:
			_items.append((it as Dictionary).duplicate(true))
	_sub_mode = ""
	_sub_panel.visible = false
	_tail.visible = false
	visible = true
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	_update_cursor(0)

func _unhandled_input(e: InputEvent) -> void:
	if !visible:
		return
	if e.is_action_pressed("ui_down"):
		_update_cursor((_cursor_idx + 1) % _main_buttons.size())
	elif e.is_action_pressed("ui_up"):
		_update_cursor((_cursor_idx - 1 + _main_buttons.size()) % _main_buttons.size())
	elif e.is_action_pressed("ui_accept"):
		_main_buttons[_cursor_idx].emit_signal("pressed")
	elif e.is_action_pressed("ui_cancel"):
		if _sub_mode != "":
			_close_submenu()

func _update_cursor(i: int) -> void:
	_cursor_idx = i
	for idx in range(_main_buttons.size()):
		if idx == _cursor_idx:
			_main_buttons[idx].grab_focus()

func _emit_main(kind: String, id: String) -> void:
	emit_signal("menu_action", kind, id)
	visible = false

func _open_submenu(kind: String) -> void:
	_sub_mode = kind
	for c in _sub_vbox.get_children():
		c.queue_free()
	var list: Array = _spells if kind == "spells" else _items
	for entry in list:
		var label: String = entry.get("name", entry.get("id", "?"))
		var mp: Variant = entry.get("mp_cost", null)
		
		# Create label with dash prefix like in the screenshot
		var item_label := Label.new()
		var _t: String = "- " + label
		if mp != null:
			_t = "- %s" % label  # MP cost shown separately if needed
		item_label.text = _t
		item_label.add_theme_color_override("font_color", Color(0, 0, 0))
		item_label.add_theme_font_size_override("font_size", 18)
		item_label.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Make it clickable
		var btn_container := Button.new()
		btn_container.flat = true
		btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_container.custom_minimum_size = Vector2(0, 32)
		btn_container.add_child(item_label)
		
		btn_container.pressed.connect(func():
			var eid: String = String(entry.get("id", label)).to_lower()
			emit_signal("menu_action", kind, eid)
			visible = false
		)
		_sub_vbox.add_child(btn_container)
	_sub_panel.visible = true
	_tail.visible = true

func _close_submenu() -> void:
	_sub_mode = ""
	_sub_panel.visible = false
	_tail.visible = false

func hide_menu() -> void:
	visible = false
	_close_submenu()

func _style_button(b: Button) -> void:
	var sbn := StyleBoxFlat.new()
	sbn.bg_color = COL_BTN
	sbn.border_color = COL_BORDER
	sbn.set_border_width_all(2)
	sbn.corner_radius_top_left = 8
	sbn.corner_radius_top_right = 8
	sbn.corner_radius_bottom_left = 8
	sbn.corner_radius_bottom_right = 8
	var sbh := sbn.duplicate() as StyleBoxFlat
	sbh.bg_color = COL_BTN_HOVER
	var sbp := sbn.duplicate() as StyleBoxFlat
	sbp.bg_color = COL_BTN_PRESSED
	b.add_theme_stylebox_override("normal", sbn)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_color_override("font_color", Color(0,0,0))
	b.add_theme_font_size_override("font_size", 22)

func _style_bubble(p: Panel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BUBBLE
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	p.add_theme_stylebox_override("panel", sb)
