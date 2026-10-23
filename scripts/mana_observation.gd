extends RefCounted
## Read-only telemetry. Never resolves an identity, tunes a spell, pays mana or
## changes a simulator snapshot. Historical frames are never recalculated.
const VERSION = 1
const Variation = preload("res://scripts/mana_variation.gd")
const Identity = preload("res://scripts/chant_identity.gd")
const Config = preload("res://scripts/chant_config.gd")
const FIELDS = ["mana_amount", "cohesion", "form_integrity", "flow_strength", "stability", "persistence", "spread", "energy_loss"]
const LABELS = {"mana_amount":"마나량", "cohesion":"응집", "form_integrity":"형상", "flow_strength":"흐름", "stability":"안정성", "persistence":"유지", "spread":"확산", "energy_loss":"손실"}
const OPERATORS = {"ACCUMULATE":"축적", "COMPRESS":"압축", "STABILIZE":"안정", "RESONATE":"공명", "SHAPE":"형상", "DIRECT":"지향", "BIND":"결속", "EXPAND":"확산", "SPLIT":"분열", "CYCLE":"순환", "ANCHOR":"정착", "DISSIPATE":"소산"}

static func numbers(source: Variant, fields: Array = FIELDS) -> Dictionary:
	var values: Dictionary = {}
	if not source is Dictionary: return values
	for field in fields:
		var value = source.get(field)
		if (value is int or value is float) and is_finite(float(value)): values[field] = value
	return values

static func difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for field in after:
		if before.has(field): delta[field] = float(after[field])-float(before[field])
	return delta

static func _frame(step: Dictionary, index: int, prefix: Array, context: Dictionary) -> Dictionary:
	var before: Dictionary = numbers(step.get("before", {}))
	var after: Dictionary = numbers(step.get("after", {}))
	var snapshot: Dictionary = step.get("after", {})
	var raw: Dictionary = numbers(snapshot.get("variation_vector", {}))
	var base: Dictionary = numbers(snapshot.get("variation_vector", {}).get("reference", {}) if snapshot.get("variation_vector", {}) is Dictionary else {})
	var counts: Dictionary = {}
	for action in prefix:
		if action in OPERATORS: counts[action] = int(counts.get(action, 0))+1
	var element = snapshot.get("base_attributes", [])
	return {"version":VERSION, "index":index+1, "key":str(step.get("input", {}).get("key", "?")),
		"operator":str(prefix.back()) if not prefix.is_empty() else "", "sequence":prefix.duplicate(), "multiset":counts,
		"context":{"attributes":element.duplicate() if element is Array else [], "school_id":context.get("magic_school_id"), "nature":null},
		"before":before, "after":after, "delta":difference(before,after), "raw":raw, "B":base,
		"raw_delta":difference(numbers(step.get("before", {}).get("variation_vector", {})),raw),
		"O":{}, "T":{}, "adjustment":{}, "projection":{}, "projection_delta":{},
		"phase":str(snapshot.get("phase", "")), "thresholds":numbers(snapshot,["collapse_threshold","unstable_threshold"]),
		"terms_available":false, "term_source":"snapshot_only", "note":"O/T 당시 분해값 미기록"}

static func capture(simulation: Dictionary, config: Dictionary = Config.DATA) -> Array:
	var frames: Array = []
	# Phase 1 has no coefficients for the new20 schools. Do not invent readings.
	var context: Dictionary = simulation.get("simulation_context", {})
	if context.has("magic_school_id") or simulation.get("kind")=="unsupported_school": return frames
	var steps: Array = simulation.get("casting_steps", [])
	var actions: Array = simulation.get("actions", [])
	for index in steps.size():
		var step: Dictionary = steps[index]
		var prefix: Array = actions.slice(0,index+1) if actions.size()>index else []
		var frame := _frame(step,index,prefix,context)
		frame["rules_version"] = simulation.get("rules_version")
		frame["property_version"] = simulation.get("property_version", "")
		if not prefix.is_empty() and not frame.raw.is_empty() and _config_matches(simulation,config):
			var terms := _terms(prefix,frame,config)
			if not terms.is_empty():
				frame.merge(terms,true)
				frame["terms_available"] = true
				frame["term_source"] = "stored_raw_and_config_decomposition"
				frame["config_fingerprint"] = config.hash()
				frame["initial_stability"] = config.thresholds.initial_stability
				frame["note"] = "B/raw는 엔진 스냅샷, O/T는 당시 설정으로 분해·검산한 진단값"
				var after: Dictionary = step.after
				var before: Dictionary = step.before
				if frame.before.size()==FIELDS.size() and frame.after.size()==FIELDS.size():
					frame.projection = Variation.projection(after,config)
					frame.projection_delta = difference(Variation.projection(before,config),frame.projection)
		frames.append(frame)
	return frames

static func _config_matches(simulation: Dictionary, config: Dictionary) -> bool:
	return simulation.get("rules_version")==config.get("rules_version") and simulation.get("property_version")==config.get("property_version") and config.has("operations") and config.has("elements") and config.has("transitions") and config.has("tuning")

