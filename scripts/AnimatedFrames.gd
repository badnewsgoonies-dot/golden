extends AnimatedSprite2D

class_name AnimatedFrames

const SpriteFactory = preload("res://art/SpriteFactory.gd")

@export var character := "adept"
@export var facing_back := true

const ANIM_DEF = {
	"idle_f": {"frames": 3, "fps": 8.0, "loop": true},
	"idle_b": {"frames": 3, "fps": 8.0, "loop": true},
	"hit_f": {"frames": 3, "fps": 12.0, "loop": false},
	"hit_b": {"frames": 3, "fps": 12.0, "loop": false},
	"attack_f": {"frames": 6, "fps": 12.0, "loop": false},
	"cast_f": {"frames": 6, "fps": 10.0, "loop": false},
	"guard_f": {"frames": 2, "fps": 8.0, "loop": true},
	"ko_f": {"frames": 5, "fps": 10.0, "loop": false},
}

const PLACEHOLDER_ANIM = "placeholder"
const IDLE_FRONT = "idle_f"
const IDLE_BACK = "idle_b"
var _has_frames := false

func _ready() -> void:
	_build_frames()
	_apply_orientation()

func _build_frames() -> void:
	var frames = SpriteFrames.new()
	var total_frames = 0
	for anim_name in ANIM_DEF.keys():
		var meta = ANIM_DEF[anim_name]
		var frame_count := int(meta.get("frames", 0))
		if frame_count <= 0:
			continue
		var textures: Array = []
		for i in range(frame_count):
			var path = "res://art/battlers/%s/%s/%s_%s_%d.png" % [character, anim_name, character, anim_name, i]
			# Avoid noisy errors by checking existence before load(); use SpriteFactory fallback later
			if FileAccess.file_exists(path):
				var tex: Texture2D = load(path)
				if tex is Texture2D:
					textures.append(tex)
				else:
					pass # Fail silently
			else:
				pass # Fail silently
		if textures.is_empty():
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(meta.get("fps", 12.0)))
		frames.set_animation_loop(anim_name, bool(meta.get("loop", false)))
		for tex in textures:
			frames.add_frame(anim_name, tex)
			total_frames += 1
	
	if total_frames == 0:
		# Build a one-frame procedural fallback via SpriteFactory
		var fallback_tex: Texture2D = _make_fallback_texture()
		var frames_fallback := SpriteFrames.new()
		var idle_name := IDLE_BACK if facing_back else IDLE_FRONT
		frames_fallback.add_animation(idle_name)
		frames_fallback.set_animation_loop(idle_name, true)
		frames_fallback.set_animation_speed(idle_name, 1.0)
		frames_fallback.add_frame(idle_name, fallback_tex)
		sprite_frames = frames_fallback
		_has_frames = true
		play(idle_name)
		return
	sprite_frames = frames
	_has_frames = true

func _make_placeholder_texture() -> Texture2D:
	var img = Image.create(48, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.25, 1.0))
	for y in range(8):
		for x in range(48):
			img.set_pixel(x, y, Color(0.7, 0.7, 0.8, 1.0))
	return ImageTexture.create_from_image(img)

func _make_fallback_texture() -> Texture2D:
	# Prefer a themed procedural sprite when assets are missing
	var role := character.to_lower()
	match role:
		"hero":
			return SpriteFactory.make_humanoid("adept", 3)
		"rogue":
			return SpriteFactory.make_humanoid("rogue", 3)
		"healer":
			return SpriteFactory.make_humanoid("cleric", 3)
		"mage":
			return SpriteFactory.make_humanoid("guard", 3)
		_:
			return SpriteFactory.make_monster(role, 3)

func _apply_orientation() -> void:
	if sprite_frames == null:
		return
	if not has_frames():
		play(PLACEHOLDER_ANIM)
		return
	_play_idle()

func _play_idle() -> void:
	var anim = IDLE_BACK if facing_back else IDLE_FRONT
	if sprite_frames.has_animation(anim) and sprite_frames.get_frame_count(anim) > 0:
		play(anim)
	else:
		var names = sprite_frames.get_animation_names()
		if names.size() > 0:
			play(names[0])

func has_frames() -> bool:
	return _has_frames

func set_facing_back(value: bool) -> void:
	facing_back = value
	_apply_orientation()

func play_idle() -> void:
	if not has_frames():
		return
	_play_idle()

func play_hit() -> void:
	var candidates = ["hit_b", "hit_f"] if facing_back else ["hit_f", "hit_b"]
	_play_and_return_to_idle(candidates)

func play_attack() -> void:
	_play_and_return_to_idle(["attack_f"])

func play_cast() -> void:
	_play_and_return_to_idle(["cast_f"])

func play_guard() -> void:
	_play_and_return_to_idle(["guard_f"], false)

func stop_guard() -> void:
	if not has_frames():
		return
	_play_idle()

func play_ko() -> void:
	_play_and_return_to_idle(["ko_f"], false)

func _play_and_return_to_idle(names: Array, auto_return = true) -> void:
	if not has_frames():
		return
	var target = ""
	for name in names:
		if sprite_frames.has_animation(name) and sprite_frames.get_frame_count(name) > 0:
			target = name
			break
	if target == "":
		return
	play(target)
	if not auto_return:
		return
	var tree = get_tree()
	if tree == null:
		return
	var frame_count = sprite_frames.get_frame_count(target)
	var speed = sprite_frames.get_animation_speed(target)
	if frame_count <= 0 or speed <= 0.0:
		return
	await tree.create_timer(frame_count / speed).timeout
	_play_idle()
