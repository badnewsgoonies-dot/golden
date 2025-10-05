class_name Action
extends RefCounted

var actor: Unit
var skill: Dictionary
var target: Unit

func _init(actor: Unit, skill: Dictionary, target: Unit) -> void:
	self.actor = actor
	self.skill = skill
	self.target = target
