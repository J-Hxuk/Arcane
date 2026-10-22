extends RefCounted
## Pure deterministic laws shared by lab and dungeon. No Input, RNG or live actors.
const RULES_VERSION := 7
const MAX_STEPS := 32
const MAX_DURATION_MS := 60000
const Profile = preload("res://scripts/chant_profile.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const Fusion = preload("res://scripts/fusion_rules.gd")

static func initial_state() -> Dictionary:
	return {"phase": "CHANNEL_OPEN", "mana_amount": 0.0, "cohesion": 0.0,
		"stability": 60.0, "resonance": {}, "form_integrity": 0.0,
		"flow_vector": [0.0, 0.0], "base_attributes": [], "energy_loss": 0.0, "resonance_attempts": 0,
		"binding_window": false, "binding_quality": 0.0, "interference": 0.0,
		"flow_strength":0.0,"spread":0.0,"coupling":0.0,"persistence":0.0,
		"branches":1,"cycles":0.0,"anchoring":0.0,"advanced_used":false}

static func simulate(profile: Profile, inputs: Array, legacy_tutorial := false, context: Dictionary = {}) -> Dictionary:
	var state := initial_state()
	var steps: Array = []
	# Compatibility adapter produces the same structure as a personal neutral chant.
	# It is the old taught formula, not an answer table for the personal key mapping.
	var tutorial: bool = profile.version() == 1 and legacy_tutorial and inputs.size() == 2 and inputs[0] is Dictionary and inputs[1] is Dictionary and inputs[0].get("key") == "Q" and inputs[1].get("key") == "E"
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
					if profile.first_word(key) == "VOID": state["neutral_legacy"] = true
					else: state["base_attributes"] = [profile.first_word(key)]
					state["phase"] = "ATTRIBUTE_SEEDED"
				else:
					state["phase"] = "FAILED"
					invalid_at = index
			else:
				var action := profile.manipulation(key)
				var declared := profile.first_word(key)
				var attributes: Array = state["base_attributes"]
				var candidate: Array = attributes + [declared]
				if state["binding_window"] and attributes.size() == 1 and declared in Fusion.ELEMENTS and declared not in attributes and Fusion.pair(candidate) in context.get("binding_pairs", []) and Fusion.authorized(candidate, context.get("main_attribute"), context.get("auxiliary_attributes", [])):
					candidate.sort()
					state["base_attributes"] = candidate
					state["binding_window"] = false
					var relation := Rules.relation(candidate[0], candidate[1])
					state["interference"] = 10.0 if relation == "supportive" else (20.0 if relation == "opposed" else 15.0)
					var inherited_pressure := 0.0
					for element in candidate:
						inherited_pressure += Rules.requirements(element, context)["interference"]
						var knowledge: Dictionary = context.get("knowledge", {}).get(element, {})
						for source in ["book", "mentor"]:
							if not knowledge.get(source, false): state["interference"] += 1.0
					state["interference"] += maxf(0.0, inherited_pressure - 16.0) * 0.25
					state["binding_quality"] = 90.0 - state["interference"]
					state["stability"] -= state["interference"]
					for element in candidate: state["resonance"][element] = 50.0
					state["phase"] = "BOUND"
				elif action.is_empty() or (profile.version() == 2 and action in Profile.ADVANCED_ACTIONS and (action not in context.get("advanced_operations",[]) or context.get("technique_rank",0)<4)):
					state["phase"] = "FAILED"
					invalid_at = index
				else:
					state["binding_window"] = false
					if profile.version()==2 and action in Profile.ADVANCED_ACTIONS:state["advanced_used"]=true
					_apply(state, action, int(hold), context)
					if action == ("BIND" if profile.version() == 2 else "STABILIZE") and attributes.size() == 1 and state["mana_amount"] >= 10.0 and state["stability"] >= 80.0:
						for pair in context.get("binding_pairs", []):
							if attributes[0] in str(pair).split("+"): state["binding_window"] = true
					state["phase"] = "MANIPULATING"
					if state["stability"] < 30.0:
						invalid_at = index
						state["phase"] = "FAILED"
		steps.append({"input": input.duplicate(true) if input is Dictionary else {},
			"before": before, "after": state.duplicate(true), "before_observation": observe(before, index, context), "observation": observe(state, index + 1, context)})
	var outcome := classify(state, inputs.size(), invalid_at, context)
	var failure_kind := "none"
	if invalid_at >= 0: failure_kind = "collapse" if state["stability"] < 30.0 else "input_error"
	elif outcome["state"] not in ["ready", "empty"]: failure_kind = "unfinished"
	state["phase"] = "READY" if outcome["state"] == "ready" else ("FAILED" if outcome["state"] == "failed" else state["phase"])
	return {"rules_version": RULES_VERSION, "state": outcome["state"], "kind": outcome["kind"], "failure_kind": failure_kind,
		"message": outcome["message"], "mana_cost": outcome["mana_cost"], "final_state": state,
		"casting_steps": steps, "failure_step": invalid_at + 1 if invalid_at >= 0 else (inputs.size() if outcome["state"] != "ready" else 0),
		"observation": observe(state, inputs.size(), context), "tutorial_compatibility": tutorial, "simulation_context": context.duplicate(true)}

static func _valid_time(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= 0 and value <= MAX_DURATION_MS

static func _apply(state: Dictionary, action: String, hold_ms: int, context: Dictionary) -> void:
	match action:
		"ACCUMULATE": state["mana_amount"] = minf(60.0, state["mana_amount"] + 10.0 + mini(hold_ms, 1000) / 250 * 5)
		"COMPRESS":
			state["cohesion"] = minf(100.0, state["cohesion"] + 25.0)
			state["stability"] -= 5.0
			state["energy_loss"] += 1.0
			state["spread"]*=0.5
			if state["flow_strength"]>0:state["flow_strength"]=minf(1,state["flow_strength"]+0.25)
		"STABILIZE":
			state["stability"] = minf(100.0, state["stability"] + 20.0)
			if state["form_integrity"]>0:state["persistence"]=minf(2,state["persistence"]+0.5)
		"RESONATE":
			state["resonance_attempts"] += 1
			if state["mana_amount"]>=10:
				state["coupling"]=minf(3,state["coupling"]+1.0)
				if state["form_integrity"]>0:state["persistence"]=minf(2,state["persistence"]+0.25)
			if state["mana_amount"] >= 10.0 and state["cohesion"] >= 25.0 and state["stability"] >= 45.0:
				for element in state["base_attributes"]:
					var requirements := Rules.requirements(element, context)
					state["resonance"][element] = minf(100.0, state["resonance"].get(element, 0.0) + requirements["gain"])
					state["stability"] -= requirements["interference"]
			else: state["energy_loss"] += 1.0
			if state["base_attributes"].is_empty(): state["stability"] -= 5.0
		"SHAPE":
			state["form_integrity"] = minf(100.0, state["form_integrity"] + 50.0)
			state["stability"] -= 5.0
			state["spread"]=minf(1,state["spread"]+(0.45 if state["flow_strength"]>0 and state["cohesion"]<25 else 0.15))
		"DIRECT":
			state["flow_vector"] = [1.0, 0.0]
			state["flow_strength"]=minf(1,state["flow_strength"]+0.5)
		"BIND": pass # Opens the one-token declaration window below, not resonance.
		"EXPAND":
			state["spread"]=minf(2,state["spread"]+0.5);state["mana_amount"]*=0.8
			state["stability"]-=8;state["advanced_used"]=true
		"SPLIT":
			state["branches"]=mini(8,state["branches"]+1);state["cohesion"]*=0.75
			state["stability"]-=8;state["advanced_used"]=true
		"CYCLE":
			state["cycles"]+=1;state["persistence"]=minf(2,state["persistence"]+0.5)
			state["energy_loss"]+=1;state["advanced_used"]=true
		"ANCHOR":
			state["anchoring"]=minf(1,state["anchoring"]+0.5)
			state["flow_strength"]*=0.5;state["advanced_used"]=true
		"DISSIPATE":
			state["mana_amount"] = maxf(0.0, state["mana_amount"] - 10.0)
			state["energy_loss"] += 2.0
			state["stability"]=minf(100,state["stability"]+5)
	state["stability"] = clampf(state["stability"], 0.0, 100.0)

static func classify(state: Dictionary, step_count: int, invalid_at := -1, context: Dictionary = {}) -> Dictionary:
	if step_count == 0: return _outcome("empty", "none", "Enter commands first: Q > E, then LMB.", 0.0)
	if invalid_at >= 0 or state["base_attributes"].size() > 2:
		return _outcome("failed", "collapse", "입력 흐름이 끊겨 구조가 무너졌습니다.", 2.0)
	var seen: Array = []
	for element in state["base_attributes"]:
		if element not in Fusion.ELEMENTS or element in seen:
			return _outcome("failed", "collapse", "유효하지 않은 기저 속성 구조입니다.", 2.0)
		seen.append(element)
	if step_count == 1:
		return _outcome("incomplete", "none", "Incomplete: 아직 관찰할 반응이 없습니다.", 0.0)
	if state["stability"] < 30.0:
		return _outcome("failed", "collapse", "구조가 붕괴했습니다.", 2.0)
	if state["base_attributes"].is_empty():
		# A basic neutral jet needs material, control and direction. Compression and
		# shaped shells remain useful for more complex structures, not prerequisites.
		if state["mana_amount"] >= 10.0 and state["stability"] >= 55.0 and state["flow_vector"] == [1.0, 0.0]:
			if state.get("neutral_legacy", false): return _outcome("ready", "neutral_motion", "중립 동력 구조가 유지됩니다.", 18.0 + state["energy_loss"])
			return _outcome("ready", "mana_bolt", "Mana Bolt ready. LMB to release.", 15.0 + state["energy_loss"])
	else:
		if state["base_attributes"].size() == 2:
			var attributes: Array = state["base_attributes"]
			if not Fusion.authorized(attributes, context.get("main_attribute"), context.get("auxiliary_attributes", [])): return _outcome("failed", "forbidden_binding", "주속성을 포함한 결속 연구 자격이 필요합니다.", 2.0)
			if state["binding_quality"] >= 60.0 and state["stability"] >= 55.0:
				return _outcome("ready", "fusion_" + Fusion.PHENOMENA.get(Fusion.pair(attributes), "unknown"), "서로 다른 두 흐름이 하나의 윤곽 안에 머뭅니다.", 8.0 + state["energy_loss"])
			return _outcome("partial", "partial_binding", "두 흐름이 만나지만 이음새가 크게 흔들립니다.", 2.0)
		if state["base_attributes"].size() != 1: return _outcome("incomplete", "none", "유지할 수 없는 결속 구조입니다.", 2.0)
		var element: String = state["base_attributes"][0]
		var requirements := Rules.requirements(element, context)
		var resonance: float = state["resonance"].get(element, 0.0)
		if resonance >= requirements["resonance"]:
			if state["stability"] >= requirements["stability"] and state["mana_amount"] >= 10.0 and state["cohesion"] >= 25.0:
				return _outcome("ready", element.to_lower() + "_resonance", Rules.Elements.DEFINITIONS[element].stable_observation, 5.0 + state["energy_loss"])
			return _outcome("unstable", "unstable", "반응은 나타났지만 떨림이 큽니다. 더 안정화해 보세요.", 2.0)
		if resonance > 0.0: return _outcome("partial", "partial", "일부 반응이 이어집니다. 안정화 후 공명을 더 탐색해 보세요.", 2.0)
		if state["resonance_attempts"] > 0: return _outcome("weak", "weak", "속성 반응은 아직 확인되지 않습니다. 밝기와 응집을 비교해 보세요.", 2.0)
	return _outcome("incomplete", "none", "Incomplete: 아직 유지할 수 있는 현상이 아닙니다.", 2.0)

static func _outcome(state: String, kind: String, message: String, cost: float) -> Dictionary:
	return {"state": state, "kind": kind, "message": message, "mana_cost": cost}

static func observe(state: Dictionary, step_count: int, context: Dictionary = {}) -> String:
	# Only sensory evidence. No element IDs, action names, affinity or raw numbers.
	if state["phase"] == "FAILED" or state["stability"] < 30.0: return "윤곽이 무너지고 잔광이 꺼집니다."
	if step_count <= 1: return "뚜렷한 변화가 관찰되지 않습니다."
	if state["mana_amount"] <= 0.0: return "떠 있는 마나 덩어리는 보이지 않습니다."
	if state.get("binding_quality", 0.0) > 0:
		return "서로 다른 잔광이 교차하며 격자처럼 이어집니다." if state["stability"] >= 55.0 else "서로 다른 잔광의 이음새가 벌어지고 흩어집니다."
	if state.get("binding_window", false): return "빛의 윤곽이 잠시 열리고 다른 흐름을 받아들일 여지가 보입니다."
	var parts := PackedStringArray()
	parts.append("옅은 잔광" if state["mana_amount"] < 10.0 else "밝아진 잔광")
	if state["cohesion"] >= 25.0: parts.append("좁아진 빛의 덩어리")
	if state["form_integrity"] >= 50.0: parts.append("이어진 윤곽")
	if state.get("spread",0)>=0.4:parts.append("넓게 펼쳐진 파문")
	if state.get("persistence",0)>=0.5:parts.append("오래 이어지는 잔상")
	if state["flow_vector"] == [1.0, 0.0]: parts.append("한 방향으로 빠르게 뻗는 궤적" if state.get("flow_strength",0)>=0.9 else "한 방향으로 흐르는 궤적")
	for element in state["base_attributes"]:
		if state["resonance_attempts"] == 0: continue
		var definition = Rules.Elements.DEFINITIONS[element]
		var requirements := Rules.requirements(element, context)
		var resonance: float = state["resonance"].get(element, 0.0)
		if resonance >= requirements["resonance"] and state["stability"] >= requirements["stability"]: parts.append(definition.stable_observation)
		elif resonance > 0.0: parts.append(definition.partial_observation)
		else: parts.append("속성 반응은 아직 확인되지 않습니다.")
	parts.append("잔잔한 떨림" if state["stability"] >= 55.0 else "불규칙한 떨림")
	return " · ".join(parts)
