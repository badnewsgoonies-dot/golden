class_name Status
extends RefCounted

## Data model for a status effect instance.
## This object holds the state of a single status effect applied to a unit.

# The unique identifier for the status (e.g., "poison", "stun").
var id: String

# The display name (e.g., "Poison").
var name: String

# How many turns this effect will last. Decremented at the end of each round.
var duration_turns: int

# An icon to represent the status in the UI.
var icon: Texture2D

# A dictionary to hold any extra data the effect might need.
# For example, for "poison", this could store {"damage": 5}.
var metadata: Dictionary


func _init(status_id: String, status_name: String, duration: int, status_icon: Texture2D = null, extra_data: Dictionary = {}):
	self.id = status_id
	self.name = status_name
	self.duration_turns = duration
	self.icon = status_icon
	self.metadata = extra_data


## Decrements the duration of the status effect by one turn.
## Returns true if the effect has expired, false otherwise.
func tick() -> bool:
	if duration_turns > 0:
		duration_turns -= 1
	
	return duration_turns <= 0


## Returns a simple string representation for debugging.
func _to_string() -> String:
	return "Status(%s, %d turns)" % [name, duration_turns]
