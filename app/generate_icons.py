#!/usr/bin/env python3
"""
Icon generator for Golden Battle Tower
Creates all required icon sizes for PWA, Android, and iOS
"""

import os
from PIL import Image, ImageDraw, ImageFont

def create_icon(size):
    """Create a game icon with the specified size"""
    # Create a new image with golden background
    img = Image.new('RGBA', (size, size), color=(255, 215, 0, 255))  # Gold color
    draw = ImageDraw.Draw(img)
    
    # Draw a simple tower shape
    tower_color = (26, 26, 26, 255)  # Dark color
    margin = size // 8
    tower_width = size - (2 * margin)
    tower_height = size - (2 * margin)
    
    # Tower base
    base_top = margin + int(tower_height * 0.6)
    draw.rectangle(
        [margin + tower_width // 4, base_top, 
         margin + 3 * tower_width // 4, margin + tower_height],
        fill=tower_color
    )
    
    # Tower middle
    middle_top = margin + int(tower_height * 0.3)
    draw.rectangle(
        [margin + tower_width // 3, middle_top,
         margin + 2 * tower_width // 3, base_top],
        fill=tower_color
    )
    
    # Tower top
    draw.polygon(
        [(margin + tower_width // 2, margin),
         (margin + tower_width // 3, middle_top),
         (margin + 2 * tower_width // 3, middle_top)],
        fill=tower_color
    )
    
    # Add battlements
    battlement_width = tower_width // 6
    for i in range(3):
        x = margin + tower_width // 3 + i * battlement_width
        if i != 1:  # Skip middle for visual balance
            draw.rectangle(
                [x, middle_top - size // 20,
                 x + battlement_width // 2, middle_top],
                fill=tower_color
            )
    
    # Add a small flag on top
    flag_color = (220, 20, 20, 255)  # Red
    flag_pole_x = margin + tower_width // 2
    draw.line(
        [(flag_pole_x, margin), (flag_pole_x, margin - size // 10)],
        fill=tower_color, width=max(1, size // 50)
    )
    draw.polygon(
        [(flag_pole_x, margin - size // 10),
         (flag_pole_x + size // 8, margin - size // 15),
         (flag_pole_x, margin - size // 20)],
        fill=flag_color
    )
    
    return img

def create_splash_screen(width, height):
    """Create a splash screen with the specified dimensions"""
    img = Image.new('RGBA', (width, height), color=(26, 26, 26, 255))
    draw = ImageDraw.Draw(img)
    
    # Draw centered icon
    icon_size = min(width, height) // 3
    icon = create_icon(icon_size)
    icon_x = (width - icon_size) // 2
    icon_y = (height - icon_size) // 2 - height // 10
    img.paste(icon, (icon_x, icon_y))
    
    # Add title text
    try:
        # Try to use a nice font, fall back to default if not available
        font_size = min(width, height) // 20
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
    except:
        font = ImageFont.load_default()
    
    text = "Golden Battle Tower"
    text_bbox = draw.textbbox((0, 0), text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    text_x = (width - text_width) // 2
    text_y = icon_y + icon_size + height // 20
    draw.text((text_x, text_y), text, fill=(255, 215, 0, 255), font=font)
    
    return img

# Icon sizes needed
icon_sizes = [
    16, 32, 72, 96, 128, 144, 152, 180, 192, 384, 512
]

# Splash screen sizes (width x height)
splash_sizes = [
    (2048, 2732),  # iPad Pro 12.9"
    (1668, 2388),  # iPad Pro 11"
    (1536, 2048),  # iPad Mini, Air
    (1125, 2436),  # iPhone X/XS/11 Pro
    (1242, 2688),  # iPhone XS Max/11 Pro Max
    (828, 1792),   # iPhone XR/11
    (1080, 1920),  # Android common
    (720, 1280),   # Android common
]

# Create directories
os.makedirs('icons', exist_ok=True)
os.makedirs('splash', exist_ok=True)

# Generate icons
print("Generating icons...")
for size in icon_sizes:
    icon = create_icon(size)
    icon.save(f'icons/icon-{size}x{size}.png')
    print(f"Created icon-{size}x{size}.png")

# Generate splash screens
print("\nGenerating splash screens...")
for width, height in splash_sizes:
    splash = create_splash_screen(width, height)
    splash.save(f'splash/splash-{width}x{height}.png')
    print(f"Created splash-{width}x{height}.png")

print("\nAll assets generated successfully!")
print("\nNote: You can replace these generated icons with custom artwork later.")