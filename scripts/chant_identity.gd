extends RefCounted
const P=preload("res://scripts/chant_profile.gd")
static func multiset(actions:Array)->String:
	var sorted:=actions.duplicate();sorted.sort();return "|".join(sorted)
static func grade_allowed(actions:Array,grade:int,context:Dictionary,config:Dictionary)->bool:
	# In the formal rules grades describe spells; they are not casting permissions.
	if context.get("formal_rules",false):return actions.size()>=1 and actions.size()<=int(config.maximum_inputs)
	var row:Dictionary=config.grades.get(str(grade),{})
	if row.is_empty() or actions.size()<row.min or actions.size()>row.max:return false
	var advanced:=0
	for action in actions:
		if action in P.ADVANCED_ACTIONS:
			advanced+=1
			if action not in context.get("advanced_operations",[]) or context.get("technique_rank",0)<4:return false
	return (not row.focus or context.get("focus_cast",false)) and advanced>=row.advanced and (grade>3 or advanced==0)
static func allowed(row:Dictionary,context:Dictionary)->bool:
	if row.get("neutral",false):return true
	if row.has("elements") and (row.elements.size()!=2 or row.elements[0]==row.elements[1]):return false
	if context.get("developer_all",false):return true
	if context.get("attribute_loadout_version",0)==1:
		var opened:Array=context.get("awakened_attributes",[])
		if context.get("main_attribute") not in opened:return false
		if row.has("elements") and not preload("res://scripts/attribute_loadout.gd").owns_pair(row.elements,opened):return false
	if row.has("elements"):
		var elements:Array=row.elements
		return preload("res://scripts/fusion_rules.gd").cast_allowed(elements,context)
	return row.element==context.get("main_attribute")
static func identify(actions:Array,context:Dictionary,config:Dictionary)->Dictionary:
	if actions.size()>config.maximum_inputs:return {"state":"failed","reason":"일반 영창은 최대 5회 입력입니다."}
	if "BIND" in actions and not context.get("developer_all",false) and context.get("auxiliary_attributes",[]).is_empty():return {"state":"locked","reason":"결속에는 서로 다른 개화 속성을 주·보조에 장착해야 합니다."}
	var signature:=multiset(actions);var candidates:Array=[];var matched:=false;var denied_grade:=false;var rejected_structure:=false;var matched_active_family:=false
	for row in config.spells:
		if multiset(row.actions)!=signature:continue
		matched=true
		if row.get("neutral",false) or row.has("elements") or row.get("element")==context.get("main_attribute"):matched_active_family=true
		if row.has("elements") and "BIND" not in actions:continue
		if not allowed(row,context):continue
		if "BIND" in actions and not row.has("elements"):continue
		if not grade_allowed(actions,int(row.grade),context,config):denied_grade=true;continue
		# Historical prototypes used structure to select an identity. Formal identity
		# depends only on element + multiset; manifestation is checked by the engine.
		if context.get("formal_rules",false):candidates.append(row);continue
		# Evaluate every authorized historical candidate against its final state.
		var element:String=row.get("element","")
		if row.has("elements"):element=preload("res://scripts/fusion_rules.gd").pair(row.elements)
		var state:Dictionary=preload("res://scripts/mana_variation.gd").state(actions,element,config)
		var structure_ok:=true
		for field in row.get("structure",{}):
			var bounds:Array=row.structure[field]
			if float(state.get(field,0))<bounds[0] or float(state.get(field,0))>bounds[1]:structure_ok=false
		if not structure_ok:rejected_structure=true;continue
		candidates.append(row)
	# Explicit binding structure > active-main single element > neutral fallback.
	var preferred:Array=candidates.filter(func(row):return row.has("elements")) if "BIND" in actions else candidates.filter(func(row):return not row.get("neutral",false) and not row.has("elements"))
	if not preferred.is_empty():candidates=preferred
	var ids:Array=candidates.map(func(row):return row.id);ids.sort()
	if candidates.size()>1:
		if context.get("developer_all",false):
			for row in candidates:
				if row.id==context.get("developer_target"):return {"state":"identified","row":row,"candidate_ids":ids,"developer_override":true}
		return {"state":"ambiguous","candidate_ids":ids,"reason":"조작 구성이 충돌합니다. 임의 주문을 선택하지 않았습니다."}
	if candidates.is_empty():
		if matched and not matched_active_family:return {"state":"locked","candidate_ids":ids,"reason":"현재 주속성으로 성립하는 주문의 조작 구성이 아닙니다."}
		return {"state":"incomplete" if rejected_structure or not matched else "locked","candidate_ids":ids,"reason":"최종 마나 구조가 부족합니다." if rejected_structure else ("주문 등급·초집중·고위 조작 연구 조건을 확인하세요." if denied_grade else "현재 개화·장착 속성으로 발현할 수 없습니다." if matched else "아직 구현된 주문의 조작 구성을 이루지 못했습니다.")}
	return {"state":"identified","row":candidates[0],"candidate_ids":ids}
