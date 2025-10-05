extends Node
## Migration helper for switching between original and enhanced status systems

class_name StatusSystemMigrator

# Configuration - set to true to use enhanced system
const USE_ENHANCED_SYSTEM: bool = false  # Change to true when ready

# Get the appropriate Status class
static func get_status_class():
	if USE_ENHANCED_SYSTEM:
		return preload("res://battle/models/StatusEnhanced.gd")
	else:
		return preload("res://battle/models/Status.gd")

# Get the appropriate EffectSystem class
static func get_effect_system_class():
	if USE_ENHANCED_SYSTEM:
		return preload("res://battle/EffectSystemEnhanced.gd")
	else:
		return preload("res://battle/EffectSystem.gd")

# Get the appropriate skills data file
static func get_skills_data_path() -> String:
	if USE_ENHANCED_SYSTEM:
		return "res://data/skills_enhanced.json"
	else:
		return "res://data/skills.json"

# Convert old status to enhanced (for migration)
static func convert_to_enhanced(old_status):
	if not USE_ENHANCED_SYSTEM:
		return old_status
	
	var StatusEnhanced = preload("res://battle/models/StatusEnhanced.gd")
	var enhanced = StatusEnhanced.new(
		old_status.id,
		old_status.name,
		old_status.duration_turns,
		old_status.icon,
		old_status.metadata
	)
	
	# Auto-detect and set additional properties
	if old_status.id in ["poison", "burn", "bleed"]:
		enhanced.category = StatusEnhanced.Category.DOT
		enhanced.stack_type = StatusEnhanced.StackType.INTENSITY
	elif old_status.id == "stun":
		enhanced.category = StatusEnhanced.Category.CONTROL
		enhanced.stack_type = StatusEnhanced.StackType.NONE
	
	return enhanced

# Quick test function to verify both systems work
static func test_both_systems():
	print("Testing Status Systems...")
	
	# Test original
	var Status = preload("res://battle/models/Status.gd")
	var original = Status.new("poison", "Poison", 3, null, {"damage": 10})
	print("Original: ", original.to_string())
	
	# Test enhanced
	var StatusEnhanced = preload("res://battle/models/StatusEnhanced.gd")
	var enhanced = StatusEnhanced.new("poison", "Poison", 3, null, {"damage": 10})
	print("Enhanced: ", enhanced.to_string())
	
	print("Both systems operational!")
