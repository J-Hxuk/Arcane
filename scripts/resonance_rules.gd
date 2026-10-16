extends RefCounted
## Prototype thresholds, not probabilities. VOID is outside both five-phase rings.
const Elements = preload("res://scripts/base_elements.gd")
const CONTROLS := {"WOOD": "EARTH", "EARTH": "WATER", "WATER": "FIRE", "FIRE": "METAL", "METAL": "WOOD"}
const GENERATES := {"WOOD": "FIRE", "FIRE": "EARTH", "EARTH": "METAL", "METAL": "WATER", "WATER": "WOOD"}

static func relation(innate: String, target: String) -> String:
	if innate.is_empty(): return "unknown"
	if innate == target: return "affine"
	if innate == "VOID" or target == "VOID": return "neutral"
	if CONTROLS.get(innate) == target or CONTROLS.get(target) == innate: return "opposed"
	if GENERATES.get(innate) == target or GENERATES.get(target) == innate: return "supportive"
	return "neutral"

static func requirements(element: String, context: Dictionary) -> Dictionary:
	var definition = Elements.DEFINITIONS[element]
	var affinity_relation := relation(str(context.get("innate_element", "")), element)
	var stability: float = definition.resonance_stability
	var resonance: float = definition.resonance_required
	var gain := 50.0
	var interference := 5.0
	match affinity_relation:
		"affine":
			stability -= 5.0
			resonance -= 10.0
			gain += 10.0
			interference = 3.0
		"opposed":
			stability += 15.0
			resonance += 25.0
			gain = 35.0
			interference = 10.0
		"supportive": stability -= 2.0
	var knowledge: Dictionary = context.get("knowledge", {}).get(element, {})
	if knowledge.get("book", false): resonance -= 10.0
	if knowledge.get("mentor", false): stability -= 10.0
	stability += float(context.get("control_penalty", 0.0))
	return {"stability": clampf(stability, 55.0, 95.0), "resonance": clampf(resonance, 50.0, 100.0),
		"gain": gain, "interference": interference, "relation": affinity_relation}

static func clue_id(element: String, source: String) -> String:
	return source + "_" + element

static func clue_text(element: String, source: String) -> String:
	if not Elements.DEFINITIONS.has(element): return "이전 연구 기록"
	var definition = Elements.DEFINITIONS[element]
	return definition.book_clue if source == "book" else definition.mentor_clue
