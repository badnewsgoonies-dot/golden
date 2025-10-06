extends Node

func _ready() -> void:
	# Defer scene change to avoid modifying the tree during initial construction
	get_tree().call_deferred("change_scene_to_file", "res://scenes/BattleScene.tscn")
