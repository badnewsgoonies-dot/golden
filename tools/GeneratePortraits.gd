@tool
extends EditorScript

# Generate character portraits for the UI
# Creates 96x96 pixel portraits for each character

const PORTRAIT_SIZE = 96

const CHARACTER_PALETTES = {
	"hero": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.55, 0.35, 0.20),
		"tunic": Color(0.2, 0.4, 0.8),
		"scarf": Color(0.8, 0.2, 0.2),
		"belt": Color(0.4, 0.25, 0.15),
		"eyes": Color(0.2, 0.2, 0.2)
	},
	"healer": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.6, 0.3, 0.2),
		"robe": Color(0.7, 0.1, 0.1),
		"trim": Color(0.4, 0.1, 0.1),
		"eyes": Color(0.2, 0.2, 0.2)
	},
	"mage": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.2, 0.6, 0.8),
		"robe": Color(0.1, 0.1, 0.6),
		"trim": Color(0.3, 0.3, 0.8),
		"eyes": Color(0.2, 0.2, 0.2)
	},
	"rogue": {
		"skin": Color(0.96, 0.87, 0.70),
		"hair": Color(0.2, 0.6, 0.2),
		"tunic": Color(0.1, 0.4, 0.1),
		"hood": Color(0.05, 0.3, 0.05),
		"eyes": Color(0.2, 0.2, 0.2)
	}
}

func _run():
	print("=== Generating Character Portraits ===")
	
	for character in CHARACTER_PALETTES:
		print("Generating %s portrait..." % character)
		generate_portrait(character)
	
	print("\n=== DONE! ===")
	print("All character portraits have been generated!")

func generate_portrait(character: String):
	var palette = CHARACTER_PALETTES[character]
	var img = Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background
	
	var center_x = PORTRAIT_SIZE / 2
	var center_y = PORTRAIT_SIZE / 2
	
	# Draw character portrait based on type
	match character:
		"hero":
			draw_hero_portrait(img, center_x, center_y, palette)
		"healer":
			draw_healer_portrait(img, center_x, center_y, palette)
		"mage":
			draw_mage_portrait(img, center_x, center_y, palette)
		"rogue":
			draw_rogue_portrait(img, center_x, center_y, palette)
	
	# Save the portrait
	var filename = "art/portraits/%s_portrait_96.png" % character
	img.save_png(filename)
	print("  Created: %s" % filename)

func draw_hero_portrait(img: Image, center_x: int, center_y: int, palette: Dictionary):
	# Head
	draw_circle(img, center_x, center_y - 10, 20, palette.skin)
	
	# Hair (spiky)
	draw_spiky_hair(img, center_x, center_y - 10, palette.hair, 18)
	
	# Eyes
	draw_circle(img, center_x - 6, center_y - 15, 3, palette.eyes)
	draw_circle(img, center_x + 6, center_y - 15, 3, palette.eyes)
	
	# Nose
	draw_circle(img, center_x, center_y - 8, 2, palette.skin)
	
	# Mouth
	draw_rect(img, center_x - 4, center_y - 2, 8, 2, palette.eyes)
	
	# Body (blue tunic)
	draw_rect(img, center_x - 15, center_y + 5, 30, 25, palette.tunic)
	
	# Red scarf
	draw_rect(img, center_x - 12, center_y + 8, 24, 6, palette.scarf)
	
	# Belt
	draw_rect(img, center_x - 10, center_y + 20, 20, 4, palette.belt)
	
	# Shoulders
	draw_rect(img, center_x - 18, center_y + 5, 6, 15, palette.skin)
	draw_rect(img, center_x + 12, center_y + 5, 6, 15, palette.skin)

