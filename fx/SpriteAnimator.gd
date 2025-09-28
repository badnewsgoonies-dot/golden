class_name SpriteAnimator
extends Node

# Attach to a sprite directly (legacy path). Builds absolute-position animations.
static func attach(sprite: Node2D, facing: int = 1) -> AnimationPlayer:
	_ensure_glow(sprite)
	var ap: AnimationPlayer = sprite.get_node_or_null("Anim")
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		sprite.add_child(ap)
		_build_animations(ap, sprite, facing)
		ap.play("idle")
	return ap

# Attach to a zero-based pivot node. All motion keys are relative (0 → offset → 0).
static func attach_to_pivot(pivot: Node2D, facing: int = 1) -> AnimationPlayer:
	_ensure_glow(pivot)
	var ap: AnimationPlayer = pivot.get_node_or_null("Anim")
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		pivot.add_child(ap)
		_build_zero_based(ap, pivot, facing)
		ap.play(_resolve_anim_name(ap, "idle"))
	return ap

static func _build_animations(ap: AnimationPlayer, sprite: Node2D, facing: int) -> void:
	ap.root_node = ap.get_path_to(sprite)

	# idle loop
	var idle: Animation = Animation.new()
	idle.loop_mode = Animation.LOOP_LINEAR
	idle.length = 0.6
	idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(0, ":position:y")
	idle.track_insert_key(0, 0.0, sprite.position.y)
	idle.track_insert_key(0, 0.3, sprite.position.y - 2.0)
	idle.track_insert_key(0, 0.6, sprite.position.y)
	_put_anim(ap, "idle", idle)

	# attack lunge + optional arm swing
	var atk: Animation = Animation.new()
	atk.length = 0.25
	atk.loop_mode = Animation.LOOP_NONE
	atk.add_track(Animation.TYPE_VALUE)
	atk.track_set_path(0, ":position:x")
	atk.track_insert_key(0, 0.0, sprite.position.x)
	atk.track_insert_key(0, 0.10, sprite.position.x + 14.0 * float(facing))
	atk.track_insert_key(0, 0.25, sprite.position.x)
	var arm: Node2D = sprite.get_node_or_null("Arm")
	if arm != null:
		atk.add_track(Animation.TYPE_VALUE)
		atk.track_set_path(1, "Arm:rotation_degrees")
		atk.track_insert_key(1, 0.0, 0.0)
		atk.track_insert_key(1, 0.06, -20.0 * float(facing))
		atk.track_insert_key(1, 0.14, 35.0 * float(facing))
		atk.track_insert_key(1, 0.25, 0.0)
	_put_anim(ap, "attack", atk)

	# cast (arm raise + glow pulse)
	var cast: Animation = Animation.new()
	cast.loop_mode = Animation.LOOP_NONE
	cast.length = 0.35
	# slight lift on Y
	cast.add_track(Animation.TYPE_VALUE)
	cast.track_set_path(0, ":position:y")
	var y0: float = sprite.position.y
	cast.track_insert_key(0, 0.0, y0)
	cast.track_insert_key(0, 0.18, y0 - 3.0)
	cast.track_insert_key(0, 0.35, y0)
	# arm raise if present
	if arm != null:
		cast.add_track(Animation.TYPE_VALUE)
		cast.track_set_path(1, "Arm:rotation_degrees")
		cast.track_insert_key(1, 0.0, -40.0 * float(facing))
		cast.track_insert_key(1, 0.18, -65.0 * float(facing))
		cast.track_insert_key(1, 0.35, 0.0)
	# glow pulse if present
	var glow: Node2D = sprite.get_node_or_null("Glow")
	if glow != null:
		var alpha_track: int = 2 if arm != null else 1
		cast.add_track(Animation.TYPE_VALUE)
		cast.track_set_path(alpha_track, "Glow:modulate:a")
		cast.track_insert_key(alpha_track, 0.0, 0.0)
		cast.track_insert_key(alpha_track, 0.18, 0.9)
		cast.track_insert_key(alpha_track, 0.35, 0.0)

		var scale_track: int = 3 if arm != null else 2
		cast.add_track(Animation.TYPE_VALUE)
		cast.track_set_path(scale_track, "Glow:scale")
		var g0: Vector2 = (glow as Node2D).scale
		cast.track_insert_key(scale_track, 0.0, g0 * 0.8)
		cast.track_insert_key(scale_track, 0.18, g0 * 1.25)
		cast.track_insert_key(scale_track, 0.35, g0 * 0.8)
	_put_anim(ap, "cast", cast)

	# hurt flash
	var hurt: Animation = Animation.new()
	hurt.length = 0.20
	hurt.loop_mode = Animation.LOOP_NONE
	hurt.add_track(Animation.TYPE_VALUE)
	hurt.track_set_path(0, ":modulate")
	hurt.track_insert_key(0, 0.0, Color(1, 1, 1, 1))
	hurt.track_insert_key(0, 0.08, Color(2, 2, 2, 1))
	hurt.track_insert_key(0, 0.20, Color(1, 1, 1, 1))
	_put_anim(ap, "hurt", hurt)

	# die fade+scale
	var die: Animation = Animation.new()
	die.length = 0.35
	die.loop_mode = Animation.LOOP_NONE
	die.add_track(Animation.TYPE_VALUE)
	die.track_set_path(0, ":modulate:a")
	die.track_insert_key(0, 0.0, 1.0)
	die.track_insert_key(0, 0.35, 0.0)
	die.add_track(Animation.TYPE_VALUE)
	die.track_set_path(1, ":scale")
	die.track_insert_key(1, 0.0, sprite.scale)
	die.track_insert_key(1, 0.35, sprite.scale * 0.6)
	_put_anim(ap, "die", die)

