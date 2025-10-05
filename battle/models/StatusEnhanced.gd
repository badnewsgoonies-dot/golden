class_name StatusEnhanced
extends RefCounted

## Enhanced status effect data model with stacking, categories, and priorities

# Core identification
var id: String
var name: String
var description: String = ""

# Duration management
var duration_turns: int
var max_duration: int  # For refresh logic
var permanent: bool = false  # Some effects might not expire

# Visual representation
var icon: Texture2D
var color: Color = Color.WHITE

# Effect categorization
enum Category {
	BUFF,      # Positive effects
	DEBUFF,    # Negative effects  
	DOT,       # Damage over time
	HOT,       # Heal over time
	CONTROL,   # Stun, freeze, etc
	SPECIAL    # Unique mechanics
}
var category: Category = Category.DEBUFF

# Stacking behavior
enum StackType {
	NONE,      # Can't stack - new application does nothing
	REFRESH,   # Refreshes duration to max
	STACK,     # Allows multiple instances
	INTENSITY, # Increases power but single instance
	EXTEND     # Adds to duration
}
var stack_type: StackType = StackType.REFRESH
var stack_count: int = 1
var max_stacks: int = 1

# Processing priority (lower = earlier)
var priority: int = 50

# Effect data
var metadata: Dictionary = {}

# Stats for tracking
var total_value_dealt: int = 0  # Track total damage/healing done
var times_triggered: int = 0

func _init(status_id: String, status_name: String, duration: int, 
		status_icon: Texture2D = null, extra_data: Dictionary = {}):
	self.id = status_id
	self.name = status_name
	self.duration_turns = duration
	self.max_duration = duration
	self.icon = status_icon
	self.metadata = extra_data.duplicate()
	
	# Auto-categorize based on ID if not specified
	if not metadata.has("category"):
		_auto_categorize()
	else:
		category = metadata.get("category", Category.DEBUFF)
	
	# Set stack type from metadata
	if metadata.has("stack_type"):
		var stack_str = metadata.get("stack_type", "refresh")
		stack_type = _string_to_stack_type(stack_str)
	
	# Set priority from metadata or auto-assign
	priority = metadata.get("priority", _auto_priority())
	
	# Max stacks for intensity stacking
	max_stacks = metadata.get("max_stacks", 5)

## Decrements duration and returns true if expired
func tick() -> bool:
	if permanent:
		return false
		
	if duration_turns > 0:
		duration_turns -= 1
	
	return duration_turns <= 0

## Handles stacking with another status of same type
func stack_with(other: StatusEnhanced) -> void:
	match stack_type:
		StackType.NONE:
			pass  # Do nothing
		
		StackType.REFRESH:
			duration_turns = max_duration
		
		StackType.STACK:
			# This would create a new instance, handled elsewhere
			pass
		
		StackType.INTENSITY:
			if stack_count < max_stacks:
				stack_count += 1
				# Increase effect power
				var damage = metadata.get("damage", 0)
				if damage > 0:
					metadata["damage"] = damage * 1.2  # 20% increase per stack
		
		StackType.EXTEND:
			duration_turns += other.duration_turns

## Get current effect value accounting for stacks
func get_effect_value(key: String) -> float:
	var base_value = float(metadata.get(key, 0))
	
	if stack_type == StackType.INTENSITY:
		return base_value * stack_count
	
	return base_value

## Auto-categorize based on common effect names
func _auto_categorize() -> void:
	var id_lower = id.to_lower()
	
	# Debuffs
	if id_lower in ["poison", "burn", "bleed", "curse", "slow", "weak"]:
		category = Category.DEBUFF
	# DOTs
	elif id_lower in ["poison", "burn", "bleed"]:
		category = Category.DOT
	# Control
	elif id_lower in ["stun", "freeze", "sleep", "paralyze", "silence"]:
		category = Category.CONTROL
	# Buffs
	elif id_lower in ["haste", "strength", "shield", "regen", "bless"]:
		category = Category.BUFF
	# HOTs
	elif id_lower in ["regen", "healing_aura"]:
		category = Category.HOT
	else:
		category = Category.SPECIAL

## Auto-assign priority based on category
func _auto_priority() -> int:
	match category:
		Category.HOT:
			return 10  # Heals first
		Category.BUFF:
			return 20
		Category.DOT:
			return 30  # Damage after heals
		Category.DEBUFF:
			return 40
		Category.CONTROL:
			return 50
		_:
			return 60

## Convert string to StackType enum
func _string_to_stack_type(type_str: String) -> StackType:
	match type_str.to_lower():
		"none": return StackType.NONE
		"refresh": return StackType.REFRESH
		"stack": return StackType.STACK
		"intensity": return StackType.INTENSITY
		"extend": return StackType.EXTEND
		_: return StackType.REFRESH

## Check if this is a beneficial effect
func is_beneficial() -> bool:
	return category in [Category.BUFF, Category.HOT]

## Check if this is a harmful effect
func is_harmful() -> bool:
	return category in [Category.DEBUFF, Category.DOT, Category.CONTROL]

## Get display info for UI
func get_display_string() -> String:
	var display = name
	if stack_count > 1:
		display += " x%d" % stack_count
	if not permanent and duration_turns > 0:
		display += " (%d)" % duration_turns
	return display

func _to_string() -> String:
	return "Status(%s, %d turns, x%d stacks, priority:%d)" % [name, duration_turns, stack_count, priority]
