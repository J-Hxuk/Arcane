extends RefCounted
static var CONFIG:Dictionary=preload("res://scripts/chant_config.gd").DATA
const Identity=preload("res://scripts/chant_identity.gd")
const Variation=preload("res://scripts/mana_variation.gd")
const Catalog=preload("res://scripts/m1_spell_catalog.gd")
const Profile=preload("res://scripts/chant_profile.gd")
static func inputs(profile,actions:Array)->Array:
	var result:Array=[]
	for action in actions:
		for key in profile.mobile_keys():
			if profile.manipulation(key)==action:result.append({"key":key,"at_ms":result.size()*100,"hold_ms":0});break
	return result
static func resolve(profile,events:Array,context:Dictionary)->Dictionary:
	context=context.duplicate(true)
	if context.get("attribute_loadout_version",0)==1:
		context.main_attribute=context.get("active_main_attribute")
		context.auxiliary_attributes=[] if context.get("active_auxiliary_attribute")==null else [context.active_auxiliary_attribute]
	var config:Dictionary=preload("res://scripts/formal_spell_registry.gd").config() if context.get("formal_rules",false) else CONFIG
	if context.get("formal_rules",false) and context.get("formula_prototypes",false) and OS.is_debug_build():config=preload("res://scripts/mana_formula_prototypes.gd").config(config)
	var actions:Array=[];var bad:=0
	var advanced_locked:=false
	var previous_time:=-1
	for event in events:
		if not event is Dictionary:bad=actions.size()+1;actions.append("");continue
		var action:String=profile.manipulation(str(event.get("key","")))
		if action not in CONFIG.operations or not preload("res://scripts/mana_simulator.gd")._valid_time(event.get("at_ms",0)) or not preload("res://scripts/mana_simulator.gd")._valid_time(event.get("hold_ms",0)):bad=actions.size()+1
		if int(event.get("at_ms",0))<previous_time:bad=actions.size()+1
		previous_time=int(event.get("at_ms",0))
		actions.append(action)
		if not context.get("formal_rules",false) and action in Profile.ADVANCED_ACTIONS and (action not in context.get("advanced_operations",[]) or context.get("technique_rank",0)<4):advanced_locked=true
	var identity:=Identity.identify(actions,context,config)
	if context.get("research_only",false):identity={"state":"incomplete"}
	if context.get("attribute_loadout_version",0)==1 and not preload("res://scripts/attribute_loadout.gd").valid_context(context):identity={"state":"locked","reason":"활성 속성 장착과 영구 개화 상태가 일치하지 않습니다."}
	if advanced_locked:identity={"state":"locked","reason":"고위 조작 연구 및 기술 등급을 충족하지 못했습니다."}
	var row:Dictionary=identity.get("row",{})
	var element:String=row.get("element",str(context.get("main_attribute","") if context.get("main_attribute")!=null else ""))
	if context.get("developer_all",false) and row.is_empty():element=""
	if context.get("laboratory",false) and row.is_empty():element=str(context.get("observation_element",""))
	if row.has("elements"):
		var pair:Array=row.elements.duplicate();pair.sort();element="+".join(pair)
	if context.get("movement_research",false):row={};identity={"state":"incomplete"};element=""
	var steps:Array=[];var before:=Variation.state([],element,CONFIG)
	for i in actions.size():
		var after:=Variation.state(actions.slice(0,i+1),element,CONFIG)
		if row.has("elements"):after["base_attributes"]=row.elements.duplicate()
		var observation:=preload("res://scripts/research_visibility.gd").observed(after)
		var normalized_input:Dictionary=events[i].duplicate(true) if events[i] is Dictionary else {"key":"?","at_ms":0};normalized_input["hold_ms"]=0
		steps.append({"input":normalized_input,"before":before.duplicate(true),"after":after.duplicate(true),"before_observation":preload("res://scripts/research_visibility.gd").observed(before),"observation":observation});before=after
	var state:=before.duplicate(true)
	state["property_version"]=CONFIG.get("property_version","clipped-legacy")
	var status:String=identity.state;var failure:="unfinished"
	if bad>0:status="failed";failure="input_error"
	elif events.size()>5:status="failed";bad=6;failure="input_error"
	elif state.stability<float(CONFIG.thresholds.collapse_below):status="failed";failure="collapse";bad=events.size()
	elif status=="identified":status="ready" if state.stability>=float(CONFIG.thresholds.unstable_below) else "unstable";failure="none" if status=="ready" else "unstable"
	if status in ["ready","unstable"]:
		for field in row.get("structure",{}):
			var bounds:Array=row.structure[field]
			if float(state.get(field,0))<bounds[0] or float(state.get(field,0))>bounds[1]:status="incomplete";failure="unfinished"
	state.phase="READY" if status=="ready" else ("FAILED" if status=="failed" else "MANIPULATING")
	var simulation={"rules_version":8,"state":status,"kind":"prototype_v2","message":identity.get("reason","마나 구조를 관측합니다."),"mana_cost":0.0,"final_state":state,"casting_steps":steps,"failure_step":bad if bad>0 else (0 if status=="ready" else events.size()),"failure_kind":failure,"observation":preload("res://scripts/research_visibility.gd").observed(state),"simulation_context":context.duplicate(true),"actions":actions,"identity":row.get("id",""),"candidate_ids":identity.get("candidate_ids",[]),"resolution_priority":"binding_structure > active_main > neutral; ties rejected"}
	var result:=simulation.duplicate(true);result["simulation"]=simulation
	simulation["property_version"]=state.property_version;result["property_version"]=state.property_version
	if context.get("formal_rules",false) and not element.is_empty():simulation.kind=element.to_lower()+"_resonance"
	simulation["grammar_profile"]=profile.to_data()
	if failure=="collapse":result["message"]="마나 구조가 붕괴했습니다. 불안정한 집중이 역류 징후로 나타납니다.";simulation["message"]=result.message
	if not row.is_empty() and status in ["ready","unstable"]:
		var definition=preload("res://scripts/formal_spell_registry.gd").definition(row.id,context.get("formal_rules",false))
		if row.get("formula_prototype",false):definition=preload("res://scripts/mana_formula_prototypes.gd").definition(row.id)
		var tuned=Variation.tune(definition,state,CONFIG)
		if tuned.formula_effect.get("water15",false):tuned=preload("res://scripts/water_phenomena.gd").apply(tuned,state)
		if row.get("formula_prototype",false):tuned=preload("res://scripts/mana_effect_score.gd").apply(tuned,state)
		if row.get("formula_prototype",false) or tuned.formula_effect.get("water15",false):
			state["formula_effect"]=tuned.formula_effect.duplicate(true)
			state["property_version"]=CONFIG.get("property_version","clipped-legacy")
			simulation["property_version"]=state.property_version
			simulation["final_state"]=state.duplicate(true)
			result["final_state"]=state.duplicate(true)
		result["spell"]=tuned;result["identity"]=row.id;result["mana_cost"]=tuned.mana_cost
		result["state"]="ready" # Unstable manifestation remains a successful, flagged cast.
		result["risk"]="unstable" if status=="unstable" else "normal"
		simulation["mana_cost"]=tuned.mana_cost
	if context.get("laboratory",false) and result.get("spell")==null and research_ready(state) and bad==0 and not advanced_locked and events.size()<=5 and status not in ["ambiguous","locked","failed"]:
		simulation.state="ready";simulation.failure_step=0;simulation.failure_kind="none"
		result.state="ready";result.mana_cost=2.0;result.message="마나 공명이 유지됩니다. 관측을 기록합니다."
	if context.get("movement_research",false) and context.get("laboratory",false) and bad==0 and events.size()<=5 and not advanced_locked and preload("res://scripts/movement_research.gd").ready(actions,state):
		simulation.state="ready";simulation.kind="movement_research";simulation.failure_kind="none";simulation.failure_step=0;state.phase="READY"
		result.state="ready";result.final_state=state.duplicate(true);result.mana_cost=preload("res://scripts/movement_research.gd").CONFIG.research.mana_cost;result.message="흐름이 짧은 길을 잇습니다. 기초 이동술 연구를 기록합니다."
	return result

static func research_ready(state:Dictionary)->bool:
	return state.get("mana_amount",0)>=10 and state.get("stability",0)>=55 and state.get("form_integrity",0)>=25 and state.get("base_attributes",[]).size()==1
