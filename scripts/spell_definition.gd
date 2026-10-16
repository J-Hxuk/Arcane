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
## State-based elementary combat spells have no command recipe.
@export var attribute: StringName = &""
@export var min_mana := 10.0
@export var min_cohesion := 25.0
@export var max_cohesion := 100.0
@export var min_resonance := 0.0
@export var research_tier := 1
@export var min_stability := 50.0
@export var min_form := 50.0
@export var status_effect: StringName = &""
@export var duration := 0.0
@export var damage_per_second := 0.0
@export var knockback := 0.0
@export var pierce_targets := 1
@export var radius := 0.0
@export var placement_distance := 95.0

func validate_requirements() -> String:
	var unique_elements: Dictionary = {}
	for element in requires_elements:
		if not BaseElements.Element.has(element):
			return "Unknown base element in spell data: " + element
		unique_elements[element] = true
	if unique_elements.size() > BaseElements.MAX_COMBINED_ELEMENTS:
		return "Spell data exceeds the three-base-element limit."
	if not attribute.is_empty():
		if not BaseElements.DEFINITIONS.has(str(attribute)) or requires_elements != PackedStringArray([str(attribute)]) or not commands.is_empty():
			return "Elementary combat data must require exactly its single attribute and no fixed commands."
		if effect not in [&"projectile", &"barrier", &"shockwave", &"blast"] or status_effect not in [&"", &"burn", &"root", &"stagger"]:
			return "Unknown elementary combat effect."
		for value in [mana_cost, damage, projectile_speed, lifetime, min_mana, min_cohesion, max_cohesion, min_resonance, min_stability, min_form, duration, damage_per_second, knockback, radius, placement_distance]:
			if not is_finite(value) or value < 0.0: return "Invalid combat spell number."
		if pierce_targets < 1 or lifetime <= 0.0 or (effect == &"projectile" and projectile_speed <= 0.0): return "Invalid combat spell lifetime/projectile."
		if effect in [&"barrier", &"shockwave", &"blast"] and (radius <= 0.0 or duration <= 0.0): return "Invalid area spell."
		if max_cohesion < min_cohesion or max_cohesion > 100.0 or min_resonance > 100.0 or research_tier < 1: return "Invalid state requirement range."
	return ""
