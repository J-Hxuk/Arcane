extends RefCounted
## Sensory projection only. No keys, RNG, affinity, element colors or spell execution.
## Old snapshots are projected as stored; this never calls ManaSimulator.
const VERSION := 1

static func number(data: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value = data.get(key, fallback)
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), low, high)

static func project(state: Dictionary) -> Dictionary:
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
	var failed: bool = state.get("phase", "") == "FAILED" or stability < 0.3
	# With no material, invisible preparation must not conjure a bright object.
	if amount <= 0.0:
		return {"version": VERSION, "presence": 0.0, "radius": 0.0, "density": 0.0,
			"brightness": 0.0, "jitter": 0.0, "form": 0.0, "flow": Vector2.ZERO,
			"orbit": 0.0, "dispersion": 0.0, "lobes": 1, "binding": 0.0, "collapsed": failed}
	var jitter := pow(1.0 - stability, 1.5) * presence
	# Fragmentation/rotation/binding are visible properties of existing structure,
	# not new chant operations or a change to mana physics.
	var lobes := 1
	if stability < 0.55 and form < 0.5: lobes = 2 if stability >= 0.4 else 3
	return {"version": VERSION, "presence": presence,
		"radius": (0.30 + 0.65 * sqrt(amount / 60.0)) * (1.0 - cohesion * 0.58),
		"density": cohesion, "brightness": clampf(0.25 + amount / 90.0 + cohesion * 0.25, 0.0, 1.0),
		"jitter": jitter, "form": form, "flow": flow * presence,
		"orbit": strength * presence, "dispersion": clampf((1.0 - cohesion) * (1.0 - form * 0.65) + number(state, "energy_loss", 0, 0, 100) * 0.035, 0.0, 1.0),
		"lobes": lobes, "binding": form * (0.35 + cohesion * 0.65), "collapsed": failed}

static func transition(before: Dictionary, after: Dictionary) -> Dictionary:
	var left := project(before)
	var right := project(after)
	var parts := PackedStringArray()
	if right["collapsed"] and not left["collapsed"]:
		parts.append("윤곽이 깨지고 빛이 흩어집니다.")
	elif left != right:
		if right["presence"] < left["presence"] or right["radius"] < left["radius"] - 0.025:
			parts.append("빛의 덩어리가 작아집니다.")
		elif right["radius"] > left["radius"] + 0.025: parts.append("빛의 덩어리가 커집니다.")
		if right["density"] > left["density"] + 0.05: parts.append("입자가 더 촘촘히 모입니다.")
		if right["brightness"] > left["brightness"] + 0.025: parts.append("잔광이 밝아집니다.")
		elif right["brightness"] < left["brightness"] - 0.025: parts.append("잔광이 옅어집니다.")
		if right["jitter"] < left["jitter"] - 0.015: parts.append("떨림이 가라앉습니다.")
		elif right["jitter"] > left["jitter"] + 0.015: parts.append("떨림이 거칠어집니다.")
		if right["lobes"] > left["lobes"]: parts.append("덩어리가 여러 갈래로 갈라집니다.")
		if right["flow"] != left["flow"]: parts.append("입자의 흐르는 방향이 달라집니다.")
		if right["binding"] > left["binding"] + 0.05: parts.append("입자를 잇는 윤곽이 이어집니다.")
		if right["orbit"] > left["orbit"] + 0.05: parts.append("둘레의 파문과 회전이 뚜렷해집니다.")
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
