extends Panel

# Simple unit representation for prototype testing
# Replace fancy art with colored rectangles

@export var unit_type: String = "warrior"
@export var unit_color: Color = Color(0.3, 0.5, 0.8, 1)
@export var is_enemy: bool = false

@onready var unit_rect = $UnitRect
@onready var label = $Label
@onready var hp_bar = $HPBar
@onready var hp_label = $HPLabel

var max_hp: int = 100
var current_hp: int = 100
var attack: int = 10
var defense: int = 5

# Unit type colors for easy identification
var unit_colors = {
	"warrior": Color(0.8, 0.3, 0.3, 1),    # Red
	"archer": Color(0.3, 0.8, 0.3, 1),     # Green
	"mage": Color(0.3, 0.3, 0.8, 1),       # Blue
	"healer": Color(0.8, 0.8, 0.3, 1),     # Yellow
	"tank": Color(0.5, 0.5, 0.5, 1),       # Gray
	"rogue": Color(0.6, 0.3, 0.6, 1),      # Purple
	"enemy": Color(0.8, 0.2, 0.2, 1)       # Dark Red
}

func _ready():
	setup_unit()
	
func setup_unit():
	# Set color based on unit type
	if is_enemy:
		unit_color = unit_colors.get("enemy", Color.RED)
		# Add a border to distinguish enemies
		var stylebox = get_theme_stylebox("panel").duplicate()
		stylebox.border_color = Color.RED
		add_theme_stylebox_override("panel", stylebox)
	else:
		unit_color = unit_colors.get(unit_type, Color.WHITE)
	
	unit_rect.color = unit_color
	label.text = unit_type.to_upper()
	update_hp_display()

func set_unit_data(data: Dictionary):
	unit_type = data.get("type", "warrior")
	max_hp = data.get("max_hp", 100)
	current_hp = data.get("current_hp", max_hp)
	attack = data.get("attack", 10)
	defense = data.get("defense", 5)
	is_enemy = data.get("is_enemy", false)
	setup_unit()

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	update_hp_display()
	
	# Simple flash effect
	unit_rect.modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	unit_rect.modulate = Color(1, 1, 1, 1)
	
	if current_hp <= 0:
		die()

func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)
	update_hp_display()
	
	# Simple heal flash
	unit_rect.modulate = Color.GREEN
	await get_tree().create_timer(0.1).timeout
	unit_rect.modulate = Color(1, 1, 1, 1)

func update_hp_display():
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = str(current_hp) + "/" + str(max_hp)
	
	# Change color based on HP percentage
	var hp_percent = float(current_hp) / float(max_hp)
	if hp_percent > 0.5:
		hp_bar.modulate = Color.GREEN
	elif hp_percent > 0.25:
		hp_bar.modulate = Color.YELLOW
	else:
		hp_bar.modulate = Color.RED

func die():
	# Simple death effect
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func play_attack_animation():
	# Simple attack animation - just move forward and back
	var original_pos = position
	var tween = get_tree().create_tween()
	if is_enemy:
		tween.tween_property(self, "position:x", position.x - 30, 0.2)
	else:
		tween.tween_property(self, "position:x", position.x + 30, 0.2)
	tween.tween_property(self, "position", original_pos, 0.2)

func highlight(enabled: bool):
	if enabled:
		unit_rect.modulate = Color(1.5, 1.5, 1.5, 1)
	else:
		unit_rect.modulate = Color(1, 1, 1, 1)