# 5-Point Summary: Status Effect System Implementation

This document outlines the five core architectural changes made to implement a foundational status effect system (e.g., Poison, Stun) in the Golden Battle Tower project.

## 1. Created `Status.gd`: The Status Effect Data Model

- **File Created:** `battle/models/Status.gd`
- **Purpose:** To create a blueprint for what a status effect is. Instead of being simple flags (like `is_poisoned = true`), each active status on a unit is now an object.
- **Details:** This `Status` class holds all the data for a single instance of an effect, including:
  - `id`: A unique identifier (e.g., "poison").
  - `name`: The display name (e.g., "Poison").
  - `duration_turns`: How many turns the effect will last.
  - `metadata`: A dictionary to store effect-specific data, like the damage per turn for poison.
- **Key Function:** `tick()`: A function that decrements the `duration_turns` counter each round.

## 2. Modified `Unit.gd`: Tracking Active Statuses

- **File Modified:** `battle/models/Unit.gd`
- **Purpose:** To give characters and enemies (`Unit` objects) the ability to have multiple status effects applied to them.
- **Details:**
  - A new property, `statuses: Array[Status]`, was added to store all active `Status` objects on the unit.
  - Helper functions were added to manage this array:
    - `add_status(status_object)`: Adds a new status effect.
    - `has_status(status_id)`: Checks if a unit is afflicted by a specific status.
    - `remove_status(status_object)`: Removes a status when it expires.
    - `tick_statuses()`: Calls the `tick()` function on all active statuses at the end of a round and removes any that have expired.

## 3. Created `EffectSystem.gd`: Centralized Effect Logic

- **File Created:** `battle/EffectSystem.gd`
- **Purpose:** To manage the *logic* of how status effects are applied and what they do. This separates the "what" (the `Status` object) from the "how" (the `EffectSystem`).
- **Details:** This script contains two key functions:
  - `apply_effects_from_skill()`: This function is called when a skill hits a target. It reads the `effects` array from the skill's data (in `skills.json`), rolls for the chance of application, and if successful, creates a new `Status` object and adds it to the target `Unit`.
  - `process_end_of_round_effects()`: This function is called at the end of each battle round. It iterates through all units, checks their active statuses, and applies the effects (e.g., deals damage for "poison," ticks down all status durations).

## 4. Updated `TurnEngine.gd`: Integrating Effects into Battle Flow

- **File Modified:** `battle/TurnEngine.gd`
- **Purpose:** To hook the new `EffectSystem` into the core battle loop so that effects are checked and applied at the correct times.
- **Details:**
  - **Turn Start:** The `build_queue()` function was modified to check if a unit `has_status("stun")`. If true, that unit is skipped and cannot act.
  - **Action Execution:** `execute_action()` now calls `EffectSystem.apply_effects_from_skill()` after a successful hit.
  - **End of Round:** A new step was added to call `EffectSystem.process_end_of_round_effects()` to handle damage-over-time and tick down durations.

## 5. Updated `skills.json` & `BattleScene.gd`: Data and UI for New Skills

- **Files Modified:** `data/skills.json` and `scenes/BattleScene.gd`
- **Purpose:** To define skills that can apply our new status effects and to provide a way for the player to use them.
- **Details:**
  - **`data/skills.json`**:
    - New skills like "Poison Dart" and "Stun Bash" were added.
    - A new `effects` array was added to the skill data structure. Each entry in the array defines a potential status effect the skill can apply, including its `id`, `chance`, and `duration`.
  - **`scenes/BattleScene.gd`**:
    - The UI logic for the "Spells" button was updated to dynamically create a button for each test skill found in `skills.json`.
    - This makes the system scalable: adding a new skill to the JSON file will automatically make it available in the battle UI for testing.
    - A generic `_on_skill_selected(skill_data)` handler was created to manage the selection of any skill, replacing separate functions for each one.
