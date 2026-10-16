extends RefCounted
## Roles are the single source of permanent choices. Legacy choices stay unassigned.
const BaseElements = preload("res://scripts/base_elements.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const Simulator = preload("res://scripts/mana_simulator.gd")
const Profile = preload("res://scripts/chant_profile.gd")
var _main := ""
var _auxiliary := PackedStringArray()
var _legacy := PackedStringArray()
var _affinity: Dictionary = {}
var _clues: Array = []
var _discoveries: Dictionary = {}
var _extra: Dictionary = {}
var _ritual := ""
var _pending_element := ""
var _pending_ticket := 0
var _ticket_sequence := 0

var main_attribute: Variant:
	get: return null if _main.is_empty() else _main
var auxiliary_attributes: PackedStringArray:
	get: return _auxiliary.duplicate()
var legacy_committed_attributes: PackedStringArray:
	get: return _legacy.duplicate()
var researched_base_elements: PackedStringArray:
	get:
		var result := _legacy.duplicate()
		if not _main.is_empty(): result.append(_main)
		result.append_array(_auxiliary)
		return result
var innate_affinity: Dictionary:
	get: return _affinity.duplicate(true)
var research_clues: Array:
	get: return _clues.duplicate(true)
var resonance_discoveries: Dictionary:
	get: return _discoveries.duplicate(true)
var ritual_target: String:
	get: return _ritual
var awakening_state: String:
	get:
		if not _main.is_empty(): return "confirmed"
		if _pending_ticket != 0: return "confirmation_pending"
		if not _ritual.is_empty(): return "ritual_active"
		return "unawakened"

func load_data(data: Dictionary) -> String:
	var affinity = data.get("innate_affinity", {})
	var clues = data.get("research_clues", [])
	var main = data.get("main_attribute")
	var auxiliary = data.get("auxiliary_attributes", [])
	var legacy = data.get("legacy_committed_attributes", data.get("researched_base_elements", []))
	var discoveries = data.get("resonance_discoveries", {})
	if not affinity is Dictionary or not clues is Array or not auxiliary is Array or not legacy is Array or not discoveries is Dictionary:
		return "연구 저장 데이터 형식이 잘못되었습니다."
	if main != null and (not main is String or not BaseElements.DEFINITIONS.has(main)):
		return "주속성 데이터가 잘못되었습니다."
	if auxiliary.size() > 2: return "보조속성이 2개를 초과합니다."
	if main == null and not auxiliary.is_empty(): return "주속성 없이 보조속성을 지정할 수 없습니다."
	var validated := PackedStringArray()
	for element in legacy + ([] if main == null else [main]) + auxiliary:
		if not element is String or not BaseElements.DEFINITIONS.has(element) or validated.has(element):
			return "기본 속성이 잘못되었거나 중복되었습니다."
		validated.append(element)
	if validated.size() > 3: return "확정 연구가 3속성을 초과합니다."
	if data.has("main_attribute") and data.has("researched_base_elements"):
		if not data["researched_base_elements"] is Array or data["researched_base_elements"].size() != validated.size(): return "Conflicting research sources."
		for element in data["researched_base_elements"]:
			if not validated.has(element): return "Conflicting research sources."
	for element in discoveries:
		if not BaseElements.DEFINITIONS.has(element) or not discoveries[element] is Dictionary: return "Invalid resonance discovery."
		var ids = discoveries[element].get("stable_experiment_ids", [])
		if not ids is Array: return "Invalid resonance evidence."
		var seen: Array = []
		for id in ids:
			if not (id is int or id is float) or not is_finite(float(id)) or id != int(id) or id < 1 or id in seen: return "Invalid resonance evidence ID."
			seen.append(id)
	_main = "" if main == null else main
	_auxiliary = PackedStringArray(auxiliary)
	_legacy = PackedStringArray(legacy)
	_affinity = affinity.duplicate(true)
	_clues = clues.duplicate(true)
	_discoveries = discoveries.duplicate(true)
	_extra = data.duplicate(true)
	_extra.erase("researched_base_elements")
	cancel_request()
	return ""

func to_data() -> Dictionary:
	var result := _extra.duplicate(true)
	result.merge({"main_attribute": main_attribute, "auxiliary_attributes": Array(_auxiliary),
		"legacy_committed_attributes": Array(_legacy), "innate_affinity": innate_affinity,
		"research_clues": research_clues, "resonance_discoveries": resonance_discoveries}, true)
	return result

func innate_element() -> String:
	# Derive a unique numeric maximum without assigning or changing old talent data.
	var highest := -INF
	var chosen := ""
	var tied := false
	for element in BaseElements.DEFINITIONS:
		var score = _affinity.get(element)
		if not (score is int or score is float) or not is_finite(float(score)): continue
		if score > highest:
			highest = float(score)
			chosen = element
			tied = false
		elif score == highest: tied = true
	return "" if tied else chosen

func has_clue(element: String, source: String) -> bool:
	return _clues.has({"element": element, "source": source, "id": Rules.clue_id(element, source)})

func simulation_context() -> Dictionary:
	var knowledge: Dictionary = {}
	for element in BaseElements.DEFINITIONS:
		knowledge[element] = {"book": has_clue(element, "book"), "mentor": has_clue(element, "mentor")}
	return {"innate_element": innate_element(), "knowledge": knowledge, "control_penalty": 0.0}

func stable_count(element: String) -> int:
	return _discoveries.get(element, {}).get("stable_experiment_ids", []).size()

func validate_evidence(records: Array) -> String:
	var by_id: Dictionary = {}
	for record in records: by_id[int(record["id"])] = record
	for element in _discoveries:
		for id in _discoveries[element].get("stable_experiment_ids", []):
			if not by_id.has(int(id)): return "Stable resonance evidence references a missing experiment."
			var record: Dictionary = by_id[int(id)]
			var result: Dictionary = record["result"]
			var version = record.get("rules_version", 0)
			if not (version is float or version is int) or not is_finite(float(version)) or version < 2 or version != int(version): return "Invalid resonance rules version."
			if result.get("outcome") != "released" or result.get("kind") != element.to_lower() + "_resonance": return "Invalid stable resonance evidence."
			var terminal = result.get("terminal_snapshot", {})
			if not terminal is Dictionary or terminal.get("base_attributes", []) != [element]: return "Resonance evidence target mismatch."
	return ""

func eligibility(element: String) -> String:
	if not BaseElements.DEFINITIONS.has(element): return "invalid_element"
	if researched_base_elements.has(element): return "already_researched"
	if researched_base_elements.size() >= 3: return "slots_full"
	return "awakening_required" if _main.is_empty() else "auxiliary_deferred"

func request_research(element: String) -> Dictionary:
	return {"state": eligibility(element)} # No old UI ticket bypass.

func ritual_eligibility(element: String) -> String:
	if not BaseElements.DEFINITIONS.has(element): return "invalid_element"
	if not _main.is_empty(): return "main_already_confirmed"
	if researched_base_elements.size() >= 3 and not _legacy.has(element): return "slots_full"
	if not has_clue(element, "book") or not has_clue(element, "mentor"): return "clues_required"
	if stable_count(element) < 2: return "stable_reproduction_required"
	return "available"

func begin_ritual(element: String) -> String:
	cancel_request()
	var state := ritual_eligibility(element)
	if state != "available": return state
	_ritual = element
	return "ritual_started"

func complete_ritual(profile: Profile, inputs: Array) -> Dictionary:
	if _ritual.is_empty() or ritual_eligibility(_ritual) != "available": return {"state": "ritual_required"}
	var result := Simulator.simulate(profile, inputs, true, simulation_context())
	var final: Dictionary = result["final_state"]
	if result["state"] != "ready" or final["base_attributes"] != [_ritual]: return {"state": "target_resonance_required"}
	if final["form_integrity"] < 50.0 or final["flow_vector"] != [1.0, 0.0]: return {"state": "ritual_structure_required"}
	_ticket_sequence += 1
	_pending_ticket = _ticket_sequence
	_pending_element = _ritual
	return {"state": "confirmation_required", "element": _ritual, "ticket": _pending_ticket}

func cancel_request() -> void:
	_ritual = ""
	_pending_element = ""
	_pending_ticket = 0

func start_element_research(element: String, confirmation_ticket: int = 0) -> String:
	if not BaseElements.DEFINITIONS.has(element): return "invalid_element"
	if not _main.is_empty(): return "already_researched" if element == _main else "main_already_confirmed"
	if researched_base_elements.size() >= 3 and not _legacy.has(element): return "slots_full"
	if confirmation_ticket == 0 or confirmation_ticket != _pending_ticket or element != _pending_element:
		return "confirmation_required"
	if ritual_eligibility(element) != "available": return "research_conditions_changed"
	if _legacy.has(element): _legacy.remove_at(_legacy.find(element))
	_main = element
	cancel_request()
	return "committed"

func acquire_clue(element: String, source: String, clue_id: String) -> String:
	if not BaseElements.DEFINITIONS.has(element): return "invalid_element"
	if source not in ["book", "mentor", "observation", "hint"] or clue_id.is_empty(): return "invalid_clue"
	var clue := {"element": element, "source": source, "id": clue_id}
	if not _clues.has(clue): _clues.append(clue)
	return "recorded"

func record_resonance(profile: Profile, inputs: Array, experiment_id: int) -> bool:
	if experiment_id < 1: return false
	var result := Simulator.simulate(profile, inputs, true, simulation_context())
	var attributes: Array = result["final_state"]["base_attributes"]
	if result["state"] != "ready" or attributes.size() != 1: return false
	var element: String = attributes[0]
	if not _discoveries.has(element): _discoveries[element] = {"stable_experiment_ids": []}
	var ids: Array = _discoveries[element]["stable_experiment_ids"]
	if not ids.has(experiment_id): ids.append(experiment_id)
	acquire_clue(element, "observation", "observation_" + element)
	return true
