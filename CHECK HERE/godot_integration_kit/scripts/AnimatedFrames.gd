
extends AnimatedSprite2D
## AnimatedFrames.gd — build SpriteFrames from res://art/battlers/<character>/<anim>/<character>_<anim>_<i>.png
## Drop this on each battler node. Set `character` & `facing_back` in the inspector.
## Godot 4.5

@export var character: String = "hero"
@export var facing_back: bool = true

const ANIMS := {
    "idle_f":  {"frames": 3, "fps": 8.0,  "loop": true},
    "idle_b":  {"frames": 3, "fps": 8.0,  "loop": true},
    "hit_f":   {"frames": 3, "fps": 12.0, "loop": false},
    "hit_b":   {"frames": 3, "fps": 12.0, "loop": false},
    "attack_f":{"frames": 6, "fps": 12.0, "loop": false},
    "cast_f":  {"frames": 6, "fps": 10.0, "loop": false},
    "guard_f": {"frames": 2, "fps": 8.0,  "loop": true},
    "ko_f":    {"frames": 5, "fps": 10.0, "loop": false},
}

signal anim_finished(name: String)

func _ready() -> void:
    var sf := SpriteFrames.new()
    for name in ANIMS.keys():
        var def := ANIMS[name]
        sf.add_animation(name)
        sf.set_animation_speed(name, def["fps"])
        sf.set_animation_loop(name, def["loop"])
        for i in def["frames"]:
            var p := "res://art/battlers/%s/%s/%s_%s_%d.png" % [character, name, character, name, i]
            var tex: Texture2D = load(p)
            if tex:
                sf.add_frame(name, tex)
    sprite_frames = sf
    play(facing_back ? "idle_b" : "idle_f")
    connect("animation_finished", Callable(self, "_on_anim_finished"))

func _on_anim_finished() -> void:
    emit_signal("anim_finished", animation)
