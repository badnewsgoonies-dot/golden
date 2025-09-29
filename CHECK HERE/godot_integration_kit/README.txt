
GODOT 4.5 JRPG INTEGRATION KIT (drop-in)

1) Copy the folders into your project:
   res://scripts/AnimatedFrames.gd
   res://scripts/PortraitLoader.gd
   res://scripts/AssetValidator.gd
   res://data/portrait_alias.json
   res://data/example_units.gd

2) Hook up battlers:
   - In your spawn code, instance AnimatedFrames.gd instead of plain Sprite2D.
     aspr.character = unit.art
     aspr.facing_back = is_party_member

3) Hook up portraits:
   - In the HUD, call: `PortraitLoader.get_portrait_for(unit.role or unit.name)`
   - Place files at res://art/portraits/<key>_portrait_96.png
     OR add a mapping inside res://art/portrait_alias.json

4) Validate assets:
   - Open scripts/AssetValidator.gd in the Script Editor, press F6.
   - It will print any missing battler frames to the Output panel.

5) Import settings for crisp pixels:
   - Select all PNGs → Import → Preset: 2D Pixel. Filter OFF. Mipmaps OFF.

Happy building! 🚀
