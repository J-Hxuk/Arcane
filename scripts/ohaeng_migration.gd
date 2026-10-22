extends RefCounted
## Lossless role adapter. Historical snapshots and personal mappings are untouched.
const ELEMENTS := ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]
const NEUTRAL_ALIASES := ["VOID", "void", "none", "NONE", "無"]
static func research(source: Dictionary) -> Dictionary:
	var data := source.duplicate(true)
	if data.has("attribute_loadout_version"):return data
	var main = data.get("main_attribute")
	if not data.get("neutral_mana", {}) is Dictionary: return data
	if not data.get("auxiliary_attributes", []) is Array or not data.get("legacy_committed_attributes", data.get("researched_base_elements", [])) is Array: return data
	var auxiliary: Array = data.get("auxiliary_attributes", []).duplicate() if data.get("auxiliary_attributes", []) is Array else []
	var legacy: Array = data.get("legacy_committed_attributes", data.get("researched_base_elements", [])).duplicate() if data.get("legacy_committed_attributes", data.get("researched_base_elements", [])) is Array else []
	if auxiliary.size()>2 or not data.get("inactive_attribute_history",{}) is Dictionary:return data
	# Never hide a conflict between canonical roles and a historical derived list.
	if data.has("main_attribute") and data.has("researched_base_elements"):
		var declared = data["researched_base_elements"]
		var roles: Array = legacy + ([] if main == null else [main]) + auxiliary
		if not declared is Array or declared.size() != roles.size(): return data
		for role in roles:
			if role not in declared: return data
	var neutral_count := 0
	for role in ([main] + auxiliary + legacy):
		if role in NEUTRAL_ALIASES: neutral_count += 1
	if neutral_count > 1: return data # Corrupt duplicate commitments stay protected.
	if neutral_count == 1:
		var neutral: Dictionary = data.get("neutral_mana", {}).duplicate(true)
		if not neutral.has("original_roles"):
			neutral["original_roles"] = {"main_attribute": main, "auxiliary_attributes": auxiliary.duplicate(), "legacy_committed_attributes": legacy.duplicate(), "researched_base_elements": data.get("researched_base_elements", []).duplicate()}
		neutral["legacy_wave_unlocked"] = true
		neutral["transition_pending"] = neutral.get("transition_pending", false) or main in NEUTRAL_ALIASES
		for alias in NEUTRAL_ALIASES:
			auxiliary.erase(alias)
			legacy.erase(alias)
		if main in NEUTRAL_ALIASES:
			main = null
			for element in auxiliary:
				if element not in legacy: legacy.append(element)
			auxiliary.clear()
		data.merge({"main_attribute": main, "auxiliary_attributes": auxiliary, "legacy_committed_attributes": legacy, "neutral_mana": neutral}, true)
		if data.has("researched_base_elements"):
			var derived := legacy.duplicate()
			if main != null: derived.append(main)
			derived.append_array(auxiliary)
			data["researched_base_elements"] = derived
	# Keep historical permanent choices and their evidence verbatim, but only the
	# first auxiliary can participate in current simulation/permission checks.
	if auxiliary.size()>1:
		var history:Dictionary=data.get("inactive_attribute_history",{}).duplicate(true)
		if not history.has("original_roles"):
			history["original_roles"]={"main_attribute":main,"auxiliary_attributes":auxiliary.duplicate(),"legacy_committed_attributes":legacy.duplicate()}
		var active:Array=[auxiliary[0]]
		for field in ["binding_studies","fusion_observations"]:
			if not history.has(field):history[field]=data.get(field,[] if field=="binding_studies" else {}).duplicate(true)
		data["binding_studies"]=data.get("binding_studies",[]).filter(func(pair):return preload("res://scripts/fusion_rules.gd").authorized(Array(str(pair).split("+")),main,active))
		var observations:Dictionary={}
		for pair in data.get("fusion_observations",{}):
			if preload("res://scripts/fusion_rules.gd").authorized(Array(str(pair).split("+")),main,active):observations[pair]=data["fusion_observations"][pair].duplicate(true)
		data["fusion_observations"]=observations
		data["inactive_attribute_history"]=history
		data["auxiliary_attributes"]=active
		if data.has("researched_base_elements"):data.erase("researched_base_elements")
	return data
