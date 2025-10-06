@tool
extends EditorScript
## AssetValidator.gd — run from the Script Editor: "File" > "Run" or F6
## Scans res://art/battlers/ and prints any missing frames per character.

const ANIMS := {
    "idle_f":3, "idle_b":3, "hit_f":3, "hit_b":3,
    "attack_f":6, "cast_f":6, "guard_f":2, "ko_f":5,
}

func _run() -> void:
    var fs := DirAccess.open("res://art/battlers")
    if fs == null:
        print("No battlers folder found at res://art/battlers")
        return
    fs.list_dir_begin()
    var name := fs.get_next()
    var missing := 0
    while name != "":
        if fs.current_is_dir() and not name.begins_with("."):
            var char := name
            for anim in ANIMS.keys():
                var frames: int = ANIMS[anim]
                for i in range(frames):
                    var p := "res://art/battlers/%s/%s/%s_%s_%d.png" % [char, anim, char, anim, i]
                    if not FileAccess.file_exists(p):
                        print("[%s] Missing %s frame %d -> %s" % [char, anim, i, p])
                        missing += 1
        name = fs.get_next()
    if missing == 0:
        print("All frames present. You're good!")
