extends RefCounted
## Replay and comparison read stored snapshots, never rerun a cast or spend mana.
var _data := {"version": 1, "next_id": 1, "records": []}

func load_data(data: Dictionary) -> String:
	if data.get("version", 1) != 1 or not data.get("records", []) is Array: return "Invalid laboratory journal."
	if data.has("auto_record_failures") and not data["auto_record_failures"] is bool: return "Invalid journal recording preference."
	if data.has("retention"):
		if not data.retention is Dictionary or not data.retention.get("pending") is bool or not _integer(data.retention.get("legacy_through"),0):return "Invalid journal retention policy."
	var observed = data.get("observed_first_words", {})
	if not observed is Dictionary: return "Invalid first-word observations."
	for key in observed:
		if key == "C" and observed[key] == "NEUTRAL": continue # Earlier explicit neutral observation.
		if key not in preload("res://scripts/chant_profile.gd").ATTRIBUTE_KEYS or observed[key] not in preload("res://scripts/chant_profile.gd").ELEMENTS: return "Invalid first-word observation."
	var next_id = data.get("next_id", 1)
	if not _integer(next_id, 1): return "Invalid experiment ID."
	var last_id := 0
	for record in data.get("records", []):
		if not record is Dictionary or not record.get("steps") is Array or not record.get("result") is Dictionary:
			return "Invalid experiment record."
		if not _integer(record.get("id"), last_id + 1):
			return "Invalid experiment sequence."
		if not record.get("note", "") is String or str(record.get("note", "")).length() > 2000:
			return "Invalid experiment note."
		if record.has("protected") and not record["protected"] is bool: return "Invalid experiment protection flag."
		if record.has("grammar_profile"):
			if not record.grammar_profile is Dictionary:return "Invalid stored experiment mapping."
			var mapping:=preload("res://scripts/chant_profile.gd").new()
			if not mapping.load_data(record.grammar_profile).is_empty():return "Invalid stored experiment mapping."
		if record.has("created_at"):
			var timestamp = record["created_at"]
			if not (timestamp is int or timestamp is float) or not is_finite(float(timestamp)) or timestamp < 0: return "Invalid experiment timestamp."
		for step in record["steps"]:
			if not step is Dictionary or not step.get("before") is Dictionary or not step.get("after") is Dictionary or not step.get("input") is Dictionary or not step.get("observation") is String:
				return "Invalid stored experiment snapshot."
			var input: Dictionary = step["input"]
			if not input.get("key") is String or not _integer(input.get("at_ms"), 0, 60000) or not _integer(input.get("hold_ms"), 0, 60000):
				return "Invalid recorded input timing."
		var result: Dictionary = record["result"]
		var spent = result.get("energy_spent")
		if not result.get("outcome") is String or not result.get("kind") is String or not result.get("observation") is String:
			return "Invalid recorded result."
		if not (spent is int or spent is float) or not is_finite(float(spent)) or spent < 0:
			return "Invalid recorded energy."
		if not _integer(result.get("elapsed_ms"), 0, 120000) or not _integer(result.get("failure_step"), 0, record["steps"].size()):
			return "Invalid recorded result timing."
		last_id = int(record["id"])
	if next_id <= last_id: return "Invalid next experiment ID."
	_data = data.duplicate(true)
	_data.merge({"version": 1, "next_id": int(next_id), "records": data.get("records", []).duplicate(true)}, true)
	return ""

