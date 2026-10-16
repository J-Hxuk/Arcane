extends RefCounted
## Pure deterministic laws shared by lab and dungeon. No Input, RNG or live actors.
const RULES_VERSION := 1
const MAX_STEPS := 32
const MAX_DURATION_MS := 60000
const PROTOTYPE_ELEMENT := "FIRE"
const Profile = preload("res://scripts/chant_profile.gd")

static func initial_state() -> Dictionary:
	return {"phase": "CHANNEL_OPEN", "mana_amount": 0.0, "cohesion": 0.0,
		"stability": 60.0, "resonance": {}, "form_integrity": 0.0,
		"flow_vector": [0.0, 0.0], "base_attributes": [], "energy_loss": 0.0}

static func simulate(profile: Profile, inputs: Array, legacy_tutorial := false) -> Dictionary:
	var state := initial_state()
	var steps: Array = []
	# Compatibility adapter produces the same structure as a personal neutral chant.
	# It is the old taught formula, not an answer table for the personal key mapping.
	var tutorial: bool = legacy_tutorial and inputs.size() == 2 and inputs[0] is Dictionary and inputs[1] is Dictionary and inputs[0].get("key") == "Q" and inputs[1].get("key") == "E"
	var invalid_at := -1
	var previous_time := -1
	for index in range(inputs.size()):
		var input = inputs[index]
		var before := state.duplicate(true)
		var valid := input is Dictionary and input.get("key") is String
		var time_value = input.get("at_ms", 0) if input is Dictionary else 0
		var hold = input.get("hold_ms", 0) if input is Dictionary else 0
		valid = valid and _valid_time(time_value) and _valid_time(hold) and time_value >= previous_time and index < MAX_STEPS
		if not valid or invalid_at >= 0:
			if invalid_at < 0: invalid_at = index
			state["phase"] = "FAILED"
		else:
			previous_time = int(time_value)
			var key: String = input["key"]
			if tutorial:
				if index == 0: state["phase"] = "ATTRIBUTE_SEEDED"
				else:
					state.merge({"mana_amount": 10.0, "cohesion": 25.0, "stability": 70.0,
						"form_integrity": 50.0, "flow_vector": [1.0, 0.0]}, true)
			elif index == 0:
				if key == "C": state["phase"] = "ATTRIBUTE_SEEDED"
				elif not profile.first_word(key).is_empty():
					state["base_attributes"] = [profile.first_word(key)]
					state["phase"] = "ATTRIBUTE_SEEDED"
				else:
					state["phase"] = "FAILED"
					invalid_at = index
			else:
				var action := profile.manipulation(key)
				if action.is_empty():
					state["phase"] = "FAILED"
					invalid_at = index
				else:
					_apply(state, action, int(hold))
					state["phase"] = "MANIPULATING"
		steps.append({"input": input.duplicate(true) if input is Dictionary else {},
			"before": before, "after": state.duplicate(true), "before_observation": observe(before, index), "observation": observe(state, index + 1)})
	var outcome := classify(state, inputs.size(), invalid_at)
	state["phase"] = "READY" if outcome["state"] == "ready" else ("FAILED" if outcome["state"] == "failed" else state["phase"])
	return {"rules_version": RULES_VERSION, "state": outcome["state"], "kind": outcome["kind"],
		"message": outcome["message"], "mana_cost": outcome["mana_cost"], "final_state": state,
		"casting_steps": steps, "failure_step": invalid_at + 1 if invalid_at >= 0 else (inputs.size() if outcome["state"] != "ready" else 0),
		"observation": observe(state, inputs.size()), "tutorial_compatibility": tutorial}

static func _valid_time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= 0 and value <= MAX_DURATION_MS

