
extends Node
## PortraitLoader.gd — alias-aware portrait resolver for HUD
## Usage:
##   var tex := PortraitLoader.get_portrait_for("hero")  # or display name
##   portrait_sprite.texture = tex

static var _alias := {}

static func _load_alias() -> void:
    if _alias.size() > 0: return
    var fa := FileAccess.open("res://art/portrait_alias.json", FileAccess.READ)
    if fa:
        var data = JSON.parse_string(fa.get_as_text())
        if typeof(data) == TYPE_DICTIONARY:
            _alias = data

static func get_portrait_for(name_or_key: String) -> Texture2D:
    _load_alias()
    var k := name_or_key.strip_edges().to_lower()
    var candidates := PackedStringArray()
    candidates.append("res://art/portraits/%s_portrait_96.png" % k)
    if _alias.has(k):
        candidates.append(String(_alias[k]))
    # common fallbacks
    candidates.append("res://assets/faces/%s_face.png" % k)
    candidates.append("res://assets/faces/%s.png" % k)
    for p in candidates:
        var t: Texture2D = load(p)
        if t:
            return t
    push_warning("Portrait not found for '%s'" % k)
    return null
