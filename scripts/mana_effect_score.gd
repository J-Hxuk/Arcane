extends RefCounted
## NEW experimental F, not an existing or approved game formula. No keys/recipes.
static var DATA:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/mana_formula_prototypes.json"))
static func smooth(value:float)->float:
	var u:=clampf(value,0,1)
	return u*u*(3-2*u)
static func readings(state:Dictionary)->Dictionary:
	var raw:Dictionary=state.variation_vector;var base:Dictionary=raw.reference
	# Signed order residuals use RAW S and B in the same coordinate space.
	var pressure:=float(raw.get("cohesion",0))-.5*float(raw.get("form_integrity",0))
	var base_pressure:=float(base.get("cohesion",0))-.5*float(base.get("form_integrity",0))
	var circulation:=float(raw.get("flow_strength",0))+.6*float(raw.get("persistence",0))
	var base_circulation:=float(base.get("flow_strength",0))+.6*float(base.get("persistence",0))
	var confinement:=float(raw.get("form_integrity",0))+.5*float(raw.get("persistence",0))*20
	var base_confinement:=float(base.get("form_integrity",0))+.5*float(base.get("persistence",0))*20
	return {"pressure":.5+.5*tanh((pressure-base_pressure)/4.0),"circulation":.5+.5*tanh((circulation-base_circulation)/.16),"confinement":.5+.5*tanh((confinement-base_confinement)/6.0),"stability":clampf(state.stability/100.0,0,1),"shape":clampf(state.form_integrity/100.0,0,1)}
static func evaluate(axis:String,state:Dictionary)->Dictionary:
	var r:=readings(state);var a:Dictionary=DATA.activation
	var score:float=.65*r[axis]+.2*r.stability+.15*r.shape
	var strength:=smooth((score-float(a.threshold))/float(a.width))*smooth((state.stability-float(a.stability_low))/(float(a.stability_high)-float(a.stability_low)))
	return {"score":score,"strength":strength,"active":strength>0,"readings":r,"threshold":a.threshold,"stability_margin":state.stability-float(a.stability_low)}
static func apply(source,state:Dictionary):
	var spell=source.duplicate();var row:Dictionary={}
	for candidate in DATA.spells:
		if candidate.id==str(source.spell_id):row=candidate;break
	if row.is_empty():return spell
	var result:=evaluate(row.score_axis,state);var amount:float=result.strength
	spell.formula_effect=source.formula_effect.duplicate(true);spell.formula_effect.merge(result)
	spell.mana_cost*=1+float(DATA.activation.extra_cost)*amount
	match row.score_axis:
		"circulation":
			spell.knockback*=1+float(row.strength_gain)*amount
			spell.radius*=1-float(row.area_tradeoff)*amount
		"pressure":
			spell.formula_effect.armor_ignore=float(row.armor_ignore)+float(row.strength_gain)*amount
			spell.projectile_radius*=1-float(row.area_tradeoff)*amount
		"confinement":
			spell.damage*=1+float(row.strength_gain)*amount
			spell.duration*=1-.15*amount
			spell.radius*=1-float(row.area_tradeoff)*amount
	spell.visual_density*=1+.4*amount;spell.visual_glow*=1+.25*amount
	return spell
static func explain(effect:Dictionary)->String:
	var cause={"circulation":"회전 흐름이 안쪽으로 모여 당김이 강해지고 범위가 좁아집니다.","pressure":"좁은 수류에 압력이 모여 방어층을 더 통과합니다.","confinement":"물막이 조밀해져 압박이 커지고 유지 시간과 범위가 줄어듭니다."}
	return cause.get(effect.get("axis",""),"") if effect.get("active",false) else "추가 현상을 유지할 구조가 형성되지 않았습니다. 기본 물성으로 발현합니다."
