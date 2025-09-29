extends AnimatedSprite2D

@export var character_name: String = "hero"

const ANIMS := {
    "idle_f": 3,
    "idle_b": 3,
    "hit_f": 3,
    "hit_b": 3
}

func _ready():
    # Build SpriteFrames programmatically from res://sprites/<character>/ folders.
    var sf := SpriteFrames.new()
    for anim_name in ANIMS.keys():
        sf.add_animation(anim_name)
        sf.set_animation_speed(anim_name, (anim_name.begins_with("idle") ? 8.0 : 12.0))
        sf.set_animation_loop(anim_name, true)
        var frames := ANIMS[anim_name]
        for i in frames:
            var path := "res://sprites/%s/%s/%s_%s_%d.png" % [character_name, anim_name, character_name, anim_name, i]
            var tex := load(path)
            if tex:
                sf.add_frame(anim_name, tex)
    sprite_frames = sf