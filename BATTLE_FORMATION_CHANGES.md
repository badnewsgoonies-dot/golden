# Battle Formation Changes

## Summary
Modified the BattleScene to support 4 hero characters positioned at the bottom and multiple enemies positioned in front of them, similar to traditional JRPG battle formations.

## Key Changes

### 1. Multiple Unit Support
- Changed from single `hero` and `enemy` units to `heroes: Array[Unit]` and `enemies: Array[Unit]`
- Added arrays for sprites and shadows: `hero_sprites`, `enemy_sprites`, `hero_shadows`, `enemy_shadows`
- Added `current_acting_hero_index` to track which hero is selecting actions

### 2. Formation Positions
Added position constants for battle formation:
```gdscript
const HERO_POSITIONS := [
    Vector2(300, 480),  # Bottom-left
    Vector2(450, 480),  # Bottom-center-left
    Vector2(600, 480),  # Bottom-center-right
    Vector2(750, 480)   # Bottom-right
]

const ENEMY_POSITIONS := [
    Vector2(400, 280),  # Top-left
    Vector2(550, 280),  # Top-center-left
    Vector2(700, 280),  # Top-center-right
    Vector2(850, 280)   # Top-right
]
```

### 3. Unit Initialization
- Heroes: Pyro Adept, Gale Rogue, Azure Cleric, Armored Knight
- Enemies: 3 enemies (2 Goblins and 1 Slime)

### 4. Turn System Updates
- Each hero selects their action individually
- After all heroes have selected actions, the turn executes
- All units (heroes and enemies) act based on their speed/initiative

### 5. UI Updates
- Top panels show summary of all heroes and enemies with HP
- Bottom-left panel shows current acting hero's detailed stats
- Target selection works with arrow keys for selecting which enemy to attack

### 6. Sprite Management
- Updated all sprite-related functions to handle multiple units
- Each unit has its own sprite and shadow
- Proper z-indexing ensures heroes appear in front and enemies in back

## Visual Layout
```
    [Enemy A]  [Enemy B]  [Enemy C]
         (back row - enemies)
    
    [Hero 1] [Hero 2] [Hero 3] [Hero 4]
         (front row - heroes)
```

## How to Test
1. Load the BattleScene or TestBattleFormation scene
2. Each hero will take turns selecting actions
3. Use Attack/Spells/Items/Defend buttons
4. When attacking, use arrow keys to select target enemy
5. After all heroes act, the turn executes with all actions

## Future Improvements
- Add visual indicators for which hero is currently acting
- Implement party formation customization
- Add support for different battle backgrounds
- Improve enemy AI to target different heroes strategically