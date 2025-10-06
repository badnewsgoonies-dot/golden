extends Node
signal state_changed(prev: String, next: String)
var _state := "intro"
var _stack: Array[String] = []
func set_state(next: String) -> void:
    if _state == next: return
    var prev := _state
    _state = next
    emit_signal("state_changed", prev, next)
func push_state(next: String) -> void:
    _stack.push_back(_state)
    set_state(next)
func pop_state() -> void:
    if _stack.is_empty(): return
    var back: String = _stack.pop_back()
    set_state(back)
func is_state(s: String) -> bool: return _state == s
func get_state() -> String: return _state
