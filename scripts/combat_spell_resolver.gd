extends RefCounted
## Converts an already interpreted final mana state, never raw keys, into combat data.
const Definition = preload("res://scripts/spell_definition.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const FIRE_STUDIES := [preload("res://data/spells/fire_lance.tres"), preload("res://data/spells/fire_blast.tres")]
const DEFINITIONS := {
	"WOOD": preload("res://data/spells/wood_bind.tres"),
	"FIRE": preload("res://data/spells/fire_ember.tres"),
	"EARTH": preload("res://data/spells/earth_barrier.tres"),
	"METAL": preload("res://data/spells/metal_lance.tres"),
	"WATER": preload("res://data/spells/water_push.tres"),
	"VOID": preload("res://data/spells/void_wave.tres"),
}

static func resolve(simulation: Dictionary, main_attribute: Variant) -> Dictionary:
	var result := simulation.duplicate(true)
	if simulation.get("state") in ["failed", "empty"] or simulation["final_state"].get("phase") == "FAILED": return result
	var final: Dictionary = simulation["final_state"]
	if final.get("mana_amount", 0.0) <= 0.0: return result
	var attributes: Array = final.get("base_attributes", [])
	if attributes.size() != 1 or not DEFINITIONS.has(attributes[0]):
		result.merge({"state": "incomplete", "message": "단일 속성의 안정 공명이 필요합니다."}, true)
		return result
	var definition: Definition = DEFINITIONS[attributes[0]]
	var error := definition.validate_requirements()
	if not error.is_empty():
		result.merge({"state": "invalid_data", "message": error}, true)
		return result
	if not matches(definition, final, simulation.get("simulation_context", {})):
		result.merge({"state": "incomplete", "message": "마나를 모아 형상과 방향을 유지하세요. 공명 재현과 전투 발현은 별개입니다."}, true)
		return result
	if main_attribute == null or attributes[0] != main_attribute:
		result.merge({"state": "locked", "message": "개화한 주속성의 전투마법만 방출할 수 있습니다. 연구실에서 공명을 탐구하세요."}, true)
		return result
	# Basic combat uses the element already awakened by a full resonance ritual.
	# It does not count as stable research evidence without the original resonance.
	if attributes[0] == "FIRE":
		for study in FIRE_STUDIES:
			if study.validate_requirements().is_empty() and matches(study, final, simulation.get("simulation_context", {})):
				definition = study
				break
	result.merge({"state": "ready", "spell": definition, "mana_cost": definition.mana_cost + final["energy_loss"],
		"kind": str(definition.spell_id).to_lower(), "message": definition.display_name + " 준비 완료. LMB로 방출."}, true)
	return result

static func matches(definition: Definition, final: Dictionary, context: Dictionary) -> bool:
	var stability := definition.min_stability
	var resonance := definition.min_resonance
	if definition.research_tier > 1:
		var requirements := Rules.requirements(str(definition.attribute), context)
		stability = maxf(stability, requirements["stability"])
		resonance = maxf(resonance, requirements["resonance"])
	return final["mana_amount"] >= definition.min_mana and final["cohesion"] >= definition.min_cohesion and final["cohesion"] <= definition.max_cohesion and final["stability"] >= stability and final["form_integrity"] >= definition.min_form and final["flow_vector"] == [1.0, 0.0] and float(final["resonance"].get(str(definition.attribute), 0.0)) >= resonance
