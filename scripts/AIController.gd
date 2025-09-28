extends Node

func choose_action(actor: Dictionary, enemy: Dictionary) -> String:
    if enemy.get("hp", 999) <= 30:
        return "attack"
    return "attack" if GameManager.randf() < 0.8 else "defend"
