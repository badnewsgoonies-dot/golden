extends Control

func _ready() -> void:
	# For demonstration, let's just print available upgrades
	print("Available Upgrades:")
	for upgrade_id in DataRegistry.upgrades:
		var upgrade_data = DataRegistry.upgrades[upgrade_id]
		print("- %s: %s" % [upgrade_data.name, upgrade_data.description])
	
	# In a real game, you would present these to the player via UI
	# and allow them to select one.
	# For now, we'll just simulate applying the first upgrade to the hero.
	if DataRegistry.upgrades.size() > 0:
		var first_upgrade_id = DataRegistry.upgrades.keys()[0]
		var first_upgrade_data = DataRegistry.upgrades[first_upgrade_id]
		
		# This part assumes you have a way to access the player's hero unit.
		# For a quick test, let's assume GameManager has a reference to the hero.
		# This will need proper integration later.
		# Apply the upgrade to the current hero unit
		if GameManager.current_hero_unit != null:
			GameManager.current_hero_unit.apply_upgrade(first_upgrade_data)
			print("Applied upgrade: %s to %s" % [first_upgrade_data.name, GameManager.current_hero_unit.name])
		else:
			print("Error: No hero unit found in GameManager to apply upgrade.")
		
	# After selection (or simulation), transition back to the Battle scene
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
