extends RefCounted
## Sensory projection only. Element evidence requires actual simulated resonance.
## Old snapshots are projected as stored; this never calls ManaSimulator.
const VERSION := 3
const Rules = preload("res://scripts/resonance_rules.gd")
const COLORS := {"WOOD": Color("8cd77b"), "FIRE": Color("ff8955"), "EARTH": Color("c5a67a"), "METAL": Color("e2e9f1"), "WATER": Color("5dbdff"), "VOID": Color("c6a0f4")}

static func collapse_threshold(state:Dictionary)->float:
	return float(state.get("collapse_threshold",25)) if state.get("grammar_version",0)>=8 else 30.0
static func stable_threshold(state:Dictionary,legacy:float)->float:
	return float(state.get("unstable_threshold",40)) if state.get("grammar_version",0)>=8 else legacy

static func evidence(state: Dictionary, context: Dictionary = {}) -> Dictionary:
	var hidden := {"element": "", "strength": 0.0, "stage": "none"}
	var attributes = state.get("base_attributes", [])
	var resonance = state.get("resonance", {})
	if attributes is Array and attributes.size() == 2 and number(state, "mana_amount", 0, 0, 60) >= 10 and number(state, "binding_quality", 0, 0, 100) > 0:
		var key := preload("res://scripts/fusion_rules.gd").pair(attributes)
		var collapsed: bool = state.get("phase") == "FAILED" or number(state, "stability", 60, 0, 100) < collapse_threshold(state)
		return {"element": "BINDING", "elements": attributes.duplicate(), "lineage": key, "strength": number(state, "binding_quality", 0, 0, 100) / 100.0,
			"stage": "collapsed" if collapsed else ("stable" if number(state, "stability", 60, 0, 100) >= stable_threshold(state,55) else "unstable")}
	if not attributes is Array or attributes.size() != 1 or not COLORS.has(attributes[0]) or not resonance is Dictionary: return hidden
	var element: String = attributes[0]
	var value := number(resonance, element, 0, 0, 100)
	# A declaration, material alone or a failed resonance attempt is not evidence.
	if number(state, "mana_amount", 0, 0, 60) < 1:return hidden
	if value<=0 and number(state,"cohesion",0,0,100)<1 and number(state,"form_integrity",0,0,100)<1 and number(state,"flow_strength",0,0,2)<.05:return hidden
	# A trace may grow from structure/flow without a compressed resonance ritual.
	# This makes Wood/Earth combat structures observable; a lone declaration
	# still has no material and cannot disclose an element.
	var structural:float=clampf((number(state,"mana_amount",0,0,60)/30.0+number(state,"form_integrity",0,0,100)/100.0+number(state,"flow_strength",0,0,1)+number(state,"cohesion",0,0,100)/100.0)/3.0,0,1)
	value=maxf(value,structural*60)
	var saved_context = state.get("research_context", context)
	if not saved_context is Dictionary: saved_context = context
	var conditions:Dictionary={"resonance":60,"stability":stable_threshold(state,40)} if state.get("grammar_version",0)>=8 else Rules.requirements(element, saved_context)
	var strength := clampf(value / conditions["resonance"], 0, 1)
	var stable: bool = number(state, "stability", 60, 0, 100) >= conditions["stability"]
	var stage := "faint" if strength < 0.5 else "growing"
	if strength >= 1: stage = "stable" if stable else "unstable"
	if state.get("phase") == "FAILED" or number(state, "stability", 60, 0, 100) < collapse_threshold(state): stage = "collapsed"
	return {"element": element, "strength": strength, "stage": stage}

static func observation_hint(state: Dictionary, context: Dictionary = {}) -> String:
	var trace := evidence(state, context)
	match trace["stage"]:
		"faint": return "관측 렌즈: 옅은 흔적이 나타납니다. 직전 단계와 비교해 보세요."
		"growing": return "관측 렌즈: 반응의 윤곽이 점점 뚜렷해집니다."
		"stable": return "관측 렌즈: 반응이 일정하게 유지됩니다. 다른 실험에서도 재현해 보세요."
		"unstable": return "관측 렌즈: 반응은 있지만 떨림이 큽니다. 안정된 재현은 아닙니다."
		"collapsed": return "관측 렌즈: 윤곽이 무너지고 흔적이 흩어집니다."
	return "관측 렌즈: 아직 구별할 수 있는 속성 흔적이 없습니다."

static func number(data: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value = data.get(key, fallback)
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), low, high)