func draw_healer_portrait(img: Image, center_x: int, center_y: int, palette: Dictionary):
	# Head
	draw_circle(img, center_x, center_y - 10, 20, palette.skin)
	
	# Hair (under hood)
	draw_circle(img, center_x, center_y - 10, 16, palette.hair)
	
	# Eyes
	draw_circle(img, center_x - 6, center_y - 15, 3, palette.eyes)
	draw_circle(img, center_x + 6, center_y - 15, 3, palette.eyes)
	
	# Nose
	draw_circle(img, center_x, center_y - 8, 2, palette.skin)
	
	# Mouth
	draw_rect(img, center_x - 4, center_y - 2, 8, 2, palette.eyes)
	
	# Red hooded robe
	draw_rect(img, center_x - 18, center_y - 5, 36, 30, palette.robe)
	draw_rect(img, center_x - 15, center_y - 2, 30, 4, palette.trim)
	
	# Hood
	draw_rect(img, center_x - 16, center_y - 15, 32, 12, palette.robe)

func draw_mage_portrait(img: Image, center_x: int, center_y: int, palette: Dictionary):
	# Head
	draw_circle(img, center_x, center_y - 10, 20, palette.skin)
	
	# Blue hair
	draw_circle(img, center_x, center_y - 10, 16, palette.hair)
	
	# Eyes
	draw_circle(img, center_x - 6, center_y - 15, 3, palette.eyes)
	draw_circle(img, center_x + 6, center_y - 15, 3, palette.eyes)
	
	# Nose
	draw_circle(img, center_x, center_y - 8, 2, palette.skin)
	
	# Mouth
	draw_rect(img, center_x - 4, center_y - 2, 8, 2, palette.eyes)
	
	# Blue robe
	draw_rect(img, center_x - 18, center_y - 5, 36, 30, palette.robe)
	draw_rect(img, center_x - 15, center_y - 2, 30, 4, palette.trim)
	
	# Shoulders
	draw_rect(img, center_x - 20, center_y + 5, 8, 15, palette.robe)
	draw_rect(img, center_x + 12, center_y + 5, 8, 15, palette.robe)

func draw_rogue_portrait(img: Image, center_x: int, center_y: int, palette: Dictionary):
	# Head
	draw_circle(img, center_x, center_y - 10, 20, palette.skin)
	
	# Green hair
	draw_circle(img, center_x, center_y - 10, 16, palette.hair)
	
	# Eyes
	draw_circle(img, center_x - 6, center_y - 15, 3, palette.eyes)
	draw_circle(img, center_x + 6, center_y - 15, 3, palette.eyes)
	
	# Nose
	draw_circle(img, center_x, center_y - 8, 2, palette.skin)
	
	# Mouth
	draw_rect(img, center_x - 4, center_y - 2, 8, 2, palette.eyes)
	
	# Green hood
	draw_rect(img, center_x - 16, center_y - 15, 32, 12, palette.hood)
	
	# Green tunic
	draw_rect(img, center_x - 18, center_y - 5, 36, 30, palette.tunic)
	
	# Shoulders
	draw_rect(img, center_x - 20, center_y + 5, 8, 15, palette.tunic)
	draw_rect(img, center_x + 12, center_y + 5, 8, 15, palette.tunic)

# Helper functions
func draw_circle(img: Image, center_x: int, center_y: int, radius: int, color: Color):
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if x*x + y*y <= radius*radius:
				var px = center_x + x
				var py = center_y + y
				if px >= 0 and px < PORTRAIT_SIZE and py >= 0 and py < PORTRAIT_SIZE:
					img.set_pixel(px, py, color)

func draw_rect(img: Image, x: int, y: int, width: int, height: int, color: Color):
	for px in range(x, x + width):
		for py in range(y, y + height):
			if px >= 0 and px < PORTRAIT_SIZE and py >= 0 and py < PORTRAIT_SIZE:
				img.set_pixel(px, py, color)

func draw_spiky_hair(img: Image, center_x: int, center_y: int, color: Color, radius: int):
	# Draw spiky hair
	var spikes = [
		Vector2(0, -radius),
		Vector2(-4, -radius + 3),
		Vector2(4, -radius + 3),
		Vector2(-6, -radius + 6),
		Vector2(6, -radius + 6),
		Vector2(-3, -radius + 9),
		Vector2(3, -radius + 9)
	]
	
	for spike in spikes:
		draw_circle(img, center_x + spike.x, center_y + spike.y, 3, color)
