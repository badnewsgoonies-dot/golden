extends Control
class_name TriangleTail

@export var fill_color: Color = Color(0.98, 0.93, 0.70)
@export var outline_color: Color = Color.BLACK
@export var outline_width: float = 2.0

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var p1 := Vector2(4.0, 0.0)
	var p2 := Vector2(w - 4.0, 0.0)
	var p3 := Vector2(w * 0.5, h)
	var pts: PackedVector2Array = [p1, p2, p3]
	draw_colored_polygon(pts, fill_color)
	draw_polyline(pts + PackedVector2Array([p1]), outline_color, outline_width)
