extends RefCounted
## Phenomena are lineage labels, never new elemental slots or combat recipes.
const ELEMENTS := ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]
const PHENOMENA := {"FIRE+WOOD": "metabolic_overdrive", "EARTH+WOOD": "poison", "METAL+WOOD": "living_metal", "WATER+WOOD": "healing", "EARTH+FIRE": "lava", "FIRE+METAL": "lightning", "FIRE+WATER": "wind", "EARTH+METAL": "crystal_alloy", "EARTH+WATER": "mud", "METAL+WATER": "ice_crystal"}
const SPELL_LINEAGES := {"ICE_CRYSTAL_NEEDLE": ["METAL", "WATER"], "ICE_CRYSTAL_BARRIER": ["METAL", "WATER"], "WIND_PRESSURE_BOLT": ["FIRE", "WATER"]}
static func pair(elements: Array) -> String:
	for element in elements:
		if not element is String or element not in ELEMENTS: return ""
	var sorted := elements.duplicate()
	sorted.sort()
	return "+".join(sorted)
static func authorized(elements: Array, main: Variant, auxiliary: Array) -> bool:
	if elements.size() != 2 or main == null or main not in elements or elements[0] == elements[1]: return false
	for element in elements:
		if element not in ELEMENTS or (element != main and (auxiliary.is_empty() or element != auxiliary[0])): return false
	return true
static func cast_allowed(elements:Array,context:Dictionary)->bool:
	if not authorized(elements,context.get("main_attribute"),context.get("auxiliary_attributes",[])):return false
	if context.get("formal_rules",false):
		# Permanent awakening is authority; past research remains historical data.
		return preload("res://scripts/attribute_loadout.gd").owns_pair(elements,context.get("awakened_attributes",[]))
	return pair(elements) in context.get("binding_pairs",[])