static func project(state: Dictionary, context: Dictionary = {}) -> Dictionary:
	var amount := number(state, "mana_amount", 0.0, 0.0, 60.0)
	var presence := minf(amount / 10.0, 1.0)
	var cohesion := number(state, "cohesion", 0.0, 0.0, 100.0) / 100.0
	var stability := number(state, "stability", 60.0, 0.0, 100.0) / 100.0
	var form := number(state, "form_integrity", 0.0, 0.0, 100.0) / 100.0
	var strength := 0.0
	var resonance = state.get("resonance", {})
	if resonance is Dictionary:
		for value in resonance.values():
			if (value is int or value is float) and is_finite(float(value)):
				strength = maxf(strength, clampf(float(value) / 100.0, 0.0, 1.0))
	var flow := Vector2.ZERO
	var vector = state.get("flow_vector", [])
	if vector is Array and vector.size() == 2:
		var components := {"x": vector[0], "y": vector[1]}
		flow = Vector2(number(components, "x", 0, -1, 1), number(components, "y", 0, -1, 1)).limit_length(1.0)
	var failed: bool = state.get("phase", "") == "FAILED" or stability < collapse_threshold(state)/100.0
	# With no material, invisible preparation must not conjure a bright object.
	if amount <= 0.0:
		return {"version": VERSION, "presence": 0.0, "radius": 0.0, "density": 0.0,
			"binding_window": state.get("binding_window", false),
			"brightness": 0.0, "jitter": 0.0, "form": 0.0, "flow": Vector2.ZERO,
			"orbit": 0.0, "dispersion": 0.0,"spread":0.0,"persistence":0.0,"anchoring":0.0, "lobes": 1, "binding": 0.0, "collapsed": failed, "reaction": evidence(state, context)}
	var jitter := pow(1.0 - stability, 1.5) * presence
	# Fragmentation/rotation/binding are visible properties of existing structure,
	# not new chant operations or a change to mana physics.
	var lobes := 1
	if stability < 0.55 and form < 0.5: lobes = 2 if stability >= 0.4 else 3
	return {"version": VERSION, "presence": presence,
		"binding_window": state.get("binding_window", false),
		"radius": (0.30 + 0.65 * sqrt(amount / 60.0)) * (1.0 - cohesion * 0.58),
		"density": cohesion, "brightness": clampf(0.25 + amount / 90.0 + cohesion * 0.25, 0.0, 1.0),
		"jitter": jitter, "form": form, "flow": flow * presence * number(state,"flow_strength",1,0,1),
		"orbit": maxf(strength,number(state,"coupling",0,0,3)*0.2+number(state,"cycles",0,0,8)*0.1) * presence,
		"dispersion": clampf((1.0 - cohesion) * (1.0 - form * 0.65) + number(state, "energy_loss", 0, 0, 100) * 0.035+number(state,"spread",0,0,2)*0.3, 0.0, 1.0),
		"spread":number(state,"spread",0,0,2),"persistence":number(state,"persistence",0,0,2),"anchoring":number(state,"anchoring",0,0,1),
		"lobes": maxi(lobes,int(number(state,"branches",1,1,8))), "binding": form * (0.35 + cohesion * 0.65), "collapsed": failed, "reaction": evidence(state, context)}

static func transition(before: Dictionary, after: Dictionary, context: Dictionary = {}) -> Dictionary:
	var left := project(before, context)
	var right := project(after, context)
	var parts := PackedStringArray()
	if right["collapsed"] and not left["collapsed"]:
		parts.append("윤곽이 깨지고 빛이 흩어집니다.")
	elif left != right:
		if right["binding_window"] and not left["binding_window"]: parts.append("빛의 윤곽에 다른 흐름을 받아들일 틈이 열립니다.")
		if right["presence"] < left["presence"] or right["radius"] < left["radius"] - 0.025:
			parts.append("빛의 덩어리가 작아집니다.")
		elif right["radius"] > left["radius"] + 0.025: parts.append("빛의 덩어리가 커집니다.")
		if right["density"] > left["density"] + 0.05: parts.append("입자가 더 촘촘히 모입니다.")
		if right["brightness"] > left["brightness"] + 0.025: parts.append("잔광이 밝아집니다.")
		elif right["brightness"] < left["brightness"] - 0.025: parts.append("잔광이 옅어집니다.")
		if right["jitter"] < left["jitter"] - 0.015: parts.append("떨림이 가라앉습니다.")
		elif right["jitter"] > left["jitter"] + 0.015: parts.append("떨림이 거칠어집니다.")
		if right["lobes"] > left["lobes"]: parts.append("덩어리가 여러 갈래로 갈라집니다.")
		if right["flow"] != left["flow"]: parts.append("입자 흐름의 방향이나 세기가 달라집니다.")
		if right["binding"] > left["binding"] + 0.05: parts.append("입자를 잇는 윤곽이 이어집니다.")
		if right["orbit"] > left["orbit"] + 0.05: parts.append("둘레의 파문과 회전이 뚜렷해집니다.")
		if right["spread"]>left["spread"]+0.05:parts.append("윤곽이 부채처럼 넓어집니다.")
		if right["persistence"]>left["persistence"]+0.05:parts.append("윤곽의 잔상이 오래 이어집니다.")
		if right["anchoring"]>left["anchoring"]+0.05:parts.append("흐름이 한 지점에 묶여 머무릅니다.")
		if right["reaction"] != left["reaction"] and right["reaction"]["stage"] != "none": parts.append("빛과 입자의 고유한 흔적이 달라집니다.")
	if not parts.is_empty(): return {"visibility": "visible", "text": " ".join(parts)}
	# Separate actual lack of change from changes hidden by sensory resolution.
	if before != after: return {"visibility": "subtle", "text": "흔적이 미세해 지금은 뚜렷한 차이를 구별하기 어렵습니다."}
	return {"visibility": "none", "text": "앞뒤의 관측 가능한 모습이 같습니다."}

static func failure_label(result: Dictionary) -> String:
	var index := int(number(result, "failure_step", 0, 0, 32))
	if index == 0: return "실패 단계 없음"
	match result.get("failure_kind", "legacy"):
		"input_error": return "입력 오류: %d번째 입력" % index
		"collapse": return "붕괴 시작: %d번째 입력" % index
		"unfinished": return "미완성 판정: %d번째 입력 뒤" % index
		_: return "당시 판정 위치: %d번째 입력 뒤" % index
