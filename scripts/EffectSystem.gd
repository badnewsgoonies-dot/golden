extends Node

func apply_poison_tick(target: Dictionary) -> int:
    var tick := int(ceil(target.get("max_hp", 100) * 0.07))
    target["hp"] = max(0, int(target.get("hp", 0)) - tick)
    return tick
