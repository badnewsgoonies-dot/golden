@tool
extends EditorScript

# Creates a sample sprite sheet template showing the expected layout
# Run this to generate a template you can use as a guide

const SPRITE_WIDTH = 48
const SPRITE_HEIGHT = 64
const SHEET_WIDTH = 6  # Max frames per row
const SHEET_HEIGHT = 8  # Number of animations

const COLORS = [
	Color(1.0, 0.5, 0.5),  # idle_f - Light red
	Color(0.5, 1.0, 0.5),  # idle_b - Light green
	Color(0.5, 0.5, 1.0),  # attack_f - Light blue
	Color(1.0, 1.0, 0.5),  # cast_f - Yellow
	Color(1.0, 0.5, 1.0),  # hit_f - Magenta
	Color(0.5, 1.0, 1.0),  # hit_b - Cyan
	Color(0.8, 0.8, 0.8),  # guard_f - Light gray
	Color(0.3, 0.3, 0.3),  # ko_f - Dark gray
]

const FRAME_COUNTS = [3, 3, 6, 6, 3, 3, 2, 5]
const ANIM_NAMES = ["idle_f", "idle_b", "attack_f", "cast_f", "hit_f", "hit_b", "guard_f", "ko_f"]

func _run():
	print("Creating sample sprite sheet template...")
	
	# Create the image
	var img = Image.create(
		SPRITE_WIDTH * SHEET_WIDTH,
		SPRITE_HEIGHT * SHEET_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)
	
	# Fill with transparency
	img.fill(Color(0, 0, 0, 0))
	
	# Draw each animation row
	for row in range(ANIM_NAMES.size()):
		var anim_name = ANIM_NAMES[row]
		var frame_count = FRAME_COUNTS[row]
		var color = COLORS[row]
		
		# Draw frames for this animation
		for col in range(frame_count):
			draw_frame(img, col, row, color, "%s_%d" % [anim_name, col])
	
	# Save the template
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("art/sprite_sheets"):
		dir.make_dir_recursive("art/sprite_sheets")
	
	img.save_png("art/sprite_sheets/template_sprite_sheet.png")
	print("Template saved to: res://art/sprite_sheets/template_sprite_sheet.png")
	print("\nAnimation rows:")
	for i in range(ANIM_NAMES.size()):
		print("Row %d: %s (%d frames) - %s" % [i, ANIM_NAMES[i], FRAME_COUNTS[i], ["Light red", "Light green", "Light blue", "Yellow", "Magenta", "Cyan", "Light gray", "Dark gray"][i]])

func draw_frame(img: Image, col: int, row: int, color: Color, label: String):
	var x_start = col * SPRITE_WIDTH
	var y_start = row * SPRITE_HEIGHT
	
	# Draw border
	for x in range(SPRITE_WIDTH):
		img.set_pixel(x_start + x, y_start, color)
		img.set_pixel(x_start + x, y_start + SPRITE_HEIGHT - 1, color)
	for y in range(SPRITE_HEIGHT):
		img.set_pixel(x_start, y_start + y, color)
		img.set_pixel(x_start + SPRITE_WIDTH - 1, y_start + y, color)
	
	# Fill with lighter color
	var fill_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.5)
	for x in range(1, SPRITE_WIDTH - 1):
		for y in range(1, SPRITE_HEIGHT - 1):
			img.set_pixel(x_start + x, y_start + y, fill_color)
	
	# Draw simple character silhouette
	var center_x = x_start + SPRITE_WIDTH / 2
	var center_y = y_start + SPRITE_HEIGHT / 2
	
	# Head
	for x in range(-6, 7):
		for y in range(-8, -2):
			if x*x + y*y < 36:
				img.set_pixel(center_x + x, center_y + y - 10, color)
	
	# Body
	for x in range(-8, 9):
		for y in range(-2, 10):
			img.set_pixel(center_x + x, center_y + y, color)
	
	# Draw frame number indicator (simple dots)
	for i in range(col + 1):
		if x_start + 2 + i * 3 < x_start + SPRITE_WIDTH - 2:
			img.set_pixel(x_start + 2 + i * 3, y_start + 2, Color.WHITE)
			img.set_pixel(x_start + 2 + i * 3, y_start + 3, Color.WHITE)
