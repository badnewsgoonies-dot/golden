extends Node2D
@export var rise := Vector2(0,-28)
@export var duration := 0.65
@export var fade_delay := 0.2
var _t := 0.0
var _start := Vector2.ZERO
var _lbl: Label
func _ready() -> void:
    _lbl = $Label
    _start = position
func configure(amount: int, crit:=false, miss:=false) -> void:
    if miss:
        _lbl.text = "Miss"
        _lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
        return
    _lbl.text = str(amount)
    if crit:
        _lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
    elif _lbl.has_theme_color_override("font_color"):
        _lbl.remove_theme_color_override("font_color")
func _process(delta: float) -> void:
    _t += delta
    position = _start.lerp(_start + rise, clamp(_t/duration, 0.0, 1.0))
    if _t > fade_delay:
        var a := 1.0 - ((_t - fade_delay) / max(0.01, duration - fade_delay))
        modulate.a = clamp(a, 0.0, 1.0)
    if _t >= duration:
        queue_free()
