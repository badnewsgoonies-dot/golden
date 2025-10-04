# Copilot Instructions for Golden Battle Tower

## Project snapshot
- Godot 4.x project (see `project.godot` with `config/features=4.5`); launch `scenes/Main.tscn`, which immediately swaps to `scenes/BattleScene.tscn`.
- Battle gameplay is self-contained in `BattleScene.gd` and the supporting `battle/` scripts.
- Autoload singletons wired in `project.godot` provide global services (`GameManager`, `RunManager`, `DataRegistry`, `SaveService`, `AudioService`).

## Runtime architecture
- `BattleScene.gd` orchestrates the fight loop: `_build_units()` loads party/enemy definitions from `DataRegistry`, `_build_sprites()` creates `AnimatedFrames` sprites, and `_execute_round()` delegates turn resolution to `TurnEngine`.
- `TurnEngine.gd` builds an initiative queue using each unit's `AGI` plus RNG, then executes `Action` objects via `Formula.gd` for damage math and `EffectSystem.gd` for status application.
- Units are `Unit` resources (`battle/models/Unit.gd`) holding stats, current HP/MP, resistances, buffs, and status helpers (heal, take_damage, upgrades).
- Status effects are `Status.gd` instances; `EffectSystem.gd` toggles `Unit.stunned` and applies end-of-round DOT ticks (`burn`, `poison`).

## Data + assets
- `DataRegistry.gd` autoload lazily parses JSON in `data/*.json` into dictionaries; use `DataRegistry.get_*()` helpers instead of reading files directly.
- Each character/enemy entry should include `stats`, optional `skills`, and `resist` multipliers; missing files fall back to safe defaults in `Unit._make_unit_from_def`.
- `AnimatedFrames.gd` expects sprite sheets at `res://art/battlers/{character}/{anim}/{character}_{anim}_{frame}.png`; missing frames trigger procedural placeholders via `SpriteFactory.gd`.
- Map `Unit.character_id` to art in `BattleScene.gd`'s `CHARACTER_ART` dictionary; expand it when you add new battlers to avoid duplicate sprites.

## UI + interaction patterns
- Action buttons (`Attack`, `Spells`, `Items`, `Defend`) are hooked in `_connect_buttons()`; spells and items are populated dynamically each time the menu opens.
- Targeting flows through `ui/TargetSelector.gd`: pass sprite nodes to `start_selection`, listen for `target_selected` and `selection_cancelled`, and call `_sprite_for(unit)` to map back to models.
- Party/enemy HUD panels in `BattleScene.tscn` follow the `%sLabel%d`/`%sHPBar%d` naming pattern; `_update_panel()` walks children in order, so keep layout indices stable.

## Developer workflows
- Run in editor: open the folder with Godot 4.2+ and press Play; `Main.gd` redirects you straight into the battle scene.
- Quick CLI battle: `godot4 --headless --run BattleScene` is not wired; instead open the editor or attach a custom runner if you need automated tests.
- HTML5/mobile preview: execute `bash test_mobile.sh` (requires Godot CLI in PATH, Python 3 for hosting); script builds to `exports/html5` and launches a local server.
- Android packaging: `bash build_android_app.sh` walks you through keystore setup and exports APK/AAB to `exports/android/` (expects environment vars like `ANDROID_SDK_ROOT`).
- Web wrapper assets live under `app/` (PWA manifest, service worker) and are served as-is alongside HTML exports.

## Gotchas & conventions
- `DataRegistry` intentionally omits `class_name` to avoid symbol conflicts with its autoload alias—keep it that way when refactoring.
- `_build_units()` in `BattleScene.gd` currently hardcodes hero/enemy IDs; update both the data files and this list when introducing new combatants.
- Skills referenced in scenes/buttons must exist in `data/skills.json`; otherwise `_get_skill()` builds a minimal fallback.
- Items must be registered in `DataRegistry` and inventory counts are managed by `RunManager.inventory`; `RunManager.use_item()` automatically erases exhausted entries.
- Maintain `res://` paths: scripts and JSON assume case-sensitive directories even on Windows, so keep asset naming consistent.
