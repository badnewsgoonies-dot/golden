# Golden Battle Tower - PROTOTYPE VERSION

## What is this?
This is a bare-bones prototype version of your Golden Battle Tower game, designed for testing game mechanics without the overhead of fancy graphics and animations.

## Features
- **Simple colored rectangles** instead of character sprites
- **Basic UI elements** with text labels
- **Full game logic preserved** from the original
- **Debug panels** showing game state
- **Color-coded units**:
  - Red = Warrior
  - Green = Archer
  - Blue = Mage
  - Yellow = Healer
  - Gray = Tank
  - Purple = Rogue
  - Dark Red = Enemy units

## How to Use
1. Open Godot 4.5 (or compatible version)
2. Import this project (golden_prototype folder)
3. Run the project to test mechanics

## Benefits of This Prototype
- **Faster loading** - No heavy art assets
- **Clearer debugging** - See exactly what's happening
- **Quick iteration** - Test changes immediately
- **Performance testing** - Know if slowdowns are from code or graphics
- **Reduced errors** - Less complexity = fewer things that can break

## Folder Structure
```
golden_prototype/
├── scenes/         # Simplified scene files
├── scripts/        # Game logic (shared with main)
├── autoload/       # Core game managers
├── data/          # Game data files
└── simple_assets/ # Basic placeholder graphics
```

## Testing Workflow
1. Make changes in the prototype first
2. Test thoroughly with simple graphics
3. Once working, apply changes to main game
4. Add visual polish in the main version

## Notes
- All game mechanics work exactly like the main game
- Unit stats, damage calculations, turn order - all preserved
- This is purely a visual simplification for testing
- You can run both versions side-by-side for comparison

## Quick Debug Features
- FPS counter in main menu
- Unit count displays in battle
- State indicators for debugging turn flow
- HP bars and numbers clearly visible
- Color changes to show unit states

Remember: This prototype is your testing ground. Break things here, not in your pretty main game!