extends Control
class_name TargetSelector

signal target_selected(target: Dictionary)
signal cancelled()

var _targets: Array[Dictionary] = []
var _selected_index: int = 0
var _selector_sprites: Array[Sprite2D] = []

func _ready() -> void:
	name = "TargetSelector"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_for_targets(targets: Array) -> void:
	_targets.clear()
	for t in targets:
		if typeof(t) == TYPE_DICTIONARY:
			_targets.append(t)
	
	if _targets.is_empty():
		visible = false
		return
	
	_selected_index = 0
	visible = true
	_update_selectors()

func hide_selector() -> void:
	visible = false
	_clear_selectors()

func _clear_selectors() -> void:
	for sprite in _selector_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_selector_sprites.clear()

func _update_selectors() -> void:
	_clear_selectors()
	
	if not visible or _targets.is_empty():
		return
	
	# Create selector sprites for each target
	for i in range(_targets.size()):
		var target: Dictionary = _targets[i]
		var sprite_node = target.get("sprite", null)
		
		if sprite_node == null:
			continue
		
		# Get the target's position
		var target_pos: Vector2 = Vector2.ZERO
		if sprite_node is Node2D:
			target_pos = (sprite_node as Node2D).global_position
		
		# Create selector arrow sprite
		var selector := Sprite2D.new()
		selector.texture = _get_arrow_texture()
		selector.global_position = target_pos + Vector2(0, -60)  # Above the target
		selector.modulate = Color(1, 1, 0) if i == _selected_index else Color(0.5, 0.5, 0.5, 0.3)
		selector.z_index = 100
		
		# Add to scene tree (find the root battle scene)
		var battle_scene = get_tree().current_scene
		if battle_scene != null:
			battle_scene.add_child(selector)
			_selector_sprites.append(selector)
		
		# Animate the selected one
		if i == _selected_index:
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(selector, "position:y", selector.position.y - 5, 0.3)
			tween.tween_property(selector, "position:y", selector.position.y, 0.3)

func _create_arrow_texture() -> Texture2D:
	# Create a simple downward-pointing arrow
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw a yellow arrow (inverted V shape pointing down)
	for y in range(16, 26):
		var width: int = (y - 15) * 2
		for x in range(16 - width / 2, 16 + width / 2 + 1):
			if x >= 0 and x < 32:
				img.set_pixel(x, y, Color(1, 1, 0))
	
	# Add black outline
	for y in range(15, 27):
		var width: int = (y - 15) * 2
		var left_x: int = 16 - width / 2 - 1
		var right_x: int = 16 + width / 2 + 1
		if left_x >= 0 and left_x < 32:
			img.set_pixel(left_x, y, Color(0, 0, 0))
		if right_x >= 0 and right_x < 32:
			img.set_pixel(right_x, y, Color(0, 0, 0))
	
	return ImageTexture.create_from_image(img)

func _get_arrow_texture() -> Texture2D:
	var ui_arrow_path := "res://Art Info/art/ui/selector_arrow.png"
	if FileAccess.file_exists(ui_arrow_path):
		var tex = load(ui_arrow_path)
		if tex is Texture2D:
			return tex
	return _create_arrow_texture()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _targets.is_empty():
		return
	
	var handled := false
	
	if event.is_action_pressed("ui_left"):
		_move_selection(-1)
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move_selection(1)
		handled = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_confirm_selection()
		handled = true
	elif event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		hide_selector()
		handled = true
	
	if handled:
		get_viewport().set_input_as_handled()

func _move_selection(delta: int) -> void:
	if _targets.is_empty():
		return
	
	_selected_index = (_selected_index + delta + _targets.size()) % _targets.size()
	_update_selectors()

func _confirm_selection() -> void:
	if _selected_index >= 0 and _selected_index < _targets.size():
		target_selected.emit(_targets[_selected_index])
		hide_selector()

func get_selected_target() -> Dictionary:
	if _selected_index >= 0 and _selected_index < _targets.size():
		return _targets[_selected_index]
	return {}
