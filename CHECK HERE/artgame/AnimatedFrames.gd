extends AnimatedSprite2D

@export var character: String = "hero"    # matches folder name in art/battlers
@export var facing_back: bool = true

const ANIM_DEF := {
    "idle_f": {"frames": 3, "fps": 8.0,  "loop": true},
    "idle_b": {"frames": 3, "fps": 8.0,  "loop": true},
    "hit_f":  {"frames": 3, "fps": 12.0, "loop": false},
    "hit_b":  {"frames": 3, "fps": 12.0, "loop": false},
    "attack_f": {"frames": 6, "fps": 12.0, "loop": false},
    "cast_f":   {"frames": 6, "fps": 10.0, "loop": false},
    "guard_f":  {"frames": 2, "fps": 8.0,  "loop": true},
    "ko_f":     {"frames": 5, "fps": 10.0, "loop": false},
}

func _ready() -> void:
    var sf := SpriteFrames.new()
    for anim_name in ANIM_DEF.keys():
        var meta = ANIM_DEF[anim_name]
        sf.add_animation(anim_name)
        sf.set_animation_speed(anim_name, meta["fps"])
        sf.set_animation_loop(anim_name, meta["loop"])
        var frames := meta["frames"]
        for i in frames:
            var path := "res://art/battlers/%s/%s/%s_%s_%d.png" % [character, anim_name, character, anim_name, i]
            var tex := load(path)
            if tex:
                sf.add_frame(anim_name, tex)
    sprite_frames = sf
    play(facing_back ? "idle_b" : "idle_f")