static func _apply(state: Dictionary, action: String, hold_ms: int) -> void:
	match action:
		"ACCUMULATE": state["mana_amount"] = minf(60.0, state["mana_amount"] + 10.0 + mini(hold_ms, 1000) / 250 * 5)
		"COMPRESS":
			state["cohesion"] = minf(100.0, state["cohesion"] + 25.0)
			state["stability"] -= 5.0
			state["energy_loss"] += 1.0
		"STABILIZE": state["stability"] = minf(100.0, state["stability"] + 20.0)
		"RESONATE":
			if state["mana_amount"] >= 10.0 and state["cohesion"] >= 25.0 and state["stability"] >= 45.0:
				for element in state["base_attributes"]:
					state["resonance"][element] = minf(100.0, state["resonance"].get(element, 0.0) + 50.0)
			else: state["energy_loss"] += 1.0
			state["stability"] -= 5.0
		"SHAPE":
			state["form_integrity"] = minf(100.0, state["form_integrity"] + 50.0)
			state["stability"] -= 5.0
		"DIRECT": state["flow_vector"] = [1.0, 0.0]
		"DISSIPATE":
			state["mana_amount"] = maxf(0.0, state["mana_amount"] - 10.0)
			state["energy_loss"] += 2.0
	state["stability"] = clampf(state["stability"], 0.0, 100.0)

static func classify(state: Dictionary, step_count: int, invalid_at := -1) -> Dictionary:
	if step_count == 0: return _outcome("empty", "none", "Enter commands first: Q > E, then LMB.", 0.0)
	if invalid_at >= 0 or state["base_attributes"].size() > 3:
		return _outcome("failed", "collapse", "입력 흐름이 끊겨 구조가 무너졌습니다.", 2.0)
	var seen: Array = []
	for element in state["base_attributes"]:
		if element not in Profile.ELEMENTS or element in seen:
			return _outcome("failed", "collapse", "유효하지 않은 기저 속성 구조입니다.", 2.0)
		seen.append(element)
	if step_count == 1:
		return _outcome("incomplete", "none", "Incomplete: 아직 관찰할 반응이 없습니다.", 0.0)
	if state["stability"] < 30.0:
		return _outcome("failed", "collapse", "구조가 붕괴했습니다.", 2.0)
	if state["base_attributes"].is_empty():
		if state["mana_amount"] >= 10.0 and state["cohesion"] >= 25.0 and state["stability"] >= 55.0 and state["form_integrity"] >= 50.0 and state["flow_vector"] == [1.0, 0.0]:
			return _outcome("ready", "mana_bolt", "Mana Bolt ready. LMB to release.", 15.0 + state["energy_loss"])
	else:
		# One experimental phenomenon only; other elements are not unlocked content.
		if state["base_attributes"] == [PROTOTYPE_ELEMENT] and state["resonance"].get(PROTOTYPE_ELEMENT, 0.0) >= 50.0:
			if state["stability"] >= 55.0 and state["mana_amount"] >= 10.0 and state["cohesion"] >= 25.0:
				return _outcome("ready", "fire_resonance", "잔잔한 온기와 일정한 빛이 유지됩니다.", 5.0 + state["energy_loss"])
			return _outcome("unstable", "unstable", "온기가 흔들리며 흩어집니다.", 2.0)
	return _outcome("incomplete", "none", "Incomplete: 아직 유지할 수 있는 현상이 아닙니다.", 2.0)

static func _outcome(state: String, kind: String, message: String, cost: float) -> Dictionary:
	return {"state": state, "kind": kind, "message": message, "mana_cost": cost}

static func observe(state: Dictionary, step_count: int) -> String:
	# Only sensory evidence. No element IDs, action names, affinity or raw numbers.
	if step_count <= 1: return "뚜렷한 변화가 관찰되지 않습니다."
	if state["phase"] == "FAILED" or state["stability"] < 30.0: return "윤곽이 무너지고 잔광이 꺼집니다."
	var parts := PackedStringArray()
	parts.append("옅은 잔광" if state["mana_amount"] < 10.0 else "밝아진 잔광")
	if state["cohesion"] >= 25.0: parts.append("좁아진 빛의 덩어리")
	if state["form_integrity"] >= 50.0: parts.append("이어진 둥근 윤곽")
	if state["flow_vector"] == [1.0, 0.0]: parts.append("한 방향으로 흐르는 궤적")
	if state["resonance"].get(PROTOTYPE_ELEMENT, 0.0) >= 50.0: parts.append("피어나는 온기")
	parts.append("잔잔한 떨림" if state["stability"] >= 55.0 else "불규칙한 떨림")
	return " · ".join(parts)
