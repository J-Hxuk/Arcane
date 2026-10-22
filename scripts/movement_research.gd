extends RefCounted
static var CONFIG:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/movement_abilities.json"))
static func ready(actions:Array,state:Dictionary)->bool:
	var actual:=actions.duplicate();actual.sort();var expected:Array=CONFIG.research.actions.duplicate();expected.sort()
	if actual!=expected or not state.get("base_attributes",[]).is_empty():return false
	for field in ["mana_amount","stability","flow_strength"]:
		var value=state.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or value<float(CONFIG.research[field]):return false
	return true
static func valid(value:Variant,allow_developer:=false)->bool:
	if not value is Dictionary or value.get("version",1)!=1 or not value.get("blink_unlocked",false) is bool:return false
	if not value.get("blink_unlocked",false):return true
	var proof=value.get("blink_proof",{})
	if not proof is Dictionary:return false
	if proof.get("source")=="developer":return allow_developer
	var id=proof.get("experiment_id")
	if proof.get("source")!="research" or proof.get("rules_version")!=8 or not (id is int or id is float) or not is_finite(float(id)) or id!=int(id) or id<1:return false
	return ready(CONFIG.research.actions,proof)
static func proof(state:Dictionary,id:int)->Dictionary:
	var record={"source":"research","rules_version":8,"experiment_id":id,"base_attributes":[]}
	for field in ["mana_amount","stability","flow_strength"]:record[field]=state[field]
	return record
