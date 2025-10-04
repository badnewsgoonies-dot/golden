# Sprite Sheet Processing Guide

## How to Use the Sprite Sheet Processor

### Step 1: Prepare Your Sprite Sheets
Place your sprite sheets in this folder (`art/sprite_sheets/`) with these names:
- `hero_sheet.png` - Hero character animations
- `healer_sheet.png` - Healer character animations
- `mage_sheet.png` - Mage character animations
- `rogue_sheet.png` - Rogue character animations

### Step 2: Sprite Sheet Format
The script expects sprite sheets organized as follows:
- Each frame is 48x64 pixels
- Animations are arranged in rows:
  - Row 0: idle_f (idle front) - 3 frames
  - Row 1: idle_b (idle back) - 3 frames
  - Row 2: attack_f (attack) - 6 frames
  - Row 3: cast_f (cast spell) - 6 frames
  - Row 4: hit_f (hit front) - 3 frames
  - Row 5: hit_b (hit back) - 3 frames
  - Row 6: guard_f (guard) - 2 frames
  - Row 7: ko_f (knocked out) - 5 frames

### Step 3: Run the Processor
1. Open the script `tools/SpriteSheetProcessor.gd` in Godot
2. Click File -> Run (or press Ctrl+Shift+X)
3. The script will process all sprite sheets and create individual frames

### Alternative: Manual Processing
If your sprite sheet has a different layout, you can modify the script or manually extract frames:
1. Each frame should be saved as: `character_animation_frame.png`
   - Example: `hero_idle_f_0.png`, `hero_idle_f_1.png`, `hero_idle_f_2.png`
2. Place them in the correct folders:
   - `art/battlers/hero/idle_f/`
   - `art/battlers/hero/attack_f/`
   - etc.

### Example Sprite Sheet Layout
```
[idle_f_0][idle_f_1][idle_f_2][empty][empty][empty]
[idle_b_0][idle_b_1][idle_b_2][empty][empty][empty]
[attack_f_0][attack_f_1][attack_f_2][attack_f_3][attack_f_4][attack_f_5]
[cast_f_0][cast_f_1][cast_f_2][cast_f_3][cast_f_4][cast_f_5]
[hit_f_0][hit_f_1][hit_f_2][empty][empty][empty]
[hit_b_0][hit_b_1][hit_b_2][empty][empty][empty]
[guard_f_0][guard_f_1][empty][empty][empty][empty]
[ko_f_0][ko_f_1][ko_f_2][ko_f_3][ko_f_4][empty]
```
