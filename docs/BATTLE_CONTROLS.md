# Battle System Controls

## Target Selection System

When you click the **Attack** button (or press the attack hotkey), the game now enters target selection mode.

### How to Use:

1. **Start Attack**: Click "Attack" from the command menu
2. **Select Target**: 
   - Use **Arrow Keys** (Left/Right or Up/Down) to cycle through enemies
   - A **yellow arrow** will appear above the currently selected enemy
3. **Confirm Target**: 
   - Press **Enter** or **Space** to confirm your selection
   - Or click the **Attack button again** (ui_action_1)
4. **Cancel**: 
   - Press **ESC** or **Cancel** button to go back to the menu

### Visual Feedback:

- The **selector arrow** (yellow, downward-pointing) appears above the selected enemy
- The arrow **bobs up and down** to make it easy to see
- The command menu **disappears** while selecting a target

### For Multiple Enemies:

The system is designed to work with multiple enemies. When you have more than one enemy on screen:
- Cycle through alive enemies using the arrow keys
- Dead enemies are automatically skipped
- The arrow will indicate which enemy you're targeting

## Current Hotkeys:

- **Action 1**: Attack
- **Action 2**: Fireball
- **Action 3**: Potion
- **Action 4**: End Turn

## Notes:

- Currently, the battle supports one enemy but the code is ready for multiple enemies
- The target selection system will automatically adapt when more enemies are added
