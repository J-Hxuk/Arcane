extends RefCounted
## Only successful releases enter this book. No generated answer recipes.
const Profile = preload("res://scripts/chant_profile.gd")
var _data := {"version": 1, "spells": {}}

static func valid_inputs(inputs: Variant) -> bool:
	if not inputs is Array or inputs.is_empty() or inputs.size() > 32: return false
	var previous := -1.0
	for input in inputs:
		if not input is Dictionary or input.get("key") not in Profile.MOBILE_KEYS + Profile.FOCUS_KEYS: return false
		for key in ["at_ms", "hold_ms"]:
			var value = input.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value != int(value) or value < 0 or value > 60000: return false
		if input["at_ms"] < previous: return false
		previous = input["at_ms"]
	return inputs[0]["key"] in Profile.ATTRIBUTE_KEYS + ["C"]

func load_data(data: Dictionary) -> String:
	if data.get("version", 1) != 1 or not data.get("spells", {}) is Dictionary: return "Invalid discovered spell book."
	for id in data.get("spells", {}):
		var entry = data["spells"][id]
		if not id is String or not entry is Dictionary or not entry.get("name") is String or not entry.get("favorite", false) is bool or not entry.get("recipes") is Array: return "Invalid discovered spell entry."
		var recipes: Array = entry["recipes"]
		var representative = entry.get("representative", 0)
		if recipes.is_empty() or not (representative is int or representative is float) or not is_finite(float(representative)) or representative != int(representative) or representative < 0 or representative >= recipes.size(): return "Invalid representative chant."
		for recipe in recipes:
			if not recipe is Dictionary or not valid_inputs(recipe.get("inputs")): return "Invalid successful chant timing."
	_data = data.duplicate(true)
	_data.merge({"version": 1, "spells": data.get("spells", {}).duplicate(true)}, true)
	for entry in _data["spells"].values():
		if not entry.has("favorite"): entry["favorite"] = false
		if not entry.has("representative"): entry["representative"] = 0
	return ""

func to_data() -> Dictionary:
	return _data.duplicate(true)

static func signature(inputs: Array) -> String:
	var result: Array = []
	var last_end := -1
	for input in inputs:
		result.append([input["key"], mini(int(input["hold_ms"]), 1000) / 250, input["at_ms"] < last_end])
		last_end = maxi(last_end, int(input["at_ms"] + input["hold_ms"]))
	return JSON.stringify(result)

func record(id: String, name: String, inputs: Array, rules_version: int, source: String) -> bool:
	if id.is_empty() or name.is_empty() or not valid_inputs(inputs): return false
	var spells: Dictionary = _data["spells"]
	if not spells.has(id): spells[id] = {"name": name, "favorite": false, "representative": 0, "recipes": []}
	var recipes: Array = spells[id]["recipes"]
	for recipe in recipes:
		if signature(recipe["inputs"]) == signature(inputs): return false
	recipes.append({"inputs": inputs.duplicate(true), "rules_version": rules_version, "source": source})
	return true

func import_journal(records: Array) -> void:
	for experiment in records:
		var result: Dictionary = experiment["result"]
		if result.get("outcome") != "released": continue
		var manifestation: Dictionary = result.get("manifestation", {})
		# Old resonance logs are not proof that an actual combat spell manifested.
		if manifestation.is_empty() and result.get("kind") == "mana_bolt": manifestation = {"spell_id": "MANA_BOLT", "name": "Mana Bolt"}
		if manifestation.is_empty(): continue
		var inputs: Array = []
		for step in experiment["steps"]: inputs.append(step["input"].duplicate(true))
		record(str(manifestation.get("spell_id", "")), str(manifestation.get("name", "")), inputs, int(experiment.get("rules_version", 1)), "journal")

func entries() -> Array:
	var result: Array = []
	for id in _data["spells"]:
		var entry: Dictionary = _data["spells"][id].duplicate(true)
		entry["spell_id"] = id
		result.append(entry)
	result.sort_custom(func(a, b):
		if a["favorite"] != b["favorite"]: return a["favorite"]
		return str(a["spell_id"]) < str(b["spell_id"]))
	return result

func set_favorite(id: String, favorite: bool) -> void:
	if _data["spells"].has(id): _data["spells"][id]["favorite"] = favorite

func choose_recipe(id: String, index: int) -> void:
	if _data["spells"].has(id) and index >= 0 and index < _data["spells"][id]["recipes"].size(): _data["spells"][id]["representative"] = index

static func format_inputs(inputs: Array) -> String:
	var result := ""
	var end_time := -1
	for input in inputs:
		if not result.is_empty(): result += " + " if input["at_ms"] < end_time else " → "
		result += str(input["key"])
		if input["hold_ms"] >= 250: result += "[%.2f초 유지]" % (float(input["hold_ms"]) / 1000.0)
		end_time = maxi(end_time, int(input["at_ms"] + input["hold_ms"]))
	return result
