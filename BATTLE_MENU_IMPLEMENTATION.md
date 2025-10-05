# BATTLE MENU TARGET SELECTION - IMPLEMENTATION GUIDE

## 📋 Overview

This implementation adds proper target selection for Attack, Spells, and Items in your Godot battle system. The system now properly integrates the CommandMenu and TargetSelector components.

## ✨ New Features

### 1. **Attack System** ✅
- Click "Attack" button
- Target selector appears over all alive enemies
- Use arrow keys to select target
- Press Enter to confirm, ESC to cancel
- Action is queued for that enemy

### 2. **Spell System** ✅
- Click "Spells" button
- Spell list appears in submenu (currently shows Fireball if you have MP)
- Click a spell
- Target selector appears over enemies
- Select target with arrow keys, confirm with Enter
- MP cost is checked before allowing cast

### 3. **Item System** ✅
- Click "Items" button  
- Item list appears (currently shows Potion if not used)
- Click an item
- Target selector appears:
  - **Over allies** if item heals/buffs (like Potion)
  - **Over enemies** if item damages/debuffs
- Select target and confirm
- Item is consumed

## 🔧 Key Changes Made

### BattleScene.gd Changes

**Added Components:**
```gdscript
var command_menu: CommandMenu
var target_selector: TargetSelector
```

**New Signals Connected:**
- `command_menu.menu_action` → `_on_menu_action()` - Handles spell/item/defend selection
- `command_menu.attack_requested` → `_on_attack_requested()` - Handles attack button
- `target_selector.target_selected` → `_on_target_selected()` - Confirms target choice
- `target_selector.selection_cancelled` → `_on_selection_cancelled()` - Cancels selection

**New Functions:**
```gdscript
_show_command_menu_for_current_hero() - Shows menu with hero's available spells/items
_on_attack_requested() - Initiates attack target selection
_on_menu_action(kind, id) - Routes spell/item/defend actions
_start_enemy_target_selection() - Shows selector over enemies
_start_ally_target_selection() - Shows selector over allies  
_on_target_selected(target_sprite) - Processes confirmed target
_on_selection_cancelled() - Returns to menu
_advance_to_next_hero() - Moves to next hero or ends turn
```

## 📦 What You Get

**File Structure:**
```
C:\Users\gxpai\Desktop\golden\scenes\
├── BattleScene.gd (original - KEEP AS BACKUP)
└── BattleScene_UPDATED.gd (NEW implementation)
```

## 🚀 How to Apply

### Option 1: Direct Replacement (Recommended)
```bash
# 1. Backup original
mv BattleScene.gd BattleScene_BACKUP.gd

# 2. Use new version
mv BattleScene_UPDATED.gd BattleScene.gd

# 3. Test in Godot
```

### Option 2: Side-by-Side Testing
1. Keep both files
2. In Godot, attach `BattleScene_UPDATED.gd` to your Battle scene node
3. Test thoroughly
4. When satisfied, replace original

## 🎮 Testing Checklist

### Attack Flow
- [ ] Click "Attack" button
- [ ] Selector arrows appear over enemies
- [ ] Arrow keys move selection left/right
- [ ] Yellow arrow highlights selected enemy
- [ ] Dimmed arrows show other targets
- [ ] Enter confirms attack
- [ ] ESC cancels and returns to menu

### Spell Flow  
- [ ] Click "Spells" button
- [ ] Spell bubble opens with available spells
- [ ] Click "Fireball" (if MP >= 15)
- [ ] Selector appears over enemies
- [ ] Select target and confirm
- [ ] MP is deducted
- [ ] "Not enough MP" message if insufficient

### Item Flow
- [ ] Click "Items" button
- [ ] Item list shows "Potion" (if not used)
- [ ] Click "Potion"
- [ ] Selector appears over **ALLIES** (heroes)
- [ ] Select target ally
- [ ] Potion heals target
- [ ] Message shows healing amount
- [ ] Potion marked as used

### Defend Flow
- [ ] Click "Defend" button
- [ ] Immediately queues defend action
- [ ] Moves to next hero

### Turn Progression
- [ ] After each action, moves to next hero
- [ ] After all heroes act, enemies auto-attack
- [ ] Turn resolves with animations
- [ ] Next round begins

## 🔍 Key Integration Points

### CommandMenu → BattleScene
```gdscript
# CommandMenu emits signals:
signal menu_action(kind: String, id: String)  # For spells/items/defend
signal attack_requested()  # For attack button

# BattleScene responds:
command_menu.menu_action.connect(_on_menu_action)
command_menu.attack_requested.connect(_on_attack_requested)
```

