
extends Node
signal turn_ready(unit_id: String)
@export var atb := false
var _charge := {}
var _speed := {}
func register(unit_id: String, speed: float) -> void:
    _speed[unit_id] = speed; _charge[unit_id] = 0.0
func unregister(unit_id: String) -> void:
    _speed.erase(unit_id); _charge.erase(unit_id)
func tick(delta: float) -> void:
    if atb:
        for k in _charge.keys():
            _charge[k] += clamp(_speed[k] * delta * 0.01, 0.0, 1.0)
            if _charge[k] >= 1.0:
                _charge[k] = 0.0
                emit_signal("turn_ready", k)
func set_ready(unit_id: String) -> void: emit_signal("turn_ready", unit_id)
func get_charge(unit_id: String) -> float: return _charge.get(unit_id, 0.0)
