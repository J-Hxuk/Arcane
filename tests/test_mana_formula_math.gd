extends SceneTree
const V=preload("res://scripts/mana_variation.gd")
const E=preload("res://scripts/chant_engine_v2.gd")
const R=preload("res://scripts/formal_spell_registry.gd")
const P=preload("res://scripts/mana_formula_prototypes.gd")
const F=preload("res://scripts/mana_effect_score.gd")
const I=preload("res://scripts/chant_identity.gd")
static var C:Dictionary=preload("res://scripts/chant_config.gd").DATA
const OUT="res://.task002_artifacts/mana_formula_audit/"
var checks:=0
var failures:=0
var stats:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: ",label)
func context()->Dictionary:
	return {"formal_rules":true,"attribute_loadout_version":1,"awakened_attributes":["WATER"],"active_main_attribute":"WATER","active_auxiliary_attribute":null,"main_attribute":"WATER","auxiliary_attributes":[],"formula_prototypes":true}
func independent(actions:Array,element:String)->Dictionary:
	var b:Dictionary={};var o:Dictionary={};var t:Dictionary={};var weight_sum:=0.0
	for index in actions.size():weight_sum+=pow(C.r,index)
	for index in actions.size():
		for field in C.operations[actions[index]]:
			var v:float=C.operations[actions[index]][field]*C.elements[element].get(field,1)
			b[field]=b.get(field,0.0)+v
			o[field]=o.get(field,0.0)+C.kappa*(pow(C.r,index)/weight_sum-1.0/actions.size())*v
		if index+1<actions.size():
			for field in C.transitions.get(actions[index]+">"+actions[index+1],{}):
				t[field]=t.get(field,0.0)+C.lambda*C.elements[element].get("interaction",1)*C.transitions[actions[index]+">"+actions[index+1]][field]
	var s:Dictionary={}
	for field in b:s[field]=b[field]+o.get(field,0)+t.get(field,0)
	s.stability-=C.elements[element].get("compression_risk",0)*pow(actions.count("COMPRESS"),2)*C.thresholds.compression_penalty_scale
	return {"B":b,"O":o,"T":t,"S":s}
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var operations:Array=C.operations.keys();var count:=0;var errors:=0;var repeat_errors:=0;var invariant_errors:=0
	var fields:Array=C.operations.ACCUMULATE.keys();var b_groups:Dictionary={}
	for element in C.elements:
		var metrics:Dictionary={"states":0,"collapsed":0,"unstable":0,"negative_raw_mana":0,"clipped_flow":0,"saturated_order_focus":0,"saturated_order_motion":0,"raw_min":{},"raw_max":{},"max_abs_O":{},"max_abs_T":{}}
		b_groups.clear()
		for n in range(1,6):
			for encoded in int(pow(12,n)):
				var actions:Array=[];var digits:=encoded
				for j in n:actions.append(operations[digits%12]);digits/=12
				var state:=V.state(actions,element,C);var replay:=V.state(actions,element,C)
				if state!=replay:repeat_errors+=1
				var raw:Dictionary=state.variation_vector;var ref:Dictionary=raw.reference
				var signature:=I.multiset(actions)
				if b_groups.has(signature):
					for field in fields:
						if absf(ref[field]-b_groups[signature][field])>.00001:invariant_errors+=1
				else:b_groups[signature]=ref
				var model:Dictionary=independent(actions,element)
				for field in fields:
					if not is_finite(state[field]) or not is_finite(raw[field]) or state[field]<0 or absf(raw[field]-model.S[field])>.00001:errors+=1
					metrics.raw_min[field]=minf(metrics.raw_min.get(field,INF),raw[field]);metrics.raw_max[field]=maxf(metrics.raw_max.get(field,-INF),raw[field])
					metrics.max_abs_O[field]=maxf(metrics.max_abs_O.get(field,0),absf(model.O.get(field,0)))
					metrics.max_abs_T[field]=maxf(metrics.max_abs_T.get(field,0),absf(model.T.get(field,0)))
				metrics.states+=1;metrics.collapsed+=int(state.stability<25);metrics.unstable+=int(state.stability>=25 and state.stability<40)
				metrics.negative_raw_mana+=int(raw.mana_amount<0);metrics.clipped_flow+=int(raw.flow_strength>1.5 or raw.flow_strength<0)
				metrics.saturated_order_focus+=int(absf((state.cohesion-state.form_integrity*.5-ref.cohesion+ref.form_integrity*.5)/4)>2)
				metrics.saturated_order_motion+=int(absf((state.flow_strength-state.persistence*.6-ref.flow_strength+ref.persistence*.6)/.16)>2)
				count+=1
				if count%20000==0:print("AUDIT_PROGRESS ",count);await process_frame
		stats[element]=metrics
		check(metrics.states==271452,element+" all 12-operation sequences length 1..5, including repeats")
		check(b_groups.size()==6187,element+" every multiset B grouped")
	check(count==1357260,"1,357,260 elemental states enumerated")
	check(errors==0,"All states finite, bounded below and equal independent B+O+T minus compression risk")
	check(repeat_errors==0,"Every state recomputed deterministically")
	check(invariant_errors==0,"B invariant in every permutation group (floating tolerance 1e-5)")
	var profile=preload("res://scripts/chant_profile.gd").new();profile.load_data(preload("res://scripts/chant_profile.gd").generate_current(1787453028))
	var rows:Array=[];var identity_errors:=0;var all_orders:=0
	for row in P.config(R.config()).spells:
		var ctx:=context();var elements:Array=row.get("elements",[row.get("element","")]);var main:String=elements[0] if not elements[0].is_empty() else "WATER"
		ctx.main_attribute=main;ctx.active_main_attribute=main;ctx.awakened_attributes=[main]
		if elements.size()==2:ctx.active_auxiliary_attribute=elements[1];ctx.auxiliary_attributes=[elements[1]];ctx.awakened_attributes=elements.duplicate();ctx.binding_pairs=[preload("res://scripts/fusion_rules.gd").pair(elements)]
		var seen:Dictionary={};var samples:Array=[];var effects:Array=[]
		for order in R.permutations(row.actions):
			var sig:="|".join(order)
			if seen.has(sig):continue
			seen[sig]=true;all_orders+=1
			var result:=E.resolve(profile,E.inputs(profile,order),ctx)
			if result.identity!=row.id:identity_errors+=1
			var sample:Dictionary={"order":order,"keys":E.inputs(profile,order).map(func(event):return event.key),"id":result.identity,"status":result.state,"state":result.final_state}
			if result.get("spell")!=null:
				var spell=result.spell
				for field in ["damage","mana_cost","projectile_speed","lifetime","projectile_radius","radius","knockback","duration","visual_density","visual_glow","visual_trail"]:sample[field]=spell.get(field)
				sample.range=spell.lifetime*spell.projectile_speed;sample.effect=spell.formula_effect.duplicate(true)
				if row.get("formula_prototype",false):effects.append(sample.effect.strength)
			samples.append(sample)
		if row.get("formula_prototype",false):
			check(effects.size()==samples.size(),row.id+" all proposed orders manifest without research/focus grants")
			check(effects.min()==0 and effects.max()>.1,row.id+" same identity includes special OFF and ON")
		rows.append({"id":row.id,"samples":samples})
	check(identity_errors==0,"Every registered spell and proposal retains one ID across ALL its unique permutations")
	stats.identity_orders=all_orders;stats.identity_errors=identity_errors
	stats.config=C
	FileAccess.open(OUT+"math_results.json",FileAccess.WRITE).store_string(JSON.stringify(stats,"\t"))
	FileAccess.open(OUT+"permutations.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	# C1 activation: infinitesimal changes at threshold do not jump output strength/cost.
	check(F.smooth(-.00001)==0 and F.smooth(.00001)<.000001 and F.smooth(1)==1,"Special activation is continuous with zero endpoint derivative")
	print("MANA FORMULA MATH: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
