extends RefCounted
## Optional v1 document extension. Legacy awakening never guesses a Yin/Yang.
## Grants are data authority, not an implemented ritual or an NG+ unlock schedule.
const Schools = preload("res://scripts/magic_schools.gd")
const FIELD = "magic_attunement"
var _data: Dictionary = defaults()
var _present := false

static func defaults() -> Dictionary:
	return {"version": 1, "unlocked_schools": [], "east_choices": {}, "active_school": null}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("version") is int and not value.get("version") is float: return false
	if value.version != 1 or not value.has("active_school"): return false
	var opened = value.get("unlocked_schools"); var choices = value.get("east_choices")
	if not opened is Array or not choices is Dictionary: return false
	var seen: Dictionary = {}
	for id in opened:
		if not id is String or Schools.find(id).is_empty() or seen.has(id): return false
		seen[id] = true
	for element in choices:
		if not element is String or not choices[element] is String: return false
		var id := Schools.east_id(element, choices[element])
		if id.is_empty() or id not in opened: return false
	for id in opened:
		var school := Schools.find(id)
		if school.world_system == "WEST" and school.elements.size() == 2:
			for element in school.elements:
				if "WEST_" + str(element) not in opened: return false
	var active = value.get("active_school")
	if active == null: return true
	if not active is String or active not in opened: return false
	var selected := Schools.find(active)
	return selected.world_system != "EAST" or choices.get(selected.elements[0]) == selected.nature

func load_data(value: Variant) -> bool:
	if not valid(value): return false
	_data = value.duplicate(true); _present = true
	return true

func load_document(document: Dictionary) -> bool:
	if document.has(FIELD): return load_data(document[FIELD])
	_data = defaults(); _present = false
	return true

func to_data() -> Dictionary:
	return _data.duplicate(true)

func document(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	if _present: result[FIELD] = to_data()
	return result

func grant_school(id: String) -> bool:
	var school := Schools.find(id)
	if school.is_empty(): return false
	if school.world_system == "WEST" and school.elements.size() == 2:
		for element in school.elements:
			if "WEST_" + str(element) not in _data.unlocked_schools: return false
	if id not in _data.unlocked_schools: _data.unlocked_schools.append(id)
	_present = true
	return true

func choose_east(element: String, nature: String) -> bool:
	var id := Schools.east_id(element, nature)
	if id.is_empty() or id not in _data.unlocked_schools: return false
	_data.east_choices[element] = nature
	# A choice changes this element alone; keep a selected school internally valid.
	var active := Schools.find(str(_data.active_school))
	if active.get("world_system") == "EAST" and active.elements[0] == element: _data.active_school = id
	_present = true
	return true

func select_school(id: String) -> bool:
	if id not in _data.unlocked_schools: return false
	var school := Schools.find(id)
	if school.world_system == "EAST": _data.east_choices[school.elements[0]] = school.nature
	_data.active_school = id; _present = true
	return true

func context() -> Dictionary:
	return {"magic_school_id": _data.active_school, "magic_attunement": to_data()}

static func context_valid(context_data: Dictionary) -> bool:
	return valid(context_data.get(FIELD)) and context_data.get("magic_school_id") != null and context_data.magic_attunement.active_school == context_data.magic_school_id
