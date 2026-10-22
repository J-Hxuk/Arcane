extends RefCounted
## Fixed GDD vocabulary, shared by spell data and future character research.
## Attribute-independent mana manipulation is represented by no requirements.

enum Element { WOOD, FIRE, EARTH, METAL, WATER, VOID }
## VOID below is a historical resource identifier, not an elemental slot.
const OHAENG := ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]
const MAX_COMBINED_ELEMENTS := 3
const MAX_RESEARCHED_ELEMENTS := 3
const DEFINITIONS := {
	"WOOD": preload("res://data/elements/wood.tres"),
	"FIRE": preload("res://data/elements/fire.tres"),
	"EARTH": preload("res://data/elements/earth.tres"),
	"METAL": preload("res://data/elements/metal.tres"),
	"WATER": preload("res://data/elements/water.tres"),
}
const NEUTRAL_DEFINITIONS := {"VOID": preload("res://data/elements/void.tres")}
static func resource(element: String):
	return DEFINITIONS.get(element, NEUTRAL_DEFINITIONS.get(element))
