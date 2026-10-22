extends RefCounted
## Pure public projection. Inspection itself is shared with release.
static func public_result(result:Dictionary,known:Array,details:=false)->Dictionary:
	var definition=result.get("spell")
	var state:Dictionary=result.get("simulation",{}).get("final_state",{})
	var observed=preload("res://scripts/research_visibility.gd").observed(state)
	if definition==null:return {"text":"관측 · "+observed,"known":false}
	var visible:=false
	for row in known:
		if str(row["spell_id"]) in [str(definition.spell_id),str(definition.catalog_id)]:visible=true
	if not visible:return {"text":"관측 · "+observed+" 실제 방출 후 현상을 기록합니다.","known":false}
	var range_value:float=definition.projectile_speed*definition.lifetime if definition.effect==&"projectile" else definition.radius
	var baseline=preload("res://scripts/m1_spell_catalog.gd").find(str(definition.spell_id))
	var delta_text="기본 성능" if baseline==null else ("피해 강화 / 비용·사거리 함께 비교" if definition.damage>baseline.damage+.01 else ("피해 완화 / 다른 성질 함께 비교" if definition.damage<baseline.damage-.01 else "피해 기본 수준"))
	var status:String=("불안정한 발현 · 흔들림 주의" if result.get("risk")=="unstable" else "발현 가능") if result["state"]=="ready" else "발현 보류"
	if not result.get("resource_allowed",true):status="자원 한도 때문에 발현 보류"
	elif result.get("cast_blocked",false):status="영창 안정화 또는 저장 보호로 발현 보류"
	if not details:return {"known":true,"name":definition.display_name,"text":"미리보기 · %s · %s\n%s · 순서를 바꾸어 집중과 전개의 차이를 관측하세요."%[definition.display_name,status,observed]}
	return {"known":true,"name":definition.display_name,"text":"미리보기 · %s · %s\n피해 %.1f · 거리/범위 %.0f px · 마나 %.1f점 · 지속 %.2f초 · %s"%[definition.display_name,status,definition.damage,range_value,result.get("mana_cost",definition.mana_cost),definition.duration,delta_text]}
