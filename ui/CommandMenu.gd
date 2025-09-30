extends Control
class_name CommandMenu

signal menu_action(kind: String, id: String)

var _spells: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _actor_name: String = ""

var _root: Panel
var _main_vbox: VBoxContainer
var _sub_panel: Panel
var _sub_vbox: VBoxContainer
var _cursor_idx := 0
var _main_buttons: Array[Button] = []
var _sub_mode := ""

func _ready() -> void:
	name = "CommandMenu"
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -520
	offset_right = 520
	offset_top = -260
	offset_bottom = -20
	_root = Panel.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_root)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_root.add_child(margin)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	margin.add_child(h)
	_main_vbox = VBoxContainer.new()
	_main_vbox.custom_minimum_size = Vector2(360, 180)
	_main_vbox.add_theme_constant_override("separation", 12)
	h.add_child(_main_vbox)
	_sub_panel = Panel.new()
	_sub_panel.visible = false
	_sub_panel.custom_minimum_size = Vector2(520, 180)
	h.add_child(_sub_panel)
	var sub_margin: MarginContainer = MarginContainer.new()
	sub_margin.add_theme_constant_override("margin_left", 16)
	sub_margin.add_theme_constant_override("margin_top", 12)
	sub_margin.add_theme_constant_override("margin_right", 16)
	sub_margin.add_theme_constant_override("margin_bottom", 12)
	_sub_panel.add_child(sub_margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_margin.add_child(scroll)
	_sub_vbox = VBoxContainer.new()
	_sub_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_sub_vbox)
	_create_main_button("Attack", func(): _emit_main("attack", "slash"))
	_create_main_button("Spells", func(): _open_submenu("spells"))
	_create_main_button("Items", func(): _open_submenu("items"))
	_create_main_button("Defend", func(): _emit_main("defend", "defend"))
	_update_cursor(0)

func _create_main_button(text: String, on_press: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
	_main_vbox.add_child(b)
	_main_buttons.append(b)

func show_for_actor(actor_name: String, spells: Array[Dictionary], items: Array[Dictionary]) -> void:
	_actor_name = actor_name
	_spells = spells
	_items = items
	_sub_mode = ""
	_sub_panel.visible = false
	visible = true
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
		var btn: Button = Button.new()
		var _t: String = label
		if mp != null:
			_t = "%s  (%d MP)" % [label, int(mp)]
		btn.text = _t
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			var eid: String = String(entry.get("id", label)).to_lower()
			emit_signal("menu_action", kind, eid)
			visible = false
		)
		_sub_vbox.add_child(btn)
	_sub_panel.visible = true

func _close_submenu() -> void:
	_sub_mode = ""
	_sub_panel.visible = false

func hide_menu() -> void:
	visible = false
	_close_submenu()
