extends Node

func _ready() -> void:
	DataRegistry.load_all()
	RunManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")
