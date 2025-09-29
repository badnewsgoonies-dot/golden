extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@export var back_facing: bool = true

func _ready():
    set_idle()

func set_idle():
    anim.play(back_facing ? "idle_b" : "idle_f")

func take_hit():
    anim.play(back_facing ? "hit_b" : "hit_f")

func play_attack():
    # We only wire idle/hit here; add "attack_f" later if you add frames.
    anim.play("hit_f")

func set_back_facing(v: bool):
    back_facing = v
    set_idle()