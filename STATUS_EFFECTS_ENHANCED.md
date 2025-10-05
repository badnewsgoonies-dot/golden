# Enhanced Status Effect System Documentation

## Overview
The enhanced status effect system provides a robust framework for managing buffs, debuffs, and other temporary effects in Golden Battle Tower. This system improves upon the original with better stacking mechanics, effect categories, resistance calculations, and priority-based processing.

## Key Improvements Over Original System

### 1. **Effect Categories**
Effects are now categorized for better organization and bulk operations:
- **BUFF**: Positive stat modifiers (Strength, Haste, Shield)
- **DEBUFF**: Negative stat modifiers (Slow, Weakness, Curse)  
- **DOT**: Damage over time (Poison, Burn, Bleed)
- **HOT**: Heal over time (Regeneration, Healing Aura)
- **CONTROL**: Movement/action restrictions (Stun, Freeze, Sleep)
- **SPECIAL**: Unique mechanics that don't fit other categories

### 2. **Stacking Behaviors**
Different effects can stack in different ways:
- **NONE**: Cannot stack - new applications are ignored
- **REFRESH**: Resets duration to maximum
- **STACK**: Allows multiple separate instances
- **INTENSITY**: Single instance but increases in power (up to max_stacks)
- **EXTEND**: Adds duration to existing effect

### 3. **Processing Priority**
Effects process in order of priority (lower = earlier):
- Heals process before damage (HOT priority: 10, DOT priority: 30)
- Buffs apply before debuffs
- Ensures consistent and predictable effect resolution

### 4. **Resistance System**
- **Status Resistance**: Units can have general or specific resistances
- **Level-based Resistance**: Higher level units resist lower level casters
- **Immunities**: Complete immunity to specific effects
- **Boss Immunities**: Bosses immune to most control effects

### 5. **Enhanced Tracking**
- Effects track total damage/healing dealt
- Number of times triggered
- Application history for statistics
- Proper cleanup and expiration messages

## File Structure

### Core Files
- `battle/models/StatusEnhanced.gd` - Enhanced status data model
- `battle/EffectSystemEnhanced.gd` - Effect processing logic
- `data/skills_enhanced.json` - Skill definitions with enhanced effects

### Integration Points
- `battle/models/Unit.gd` - Needs update to use StatusEnhanced
- `battle/TurnEngine.gd` - Needs update to use EffectSystemEnhanced
- `scenes/BattleScene.gd` - UI updates for effect display

## Usage Examples

### Defining a New Effect in skills.json
```json
{
  "id": "poison",
  "name": "Poison",
  "chance": 0.8,
  "duration": 3,
  "metadata": {
    "damage": 10,
    "category": "DOT",
    "stack_type": "intensity",
    "max_stacks": 3,
    "priority": 30
  }
}
```

### Applying Resistance to a Unit
```gdscript
# In Unit setup
unit.metadata["status_resist"] = {
  "poison": 0.3,     # 30% poison resistance
  "all": 0.1         # 10% general status resistance
}

# For immunities
unit.metadata["immunities"] = ["stun", "freeze"]
```

### Cleansing Effects
```gdscript
# Remove all debuffs from a unit
var logs = effect_system.cleanse_effects(
  target_unit, 
  [StatusEnhanced.Category.DEBUFF, StatusEnhanced.Category.DOT]
)
```

## Implementation Checklist

To fully integrate the enhanced system:

1. **Update Unit.gd**
   - [ ] Change `Status` references to `StatusEnhanced`
   - [ ] Add `get_status(id)` method to find specific status
   - [ ] Update status array type to `Array[StatusEnhanced]`

2. **Update TurnEngine.gd**
   - [ ] Change `EffectSystem` to `EffectSystemEnhanced`
   - [ ] Pass caster reference to effect application
   - [ ] Update stun check to use enhanced status

3. **Update BattleScene.gd**
   - [ ] Add status icon display on units
   - [ ] Show stack counts for intensity effects
   - [ ] Display remaining duration on status tooltips
   - [ ] Use skills_enhanced.json instead of skills.json

4. **Add Visual Feedback**
   - [ ] Status effect icons (create texture assets)
   - [ ] Effect application animations
   - [ ] Resistance/immunity feedback
   - [ ] Stack indicator UI

5. **Balance Testing**
   - [ ] Verify resistance calculations feel fair
   - [ ] Test stacking limits work correctly
   - [ ] Ensure priority ordering is correct
   - [ ] Check cleanse abilities function properly

## New Skill Examples

The enhanced system enables more interesting skill designs:

### Multi-Effect Skills
```json
"toxic_cloud": {
  "effects": [
    {"id": "poison", "chance": 0.8, ...},
    {"id": "blind", "chance": 0.5, ...}
  ]
}
```

### Stacking Intensity DOT
```json
"poison_dart": {
  "effects": [{
    "id": "poison",
    "metadata": {
      "stack_type": "intensity",
      "max_stacks": 3
    }
  }]
}
```

### Buff Combinations
```json
"battle_cry": {
  "target": "self",
  "effects": [
    {"id": "strength", ...},
    {"id": "haste", ...}
  ]
}
```

## Migration Path

1. Keep original files as backup (`Status.gd`, `EffectSystem.gd`)
2. Test enhanced system in parallel
3. Gradually migrate features
4. Remove deprecated code once stable

## Performance Considerations

- Priority sorting happens once per round, not per effect
- Status array is filtered in-place for removals
- Effect history can be disabled for production builds
- Metadata dictionaries are duplicated to prevent reference issues

## Future Enhancements

- **Aura Effects**: Effects that affect nearby units
- **Triggered Effects**: Effects that activate on specific conditions
- **Combo Effects**: Effects that interact with each other
- **Scaling Effects**: Effects that get stronger over time
- **Transfer Effects**: Effects that can jump between units

## Notes for Gemini Integration

When implementing Enemy AI, consider:
- AI should check for immunities before using status skills
- AI can track which effects are already on player
- AI should prioritize high-value effects based on situation
- Bosses might have special effect interactions
