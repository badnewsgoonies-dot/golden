extends Node
class_name PortraitLoader

static var _cache: Dictionary = {}
static var _alias: Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	var path := "res://art/portrait_alias.json"
	if FileAccess.file_exists(path):
		var txt := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			# Normalize keys to lowercase
			for k in parsed.keys():
				_alias[String(k).to_lower()] = String(parsed[k])
	_loaded = true

static func get_portrait_for(name: String) -> Texture2D:
	_ensure_loaded()
	if name == null or String(name).is_empty():
		return null
	var key := String(name).strip_edges().to_lower()
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	# 1) alias lookup
	if _alias.has(key):
		tex = _try_load_texture(_alias[key])
	# 2) direct filename using snake case
	if tex == null:
		var snake := key.replace(" ", "_")
		tex = _try_load_texture("res://art/portraits/%s_portrait_96.png" % snake)
	# 3) fallback
	_cache[key] = tex
	return tex

static func _try_load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if FileAccess.file_exists(path) else null