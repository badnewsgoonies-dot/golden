
extends Node
func spawn_damage_number(root: Node, pos: Vector2, amount: int, crit:=false) -> void:
    var scene: PackedScene = load("res://scenes/FX/damage_number.tscn")
    var n := scene.instantiate()
    root.add_child(n)
    n.global_position = pos
    n.call_deferred("configure", amount, crit)
func spawn_selector(root: Node, pos: Vector2) -> Node2D:
    var scene: PackedScene = load("res://scenes/FX/selector_arrow.tscn")
    var a := scene.instantiate()
    root.add_child(a)
    a.global_position = pos
    return a
