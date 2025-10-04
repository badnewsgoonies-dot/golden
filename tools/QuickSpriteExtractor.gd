@tool
extends EditorScript

# Quick Sprite Extractor - Single Character Version
# This is a simpler version for processing one character at a time
# Edit the settings below and run the script

# === EDIT THESE SETTINGS ===
const CHARACTER_NAME = "hero"  # Change to: hero, healer, mage, or rogue
const SPRITE_SHEET_PATH = "res://art/sprite_sheets/hero_sheet.png"  # Path to your sprite sheet
const SPRITE_WIDTH = 48
const SPRITE_HEIGHT = 64

# Animation frame counts (don't change unless your animations are different)
const FRAME_COUNTS = [3, 3, 6, 6, 3, 3, 2, 5]  # idle_f, idle_b, attack_f, cast_f, hit_f, hit_b, guard_f, ko_f
const ANIM_NAMES = ["idle_f", "idle_b", "attack_f", "cast_f", "hit_f", "hit_b", "guard_f", "ko_f"]

func _run():
	print("=== Quick Sprite Extractor ===")
	print("Processing %s sprite sheet..." % CHARACTER_NAME)
	
	# Load the sprite sheet
	var image = Image.new()
	var err = image.load(SPRITE_SHEET_PATH.substr(6))  # Remove "res://"
	if err != OK:
		print("ERROR: Could not load sprite sheet at: %s" % SPRITE_SHEET_PATH)
		print("Make sure the file exists and the path is correct!")
		return
	
	print("Sprite sheet loaded: %dx%d pixels" % [image.get_width(), image.get_height()])
	
	# Process each animation (row)
	for row in range(ANIM_NAMES.size()):
		var anim_name = ANIM_NAMES[row]
		var frame_count = FRAME_COUNTS[row]
		
		print("\nProcessing %s animation (%d frames)..." % [anim_name, frame_count])
		
		# Create directory for this animation
		var dir_path = "art/battlers/%s/%s" % [CHARACTER_NAME, anim_name]
		var dir = DirAccess.open("res://")
		if not dir.dir_exists(dir_path):
			var err2 = dir.make_dir_recursive(dir_path)
			if err2 != OK:
				print("ERROR: Could not create directory: %s" % dir_path)
				continue
		
		# Extract each frame
		for col in range(frame_count):
			# Calculate position in sprite sheet
			var src_rect = Rect2i(
				col * SPRITE_WIDTH,
				row * SPRITE_HEIGHT,
				SPRITE_WIDTH,
				SPRITE_HEIGHT
			)
			
			# Create new image for this frame
			var frame = Image.create(SPRITE_WIDTH, SPRITE_HEIGHT, false, Image.FORMAT_RGBA8)
			frame.blit_rect(image, src_rect, Vector2i.ZERO)
			
			# Save the frame
			var filename = "%s/%s_%s_%d.png" % [dir_path, CHARACTER_NAME, anim_name, col]
			var save_err = frame.save_png(filename)
			
			if save_err == OK:
				print("  ✓ Saved: %s" % filename)
			else:
				print("  ✗ ERROR saving: %s" % filename)
	
	print("\n=== DONE! ===")
	print("Extracted sprites for: %s" % CHARACTER_NAME)
	print("You may need to restart Godot or reimport the assets to see the changes.")

# Helper function to check sprite sheet dimensions
func check_sprite_sheet():
	var image = Image.new()
	var err = image.load(SPRITE_SHEET_PATH.substr(6))
	if err != OK:
		print("Could not load sprite sheet")
		return
		
	var expected_width = SPRITE_WIDTH * 6  # Max 6 frames per animation
	var expected_height = SPRITE_HEIGHT * 8  # 8 animations
	
	print("Sprite sheet size: %dx%d" % [image.get_width(), image.get_height()])
	print("Expected minimum: %dx%d" % [expected_width, expected_height])
	
	if image.get_width() < expected_width or image.get_height() < expected_height:
		print("WARNING: Sprite sheet may be too small!")
