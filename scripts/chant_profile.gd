extends RefCounted
## Versioned character-specific permutations. Stored tables are authoritative.
const VERSION := 1
const ATTRIBUTE_KEYS := ["Q", "E", "R", "F", "Z", "X"]
const ELEMENTS := ["WOOD", "FIRE", "EARTH", "METAL", "WATER", "VOID"]
const MOBILE_KEYS := ["Q", "E", "R", "F", "Z", "X", "C", "V", "T", "G"]
const FOCUS_KEYS := ["W", "A", "S", "D"]
const ACTIONS := ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE", "SHAPE", "DIRECT", "DISSIPATE"]
var _data: Dictionary = {}

static func generate(character_seed: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = character_seed
	var attributes := ELEMENTS.duplicate()
	_shuffle(attributes, random)
	# Every operation is available in mobile casting; focus adds aliases.
	var actions := ACTIONS + ["ACCUMULATE", "COMPRESS", "STABILIZE"]
	_shuffle(actions, random)
	var first: Dictionary = {}
	var later: Dictionary = {}
	for index in range(ATTRIBUTE_KEYS.size()): first[ATTRIBUTE_KEYS[index]] = attributes[index]
	for index in range(MOBILE_KEYS.size()): later[MOBILE_KEYS[index]] = actions[index]
	for key in FOCUS_KEYS: later[key] = ACTIONS[random.randi_range(0, ACTIONS.size() - 1)]
	return {"version": VERSION, "character_seed": character_seed, "first_words": first, "manipulations": later}

static func _shuffle(values: Array, random: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var value = values[index]
		values[index] = values[other]
		values[other] = value

func load_data(data: Dictionary) -> String:
	if data.get("version") != VERSION: return "Unsupported chant profile version."
	var seed_value = data.get("character_seed")
	if not (seed_value is float or seed_value is int) or seed_value != int(seed_value) or seed_value < 1 or seed_value > 2147483647:
		return "Invalid character chant seed."
	var first = data.get("first_words")
	var later = data.get("manipulations")
	if not first is Dictionary or not later is Dictionary: return "Invalid chant mapping tables."
	if first.size() != ATTRIBUTE_KEYS.size() or later.size() != MOBILE_KEYS.size() + FOCUS_KEYS.size():
		return "Incomplete chant mapping tables."
	var seen: Array = []
	for key in ATTRIBUTE_KEYS:
		if not first.get(key) in ELEMENTS or first[key] in seen: return "Invalid first-word permutation."
		seen.append(first[key])
	var available: Array = []
	for key in MOBILE_KEYS + FOCUS_KEYS:
		if not later.get(key) in ACTIONS: return "Invalid manipulation mapping."
		if key in MOBILE_KEYS: available.append(later[key])
	for action in ACTIONS:
		if action not in available: return "Mobile casting lacks a required operation."
	_data = data.duplicate(true)
	return ""

func to_data() -> Dictionary:
	return _data.duplicate(true)

func first_word(key: String) -> String:
	return str(_data.get("first_words", {}).get(key, ""))

func manipulation(key: String) -> String:
	return str(_data.get("manipulations", {}).get(key, ""))
