extends RefCounted
## Interpret only the keys actually entered and the computed state delta.
const WORDS={"ACCUMULATE":"축적","COMPRESS":"압축","STABILIZE":"안정화","RESONATE":"공명","SHAPE":"형상","DIRECT":"방향","BIND":"결속","EXPAND":"확산","SPLIT":"분열","CYCLE":"회전","ANCHOR":"고정","DISSIPATE":"소산"}
static func interpret(profile,keys:Array,state:Dictionary,before:Dictionary)->Dictionary:
	var meanings:PackedStringArray=[]
	for key in keys:
		var word:String=WORDS.get(profile.manipulation(str(key)),"해석되지 않은 조작")
		meanings.append(str(key)+" — "+word)
	var readings:PackedStringArray=[]
	if not before.is_empty():
		for field in ["mana_amount","cohesion","form_integrity","flow_strength","stability","spread","branches"]:
			var difference:float=float(state.get(field,0))-float(before.get(field,0))
			match field:
				"mana_amount":
					if difference>.4:readings.append("마나 축적 중")
				"cohesion":
					if difference>2:readings.append("응집 중")
				"form_integrity":
					if difference>2:readings.append("형태 부여 중")
				"flow_strength":
					if difference>.05:readings.append("방향성 형성")
				"stability":
					if difference>2:readings.append("안정화 진행")
					elif difference< -2:readings.append("흔들림 증가")
				"spread":
					if difference>.1:readings.append("분포가 넓어짐")
				"branches":
					if difference>=1:readings.append("흐름이 갈라짐")
	if state.get("formula_effect",{}).get("prototype",false):readings.append(preload("res://scripts/mana_effect_score.gd").explain(state.formula_effect))
	if state.get("formula_effect",{}).get("water15",false):readings.append(preload("res://scripts/water_phenomena.gd").explain(state.formula_effect))
	return {"meanings":" · ".join(meanings),"reading":" / ".join(readings) if not readings.is_empty() else "뚜렷한 물성 변화가 작습니다.","caption":WORDS.get(profile.manipulation(str(keys.back())),"") if not keys.is_empty() else ""}
