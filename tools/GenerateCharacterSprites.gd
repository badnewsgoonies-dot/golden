@tool
extends EditorScript

# Generate character sprites based on the provided character designs
# This creates actual character sprites instead of colored blocks

const SPRITE_WIDTH = 48
const SPRITE_HEIGHT = 64

# Character color palettes based on the provided images
const CHARACTER_PALETTES = {
	"hero": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.55, 0.35, 0.20),
		"tunic": Color(0.2, 0.4, 0.8),
		"scarf": Color(0.8, 0.2, 0.2),
		"belt": Color(0.4, 0.25, 0.15),
		"boots": Color(0.3, 0.2, 0.1),
		"weapon": Color(0.8, 0.8, 0.9)
	},
	"healer": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.6, 0.3, 0.2),
		"robe": Color(0.7, 0.1, 0.1),
		"trim": Color(0.4, 0.1, 0.1),
		"staff": Color(0.4, 0.25, 0.15),
		"belt": Color(0.3, 0.2, 0.1)
	},
	"mage": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.2, 0.6, 0.8),
		"robe": Color(0.1, 0.1, 0.6),
		"trim": Color(0.3, 0.3, 0.8),
		"staff": Color(0.4, 0.25, 0.15),
		"belt": Color(0.3, 0.2, 0.1)
	},
	"rogue": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.2, 0.6, 0.2),
		"tunic": Color(0.1, 0.4, 0.1),
		"hood": Color(0.05, 0.3, 0.05),
		"belt": Color(0.3, 0.2, 0.1),
		"boots": Color(0.2, 0.15, 0.1),
		"bow": Color(0.4, 0.25, 0.15)
	}
}

const ANIMATIONS = {
	"idle_f": 3,
	"idle_b": 3,
	"attack_f": 6,
	"cast_f": 6,
	"hit_f": 3,
	"hit_b": 3,
	"guard_f": 2,
	"ko_f": 5
}

func _run():
	print("=== Generating Character Sprites ===")
	
	for character in CHARACTER_PALETTES:
		print("\nGenerating %s sprites..." % character)
		generate_character_sprites(character)
	
	print("\n=== DONE! ===")
	print("All character sprites have been generated!")
	print("Restart Godot or reimport assets to see the changes.")

func generate_character_sprites(character: String):
	var palette = CHARACTER_PALETTES[character]
	
	for anim_name in ANIMATIONS:
		var frame_count = ANIMATIONS[anim_name]
		
		# Create animation directory
		var dir_path = "art/battlers/%s/%s" % [character, anim_name]
		var dir = DirAccess.open("res://")
		if not dir.dir_exists(dir_path):
			dir.make_dir_recursive(dir_path)
		
		# Generate each frame
		for frame in range(frame_count):
			var img = generate_character_frame(character, anim_name, frame, palette)
			
			# Save the frame
			var filename = "%s/%s_%s_%d.png" % [dir_path, character, anim_name, frame]
			img.save_png(filename)
			print("  Created: %s" % filename)

