extends RefCounted
## New school identities only. No spell registration, coefficients or legacy remap.
const SOURCE = preload("res://scripts/chant_profile.gd")
const Identity = preload("res://scripts/chant_identity.gd")
const EAST_ELEMENTS = ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]
const WEST_ELEMENTS = ["FIRE", "WATER", "AIR", "EARTH"]
static var DATA: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/magic_schools.json"))

static func all() -> Array:
	return DATA.schools.duplicate(true)

static func find(id: String) -> Dictionary:
	for school in DATA.schools:
		if school.id == id: return school.duplicate(true)
	return {}

static func by_name(region: String, name: String) -> Dictionary:
	var system := "EAST" if region == "동양" else "WEST" if region == "서양" else ""
	for school in DATA.schools:
		if school.world_system == system and school.name == name: return school.duplicate(true)
	return {}

static func east_id(element: String, nature: String) -> String:
	var id := "EAST_" + element + "_" + nature
	return id if not find(id).is_empty() else ""

static func west_fusion(elements: Array) -> String:
	if elements.size() != 2: return ""
	for element in elements:
		if not element is String or element not in WEST_ELEMENTS: return ""
	if elements[0] == elements[1]: return ""
	var pair := elements.duplicate(); pair.sort()
	for school in DATA.schools:
		if school.world_system != "WEST" or school.elements.size() != 2: continue
		var candidate: Array = school.elements.duplicate(); candidate.sort()
		if candidate == pair: return school.id
	return ""

static func valid_actions(actions: Array) -> bool:
	if actions.is_empty() or actions.size() > 5: return false
	for action in actions:
		if not action is String or action not in SOURCE.BASIC_ACTIONS + SOURCE.ADVANCED_ACTIONS: return false
	return true

static func identity_key(school_id: String, actions: Array) -> String:
	if find(school_id).is_empty() or not valid_actions(actions): return ""
	return school_id + ":" + Identity.multiset(actions)

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}; var names: Dictionary = {}; var pairs: Dictionary = {}
	var east := 0; var west := 0
	for row in DATA.schools:
		if not row is Dictionary or not row.get("id") is String or not row.get("name") is String or not row.get("elements") is Array:
			errors.append("Invalid school row"); continue
		if ids.has(row.id) or names.has(row.name): errors.append("Duplicate school: " + row.id)
		ids[row.id] = true; names[row.name] = true
		if row.world_system == "EAST":
			east += 1
			if row.elements.size() != 1 or row.elements[0] not in EAST_ELEMENTS or row.nature not in ["YANG", "YIN"] or row.id != "EAST_" + str(row.elements[0]) + "_" + str(row.nature): errors.append("Invalid eastern school: " + row.id)
		elif row.world_system == "WEST":
			west += 1
			if row.nature != "" or row.elements.size() not in [1, 2]: errors.append("Invalid western school: " + row.id)
			for element in row.elements:
				if element not in WEST_ELEMENTS: errors.append("Unknown western element")
			var key: Array = row.elements.duplicate(); key.sort()
			if (key.size() == 2 and key[0] == key[1]) or pairs.has(str(key)): errors.append("Duplicate western lineage")
			pairs[str(key)] = true
		else: errors.append("Unknown world system")
	if DATA.get("version") != 1 or east != 10 or west != 10: errors.append("Expected version 1, east10 + west10")
	return errors
