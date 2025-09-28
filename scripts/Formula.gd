extends Node

func damage(atk: int, def: int, variance: int = 2, is_crit: bool = false, weak: bool = false, resist: bool = false) -> int:
    var base: int = atk - int(def * 0.5)
    var var_roll: int = GameManager.randi_range(-variance, variance)
    var dmg: int = max(1, base + var_roll)
    if is_crit:
        dmg = int(dmg * 1.5)
    if weak:
        dmg = int(dmg * 1.5)
    if resist:
        dmg = int(dmg * 0.5)
    return max(1, dmg)
