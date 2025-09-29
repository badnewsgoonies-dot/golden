extends Node

var rng := RandomNumberGenerator.new()
var rng_seed: int = 0

func set_seed(new_seed: int) -> void:
	rng_seed = new_seed
	rng.seed = new_seed

func randf() -> float:
	return rng.randf()

func randi_range(a: int, b: int) -> int:
	return rng.randi_range(a, b)