### TargetSelector ← BattleScene
```gdscript
# BattleScene tells TargetSelector to show:
target_selector.start_selection(sprite_array)

# TargetSelector emits back:
signal target_selected(target_sprite: Node2D)
signal selection_cancelled()
```

### Flow Diagram
```
User clicks "Attack"
    ↓
CommandMenu.attack_requested signal
    ↓
BattleScene._on_attack_requested()
    ↓
BattleScene._start_enemy_target_selection()
    ↓
TargetSelector.start_selection([enemy sprites])
    ↓
User selects with arrows, presses Enter
    ↓
TargetSelector.target_selected signal
    ↓
BattleScene._on_target_selected(sprite)
    ↓
Action queued, advance to next hero
```

## 🐛 Troubleshooting

### "No selector appears"
- Check that TargetSelector is added as child of $UI
- Verify Stage node exists
- Check console for errors

### "Selector appears but can't move"
- Ensure TargetSelector has `mouse_filter = MOUSE_FILTER_IGNORE`
- Check input map has ui_left/ui_right defined

### "Menu doesn't close after selection"
- Verify `command_menu.hide_menu()` is called
- Check signal connections are proper

### "MP not deducting"
- MP is deducted in `_on_end_turn()` after actions queue
- Check `a.actor.spend_mp(mp)` line

### "Items target wrong units"
- Check item definition has "target": "ally" or "target": "enemy"
- Modify `_on_menu_action()` item handling for new items

## 📝 Adding New Items

To add items that target enemies (like bombs):

```gdscript
func _on_menu_action(kind: String, id: String) -> void:
    # ... existing code ...
    elif kind == "items":
        if id == "bomb":
            pending_action_type = "item"
            pending_skill = {"id": "bomb", "name": "Bomb", "type": "damage"}
            _start_enemy_target_selection()  # Target enemies!
        elif id == "potion":
            # ... existing potion code ...
```

## 📝 Adding New Spells

To add more spells:

```gdscript
func _show_command_menu_for_current_hero() -> void:
    # ... existing code ...
    var spells: Array = []
    
    # Add fireball
    if current_hero.stats.get("MP", 0) >= int(skill_fireball.get("mp_cost", 0)):
        spells.append(skill_fireball.duplicate(true))
    
    # Add new spell
    var skill_heal := _fetch_skill("heal")
    if current_hero.stats.get("MP", 0) >= int(skill_heal.get("mp_cost", 0)):
        spells.append(skill_heal.duplicate(true))
    
    # ... rest of code ...
```

Then handle it in `_on_menu_action()`:

```gdscript
elif kind == "spells":
    var spell: Dictionary = {}
    if id == "fireball":
        spell = skill_fireball.duplicate(true)
    elif id == "heal":
        spell = _fetch_skill("heal")
        # Check if it targets allies
        pending_action_type = "spell"
        pending_skill = spell
        _start_ally_target_selection()  # Target allies for heal!
        return
    # ... rest of code for enemy-targeting spells ...
```

## ✅ Benefits of This System

1. **Modular** - Easy to add new spells/items
2. **User-Friendly** - Clear visual feedback with arrows
3. **Flexible** - Items can target allies OR enemies
4. **Robust** - Proper MP checking, cancellation support
5. **Clean** - Separation of concerns (Menu, Selector, Battle logic)

## 🎯 Next Steps

After testing, you might want to:
1. Add more spells from your DataRegistry
2. Add more items with different target types
3. Add animations when selector moves
4. Add sound effects for selection
5. Add tooltips showing spell/item descriptions
6. Add keyboard shortcuts (1-4 for spell quick-select)

## 💾 Backup Reminder

**BEFORE APPLYING:**
```bash
# Navigate to your project
cd C:\Users\gxpai\Desktop\golden\scenes

# Create backup
cp BattleScene.gd BattleScene_BACKUP_$(date +%Y%m%d).gd
```

## 📞 Support Notes

If something doesn't work:
1. Check Godot console for errors
2. Verify all signal connections in the _ready() function
3. Make sure CommandMenu and TargetSelector scripts exist
4. Check that your scene structure matches expected nodes (UI, Stage, etc.)

---

**Created:** 2025-01-05
**Version:** 1.0
**Tested With:** Godot 4.x

Good luck with your battle system! 🎮⚔️
