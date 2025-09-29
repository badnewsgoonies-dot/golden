JRPG Battle Sample (Godot 4.5-ready)
====================================

How to use:
1) Open Godot 4.5 and import this folder as a project (project.godot is included).
2) Run the main scene (res://scenes/Battle.tscn). You should see 4 party battlers (back-facing)
   and 2 enemies (front-facing), each animating with placeholder frames.
3) Replace placeholder frames under res://sprites/<character>/<anim>/ with your real art,
   keeping names and counts the same. The AnimatedLoader.gd builds SpriteFrames automatically.

Specs:
- Frame size: 48x64 (pivot at bottom-center)
- Portraits: res://sprites/portraits/*_portrait_96.png (96x96)
- Minimal animations: idle_f (3), idle_b (3), hit_f (3), hit_b (3)
- Timing: idle 8 fps, hit 12 fps

Extend:
- Add new animations (e.g., "attack_f") by creating folders and frames, then
  updating ANIMS in AnimatedLoader.gd and calling anim.play("attack_f").