extends Node
const SAVE_PATH := "user://save.json"

func save_snapshot(snapshot: Dictionary) -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(snapshot))
        f.close()

func load_snapshot() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var txt := f.get_as_text()
    f.close()
    var data: Variant = JSON.parse_string(txt)
    return data if typeof(data) == TYPE_DICTIONARY else {}
