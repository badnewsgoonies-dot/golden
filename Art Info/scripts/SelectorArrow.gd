
extends Sprite2D
@export var bob_amplitude := 4.0
@export var bob_speed := 2.2
var _t := 0.0
func _process(delta: float) -> void:
	_t += delta
	position.y = -abs(sin(_t * bob_speed)) * bob_amplitude
