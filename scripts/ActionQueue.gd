extends Node
class Act:
    var unit_id: String
    var action: String
    var speed: float
    var payload := {}
    func _init(id, act, spd, pay={}):
        unit_id = id; action = act; speed = spd; payload = pay
var _queue: Array = []
var _counter := 0
func push(act: Act) -> void:
    _counter += 1
    _queue.append({"k": -act.speed, "t": _counter, "v": act})
    _queue.sort_custom(Callable(self, "_cmp"))
func _cmp(a, b):
    if a.k == b.k: return a.t < b.t
    return a.k < b.k
func pop() -> Act:
    if _queue.is_empty(): return null
    return _queue.pop_front().v
func is_empty() -> bool: return _queue.is_empty()
func clear() -> void: _queue.clear()
