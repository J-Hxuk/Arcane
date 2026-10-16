extends RefCounted
## All live research mutations go through this model, including non-UI callers.
## Knowledge, affinity and committed research are independent data.

const BaseElements = preload("res://scripts/base_elements.gd")
var _researched := PackedStringArray()
var _affinity: Dictionary = {}
var _clues: Array = []
var _extra: Dictionary = {}
var _pending_element := ""
var _pending_ticket := 0
var _ticket_sequence := 0

var researched_base_elements: PackedStringArray:
	get: return _researched.duplicate()
var innate_affinity: Dictionary:
	get: return _affinity.duplicate(true)
var research_clues: Array:
	get: return _clues.duplicate(true)

func load_data(data: Dictionary) -> String:
	# Reject inconsistent data instead of truncating permanent choices or rerolling.
	var elements = data.get("researched_base_elements", [])
	var affinity = data.get("innate_affinity", {})
	var clues = data.get("research_clues", [])
	if not elements is Array or not affinity is Dictionary or not clues is Array:
		return "연구 저장 데이터 형식이 잘못되었습니다."
	var validated := PackedStringArray()
	for element in elements:
		if not element is String or not BaseElements.DEFINITIONS.has(element):
			return "알 수 없는 기본 속성입니다."
		if validated.has(element):
			return "저장된 연구 목록에 중복 속성이 있습니다."
		validated.append(element)
	if validated.size() > BaseElements.MAX_RESEARCHED_ELEMENTS:
		return "저장된 연구가 3속성을 초과합니다."
	# Values (and future affinity fields) are kept verbatim; no balance formula yet.
	_researched = validated
	_affinity = affinity.duplicate(true)
	_clues = clues.duplicate(true)
	_extra = data.duplicate(true)
	cancel_request()
	return ""

func to_data() -> Dictionary:
	var result := _extra.duplicate(true)
	result["researched_base_elements"] = Array(_researched)
	result["innate_affinity"] = innate_affinity
	result["research_clues"] = research_clues
	return result

func eligibility(element: String) -> String:
	if not BaseElements.DEFINITIONS.has(element): return "invalid_element"
	if _researched.has(element): return "already_researched"
	if _researched.size() >= BaseElements.MAX_RESEARCHED_ELEMENTS: return "slots_full"
	return "available"

func request_research(element: String) -> Dictionary:
	cancel_request()
	var state := eligibility(element)
	if state != "available": return {"state": state}
	_ticket_sequence += 1
	_pending_ticket = _ticket_sequence
	_pending_element = element
	return {"state": "confirmation_required", "ticket": _pending_ticket}

func cancel_request() -> void:
	_pending_element = ""
	_pending_ticket = 0

func start_element_research(element: String, confirmation_ticket: int = 0) -> String:
	var state := eligibility(element)
	if state != "available": return state
	if confirmation_ticket == 0 or confirmation_ticket != _pending_ticket or element != _pending_element:
		return "confirmation_required"
	cancel_request() # One use, and recheck eligibility at the moment of commitment.
	_researched.append(element)
	return "committed"

func acquire_clue(element: String, source: String, clue_id: String) -> String:
	if not BaseElements.DEFINITIONS.has(element): return "invalid_element"
	if source not in ["book", "observation", "hint"] or clue_id.is_empty(): return "invalid_clue"
	var clue := {"element": element, "source": source, "id": clue_id}
	if not _clues.has(clue): _clues.append(clue)
	return "recorded"
