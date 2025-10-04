
extends Node
# NOTE: No `class_name` here because this script is autoloaded as `DataRegistry`.
# Having both `class_name DataRegistry` and an Autoload named `DataRegistry` causes symbol conflicts.

var characters: Dictionary = {}
var enemies: Dictionary = {}
var skills: Dictionary = {}
var items: Dictionary = {}
var encounters: Dictionary = {}
var upgrades: Dictionary = {} # New: Upgrades data

func _ready() -> void:
    load_all()

func load_all() -> void:
    characters = _load_json_dict("res://data/characters.json")
    enemies    = _load_json_dict("res://data/enemies.json")
    skills     = _load_json_dict("res://data/skills.json")
    items      = _load_json_dict("res://data/items.json")
    encounters = _load_json_dict("res://data/encounters.json")
    upgrades   = _load_json_dict("res://data/upgrades.json") # New: Load upgrades

func _load_json_dict(path: String) -> Dictionary:
    var dict: Dictionary = {}
    if not FileAccess.file_exists(path):
        return dict

    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return dict
    var txt: String = f.get_as_text()
    f.close()

    var data: Variant = JSON.parse_string(txt)
    match typeof(data):
        TYPE_DICTIONARY:
            dict = data
        TYPE_ARRAY:
            for entry in data:
                if typeof(entry) != TYPE_DICTIONARY:
                    continue
                var key: String = ""
                if entry.has("id"):
                    key = str(entry["id"])
                elif entry.has("name"):
                    key = str(entry["name"])
                else:
                    key = str(dict.size())
                dict[key] = entry
        _:
            pass
    return dict
