# Guide: Using AI Coding Assistants With Godot 4 (GDScript)

This guide turns the “multiple‑iteration problem” into a playbook you can follow. It focuses on Godot 4.x, typed GDScript, and tactics that reduce back‑and‑forth when you ask an AI for help.

## TL;DR

- Always state: Godot 4.x, GDScript, node types/paths, exact errors.
- Use typed code and cast values from `Dictionary.get(...)` (e.g., `int(dict.get("HP", 0))`).
- Sanity‑check API calls against Godot 4 docs (avoid 3.x leftovers).
- Run the included Sanity Test scene (`scenes/SanityTest.tscn`) to flag common 3→4 mistakes and encoding/typing hazards before you iterate.

---

## Common Failure Modes (and what to do)

### 1) Ambiguity and missing context
- Problem: Prompts without version, node names, or error text force the AI to guess.
- Fix: Include version (Godot 4.x), scene/node context, and the exact error line.

### 2) Static analysis vs runtime reality
- Problem: The AI can’t run your game. Plausible code may fail at runtime.
- Fix: Provide the error output and minimal code/scene snippet; ask for a self‑contained fix with a short rationale.

### 3) GDScript typing + Godot 3→4 API drift
- Problem: `Dictionary.get()` returns Variant; typed vars need casts. Many Godot 3 methods moved/changed in 4.
- Fix: Cast and prefer typed inference, and confirm API calls match 4.x.

```
# Cast Dictionary values
var hp: int = int(stats.get("HP", 0))
var dmg: int = int(clamp(amount, 0, hp))
# Or infer via :=
var max_hp := int(stats.get("max_hp", 0))
```

Common 3→4 pitfalls (fixes in parentheses):
- `KinematicBody2D` (use `CharacterBody2D`)
- `move_and_slide(vel, up)` (set `velocity` and call `move_and_slide()` with no args)
- `get_position()`/`get_global_position()` (use `node.position` / `node.global_position` properties)
- `Sprite2D.play(...)` (use `AnimatedSprite2D.play(...)` or `AnimationPlayer`)
- `yield(...)` (use `await`)

### 4) Conversation/context limits
- Problem: Long chats lose details; suggestions may contradict earlier constraints.
- Fix: Remind constraints in each prompt (“Godot 4.x only, typed GDScript”).

---

## Prompt Template (copy/paste)

```
Godot 4.x, GDScript. Node(s): <types/names>. Scene path(s): <paths>.
Goal: <what you want>.
Current code (minimal):
<snippet>
Error/behavior: <exact message or what happens>.
Constraints: typed code, no Godot 3 APIs, minimal changes.
Return: self‑contained function/snippet + 2‑line rationale.
```

Example: “Implement jump for `CharacterBody2D` Player (with `Camera2D` child). I get ‘Too many arguments to move_and_slide’. Fix for Godot 4.2 with typed vars.”

---

## “LLM Sanity Test” Scene

Run `scenes/SanityTest.tscn` to scan your project for:
- Godot 3→4 API leftovers (`KinematicBody2D`, `move_and_slide(...)` with arguments, `get_position()`),
- suspicious calls on `Sprite2D.play(...)`,
- `yield(...)` usages (prefer `await`),
- BOM/encoding at file start, and
- typed‑var assignments from `Dictionary.get(...)` without casts (`: int = ...get(`).

It prints a summary to the Output and shows a short report in a label. Use it before/after copying AI code to catch obvious issues early.

---

## One‑Page Playbook

- Add context: version, nodes, code, error text.
- Ask for typed code; forbid Godot 3 APIs.
- SanityTest scene → fix flagged issues.
- Re‑run; paste exact errors on failure.
- Turn warnings‑as‑errors back on once clean.

---

## Source Notes

This guidance condenses community experience: Godot 4 API changes, pitfalls of dynamic typing, and the value of precise prompts. It favors practical checks over theory so you can ship faster with fewer AI iterations.