static func _build_zero_based(ap: AnimationPlayer, pivot: Node2D, facing: int) -> void:
	# AnimationPlayer paths are relative to the pivot (root_node).
	ap.root_node = ap.get_path_to(pivot)

	# IDLE: small bob on Y around zero. No absolute positions.
	var idle: Animation = Animation.new()
	idle.loop_mode = Animation.LOOP_LINEAR
	idle.length = 0.6
	idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(0, ":position:y")
	idle.track_insert_key(0, 0.0, 0.0)
	idle.track_insert_key(0, 0.3, -2.0)
	idle.track_insert_key(0, 0.6, 0.0)
	_put_anim(ap, "idle", idle)

	# ATTACK: lunge on X relative to zero; optional Arm swing if present.
	var atk: Animation = Animation.new()
	atk.length = 0.25
	atk.loop_mode = Animation.LOOP_NONE
	atk.add_track(Animation.TYPE_VALUE)
	atk.track_set_path(0, ":position:x")
	atk.track_insert_key(0, 0.0, 0.0)
	atk.track_insert_key(0, 0.10, 14.0 * float(facing))
	atk.track_insert_key(0, 0.25, 0.0)
	var arm_node: Node2D = pivot.get_node_or_null("Arm")
	if arm_node != null:
		atk.add_track(Animation.TYPE_VALUE)
		atk.track_set_path(1, "Arm:rotation_degrees")
		atk.track_insert_key(1, 0.0, 0.0)
		atk.track_insert_key(1, 0.06, -20.0 * float(facing))
		atk.track_insert_key(1, 0.14, 35.0 * float(facing))
		atk.track_insert_key(1, 0.25, 0.0)
	_put_anim(ap, "attack", atk)

	# CAST: slight lift; optional Arm raise and Glow pulse (children of pivot).
	var cast: Animation = Animation.new()
	cast.loop_mode = Animation.LOOP_NONE
	cast.length = 0.35
	# Y lift on the pivot
	cast.add_track(Animation.TYPE_VALUE)
	cast.track_set_path(0, ":position:y")
	cast.track_insert_key(0, 0.0, 0.0)
	cast.track_insert_key(0, 0.18, -3.0)
	cast.track_insert_key(0, 0.35, 0.0)
	# Arm raise if present
	if arm_node != null:
		cast.add_track(Animation.TYPE_VALUE)
		cast.track_set_path(1, "Arm:rotation_degrees")
		cast.track_insert_key(1, 0.0, -40.0 * float(facing))
		cast.track_insert_key(1, 0.18, -65.0 * float(facing))
		cast.track_insert_key(1, 0.35, 0.0)
	# Glow pulse if present
	var glow: Node2D = pivot.get_node_or_null("Glow")
	if glow != null:
		var alpha_track: int = 2 if arm_node != null else 1
		cast.add_track(Animation.TYPE_VALUE)
		cast.track_set_path(alpha_track, "Glow:modulate:a")
		cast.track_insert_key(alpha_track, 0.0, 0.0)
		cast.track_insert_key(alpha_track, 0.18, 0.9)
		cast.track_insert_key(alpha_track, 0.35, 0.0)
		var scale_track: int = alpha_track + 1
		cast.add_track(Animation.TYPE_VALUE)
		cast.track_set_path(scale_track, "Glow:scale")
		var g0: Vector2 = (glow as Node2D).scale
		cast.track_insert_key(scale_track, 0.0, g0 * 0.8)
		cast.track_insert_key(scale_track, 0.18, g0 * 1.25)
		cast.track_insert_key(scale_track, 0.35, g0 * 0.8)
	_put_anim(ap, "cast", cast)

	# HURT: flash by modulating pivot (propagates to children)
	var hurt: Animation = Animation.new()
	hurt.length = 0.20
	hurt.loop_mode = Animation.LOOP_NONE
	hurt.add_track(Animation.TYPE_VALUE)
	hurt.track_set_path(0, ":modulate")
	hurt.track_insert_key(0, 0.0, Color(1, 1, 1, 1))
	hurt.track_insert_key(0, 0.08, Color(2, 2, 2, 1))
	hurt.track_insert_key(0, 0.20, Color(1, 1, 1, 1))
	_put_anim(ap, "hurt", hurt)

	# DIE: fade + scale down via pivot
	var die: Animation = Animation.new()
	die.length = 0.35
	die.loop_mode = Animation.LOOP_NONE
	die.add_track(Animation.TYPE_VALUE)
	die.track_set_path(0, ":modulate:a")
	die.track_insert_key(0, 0.0, 1.0)
	die.track_insert_key(0, 0.35, 0.0)
	die.add_track(Animation.TYPE_VALUE)
	die.track_set_path(1, ":scale")
	die.track_insert_key(1, 0.0, pivot.scale)
	die.track_insert_key(1, 0.35, pivot.scale * 0.6)
	_put_anim(ap, "die", die)

