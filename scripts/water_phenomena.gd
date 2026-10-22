extends RefCounted
## QA defaults: qualitative phenomena, no keys, discovery flags, or random rolls.
const Score=preload("res://scripts/mana_effect_score.gd")
static func apply(source,state:Dictionary):
	var spell=source.duplicate();var item=preload("res://scripts/water_spell_catalog.gd").row(str(source.spell_id))
	if item.is_empty():return spell
	var r:Dictionary=Score.readings(state);var raw:Dictionary=state.variation_vector;var b:Dictionary=raw.reference
	r.distribution=.5+.5*tanh((float(raw.get("spread",0))-float(b.get("spread",0)))/.12)
	r.motion=.5+.5*tanh(((float(raw.get("flow_strength",0))-.6*float(raw.get("persistence",0)))-(float(b.get("flow_strength",0))-.6*float(b.get("persistence",0))))/.16)
	r.persistence=.5+.5*tanh((float(raw.get("persistence",0))-float(b.get("persistence",0)))/.2)
	var score:float=r.get(item.axis,0)
	if item.id=="OH-070":score=.5*r.pressure+.5*r.motion
	if item.id=="OH-072":score=.5*r.confinement+.25*r.pressure+.25*r.persistence
	var strength:float=Score.smooth((score-float(item.threshold))/float(item.width))*Score.smooth((state.stability-25)/30)
	if item.axis.is_empty():strength=0
	spell.formula_effect=source.formula_effect.duplicate(true)
	spell.formula_effect.merge({"strength":strength,"active":strength>0.001,"score":score,"readings":r,"property_version":"raw-bot-1","effect_version":"water15-qa-1"},true)
	# Exactly one qualitative surcharge; old PX numerical F is not applied.
	spell.mana_cost*=1+float(item.extra_cost)*strength
	if item.id in ["OH-068","OH-071","OH-073"]:spell.radius*=1-float(item.area_tradeoff)*strength
	if item.id=="OH-070":spell.lifetime*=1-.12*strength
	if item.id=="OH-072":spell.placement_distance*=1-.15*strength
	spell.visual_density*=1+.4*strength
	if int(str(item.id).right(3))>=64:
		var projected=preload("res://scripts/mana_variation.gd").projection(state,preload("res://scripts/chant_config.gd").DATA)
		spell.status_strength=clampf(1+.15*projected.focus-.15*projected.motion,.7,1.3)
	return spell
static func explain(effect:Dictionary)->String:
	if not effect.get("active",false):return "추가 흐름이 유지되지 않아 기본 형태로 발현합니다."
	return {"OH-067":"회전 수막이 첫 탄체의 진행 방향을 비틉니다.","OH-068":"안쪽 견인과 접선 흐름이 합쳐져 곡선 궤도를 만듭니다.","OH-069":"갈라진 흐름이 서로 다른 폭으로 펼쳐집니다.","OH-070":"집중 압력과 유동이 굽은 제트 궤적을 만듭니다.","OH-071":"유지되는 수류가 시간차를 둔 두 번의 집속을 만듭니다.","OH-072":"구속이 풀릴 때 모인 수압이 바깥 고리로 방출됩니다.","OH-073":"겹친 수류가 서로 반대로 회전합니다.","OH-074":"압력 일부가 뒤늦게 전달되어 충격이 두 시점으로 나뉩니다.","OH-075":"분기와 회전이 여러 독립 곡선 수류를 만듭니다."}.get(effect.get("source_id",""),"")