static func _terms(actions: Array, frame: Dictionary, config: Dictionary) -> Dictionary:
	var elements: Array = []
	for element in frame.context.attributes:
		if not element is String: return {}
		for part in element.split("+"): elements.append(part)
	if elements.size()>2: return {}
	var coefficients: Dictionary = {}
	for element in elements:
		if not config.elements.has(element): return {}
	if elements.size()==1: coefficients=config.elements[elements[0]]
	elif elements.size()==2:
		for field in FIELDS+["compression_risk","interaction"]:
			var fallback := 0.0 if field=="compression_risk" else 1.0
			coefficients[field]=(float(config.elements[elements[0]].get(field,fallback))+float(config.elements[elements[1]].get(field,fallback)))*.5
	var weights := 0.0
	for i in actions.size(): weights+=pow(float(config.r),i)
	var order: Dictionary = {}; var transition: Dictionary = {}
	for field in frame.raw: order[field]=0.0; transition[field]=0.0
	for i in actions.size():
		if actions[i] not in config.operations: return {}
		var vector: Dictionary = config.operations[actions[i]]
		for field in order:
			var value := float(vector.get(field,0))*float(coefficients.get(field,1.0))
			order[field]+=float(config.kappa)*(pow(float(config.r),i)/weights-1.0/actions.size())*value
		if i>0:
			var adjacent: Dictionary = config.transitions.get(str(actions[i-1])+">"+str(actions[i]),{})
			for field in transition: transition[field]+=float(config.lambda)*float(coefficients.get("interaction",1))*float(adjacent.get(field,0))
	var adjustment := {"stability":-float(coefficients.get("compression_risk",0))*actions.count("COMPRESS")*actions.count("COMPRESS")*float(config.thresholds.compression_penalty_scale)}
	# No best-guess terms: suppress decomposition if it disagrees with raw.
	for field in frame.raw:
		if not frame.B.has(field): return {}
		var reconstructed := float(frame.B[field])+float(order[field])+float(transition[field])+float(adjustment.get(field,0))
		if absf(reconstructed-float(frame.raw[field]))>0.00001: return {}
	return {"O":order, "T":transition, "adjustment":adjustment}

static func from_record(record: Dictionary, index: int) -> Dictionary:
	var steps: Array = record.get("steps", [])
	if index<0 or index>=steps.size(): return {}
	var step: Dictionary = steps[index]
	var stored = step.get("mana_observation")
	if valid_frame(stored):
		return stored.duplicate(true)
	# Old snapshots remain opaque: never use today's keys or coefficients.
	return _frame(step,index,[],record.get("simulation_context",{}))

static func valid_frame(value: Variant) -> bool:
	if not value is Dictionary: return false
	var version = value.get("version"); var index = value.get("index")
	if not (version is int or version is float) or version!=VERSION: return false
	if not (index is int or index is float) or not is_finite(float(index)) or index<1 or index!=int(index): return false
	if not value.get("key") is String or not value.get("operator") is String or not value.get("sequence") is Array or not value.get("context") is Dictionary or not value.get("multiset") is Dictionary: return false
	for map in ["before","after","delta","raw_delta","B","O","T","raw","projection","adjustment","thresholds"]:
		if not value.get(map) is Dictionary: return false
		for number in value[map].values():
			if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

static func band(frame: Dictionary) -> String:
	var value = frame.get("after",{}).get("stability")
	var thresholds: Dictionary = frame.get("thresholds",{})
	if value==null or not thresholds.has("collapse_threshold") or not thresholds.has("unstable_threshold"): return "안정 구간 미기록"
	if value<float(thresholds.collapse_threshold): return "붕괴 구간"
	if value<float(thresholds.unstable_threshold): return "불안정 구간"
	return "정상 안정 구간 · 발현 성공 판정과 별개"

static func describe(frame: Dictionary) -> String:
	var changes := PackedStringArray()
	for field in FIELDS:
		var value: float = frame.get("delta",{}).get(field,0.0)
		if absf(value)>0.00000001: changes.append(LABELS[field]+("↑" if value>0 else "↓"))
		else:
			var raw_value: float=frame.get("raw_delta",{}).get(field,0.0)
			if absf(raw_value)>0.00000001: changes.append(LABELS[field]+" raw"+("↑" if raw_value>0 else "↓"))
	return "이번 입력 변화: "+(" · ".join(changes) if not changes.is_empty() else "제공된 수치 변화 없음")

static func compact(frame: Dictionary) -> String:
	if frame.is_empty(): return "관측 수치 미기록"
	var lines := PackedStringArray(["당시 수치 · "+band(frame)])
	for field in FIELDS:
		if not frame.after.has(field): continue
		lines.append("%s %.3f → %.3f (Δ%+.3f)" % [LABELS[field],frame.before.get(field,frame.after[field]),frame.after[field],frame.delta.get(field,0)])
	return "\n".join(lines)
