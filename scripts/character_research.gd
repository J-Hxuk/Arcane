extends RefCounted
## Permanent awakenings and active equipment are separate; legacy choices retain their evidence.
const BaseElements = preload("res://scripts/base_elements.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const Simulator = preload("res://scripts/mana_simulator.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Migration = preload("res://scripts/ohaeng_migration.gd")
const Fusion = preload("res://scripts/fusion_rules.gd")
const Loadout=preload("res://scripts/attribute_loadout.gd")
var free_attributes:=false
var _awakened:Array=[]
var selected_attribute_slot:="main"
var awakened_attributes:Array:
	get:return _awakened.duplicate() if free_attributes else Array(active_elements)
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
var use_current_rules:=false

var main_attribute: Variant:
	get: return null if _main.is_empty() else _main
var auxiliary_attributes: PackedStringArray:
	get: return _auxiliary.duplicate()
var active_elements:PackedStringArray:
	get:
		var result:=PackedStringArray()
		if not _main.is_empty():result.append(_main)
		result.append_array(_auxiliary)
		return result
var legacy_committed_attributes: PackedStringArray:
	get: return _legacy.duplicate()
var researched_base_elements: PackedStringArray:
	get:
		var result := _legacy.duplicate()
		if free_attributes:
			for element in _awakened:
				if element not in result:result.append(element)
			return result
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
		if _pending_ticket != 0: return "confirmation_pending"
		if not _ritual.is_empty(): return "ritual_active"
		if not _main.is_empty(): return "confirmed"
		return "unawakened"

func load_data(data: Dictionary) -> String:
	data = Migration.research(data)
	var free:=data.has("attribute_loadout_version")
	if free and not Loadout.valid(data):return "개화 목록과 활성 속성 저장이 잘못되었습니다."
	if not preload("res://scripts/movement_research.gd").valid(data.get("movement_research",{}),true):return "이동술 연구 저장이 잘못되었습니다."
	var validations=data.get("catalyst_validations",{})
	if not validations is Dictionary:return "촉매 검증 형식이 잘못되었습니다."
	for element in validations:
		var proof=validations[element]
		if element not in BaseElements.OHAENG or not proof is Dictionary:return "촉매 검증 대상이 잘못되었습니다."
		for field in {"mana_amount":10.0,"stability":55.0,"form_integrity":25.0}:
			var value=proof.get(field);var limits={"mana_amount":10.0,"stability":55.0,"form_integrity":25.0}
			if not (value is int or value is float) or not is_finite(float(value)) or value<float(limits[field]):return "촉매 검증 상태가 잘못되었습니다."
	var affinity = data.get("innate_affinity", {})
	var clues = data.get("research_clues", [])
	var main = data.get("main_attribute")
	var auxiliary = data.get("auxiliary_attributes", [])
	var legacy = data.get("legacy_committed_attributes", data.get("researched_base_elements", []))
	var discoveries = data.get("resonance_discoveries", {})
	if not data.get("binding_studies", []) is Array or not data.get("fusion_observations", {}) is Dictionary or not data.get("neutral_mana", {}) is Dictionary: return "Invalid binding/neutral research data."
	if not data.get("inactive_attribute_history",{}) is Dictionary:return "이전 비활성 속성 기록 형식이 잘못되었습니다."
	if not affinity is Dictionary or not clues is Array or not auxiliary is Array or not legacy is Array or not discoveries is Dictionary:
		return "연구 저장 데이터 형식이 잘못되었습니다."
	if not data.get("advanced_manipulation_research",[]) is Array:return "고위 조작 연구 형식이 잘못되었습니다."
	for operation in data.get("advanced_manipulation_research",[]):
		if operation not in Profile.ADVANCED_ACTIONS:return "알 수 없는 고위 조작 연구입니다."
	var rank=data.get("technique_rank",0)
	if not (rank is int or rank is float) or not is_finite(float(rank)) or rank!=int(rank) or rank<0 or rank>4:return "기술 등급 형식이 잘못되었습니다."
	if main != null and (not main is String or not BaseElements.DEFINITIONS.has(main)):
		return "주속성 데이터가 잘못되었습니다."
	if auxiliary.size() > 1: return "보조속성은 하나만 사용할 수 있습니다."
	if main == null and not auxiliary.is_empty(): return "주속성 없이 보조속성을 지정할 수 없습니다."
	var validated := PackedStringArray()
	for element in legacy + ([] if main == null else [main]) + auxiliary:
		if not element is String or not BaseElements.DEFINITIONS.has(element) or (validated.has(element) and not free):
			return "기본 속성이 잘못되었거나 중복되었습니다."
		validated.append(element)
	if validated.size() > 3 and not free: return "확정 연구가 3속성을 초과합니다."
	if not free and data.has("main_attribute") and data.has("researched_base_elements"):
		if not data["researched_base_elements"] is Array or data["researched_base_elements"].size() != validated.size(): return "Conflicting research sources."
		for element in data["researched_base_elements"]:
			if not validated.has(element): return "Conflicting research sources."
	for pair in data.get("binding_studies", []):
		if not pair is String or pair not in Fusion.PHENOMENA:return "Invalid studied binding lineage."
		if not (Loadout.owns_pair(Array(pair.split("+")),data.awakened_attributes) if free else Fusion.authorized(Array(pair.split("+")), main, auxiliary)):return "Invalid studied binding lineage."
	for element in discoveries:
		if not element is String or BaseElements.resource(element) == null or not discoveries[element] is Dictionary: return "Invalid resonance discovery."
		var ids = discoveries[element].get("stable_experiment_ids", [])
		if not ids is Array: return "Invalid resonance evidence."
		var interference_ids = discoveries[element].get("interference_experiment_ids", [])
		if not interference_ids is Array: return "Invalid interference evidence."
		for id in interference_ids:
			if id not in ids: return "Interference evidence must reference stable evidence."
		var seen: Array = []
		for id in ids:
			if not (id is int or id is float) or not is_finite(float(id)) or id != int(id) or id < 1 or id in seen: return "Invalid resonance evidence ID."
			seen.append(id)
	_main = "" if main == null else main
	free_attributes=free
	_awakened=data.get("awakened_attributes",[]).duplicate()
	selected_attribute_slot=data.get("selected_attribute_slot","main")
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
	if free_attributes:result.merge({"attribute_loadout_version":1,"awakened_attributes":_awakened.duplicate(),"active_main_attribute":main_attribute,"active_auxiliary_attribute":null if _auxiliary.is_empty() else _auxiliary[0],"selected_attribute_slot":selected_attribute_slot},true)
	return result

func enable_free_attributes()->String:return load_data(Loadout.upgrade(to_data()))
func set_active(main:Variant,aux:Variant)->bool:
	if not free_attributes:return false
	var data:=to_data();data.merge({"active_main_attribute":main,"active_auxiliary_attribute":aux,"main_attribute":main,"auxiliary_attributes":[] if aux==null else [aux]},true)
	if not Loadout.valid(data):return false
	_main="" if main==null else str(main);_auxiliary=PackedStringArray([] if aux==null else [aux]);return true
func slot_candidates(slot:String)->Array:return Loadout.candidates(_awakened,main_attribute,null if _auxiliary.is_empty() else _auxiliary[0],slot)
func cycle_active(direction:int)->bool:
	if not free_attributes or direction not in [-1,1]:return false
	var values:=slot_candidates(selected_attribute_slot)
	if values.is_empty():return false
	var old=main_attribute if selected_attribute_slot=="main" else (null if _auxiliary.is_empty() else _auxiliary[0])
	var next=values[posmod(values.find(old)+direction,values.size())]
	if next==old:return false
	return set_active(next,null if _auxiliary.is_empty() else _auxiliary[0]) if selected_attribute_slot=="main" else set_active(main_attribute,next)

func innate_element() -> String:
	# Derive a unique numeric maximum without assigning or changing old talent data.
	var highest := -INF
	var chosen := ""
	var tied := false
	for element in BaseElements.OHAENG + ["VOID"]:
		var score = _affinity.get(element)
		if not (score is int or score is float) or not is_finite(float(score)): continue
		if score > highest:
			highest = float(score)
			chosen = element
			tied = false
		elif score == highest: tied = true
	return "" if tied or chosen == "VOID" else chosen

func has_clue(element: String, source: String) -> bool:
	return _clues.has({"element": element, "source": source, "id": Rules.clue_id(element, source)})

func simulation_context() -> Dictionary:
	var knowledge: Dictionary = {}
	for element in BaseElements.DEFINITIONS:
		knowledge[element] = {"book": has_clue(element, "book"), "mentor": has_clue(element, "mentor")}
	return {"innate_element": innate_element(), "knowledge": knowledge, "control_penalty": 0.0,
		"attribute_loadout_version":1 if free_attributes else 0,"awakened_attributes":awakened_attributes,
		"active_main_attribute":main_attribute,"active_auxiliary_attribute":null if _auxiliary.is_empty() else _auxiliary[0],
		"main_attribute": main_attribute, "auxiliary_attributes": Array(_auxiliary),
		"legacy_committed_attributes": Array(_legacy), "neutral_wave_unlocked": _extra.get("neutral_mana", {}).get("legacy_wave_unlocked", false), "binding_pairs": _extra.get("binding_studies", []).duplicate(),
		"advanced_operations":_extra.get("advanced_manipulation_research",[]).duplicate(),"technique_rank":_extra.get("technique_rank",0)}

func stable_count(element: String) -> int:
	return _discoveries.get(element, {}).get("stable_experiment_ids", []).size()

func blink_unlocked()->bool:return _extra.get("movement_research",{}).get("blink_unlocked",false)
func complete_movement_research(simulation:Dictionary,id:int)->bool:
	if id<1 or simulation.get("state")!="ready" or not simulation.get("simulation_context",{}).get("movement_research",false):return false
	if simulation.get("kind")!="movement_research" or simulation.get("rules_version")!=8 or not simulation.simulation_context.get("laboratory",false) or not simulation.simulation_context.get("formal_rules",false):return false
	var study=preload("res://scripts/movement_research.gd")
	if not study.ready(simulation.get("actions",[]),simulation.get("final_state",{})):return false
	var data:Dictionary=_extra.get("movement_research",{}).duplicate(true)
	data.merge({"version":1,"blink_unlocked":true,"blink_proof":study.proof(simulation.final_state,id)},true);_extra.movement_research=data
	return true
func developer_blink(enabled:bool)->void:
	_extra["movement_research"]={"version":1,"blink_unlocked":enabled,"blink_proof":{"source":"developer"} if enabled else {}}

func developer_reset(kind:String,element:String)->bool:
	if kind=="blink":developer_blink(false);return true
	if free_attributes:return _developer_free_reset(kind,element)
	var data:=to_data()
	if kind=="toggle":
		if element not in BaseElements.OHAENG:return false
		if element==_main:kind="primary"
		elif element in _auxiliary:kind="auxiliary"
		elif _main.is_empty():data.main_attribute=element
		elif _auxiliary.is_empty():data.auxiliary_attributes=[element];data.binding_studies=[];data.fusion_observations={}
		else:return false
	match kind:
		"primary":data.main_attribute=null;data.auxiliary_attributes=[];data.legacy_committed_attributes=[];data.binding_studies=[];data.fusion_observations={}
		"auxiliary":data.auxiliary_attributes=[];data.binding_studies=[];data.fusion_observations={}
		"catalysts":data["catalyst_validations"]={}
		"all":data={"main_attribute":null,"auxiliary_attributes":[],"legacy_committed_attributes":[],"innate_affinity":innate_affinity,"research_clues":[],"resonance_discoveries":{},"binding_studies":[],"fusion_observations":{}}
		"toggle":pass
		_:return false
	data.erase("inactive_attribute_history");data.erase("researched_base_elements")
	return load_data(data).is_empty()

func _developer_free_reset(kind:String,element:String)->bool:
	var data:=to_data()
	match kind:
		"all_elements":data.awakened_attributes=Loadout.ORDER.duplicate()
		"selections":return set_active(_awakened[0] if not _awakened.is_empty() else null,null)
		"only":
			if element not in Loadout.ORDER:return false
			data.awakened_attributes=[element];data.binding_studies=[];data.fusion_observations={};data.main_attribute=element;data.auxiliary_attributes=[]
		"toggle":
			if element not in Loadout.ORDER:return false
			if element in data.awakened_attributes:data.awakened_attributes.erase(element)
			else:data.awakened_attributes.append(element)
		"primary":data.awakened_attributes=[];data.main_attribute=null;data.auxiliary_attributes=[];data.binding_studies=[];data.fusion_observations={}
		"auxiliary":data.auxiliary_attributes=[];data.binding_studies=[];data.fusion_observations={}
		"catalysts":data.catalyst_validations={}
		"all":
			data={"attribute_loadout_version":1,"awakened_attributes":[],"main_attribute":null,"auxiliary_attributes":[],"legacy_committed_attributes":[],"innate_affinity":innate_affinity,"research_clues":[],"resonance_discoveries":{},"binding_studies":[],"fusion_observations":{}}
		_:return false
	var opened:Array=data.awakened_attributes
	if data.main_attribute not in opened:data.main_attribute=opened[0] if not opened.is_empty() else null
	data.auxiliary_attributes=data.auxiliary_attributes.filter(func(e):return e in opened and e!=data.main_attribute)
	data.active_main_attribute=data.main_attribute;data.active_auxiliary_attribute=data.auxiliary_attributes[0] if not data.auxiliary_attributes.is_empty() else null;data.selected_attribute_slot="main"
	data.binding_studies=data.get("binding_studies",[]).filter(func(p):return Loadout.owns_pair(Array(p.split("+")),opened))
	for pair in data.get("fusion_observations",{}).keys():
		if not Loadout.owns_pair(Array(pair.split("+")),opened):data.fusion_observations.erase(pair)
	data.erase("researched_base_elements");return load_data(data).is_empty()

func validate_evidence(records: Array) -> String:
	var by_id: Dictionary = {}
	var permanent=_extra.get("permanent_evidence",{})
	if not permanent is Dictionary:return "Invalid permanent evidence."
	for key in permanent:
		if not permanent[key] is Dictionary or not permanent[key].get("result") is Dictionary:return "Invalid permanent evidence record."
		if str(key)!=str(int(permanent[key].get("id",-1))):return "Invalid permanent evidence key."
		by_id[int(permanent[key].id)]=permanent[key]
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
			if id in _discoveries[element].get("interference_experiment_ids", []):
				var new_learning: bool = version >= 6
				var original_main=record.get("simulation_context", {}).get("main_attribute")
				if terminal.get("cohesion", 0.0) < (25.0 if new_learning else 50.0) or terminal.get("stability", 0.0) < (75.0 if new_learning else 85.0) or terminal.get("form_integrity", 0.0) < 50.0 or (original_main not in _awakened if free_attributes else original_main != main_attribute): return "Invalid saved interference stabilization."
	for pair in _extra.get("fusion_observations", {}):
		var observation = _extra["fusion_observations"][pair]
		if not pair is String or pair not in Fusion.PHENOMENA or not observation is Dictionary or not observation.get("experiment_ids") is Array: return "Invalid fusion evidence."
		if not (Loadout.owns_pair(Array(pair.split("+")),_awakened) if free_attributes else Fusion.authorized(Array(pair.split("+")), main_attribute, Array(_auxiliary))): return "Forbidden fusion evidence lineage."
		for id in observation["experiment_ids"]:
			if not (id is int or id is float) or not by_id.has(int(id)): return "Missing fusion experiment."
			var saved_result: Dictionary = by_id[int(id)]["result"]
			if saved_result.get("outcome") != "released" or Fusion.pair(saved_result.get("terminal_snapshot", {}).get("base_attributes", [])) != pair: return "Invalid fusion experiment lineage."
	return ""

func detach_evidence(records:Array)->void:
	# Minimal, immutable earned proof: no input keys, replay frames, notes or UI flags.
	var required:Array=[]
	for row in _discoveries.values():required.append_array(row.get("stable_experiment_ids",[]))
	for row in _extra.get("fusion_observations",{}).values():required.append_array(row.get("experiment_ids",[]))
	for row in _extra.get("inactive_attribute_history",{}).get("fusion_observations",{}).values():required.append_array(row.get("experiment_ids",[]))
	if required.is_empty():return
	if not _extra.has("permanent_evidence"):_extra["permanent_evidence"]={}
	for record in records:
		if not preload("res://scripts/experiment_journal.gd").has_id(required,record.id):continue
		var source:Dictionary=record.result;var state:Dictionary=source.get("terminal_snapshot",{})
		var terminal:Dictionary={}
		for key in ["base_attributes","cohesion","stability","form_integrity"]:
			if state.has(key):terminal[key]=state[key]
		_extra.permanent_evidence[str(int(record.id))]={"id":int(record.id),"rules_version":record.get("rules_version",0),"result":{"outcome":source.get("outcome",""),"kind":source.get("kind",""),"terminal_snapshot":terminal},"simulation_context":{"main_attribute":record.get("simulation_context",{}).get("main_attribute")}}

func eligibility(element: String) -> String:
	if element not in BaseElements.OHAENG: return "invalid_element"
	if free_attributes:return "already_researched" if element in _awakened else "awakening_required"
	if researched_base_elements.has(element): return "already_researched"
	if not _main.is_empty() and not _auxiliary.is_empty(): return "slots_full"
	if researched_base_elements.size()>=3 and not _legacy.has(element):return "slots_full"
	return "awakening_required" if _main.is_empty() else "auxiliary_awakening_required"

func request_research(element: String) -> Dictionary:
	return {"state": eligibility(element)} # No old UI ticket bypass.

func ritual_eligibility(element: String) -> String:
	if element not in BaseElements.OHAENG: return "invalid_element"
	if _extra.get("neutral_mana", {}).get("transition_pending", false): return "neutral_transition_required"
	if (element in _awakened if free_attributes else element == _main or _auxiliary.has(element)): return "already_researched"
	if not free_attributes and not _main.is_empty() and _auxiliary.size() >= 1: return "slots_full"
	if not free_attributes and researched_base_elements.size()>=3 and not _legacy.has(element):return "slots_full"
	if not has_clue(element, "book") and not has_clue(element, "mentor") and (use_current_rules or not has_clue(element,"environment")): return "clues_required"
	if stable_count(element) < 1: return "stable_reproduction_required"
	if use_current_rules and not catalyst_verified(element):return "catalyst_required"
	if not _main.is_empty() and interference_count(element) < 1: return "interference_research_required"
	return "available"

func begin_ritual(element: String) -> String:
	cancel_request()
	var state := ritual_eligibility(element)
	if state != "available": return state
	_ritual = element
	return "ritual_started"

func complete_ritual(profile: Profile, inputs: Array,current:=false) -> Dictionary:
	if _ritual.is_empty() or ritual_eligibility(_ritual) != "available": return {"state": "ritual_required"}
	var result:Dictionary
	if current:
		var context:=simulation_context();context.merge({"formal_rules":true,"laboratory":true,"research_only":true,"observation_element":_ritual})
		result=preload("res://scripts/chant_engine_v2.gd").resolve(profile,inputs,context).simulation
	else:result=Simulator.simulate(profile, inputs, true, simulation_context())
	var final: Dictionary = result["final_state"]
	if result["state"] != "ready" or final["base_attributes"] != [_ritual]: return {"state": "target_resonance_required"}
	if final["form_integrity"] < 50.0 or (final.get("flow_strength",0)<.5 if current else final["flow_vector"] != [1.0, 0.0]): return {"state": "ritual_structure_required"}
	_ticket_sequence += 1
	_pending_ticket = _ticket_sequence
	_pending_element = _ritual
	return {"state": "confirmation_required", "element": _ritual, "ticket": _pending_ticket}

func cancel_request() -> void:
	_ritual = ""
	_pending_element = ""
	_pending_ticket = 0

func start_element_research(element: String, confirmation_ticket: int = 0) -> String:
	if element not in BaseElements.OHAENG: return "invalid_element"
	if (element in _awakened if free_attributes else element == _main or _auxiliary.has(element)): return "already_researched"
	if not free_attributes and not _main.is_empty() and not _auxiliary.is_empty(): return "slots_full"
	if not free_attributes and researched_base_elements.size()>=3 and not _legacy.has(element):return "slots_full"
	if confirmation_ticket == 0 or confirmation_ticket != _pending_ticket or element != _pending_element:
		return "confirmation_required"
	if ritual_eligibility(element) != "available": return "research_conditions_changed"
	if _legacy.has(element): _legacy.remove_at(_legacy.find(element))
	if free_attributes:
		_awakened.append(element)
		if _main.is_empty():_main=element
	elif _main.is_empty(): _main = element
	else: _auxiliary.append(element)
	cancel_request()
	return "committed"

func acquire_clue(element: String, source: String, clue_id: String) -> String:
	if BaseElements.resource(element) == null: return "invalid_element"
	if source not in ["book", "mentor", "environment", "observation", "hint"] or clue_id.is_empty(): return "invalid_clue"
	var clue := {"element": element, "source": source, "id": clue_id}
	if not _clues.has(clue): _clues.append(clue)
	return "recorded"

func record_resonance(profile: Profile, inputs: Array, experiment_id: int) -> bool:
	if experiment_id < 1: return false
	var result := Simulator.simulate(profile, inputs, true, simulation_context())
	var attributes: Array = result["final_state"]["base_attributes"]
	if result["state"] != "ready": return false
	if attributes.size() == 2:
		if not Fusion.authorized(attributes, main_attribute, Array(_auxiliary)): return false
		if not _extra.has("fusion_observations"): _extra["fusion_observations"] = {}
		var key := Fusion.pair(attributes)
		if not _extra["fusion_observations"].has(key): _extra["fusion_observations"][key] = {"phenomenon": Fusion.PHENOMENA.get(key, "unknown"), "experiment_ids": []}
		var observations: Array = _extra["fusion_observations"][key]["experiment_ids"]
		if experiment_id not in observations: observations.append(experiment_id)
		return true
	if attributes.size() != 1: return false
	var element: String = attributes[0]
	if not _discoveries.has(element): _discoveries[element] = {"stable_experiment_ids": []}
	var ids: Array = _discoveries[element]["stable_experiment_ids"]
	if not ids.has(experiment_id): ids.append(experiment_id)
	if not _main.is_empty() and element != _main and result["final_state"]["cohesion"] >= 25.0 and result["final_state"]["stability"] >= 75.0 and result["final_state"]["form_integrity"] >= 50.0:
		if not _discoveries[element].has("interference_experiment_ids"): _discoveries[element]["interference_experiment_ids"] = []
		var interference_ids: Array = _discoveries[element]["interference_experiment_ids"]
		if experiment_id not in interference_ids: interference_ids.append(experiment_id)
	acquire_clue(element, "observation", "observation_" + element)
	return true

func interference_count(element: String) -> int:
	return _discoveries.get(element, {}).get("interference_experiment_ids", []).size()

func catalyst_verified(element:String)->bool:return _extra.get("catalyst_validations",{}).has(element)
func verify_catalyst(element:String,state:Dictionary)->String:
	if not has_clue(element,"book") and not has_clue(element,"mentor"):return "clues_required"
	if stable_count(element)<1:return "stable_reproduction_required"
	if not preload("res://scripts/chant_engine_v2.gd").research_ready(state) or state.get("base_attributes",[])!=[element]:return "catalyst_rejected"
	if not _extra.has("catalyst_validations"):_extra.catalyst_validations={}
	_extra.catalyst_validations[element]={"rules_version":8,"mana_amount":state.mana_amount,"stability":state.stability,"form_integrity":state.form_integrity}
	acquire_clue(element,"environment",Rules.clue_id(element,"environment"))
	return "verified"
func record_current_resonance(simulation:Dictionary,id:int)->bool:
	var state:Dictionary=simulation.final_state
	var lineage:Array=state.get("base_attributes",[])
	if lineage.size()==2 and simulation.get("state")=="ready" and state.get("binding_quality",0)>=55 and Fusion.authorized(lineage,main_attribute,Array(_auxiliary)):
		var key:=Fusion.pair(lineage)
		if not _extra.has("fusion_observations"):_extra.fusion_observations={}
		if not _extra.fusion_observations.has(key):_extra.fusion_observations[key]={"phenomenon":Fusion.PHENOMENA.get(key,"unknown"),"experiment_ids":[]}
		var ids:Array=_extra.fusion_observations[key].experiment_ids
		if not preload("res://scripts/experiment_journal.gd").has_id(ids,id):ids.append(id)
		return true
	if not preload("res://scripts/chant_engine_v2.gd").research_ready(state):return false
	var element:String=state.base_attributes[0]
	if not _discoveries.has(element):_discoveries[element]={"stable_experiment_ids":[]}
	var row:Dictionary=_discoveries[element]
	if not preload("res://scripts/experiment_journal.gd").has_id(row.stable_experiment_ids,id):row.stable_experiment_ids.append(id)
	if _main!="" and element!=_main and state.cohesion>=25 and state.stability>=75 and state.form_integrity>=50:
		if not row.has("interference_experiment_ids"):row.interference_experiment_ids=[]
		if not preload("res://scripts/experiment_journal.gd").has_id(row.interference_experiment_ids,id):row.interference_experiment_ids.append(id)
	return true

func study_binding(element: String) -> String:
	if not _auxiliary.has(element) or _main.is_empty(): return "confirmed_auxiliary_required"
	if Fusion.pair([_main,element]) in _extra.get("binding_studies",[]):return "binding_studied"
	if interference_count(element) < 1 or not has_clue(element, "environment"): return "interference_research_required"
	if use_current_rules and not catalyst_verified(element):return "catalyst_required"
	var pair := Fusion.pair([_main, element])
	if not _extra.has("binding_studies"): _extra["binding_studies"] = []
	if pair not in _extra["binding_studies"]: _extra["binding_studies"].append(pair)
	return "binding_studied"

func acknowledge_neutral_transition() -> bool:
	if not _extra.get("neutral_mana", {}).get("transition_pending", false): return false
	_extra["neutral_mana"]["transition_pending"] = false
	return true
