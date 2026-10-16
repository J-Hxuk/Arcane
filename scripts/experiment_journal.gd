extends RefCounted
## Replay and comparison read stored snapshots, never rerun a cast or spend mana.
var _data := {"version": 1, "next_id": 1, "records": []}

func load_data(data: Dictionary) -> String:
	if data.get("version", 1) != 1 or not data.get("records", []) is Array: return "Invalid laboratory journal."
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

func append(result: Dictionary, outcome: String, spent: float, elapsed_ms: int, profile_version: int) -> int:
	var id := int(_data["next_id"])
	var terminal: Dictionary = result["final_state"].duplicate(true)
	terminal["phase"] = "CANCEL" if outcome == "cancelled" else ("RELEASE" if outcome == "released" else "FAILED")
	_data["records"].append({"id": id, "steps": result["casting_steps"].duplicate(true),
		"result": {"outcome": outcome, "kind": result["kind"], "observation": result["observation"],
			"failure_step": 0 if outcome == "cancelled" else result["failure_step"], "energy_spent": spent, "elapsed_ms": elapsed_ms,
			"terminal_snapshot": terminal},
		"rules_version": result["rules_version"], "profile_version": profile_version, "note": ""})
	_data["next_id"] = id + 1
	return id

func note(id: int, value: String) -> bool:
	if value.length() > 2000: return false
	for record in _data["records"]:
		if record["id"] == id:
			record["note"] = value
			return true
	return false

func replay(id: int, step_index: int) -> Dictionary:
	for record in _data["records"]:
		if record["id"] == id and step_index >= 0 and step_index < record["steps"].size():
			return record["steps"][step_index].duplicate(true)
	return {}

func compare(left_id: int, left_step: int, right_id: int, right_step: int) -> Dictionary:
	return {"left": replay(left_id, left_step), "right": replay(right_id, right_step)}