func generate_character_frame(character: String, anim: String, frame: int, palette: Dictionary) -> Image:
	var img = Image.create(SPRITE_WIDTH, SPRITE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background
	
	# Draw character based on type and animation
	match character:
		"hero":
			draw_hero(img, anim, frame, palette)
		"healer":
			draw_healer(img, anim, frame, palette)
		"mage":
			draw_mage(img, anim, frame, palette)
		"rogue":
			draw_rogue(img, anim, frame, palette)
	
	return img

func draw_hero(img: Image, anim: String, frame: int, palette: Dictionary):
	var center_x = SPRITE_WIDTH / 2
	var center_y = SPRITE_HEIGHT / 2
	
	# Animation offsets
	var bob_offset = sin(frame * 0.5) * 2 if anim.begins_with("idle") else 0
	var attack_offset = frame * 3 if anim == "attack_f" else 0
	var hit_offset = sin(frame * 2) * 3 if anim.begins_with("hit") else 0
	
	# Head
	draw_circle(img, center_x, center_y - 20 + bob_offset, 8, palette.skin)
	draw_circle(img, center_x, center_y - 20 + bob_offset, 6, palette.skin)
	
	# Hair (spiky)
	draw_spiky_hair(img, center_x, center_y - 20 + bob_offset, palette.hair)
	
	# Body (blue tunic)
	draw_rect(img, center_x - 8, center_y - 12 + bob_offset, 16, 20, palette.tunic)
	
	# Red scarf
	draw_rect(img, center_x - 6, center_y - 10 + bob_offset, 12, 4, palette.scarf)
	
	# Belt
	draw_rect(img, center_x - 6, center_y + 2 + bob_offset, 12, 3, palette.belt)
	
	# Legs
	draw_rect(img, center_x - 6, center_y + 5 + bob_offset, 5, 12, palette.tunic)
	draw_rect(img, center_x + 1, center_y + 5 + bob_offset, 5, 12, palette.tunic)
	
	# Boots
	draw_rect(img, center_x - 6, center_y + 17 + bob_offset, 5, 4, palette.boots)
	draw_rect(img, center_x + 1, center_y + 17 + bob_offset, 5, 4, palette.boots)
	
	# Arms
	draw_rect(img, center_x - 12, center_y - 8 + bob_offset, 4, 12, palette.skin)
	draw_rect(img, center_x + 8, center_y - 8 + bob_offset, 4, 12, palette.skin)
	
	# Weapon (dagger)
	if anim == "attack_f":
		draw_rect(img, center_x + 8 + attack_offset, center_y - 12 + bob_offset, 2, 8, palette.weapon)
		draw_rect(img, center_x + 9 + attack_offset, center_y - 4 + bob_offset, 4, 2, palette.belt)
	else:
		draw_rect(img, center_x + 8, center_y - 4 + bob_offset, 2, 6, palette.weapon)
		draw_rect(img, center_x + 9, center_y - 2 + bob_offset, 3, 2, palette.belt)

func draw_healer(img: Image, anim: String, frame: int, palette: Dictionary):
	var center_x = SPRITE_WIDTH / 2
	var center_y = SPRITE_HEIGHT / 2
	
	var bob_offset = sin(frame * 0.5) * 2 if anim.begins_with("idle") else 0
	var cast_offset = frame * 2 if anim == "cast_f" else 0
	
	# Head
	draw_circle(img, center_x, center_y - 20 + bob_offset, 8, palette.skin)
	
	# Hair (under hood)
	draw_circle(img, center_x, center_y - 20 + bob_offset, 6, palette.hair)
	
	# Red hooded robe
	draw_rect(img, center_x - 10, center_y - 18 + bob_offset, 20, 25, palette.robe)
	draw_rect(img, center_x - 8, center_y - 16 + bob_offset, 16, 3, palette.trim)
	
	# Staff
	if anim == "cast_f":
		draw_rect(img, center_x + 8 + cast_offset, center_y - 15 + bob_offset, 2, 20, palette.staff)
		draw_circle(img, center_x + 9 + cast_offset, center_y - 15 + bob_offset, 3, palette.staff)
	else:
		draw_rect(img, center_x + 8, center_y - 10 + bob_offset, 2, 15, palette.staff)
	
	# Belt
	draw_rect(img, center_x - 6, center_y + 2 + bob_offset, 12, 3, palette.belt)
	
	# Legs (under robe)
	draw_rect(img, center_x - 6, center_y + 5 + bob_offset, 5, 12, palette.robe)
	draw_rect(img, center_x + 1, center_y + 5 + bob_offset, 5, 12, palette.robe)

func draw_mage(img: Image, anim: String, frame: int, palette: Dictionary):
	var center_x = SPRITE_WIDTH / 2
	var center_y = SPRITE_HEIGHT / 2
	
	var bob_offset = sin(frame * 0.5) * 2 if anim.begins_with("idle") else 0
	var cast_offset = frame * 2 if anim == "cast_f" else 0
	
	# Head
	draw_circle(img, center_x, center_y - 20 + bob_offset, 8, palette.skin)
	
	# Blue hair
	draw_circle(img, center_x, center_y - 20 + bob_offset, 6, palette.hair)
	
	# Blue robe
	draw_rect(img, center_x - 10, center_y - 12 + bob_offset, 20, 25, palette.robe)
	draw_rect(img, center_x - 8, center_y - 10 + bob_offset, 16, 3, palette.trim)
	
	# Staff
	if anim == "cast_f":
		draw_rect(img, center_x + 8 + cast_offset, center_y - 15 + bob_offset, 2, 20, palette.staff)
		draw_circle(img, center_x + 9 + cast_offset, center_y - 15 + bob_offset, 3, palette.staff)
	else:
		draw_rect(img, center_x + 8, center_y - 10 + bob_offset, 2, 15, palette.staff)
	
	# Belt
	draw_rect(img, center_x - 6, center_y + 2 + bob_offset, 12, 3, palette.belt)
	
	# Legs
	draw_rect(img, center_x - 6, center_y + 5 + bob_offset, 5, 12, palette.robe)
	draw_rect(img, center_x + 1, center_y + 5 + bob_offset, 5, 12, palette.robe)

func draw_rogue(img: Image, anim: String, frame: int, palette: Dictionary):
	var center_x = SPRITE_WIDTH / 2
	var center_y = SPRITE_HEIGHT / 2
	
	var bob_offset = sin(frame * 0.5) * 2 if anim.begins_with("idle") else 0
	var attack_offset = frame * 2 if anim == "attack_f" else 0
	
	# Head
	draw_circle(img, center_x, center_y - 20 + bob_offset, 8, palette.skin)
	
	# Green hair
	draw_circle(img, center_x, center_y - 20 + bob_offset, 6, palette.hair)
	
	# Green hood
	draw_rect(img, center_x - 8, center_y - 18 + bob_offset, 16, 8, palette.hood)
	
	# Green tunic
	draw_rect(img, center_x - 8, center_y - 10 + bob_offset, 16, 20, palette.tunic)
	
	# Belt
	draw_rect(img, center_x - 6, center_y + 2 + bob_offset, 12, 3, palette.belt)
	
	# Legs
	draw_rect(img, center_x - 6, center_y + 5 + bob_offset, 5, 12, palette.tunic)
	draw_rect(img, center_x + 1, center_y + 5 + bob_offset, 5, 12, palette.tunic)
	
	# Boots
	draw_rect(img, center_x - 6, center_y + 17 + bob_offset, 5, 4, palette.boots)
	draw_rect(img, center_x + 1, center_y + 17 + bob_offset, 5, 4, palette.boots)
	
	# Bow
	if anim == "attack_f":
		draw_rect(img, center_x - 12 - attack_offset, center_y - 8 + bob_offset, 8, 2, palette.bow)
		draw_rect(img, center_x - 8 - attack_offset, center_y - 10 + bob_offset, 2, 6, palette.bow)
	else:
		draw_rect(img, center_x - 12, center_y - 6 + bob_offset, 6, 2, palette.bow)

# Helper functions
func draw_circle(img: Image, center_x: int, center_y: int, radius: int, color: Color):
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if x*x + y*y <= radius*radius:
				var px = center_x + x
				var py = center_y + y
				if px >= 0 and px < SPRITE_WIDTH and py >= 0 and py < SPRITE_HEIGHT:
					img.set_pixel(px, py, color)

func draw_rect(img: Image, x: int, y: int, width: int, height: int, color: Color):
	for px in range(x, x + width):
		for py in range(y, y + height):
			if px >= 0 and px < SPRITE_WIDTH and py >= 0 and py < SPRITE_HEIGHT:
				img.set_pixel(px, py, color)

func draw_spiky_hair(img: Image, center_x: int, center_y: int, color: Color):
	# Draw spiky hair
	var spikes = [
		Vector2(0, -8),
		Vector2(-3, -6),
		Vector2(3, -6),
		Vector2(-5, -4),
		Vector2(5, -4),
		Vector2(-2, -2),
		Vector2(2, -2)
	]
	
	for spike in spikes:
		draw_circle(img, center_x + spike.x, center_y + spike.y, 2, color)
