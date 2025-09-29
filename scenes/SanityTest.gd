extends Node

# LLM Sanity Test for Godot 4.x projects.
# Scans all .gd files under res:// for common Godot 3->4 API leftovers,
# typed-assignments from Dictionary.get without casts, yield(...), and BOM.

var issues: Array[String] = []
@onready var label: RichTextLabel = RichTextLabel.new()

func _ready() -> void:
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_add_view()
	_scan_project()
	_report()

func _add_view() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	ui.add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := Label.new()
	title.text = "LLM Sanity Test (Godot 4.x)"
	vb.add_child(title)
	vb.add_child(label)
	root.add_child(panel)

func _scan_project() -> void:
	issues.clear()
	_scan_dir("res://")

func _scan_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name.begins_with(".") or name in [".git", ".godot", ".import"]:
			continue
		var p := path.path_join(name)
		if d.current_is_dir():
			_scan_dir(p)
			continue
		if p.ends_with(".gd"):
			_scan_script(p)
		elif p.ends_with(".tscn"):
			_check_bom(p)
	d.list_dir_end()

func _check_bom(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	if not txt.is_empty() and int(txt.unicode_at(0)) == 0xFEFF:
		issues.append("BOM detected at start of: %s (save as UTF-8 without BOM)" % path)
	f.close()

func _scan_script(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	if not txt.is_empty() and int(txt.unicode_at(0)) == 0xFEFF:
		issues.append("BOM detected in %s (save as UTF-8 no BOM)" % path)
	var lines := txt.split("\n")
	for i in lines.size():
		var ln := lines[i]
		var ln_no := i + 1
		# Godot 3->4 API patterns
		if ln.find("KinematicBody2D") != -1:
			issues.append("%s:%d: Use CharacterBody2D instead of KinematicBody2D." % [path, ln_no])
		if ln.find("move_and_slide(") != -1 and ln.find(",") != -1:
			issues.append("%s:%d: move_and_slide() called with arguments; in G4 set velocity and call without args." % [path, ln_no])
		if ln.find("get_position(") != -1 or ln.find("get_global_position(") != -1:
			issues.append("%s:%d: Use position/global_position properties (Godot 4)." % [path, ln_no])
		if ln.find("Sprite2D.play(") != -1 or ln.find("Sprite.play(") != -1:
			issues.append("%s:%d: Sprite2D has no play(); use AnimatedSprite2D or AnimationPlayer." % [path, ln_no])
		if ln.find("yield(") != -1:
			issues.append("%s:%d: yield(...) found; prefer await in Godot 4." % [path, ln_no])
		# Typed var from Dictionary.get without cast
		if _typed_get_without_cast(ln):
			issues.append("%s:%d: Typed var assigned from Dictionary.get(...); add a cast (e.g., int(...))." % [path, ln_no])
	f.close()

func _typed_get_without_cast(line: String) -> bool:
	# Heuristic: line declares a typed var using ':' and '=' and calls get(
	if line.find(":") == -1 or line.find("=") == -1 or line.find("get(") == -1:
		return false
	var has_cast := line.find("int(") != -1 or line.find("float(") != -1 or line.find("bool(") != -1 or line.find("String(") != -1
	return not has_cast

func _report() -> void:
	if issues.is_empty():
		label.text = "All clear. No obvious 3->4 API leftovers or typing hazards found."
		print(label.text)
		return
	var out := "[b]Sanity findings:[/b]\n\n"
	for m in issues:
		out += "- %s\n" % m
	label.bbcode_enabled = true
	label.text = out
	print("Sanity Test Report:")
	for m in issues:
		print(" - %s" % m)