func _integer(value: Variant, minimum: int, maximum := 2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= minimum and value <= maximum

func to_data() -> Dictionary:
	return _data.duplicate(true)

func records() -> Array:
	return _data["records"].duplicate(true)

func append_environment(element:String,text:String,profile_version:int)->int:
	var id:=append({"final_state":{},"casting_steps":[],"kind":"environment_clue","observation":text,"state":"observed","failure_step":0,"failure_kind":"none","rules_version":7},"released",0,0,profile_version)
	_data.records.back()["observation_title"]="환경 단서 관측 — "+str(preload("res://scripts/base_elements.gd").DEFINITIONS[element].display_name)
	_data.records.back()["environment_element"]=element
	return id

func mark_manifestation(id: int, manifestation: Dictionary) -> void:
	for record in _data["records"]:
		if record["id"] != id: continue
		var result: Dictionary = record["result"]
		result["manifestation"] = manifestation.duplicate(true)
		result["simulation_stage"] = result.get("response_stage", "")
		result["response_stage"] = "manifested"
		result["failure_step"] = 0
		result["failure_kind"] = "none"
		return

func append(result: Dictionary, outcome: String, spent: float, elapsed_ms: int, profile_version: int) -> int:
	var id := int(_data["next_id"])
	if not _data.has("retention"):_data["retention"]={"pending":_data["records"].size()>10,"legacy_through":id-1 if _data["records"].size()>10 else 0}
	var terminal: Dictionary = result["final_state"].duplicate(true)
	terminal["phase"] = "CANCEL" if outcome == "cancelled" else ("RELEASE" if outcome == "released" else "FAILED")
	_data["records"].append({"id": id, "steps": result["casting_steps"].duplicate(true),
		"result": {"outcome": outcome, "kind": result["kind"], "observation": result["observation"], "response_stage": result["state"],
			"failure_step": 0 if outcome == "cancelled" else result["failure_step"],
			"failure_kind": "none" if outcome == "cancelled" else result.get("failure_kind", "legacy"), "energy_spent": spent, "elapsed_ms": elapsed_ms,
			"terminal_snapshot": terminal},
		"rules_version": result["rules_version"], "profile_version": profile_version, "note": "",
		"created_at": Time.get_unix_time_from_system(), "protected": false,
		"simulation_context": result.get("simulation_context", {}).duplicate(true)})
	_data["next_id"] = id + 1
	if int(result["rules_version"])>=8:_data["records"].back()["grammar_profile"]=result.get("grammar_profile",{}).duplicate(true)
	if result.has("property_version"):_data["records"].back()["property_version"]=result.property_version
	return id

static func category(record: Dictionary) -> String:
	var result: Dictionary = record["result"]
	if not result.get("manifestation", {}).is_empty(): return "discovery" if result["manifestation"].get("new_spell", false) else "reproduction"
	if result.get("outcome") == "cancelled": return "cancelled"
	if result.get("failure_kind") in ["collapse", "input_error"]: return "failed"
	var state: Dictionary = result.get("terminal_snapshot", {})
	if float(state.get("mana_amount", 0)) <= 0 and state.get("resonance", {}).is_empty(): return "no_result"
	if result.get("outcome") in ["failed", "exhausted", "insufficient_mana", "blocked"]: return "failed"
	return "observation"

static func title(record:Dictionary)->String:
	var result:Dictionary=record.result;var manifestation:Dictionary=result.get("manifestation",{})
	if not manifestation.is_empty():
		var name:String=manifestation.get("english_name",manifestation.get("name",preload("res://scripts/spell_names.gd").label(str(manifestation.get("spell_id","")))))
		if name.is_empty():name=manifestation.get("name",preload("res://scripts/spell_names.gd").label(str(manifestation.get("spell_id",""))))
		return ("마법 발견 — " if manifestation.get("new_spell",false) else "영창 성공 — ")+name
	if record.get("observation_title","")!="":return record.observation_title
	if category(record)=="failed":return "영창 불발 — "+{"collapse":"마나 붕괴","unstable":"안정성 부족","input_error":"입력 이상"}.get(result.get("failure_kind",""),"구조 미완성")
	if category(record)=="cancelled":return "영창 취소 — 사용자 중단"
	return "마나 관측 — "+preload("res://scripts/research_visibility.gd").observed(result.get("terminal_snapshot",{}))

func eligible_ids(ids: Array, evidence_ids: Array) -> Array:
	var allowed: Array = []
	for record in _data["records"]:
		if has_id(ids,record.id) and not has_id(evidence_ids,record.id) and not record.get("protected", false): allowed.append(record["id"])
	return allowed

func remove_records(ids: Array, evidence_ids: Array) -> int:
	var allowed := eligible_ids(ids, evidence_ids)
	_data["records"] = _data["records"].filter(func(record): return not has_id(allowed,record.id))
	return allowed.size()

func protect(id: int, enabled: bool) -> void:
	for record in _data["records"]:
		if record["id"] == id: record["protected"] = enabled

func auto_failures() -> bool: return _data.get("auto_record_failures", true)
func set_auto_failures(enabled: bool) -> void: _data["auto_record_failures"] = enabled

func observe_first_word(key: String, element: String) -> bool:
	if not _data.has("observed_first_words"): _data["observed_first_words"] = {}
	if _data["observed_first_words"].get(key) == element: return false
	_data["observed_first_words"][key] = element
	return true

func note(id: int, value: String) -> bool:
	if value.length() > 2000: return false
	for record in _data["records"]:
		if record["id"] == id:
			record["note"] = value
			return true
	return false

func retention_pending()->bool:
	return _data.get("retention",{}).get("pending",_data["records"].size()>10)
func trim_preview(evidence:Array)->Dictionary:
	var normal:Array=[];var keep:Array=[]
	for record in records():
		if record.get("protected",false) or has_id(evidence,record.id):keep.append(record["id"])
		else:normal.append(record["id"])
	keep.append_array(normal.slice(maxi(0,normal.size()-10)))
	var remove:Array=[]
	for record in records():
		if not has_id(keep,record.id):remove.append(record["id"])
	return {"keep":keep,"remove":remove,"normal_kept":mini(10,normal.size())}
func trim_new_records(evidence:Array)->void:
	if retention_pending():
		# Old records remain selectable until explicit migration approval. New
		# records alone use the rolling policy, including while approval is pending.
		var cutoff:int=_data.get("retention",{}).get("legacy_through",_data.next_id-1)
		var newer:Array=[]
		for record in records():
			if record.id>cutoff and not record.get("protected",false) and not has_id(evidence,record.id):newer.append(record.id)
		remove_records(newer.slice(0,maxi(0,newer.size()-10)),evidence)
	else:remove_records(trim_preview(evidence).remove,evidence)
func confirm_retention(evidence:Array)->void:
	remove_records(trim_preview(evidence).remove,evidence)
	_data["retention"]={"pending":false,"legacy_through":0}

static func has_id(ids:Array,id:Variant)->bool:
	for candidate in ids:
		if candidate==id:return true
	return false

func replay(id: int, step_index: int) -> Dictionary:
	for record in _data["records"]:
		if record["id"] == id and step_index >= 0 and step_index < record["steps"].size():
			return record["steps"][step_index].duplicate(true)
	return {}

func compare(left_id: int, left_step: int, right_id: int, right_step: int) -> Dictionary:
	return {"left": replay(left_id, left_step), "right": replay(right_id, right_step)}