static func _resolve_anim_name(ap: AnimationPlayer, name: String) -> StringName:
	var n: StringName = name
	if ap.has_animation(n):
		return n
	var lib_name: StringName = StringName("code/" + name)
	if ap.has_animation(lib_name):
		return lib_name
	return n

static func play(ap: AnimationPlayer, name: String) -> void:
	if ap == null:
		return
	ap.play(_resolve_anim_name(ap, name))

static func play_and_wait(ap: AnimationPlayer, name: String) -> void:
	if ap == null:
		return
	ap.play(_resolve_anim_name(ap, name))
	await ap.animation_finished

# helper: ensure a Glow sprite exists for cast anim
static func _ensure_glow(sprite: Node2D) -> void:
	if sprite.get_node_or_null("Glow") != null:
		return
	var g: Sprite2D = Sprite2D.new()
	g.name = "Glow"
	g.centered = true
	g.texture = _make_glow_texture(48, Color(1.0, 0.95, 0.6, 1.0))
	g.modulate = Color(1, 1, 1, 0.0)
	g.position = Vector2(10, -10)
	g.scale = Vector2.ONE
	sprite.add_child(g)

static func _make_glow_texture(size_px: int, tint: Color) -> Texture2D:
	var img: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var c: Vector2i = Vector2i(size_px / 2, size_px / 2)
	var r: float = float(size_px) * 0.5
	for y in range(size_px):
		for x in range(size_px):
			var d: float = Vector2(float(x - c.x), float(y - c.y)).length() / r
			var t: float = clamp(1.0 - d, 0.0, 1.0)
			var a: float = pow(t, 2.0) * tint.a
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, a))
	return ImageTexture.create_from_image(img)

# Put animation into player regardless of build (direct or via library)
static func _put_anim(ap: AnimationPlayer, name: String, anim: Animation) -> void:
	if ap.has_method("add_animation"):
		ap.add_animation(name, anim)
		return
	var LIB: StringName = &"code"
	var lib: AnimationLibrary = ap.get_animation_library(LIB)
	if lib == null:
		lib = AnimationLibrary.new()
		ap.add_animation_library(LIB, lib)
	lib.add_animation(name, anim)
