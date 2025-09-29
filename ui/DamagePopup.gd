extends Label

@export var rise_distance: float = 24.0
@export var duration: float = 0.6
@export var start_alpha: float = 1.0
@export var end_alpha: float = 0.0

var _tween: Tween

func popup(at_screen_pos: Vector2, text_value: String, color: Color = Color.WHITE) -> void:
	text = text_value
	modulate = Color(color.r, color.g, color.b, start_alpha)
	position = at_screen_pos
	_tween = create_tween()
	_tween.tween_property(self, "position", position + Vector2(0, -rise_distance), duration)
	_tween.parallel().tween_property(self, "modulate:a", end_alpha, duration)
	_tween.finished.connect(queue_free)
