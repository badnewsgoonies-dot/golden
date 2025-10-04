@tool
extends EditorScript

# Sprite Sheet Processor
# This script helps split sprite sheets into individual animation frames
# Place your sprite sheets in art/sprite_sheets/ folder
# Run this script from the Script Editor: File -> Run

const SPRITE_WIDTH = 48  # Width of each sprite frame
const SPRITE_HEIGHT = 64  # Height of each sprite frame

# Define the animations and their frame counts
const ANIMATIONS = {
	"idle_f": 3,
	"idle_b": 3,
	"hit_f": 3,
	"hit_b": 3,
	"attack_f": 6,
	"cast_f": 6,
	"guard_f": 2,
	"ko_f": 5
}

# Character configurations
# Adjust these based on your sprite sheet layout
const CHARACTERS = {
	"hero": {
		"sheet": "res://art/sprite_sheets/hero_sheet.png",
		"animations": {
			"idle_f": {"row": 0, "start_col": 0},
			"idle_b": {"row": 1, "start_col": 0},
			"attack_f": {"row": 2, "start_col": 0},
			"cast_f": {"row": 3, "start_col": 0},
			"hit_f": {"row": 4, "start_col": 0},
			"hit_b": {"row": 5, "start_col": 0},
			"guard_f": {"row": 6, "start_col": 0},
			"ko_f": {"row": 7, "start_col": 0}
		}
	},
	"healer": {
		"sheet": "res://art/sprite_sheets/healer_sheet.png",
		"animations": {
			"idle_f": {"row": 0, "start_col": 0},
			"idle_b": {"row": 1, "start_col": 0},
			"attack_f": {"row": 2, "start_col": 0},
			"cast_f": {"row": 3, "start_col": 0},
			"hit_f": {"row": 4, "start_col": 0},
			"hit_b": {"row": 5, "start_col": 0},
			"guard_f": {"row": 6, "start_col": 0},
			"ko_f": {"row": 7, "start_col": 0}
		}
	},
	"mage": {
		"sheet": "res://art/sprite_sheets/mage_sheet.png",
		"animations": {
			"idle_f": {"row": 0, "start_col": 0},
			"idle_b": {"row": 1, "start_col": 0},
			"attack_f": {"row": 2, "start_col": 0},
			"cast_f": {"row": 3, "start_col": 0},
			"hit_f": {"row": 4, "start_col": 0},
			"hit_b": {"row": 5, "start_col": 0},
			"guard_f": {"row": 6, "start_col": 0},
			"ko_f": {"row": 7, "start_col": 0}
		}
	},
	"rogue": {
		"sheet": "res://art/sprite_sheets/rogue_sheet.png",
		"animations": {
			"idle_f": {"row": 0, "start_col": 0},
			"idle_b": {"row": 1, "start_col": 0},
			"attack_f": {"row": 2, "start_col": 0},
			"cast_f": {"row": 3, "start_col": 0},
			"hit_f": {"row": 4, "start_col": 0},
			"hit_b": {"row": 5, "start_col": 0},
			"guard_f": {"row": 6, "start_col": 0},
			"ko_f": {"row": 7, "start_col": 0}
		}
	}
}

func _run():
	print("=== Sprite Sheet Processor ===")
	print("Processing sprite sheets...")
	
	# Create sprite_sheets directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("art/sprite_sheets"):
		dir.make_dir_recursive("art/sprite_sheets")
		print("Created art/sprite_sheets/ directory")
		print("Please place your sprite sheets there and run this script again")
		return
	
	var processed = 0
	
	for character_name in CHARACTERS:
		var config = CHARACTERS[character_name]
		if process_character(character_name, config):
			processed += 1
	
	print("\nProcessing complete! Processed %d characters" % processed)
	print("You may need to restart the editor to see the new sprites")

func process_character(character_name: String, config: Dictionary) -> bool:
	var sheet_path = config.sheet
	
	# Check if sprite sheet exists
	if not FileAccess.file_exists(sheet_path):
		print("Sprite sheet not found: %s" % sheet_path)
		print("Please add the sprite sheet or update the path in the script")
		return false
	
	print("\nProcessing %s..." % character_name)
	
	# Load the sprite sheet
	var sheet_image = Image.load_from_file(sheet_path.substr(6))  # Remove "res://"
	if sheet_image == null:
		print("Failed to load sprite sheet: %s" % sheet_path)
		return false
	
	# Process each animation
	for anim_name in config.animations:
		var anim_config = config.animations[anim_name]
		var frame_count = ANIMATIONS.get(anim_name, 3)
		
		# Create animation directory
		var anim_dir = "res://art/battlers/%s/%s" % [character_name, anim_name]
		var dir = DirAccess.open("res://")
		if not dir.dir_exists(anim_dir.substr(6)):
			dir.make_dir_recursive(anim_dir.substr(6))
		
		# Extract frames
		for frame_idx in range(frame_count):
			var col = anim_config.start_col + frame_idx
			var row = anim_config.row
			
			# Calculate position in sprite sheet
			var src_x = col * SPRITE_WIDTH
			var src_y = row * SPRITE_HEIGHT
			
			# Create frame image
			var frame_image = Image.create(SPRITE_WIDTH, SPRITE_HEIGHT, false, sheet_image.get_format())
			frame_image.blit_rect(sheet_image, 
				Rect2i(src_x, src_y, SPRITE_WIDTH, SPRITE_HEIGHT), 
				Vector2i(0, 0))
			
			# Save frame
			var frame_path = "%s/%s_%s_%d.png" % [anim_dir, character_name, anim_name, frame_idx]
			frame_image.save_png(frame_path.substr(6))
			
			print("  Created: %s" % frame_path)
	
	return true

# Alternative simple function to process a single sprite sheet
# Call this if you have a different layout
func process_simple_sheet(sheet_path: String, character_name: String, cols_per_animation: int = 6):
	print("\nSimple processing for %s" % character_name)
	
	var sheet_image = Image.load_from_file(sheet_path.substr(6))
	if sheet_image == null:
		print("Failed to load sprite sheet: %s" % sheet_path)
		return
	
	var anim_names = ["idle_f", "idle_b", "hit_f", "hit_b", "attack_f", "cast_f", "guard_f", "ko_f"]
	
	for row in range(anim_names.size()):
		var anim_name = anim_names[row]
		var frame_count = ANIMATIONS.get(anim_name, 3)
		
		# Create animation directory
		var anim_dir = "res://art/battlers/%s/%s" % [character_name, anim_name]
		var dir = DirAccess.open("res://")
		if not dir.dir_exists(anim_dir.substr(6)):
			dir.make_dir_recursive(anim_dir.substr(6))
		
		# Extract frames
		for frame_idx in range(frame_count):
			# Create frame image
			var frame_image = Image.create(SPRITE_WIDTH, SPRITE_HEIGHT, false, sheet_image.get_format())
			frame_image.blit_rect(sheet_image, 
				Rect2i(frame_idx * SPRITE_WIDTH, row * SPRITE_HEIGHT, SPRITE_WIDTH, SPRITE_HEIGHT), 
				Vector2i(0, 0))
			
			# Save frame
			var frame_path = "%s/%s_%s_%d.png" % [anim_dir, character_name, anim_name, frame_idx]
			frame_image.save_png(frame_path.substr(6))
			
			print("  Created: %s" % frame_path)
