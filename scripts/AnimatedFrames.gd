extends AnimatedSprite2D

class_name AnimatedFrames

@export var character: String = "adept"
@export var facing_back: bool = true

const ANIMS := {
	"idle_f": 3,
	"idle_b": 3,
	"hit_f": 3,
	"hit_b": 3,
}

const PLACEHOLDER_ANIM := "placeholder"
var _has_frames := false

func _ready() -> void:
	_build_frames()
	_apply_orientation()

func _build_frames() -> void:
	var frames := SpriteFrames.new()
	var total_frames := 0
	for anim_name in ANIMS.keys():
		var frame_count := int(ANIMS[anim_name])
		var textures: Array[Texture2D] = []
		for i in range(frame_count):
			var path := "res://art/battlers/%s/%s/%s_%s_%d.png" % [character, anim_name, character, anim_name, i]
			var tex: Texture2D = load(path)
			if tex is Texture2D:
				textures.append(tex)
		if textures.is_empty():
			continue
		frames.add_animation(anim_name)
		var loop: bool = String(anim_name).begins_with("idle")
		frames.set_animation_loop(anim_name, loop)
		var speed := 8.0 if loop else 12.0
		frames.set_animation_speed(anim_name, speed)
		for tex in textures:
			frames.add_frame(anim_name, tex)
			total_frames += 1
	if total_frames == 0:
		var placeholder := SpriteFrames.new()
		placeholder.add_animation(PLACEHOLDER_ANIM)
		placeholder.set_animation_loop(PLACEHOLDER_ANIM, true)
		placeholder.set_animation_speed(PLACEHOLDER_ANIM, 1.0)
		placeholder.add_frame(PLACEHOLDER_ANIM, _make_placeholder_texture())
		sprite_frames = placeholder
		_has_frames = true
		play(PLACEHOLDER_ANIM)
		return
	sprite_frames = frames
	_has_frames = true

func _make_placeholder_texture() -> Texture2D:
	var img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.25, 1.0))
	for y in range(8):
		for x in range(48):
			img.set_pixel(x, y, Color(0.7, 0.7, 0.8, 1.0))
	return ImageTexture.create_from_image(img)

func _apply_orientation() -> void:
	if sprite_frames == null:
		return
	if not has_frames():
		play(PLACEHOLDER_ANIM)
		return
	var anim := "idle_b" if facing_back else "idle_f"
	if sprite_frames.has_animation(anim) and sprite_frames.get_frame_count(anim) > 0:
		play(anim)
	else:
		var names := sprite_frames.get_animation_names()
		if names.size() > 0:
			play(names[0])

func has_frames() -> bool:
	return _has_frames

func set_facing_back(value: bool) -> void:
	facing_back = value
	_apply_orientation()

func play_hit() -> void:
	if not has_frames():
		return
	var anim := "hit_b" if facing_back else "hit_f"
	if sprite_frames.has_animation(anim) and sprite_frames.get_frame_count(anim) > 0:
		play(anim)
		var idle_anim := "idle_b" if facing_back else "idle_f"
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(0.18).timeout
			play(idle_anim)
