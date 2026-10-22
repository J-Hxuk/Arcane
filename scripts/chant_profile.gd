extends RefCounted
## Versioned character-specific permutations. Stored tables are authoritative.
const VERSION := 1
const CURRENT_VERSION := 2
const TWELVE_KEYS := ["Q", "W", "E", "R", "A", "S", "D", "F", "Z", "X", "C", "V"]
const BASIC_ACTIONS := ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE", "SHAPE", "DIRECT", "BIND"]
const ADVANCED_ACTIONS := ["EXPAND", "SPLIT", "CYCLE", "ANCHOR", "DISSIPATE"]
const ATTRIBUTE_KEYS := ["Q", "E", "R", "F", "Z", "X"]
const ELEMENTS := ["WOOD", "FIRE", "EARTH", "METAL", "WATER", "VOID"]
const OHAENG := ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]
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

static func generate_current(character_seed: int) -> Dictionary:
	# No automatic conversion of stored profiles. First-word permutation stays
	# deterministic for the same seed; only genuinely new characters use v2.
	var result := generate(character_seed)
	var random := RandomNumberGenerator.new(); random.seed = character_seed
	var actions := BASIC_ACTIONS + ADVANCED_ACTIONS
	_shuffle(actions, random)
	var later := {}
	for i in TWELVE_KEYS.size(): later[TWELVE_KEYS[i]] = actions[i]
	result["version"] = CURRENT_VERSION; result["manipulations"] = later
	return result

func version() -> int: return int(_data.get("version", VERSION))
func mobile_keys() -> Array: return TWELVE_KEYS if version() == CURRENT_VERSION else MOBILE_KEYS

func load_data(data: Dictionary) -> String:
	var saved_version = data.get("version")
	if not (saved_version is int or saved_version is float) or not is_finite(float(saved_version)) or saved_version != int(saved_version) or int(saved_version) not in [VERSION, CURRENT_VERSION]: return "Unsupported chant profile version."
	var seed_value = data.get("character_seed")
	if not (seed_value is float or seed_value is int) or seed_value != int(seed_value) or seed_value < 1 or seed_value > 2147483647:
		return "Invalid character chant seed."
	var first = data.get("first_words")
	var later = data.get("manipulations")
	if not first is Dictionary or not later is Dictionary: return "Invalid chant mapping tables."
	var current: bool = data["version"] == CURRENT_VERSION
	var keys: Array = TWELVE_KEYS if current else MOBILE_KEYS + FOCUS_KEYS
	var actions: Array = BASIC_ACTIONS + ADVANCED_ACTIONS if current else ACTIONS
	if first.size() != ATTRIBUTE_KEYS.size() or later.size() != keys.size():
		return "Incomplete chant mapping tables."
	var seen: Array = []
	for key in ATTRIBUTE_KEYS:
		if not first.get(key) in ELEMENTS or first[key] in seen: return "Invalid first-word permutation."
		seen.append(first[key])
	var available: Array = []
	for key in keys:
		if not later.get(key) in actions: return "Invalid manipulation mapping."
		if current or key in MOBILE_KEYS: available.append(later[key])
	for action in actions:
		if action not in available: return "Mobile casting lacks a required operation."
	_data = data.duplicate(true)
	return ""

func to_data() -> Dictionary:
	return _data.duplicate(true)

func first_word(key: String) -> String:
	return str(_data.get("first_words", {}).get(key, ""))

func manipulation(key: String) -> String:
	return str(_data.get("manipulations", {}).get(key, ""))
