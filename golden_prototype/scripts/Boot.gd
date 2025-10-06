extends Node

func _ready() -> void:
	print("Boot _ready()")
	_change_to_quickstart()

func _change_to_quickstart() -> void:
	var err := get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
	if err != OK:
		push_error("Failed to load BattleScene.tscn: %d" % err)
	else:
		print("Loaded BattleScene")
