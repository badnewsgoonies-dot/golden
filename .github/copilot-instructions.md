# AI Coding Agent Instructions for Golden Battle Tower

## Project Overview
A turn-based RPG battle system built with Godot 4.5. Features a JRPG-style side-view battlefield with animated character sprites, turn-based combat, and data-driven design.

## Architecture

### Core Systems
- **Battle System** (`battle/`): Turn-based combat engine
  - `TurnEngine.gd`: Manages turn order and action queue
  - `EffectSystem.gd`: Handles status effects and battle events
  - `models/Unit.gd`: Data model for characters and enemies in battle
  - `models/Action.gd`: Represents combat actions
  
- **Autoload Singletons** (`autoload/`): Global services available everywhere
  - `DataRegistry`: Loads and caches game data from JSON files in `data/`
  - `GameManager`: RNG seed management and current hero unit reference
  - `RunManager`: Manages game progression and runs
  - `SaveService`: Handles save/load functionality
  - `AudioService`: Manages music and sound effects

- **Data-Driven Design**: All game data stored in JSON files (`data/`)
  - `characters.json`: Hero character stats and properties
  - `enemies.json`: Enemy definitions
  - `skills.json`: Combat skills and abilities
  - `items.json`: Usable items
  - Access data via `DataRegistry` autoload at runtime

### Scene Structure
- **Main Scene** (`scenes/Main.tscn`): Entry point that loads BattleScene
- **Battle Scene** (`scenes/BattleScene.tscn`): Main combat interface
  - Script: `scenes/BattleScene.gd` - Core battle logic and UI management
  - Stage: Node2D container for sprites, shadows, and battlefield floor
  - UI: HUD panels for hero/enemy info, active character, and action buttons
  - FX: Visual effects and popup container
  - Overlay: Battle start/end screen transitions

### Sprite System
- **Character Sprites** (`scripts/AnimatedFrames.gd`): Custom AnimatedSprite2D
  - Loads animations from `art/battlers/<character_name>/<animation_name>/`
  - Path pattern: `<character>_<animation>_<frame>.png` (e.g., `barbarian_idle_f_0.png`)
  - Animations: idle_f, idle_b, attack_f, cast_f, hit_f, hit_b, guard_f, ko_f
  - Each animation folder contains numbered frames (0, 1, 2, ...)
  
- **Available Characters**: barbarian, cleric_blue, mage_red, werewolf, hero, hero_warrior, rogue, healer, mage, knight_armored, archer_green, wizard_elder

## Battle Layout Conventions

### Positioning (CRITICAL)
- **Heroes**: LEFT side of screen (X=350-450) - face FORWARD (facing_back=false)
- **Enemies**: RIGHT side of screen (X=800-850) - face BACKWARD (facing_back=true)
- This creates a JRPG side-view where heroes are close to camera, enemies in background

### Z-Index Layering
- Battlefield floor: z_index = -100 (far background)
- Enemy shadows: z_index = 0
- Enemy sprites: z_index = 1
- Hero shadows: z_index = 9
- Hero sprites: z_index = 10 (foreground)
- Selector arrow: z_index = 1000 (always on top)

### Sprite Scale
- Default scale: Vector2(2.0, 2.0) for both heroes and enemies
- Shadow scale: Vector2(1.2, 0.6) - smaller and flatter
- Source sprite size: 48x64 pixels per frame

### Battlefield Floor
- Blue diamond shape defined by FLOOR_POINTS in BattleScene.gd
- Created as Polygon2D with FLOOR_COLOR: Color(0.28, 0.4, 0.7, 0.85)
- Added to Stage node with z_index = -100

## Key Files to Understand

### Battle Logic Flow
1. `scenes/BattleScene.gd:_ready()` - Initializes battle, creates sprites, sets up UI
2. `battle/TurnEngine.gd` - Determines turn order based on speed stats
3. `scenes/BattleScene.gd:_execute_action()` - Processes combat actions
4. `battle/EffectSystem.gd` - Applies damage, healing, status effects

### Character Art Mapping
- Edit `BattleScene.gd:CHARACTER_ART` dictionary to map unit IDs to art folders
- Example: `"barbarian": "barbarian"` maps the "barbarian" unit to `art/battlers/barbarian/`
- Allows color variants like `"cleric_blue": "cleric_blue"`

