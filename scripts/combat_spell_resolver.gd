extends RefCounted
## Converts an already interpreted final mana state, never raw keys, into combat data.
const Definition = preload("res://scripts/spell_definition.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const M1 = preload("res://scripts/m1_spell_catalog.gd")
const FUSION_SPELLS := [preload("res://data/spells/ice_crystal_barrier.tres"), preload("res://data/spells/ice_crystal_needle.tres"), preload("res://data/spells/wind_pressure_bolt.tres")]
const FIRE_STUDIES := [preload("res://data/spells/fire_lance.tres"), preload("res://data/spells/fire_blast.tres")]
const DEFINITIONS := {
	"WOOD": preload("res://data/spells/wood_bind.tres"),
	"FIRE": preload("res://data/spells/fire_ember.tres"),
	"EARTH": preload("res://data/spells/earth_barrier.tres"),
	"METAL": preload("res://data/spells/metal_lance.tres"),
	"WATER": preload("res://data/spells/water_push.tres"),
	"VOID": preload("res://data/spells/void_wave.tres"),
}

static func resolve(simulation: Dictionary, main_attribute: Variant, access: Dictionary = {}) -> Dictionary:
	var result := simulation.duplicate(true)
	if simulation.get("state") in ["failed", "empty"] or simulation["final_state"].get("phase") == "FAILED": return result
	var final: Dictionary = simulation["final_state"]
	if final.get("mana_amount", 0.0) <= 0.0: return result
	var attributes: Array = final.get("base_attributes", [])
	if attributes.size() > 1:
		var context: Dictionary = simulation.get("simulation_context", {}).duplicate(true)
		context.merge(access, true)
		var fusion_rules = preload("res://scripts/fusion_rules.gd")
		context["main_attribute"]=main_attribute
		var allowed: bool = fusion_rules.cast_allowed(attributes,context)
		result.merge({"state": "incomplete" if allowed else "locked", "message": "복합 현상입니다. 전투 형상과 흐름을 더 연구하세요." if allowed else "주속성을 포함한 확정 오행 결속만 허용합니다."}, true)
		if allowed:
			for fusion in FUSION_SPELLS:
				if fusion.validate_requirements().is_empty() and matches(fusion, final, context):
					result.merge({"state": "ready", "spell": fusion, "mana_cost": fusion.mana_cost + final.get("energy_loss", 0.0), "kind": str(fusion.spell_id).to_lower(), "message": fusion.display_name + " 준비 완료."}, true)
					break
		return result
	if final.get("neutral_legacy", false):
		var neutral: Definition = DEFINITIONS["VOID"]
		if not matches(neutral, final, simulation.get("simulation_context", {})): return result
		var unlocked: bool = access.get("neutral_wave_unlocked", simulation.get("simulation_context", {}).get("neutral_wave_unlocked", false)) or main_attribute == "VOID"
		result.merge({"state": "ready" if unlocked else "locked", "message": "중립 충격파" if unlocked else "중립 동력술식의 연구 권한이 필요합니다."}, true)
		if unlocked: result.merge({"spell": neutral, "kind": "void_wave", "mana_cost": neutral.mana_cost + final["energy_loss"]}, true)
		return result
	if attributes.size() != 1 or not DEFINITIONS.has(attributes[0]):
		result.merge({"state": "incomplete", "message": "단일 속성의 안정 공명이 필요합니다."}, true)
		return result
	if attributes[0]!=main_attribute:
		result.merge({"state":"locked","message":"단일마법은 주속성만 발현할 수 있습니다. 보조속성은 공명·결속 연구와 주속성 융합에 사용하세요."},true)
		return result
	# Existing intermediate fire studies retain their own valid state ranges.
	# M1 overload limits must not silently remove an already discovered study.
	var definition: Definition
	if attributes[0] == "FIRE":
		for study in FIRE_STUDIES:
			if study.validate_requirements().is_empty() and matches(study, final, simulation.get("simulation_context", {})):
				definition = study; break
	if definition == null: definition = M1.select(final, attributes[0])
	if definition == null:
		result.merge({"state": "incomplete", "message": "현재 형상을 유지하기에는 마나가 지나치게 많거나 압축·손실이 큽니다. 관측 렌즈로 마지막 변화를 비교하세요."}, true)
		return result
	var error := definition.validate_requirements()
	if not error.is_empty():
		result.merge({"state": "invalid_data", "message": error}, true)
		return result
	if definition.catalog_id.is_empty() and not matches(definition, final, simulation.get("simulation_context", {})):
		result.merge({"state": "incomplete", "message": "마나를 모아 형상과 방향을 유지하세요. 공명 재현과 전투 발현은 별개입니다."}, true)
		return result
	# Basic combat uses the element already awakened by a full resonance ritual.
	# It does not count as stable research evidence without the original resonance.
	if not definition.catalog_id.is_empty(): definition = M1.tuned(definition, final)
	var permissions: Dictionary = simulation.get("simulation_context", {}).duplicate(true)
	permissions.merge(access, true)
	if attributes[0] != main_attribute:
		result.merge({"state": "locked", "message": "단일마법은 주속성만 발현할 수 있습니다. 보조속성은 주속성과의 결속 연구·융합에 사용하세요."}, true)
		return result
	result.merge({"state": "ready", "spell": definition, "mana_cost": definition.mana_cost + final["energy_loss"],
		"kind": str(definition.spell_id).to_lower(), "message": definition.display_name + " 준비 완료. LMB로 방출."}, true)
	return result

static func matches(definition: Definition, final: Dictionary, context: Dictionary) -> bool:
	if definition.requires_elements.size() > 1:
		var actual: Array = final.get("base_attributes", []).duplicate()
		actual.sort()
		var required: Array = Array(definition.requires_elements)
		required.sort()
		if actual != required or final.get("binding_quality", 0.0) < definition.min_binding_quality: return false
		for element in required:
			if float(final.get("resonance", {}).get(element, 0.0)) < 50.0: return false
		return final.get("mana_amount", 0.0) >= definition.min_mana and final.get("stability", 0.0) >= definition.min_stability and final.get("cohesion", 0.0) >= definition.min_cohesion and final.get("form_integrity", 0.0) >= definition.min_form and final.get("form_integrity", 0.0) <= definition.max_form and final.get("flow_vector") == [1.0, 0.0]
	var stability := definition.min_stability
	var resonance := definition.min_resonance
	if definition.research_tier > 1:
		var requirements := Rules.requirements(str(definition.attribute), context)
		stability = maxf(stability, requirements["stability"])
		resonance = maxf(resonance, requirements["resonance"])
	return final["mana_amount"] >= definition.min_mana and final["cohesion"] >= definition.min_cohesion and final["cohesion"] <= definition.max_cohesion and final["stability"] >= stability and final["form_integrity"] >= definition.min_form and final["flow_vector"] == [1.0, 0.0] and float(final["resonance"].get(str(definition.attribute), 0.0)) >= resonance
