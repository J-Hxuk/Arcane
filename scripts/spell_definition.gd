extends Resource
## A formula describes input, access requirements and an effect independently.
## Empty requirements mean attribute-independent mana manipulation, never VOID.

const BaseElements = preload("res://scripts/base_elements.gd")

@export var spell_id: StringName
@export var display_name: String
@export var commands: PackedStringArray
@export var requires_elements: PackedStringArray
@export var mana_cost := 15.0
@export var effect: StringName = &"projectile"
@export var damage := 35.0
@export var projectile_speed := 460.0
@export var lifetime := 1.8
@export var projectile_color := Color("9eeaff")

func validate_requirements() -> String:
	var unique_elements: Dictionary = {}
	for element in requires_elements:
		if not BaseElements.Element.has(element):
			return "Unknown base element in spell data: " + element
		unique_elements[element] = true
	if unique_elements.size() > BaseElements.MAX_COMBINED_ELEMENTS:
		return "Spell data exceeds the three-base-element limit."
	return ""