## Development Workflows

### Running the Game
- Main scene: `res://scenes/Main.tscn` (auto-loads BattleScene)
- Direct battle testing: Run `res://scenes/BattleScene.tscn`
- Window size: 1280x720 (configured in project.godot)

### Adding New Characters
1. Add sprite frames to `art/battlers/<character_name>/<animation_name>/`
2. Update `CHARACTER_ART` mapping in `scenes/BattleScene.gd`
3. Add character data to `data/characters.json` or `data/enemies.json`
4. Reference by ID in `BattleScene.gd:_ready()` hero_characters or enemy_types arrays

### Processing Sprite Sheets
- Use `tools/SpriteSheetProcessor.gd` to split sprite sheets into individual frames
- Expected format: 48x64 pixel frames, specific row layout (see `art/sprite_sheets/README.md`)
- Output goes to `art/battlers/<character>/<animation>/`

### Modifying Battle UI
- UI nodes accessed via `@onready` variables in `BattleScene.gd`
- Hero info: `hero_info_container` (top right panel)
- Enemy info: `enemy_info_container` (top left panel)
- Active character: `active_portrait`, `active_hp_bar`, etc. (bottom left)
- Action buttons: `btn_attack`, `btn_spells`, `btn_items`, `btn_defend` (bottom right)

## Common Patterns

### Creating Battle Units
```gdscript
var unit: Unit = _build_unit_from_character("barbarian")  # For heroes
var unit: Unit = _build_unit_from_enemy("werewolf")      # For enemies
```

### Accessing Game Data
```gdscript
var skill_data = DataRegistry.get_skill("fireball")
var char_data = DataRegistry.get_character("hero")
```

### Sprite Animation Playback
```gdscript
sprite.play_animation("attack_f")  # Plays attack animation
await sprite.animation_finished     # Wait for completion
sprite._play_idle()                # Return to idle
```

## Testing & Building

### Godot Version
- Project uses Godot 4.5 stable
- Config: `project.godot` (config_version=5)

### Export Targets
- HTML5/PWA: Use `./deploy_web_app.sh` (outputs to `exports/html5/`)
- Android: Use `./build_android_app.sh` (outputs to `exports/android/`)
- Quick mobile test: `./test_mobile.sh`

## Important Notes

### Positioning Anti-Pattern
❌ **WRONG**: Heroes on right (X=800+), enemies on left (X=300)
✅ **CORRECT**: Heroes on left (X=350-450), enemies on right (X=800+)

### Sprite Orientation Anti-Pattern
❌ **WRONG**: Heroes facing_back=true, enemies facing_back=false
✅ **CORRECT**: Heroes facing_back=false (face forward), enemies facing_back=true (face away)

### Common Issues
- **Blue placeholder sprites**: Animation files not found or path incorrect
- **Parser errors**: Usually duplicate variable declarations or indentation issues
- **Sprites stacked**: Incorrect position constants or z-index layering
- **No battlefield floor**: z_index too high or polygon not added to Stage

## Data Flow Example
1. `Main.tscn` loads → `BattleScene.tscn`
2. `BattleScene.gd:_ready()` calls `DataRegistry` to load JSON data
3. Creates `Unit` objects from character/enemy data
4. Spawns `AnimatedFrames` sprites positioned on Stage
5. `TurnEngine` determines first actor based on speed
6. Player selects action via UI buttons
7. `_execute_action()` processes combat using `Formula.gd` calculations
8. `EffectSystem` applies results (damage, healing, status)
9. UI updates reflect new HP/MP values
10. Next turn begins

## Animation Frame Naming Convention
All sprite files follow this strict pattern:
`<character_name>_<animation_name>_<frame_number>.png`

Examples:
- `barbarian_idle_f_0.png`, `barbarian_idle_f_1.png`, `barbarian_idle_f_2.png`
- `werewolf_attack_f_0.png` through `werewolf_attack_f_5.png`
- `cleric_blue_cast_f_0.png` through `cleric_blue_cast_f_5.png`

Directory structure: `art/battlers/<character>/<animation>/<frame_files>`
