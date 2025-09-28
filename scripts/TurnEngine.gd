extends Node

func build_initiative(combatants: Array) -> Array:
    var entries: Array = []
    for c in combatants:
        var spd := int(c.get("spd", 10))
        var jitter := GameManager.randi_range(0, max(1, int(spd * 0.25)))
        entries.append({ "name": c.get("name","?"), "ref": c, "roll": spd + jitter })
    entries.sort_custom(func(a, b): return a["roll"] > b["roll"])
    return entries
