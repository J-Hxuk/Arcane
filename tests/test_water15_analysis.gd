extends SceneTree
const V=preload("res://scripts/mana_variation.gd")
const Score=preload("res://scripts/mana_effect_score.gd")
static var C:Dictionary=preload("res://scripts/chant_config.gd").DATA
const OUT="res://.task002_artifacts/water15_integration/math/"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: ",label)
func projection(state:Dictionary,raw_order:bool)->Dictionary:
	var t:Dictionary=C.tuning;var b:Dictionary=state.variation_vector.reference
	var focus:float=(state.cohesion-state.form_integrity*t.form_density_ratio)
	var motion:float=state.flow_strength-state.persistence*t.motion_persistence
	var residual_focus:float=focus-(b.cohesion-b.form_integrity*t.form_density_ratio)
	var residual_motion:float=motion-(b.flow_strength-b.persistence*t.motion_persistence)
	if raw_order:
		var raw:Dictionary=state.variation_vector
		residual_focus=(raw.cohesion-raw.form_integrity*t.form_density_ratio)-(b.cohesion-b.form_integrity*t.form_density_ratio)
		residual_motion=(raw.flow_strength-raw.persistence*t.motion_persistence)-(b.flow_strength-b.persistence*t.motion_persistence)
	return {"focus":tanh(clampf(focus/t.focus_denominator,-1,1)+t.order_gain*tanh(residual_focus/t.order_focus_scale)),"motion":tanh(clampf(motion,-1,1)+t.order_gain*tanh(residual_motion/t.order_motion_scale)),"order_focus_input":residual_focus/t.order_focus_scale,"order_motion_input":residual_motion/t.order_motion_scale}
func benefit(sample:Dictionary,field:String)->float:
	if field=="knockback":return absf(sample.get(field,0))
	if field=="special":return float(sample.get("effect",{}).get("strength",0))
	return float(sample.get(field,0))
func dominates(a:Dictionary,b:Dictionary,fields:Array)->bool:
	var strict:=false
	for field in fields:
		if benefit(a,field)+.00001<benefit(b,field):return false
		if benefit(a,field)>benefit(b,field)+.00001:strict=true
	if a.mana_cost>b.mana_cost+.00001 or a.state.stability+.00001<b.state.stability:return false
	return strict or a.mana_cost+.00001<b.mana_cost or a.state.stability>b.state.stability+.00001
func run()->void:
	var rows:Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"permutations.json"))
	var report:Array=[];var repeats:Array=[]
	for element in C.elements:
		for extreme in ["COMPRESS","EXPAND","SPLIT"]:
			var chain:Array=[];chain.resize(5);chain.fill(extreme)
			check(V.state(chain,element,C).phase=="FAILED",element+" extreme "+extreme+" x5 collapses")
		for action in C.operations:
			for n in range(1,6):
				var order:Array=[];order.resize(n);order.fill(action)
				var state:=V.state(order,element,C);var old:=projection(state,false);var candidate:=projection(state,true)
				check(absf(candidate.order_focus_input)<.00001 and absf(candidate.order_motion_input)<.00001,"Raw residual proposal has zero positional bonus for identical repeats "+element+" "+action+str(n))
				if absf(old.order_focus_input)>.1 or absf(old.order_motion_input)>.1:repeats.append({"element":element,"operation":action,"count":n,"existing":old,"raw_residual_proposal":candidate})
	for row in rows:
		var definition=preload("res://scripts/mana_formula_prototypes.gd").definition(row.id) if row.id.begins_with("PX-") else preload("res://scripts/formal_spell_registry.gd").definition(row.id)
		var physical_fields:Array=["radius","duration"] if definition.effect==&"barrier" else ["damage","projectile_speed","range","projectile_radius"] if definition.effect==&"projectile" else ["damage","radius"]
		if not definition.status_effect.is_empty() and "duration" not in physical_fields:physical_fields.append("duration")
		if definition.knockback!=0:physical_fields.append("knockback")
		if row.id.begins_with("PX-"):physical_fields.append("special")
		var success:Array=row.samples.filter(func(sample):return sample.has("damage"))
		var bounds:Dictionary={};var front:=0;var universal:Array=[];var max_difference:=0.0
		for a in success:
			var beaten:=false;var beats_all:=success.size()>1
			for b in success:
				if a==b:continue
				if dominates(b,a,physical_fields):beaten=true
				if not dominates(a,b,physical_fields):beats_all=false
			if not beaten:front+=1
			if beats_all:universal.append(a.order)
			var old:=projection(a.state,false);var candidate:=projection(a.state,true)
			max_difference=maxf(max_difference,maxf(absf(old.focus-candidate.focus),absf(old.motion-candidate.motion)))
			for field in ["damage","mana_cost","projectile_speed","range","radius","projectile_radius","duration"]:
				var pair:Array=bounds.get(field,[INF,-INF]);pair[0]=minf(pair[0],a[field]);pair[1]=maxf(pair[1],a[field]);bounds[field]=pair
			check(absf(candidate.focus)<=1 and absf(candidate.motion)<=1,"Raw residual proposal remains bounded "+row.id)
		if row.id.begins_with("PX-"):check(universal.is_empty(),"No prototype order dominates every successful permutation "+row.id)
		report.append({"id":row.id,"orders":row.samples.size(),"manifestable":success.size(),"pareto_front":front,"universal_dominators":universal,"relevant_metrics":physical_fields,"bounds":bounds,"max_projection_change_if_raw_proposal_used":max_difference})
	check(not repeats.is_empty(),"Existing clip-vs-unclipped-reference bias reproduced in repeated operations")
	# Additional effect is C1 at threshold, and zero at collapse stability.
	for axis in ["circulation","pressure","confinement"]:
		var state:=V.state(["ACCUMULATE","SHAPE","DIRECT","STABILIZE","CYCLE"],"WATER",C)
		state.stability=25
		check(Score.evaluate(axis,state).strength==0,"No additional special structure at collapse boundary "+axis)
	FileAccess.open(OUT+"risk_analysis.json",FileAccess.WRITE).store_string(JSON.stringify({"spells":report,"repeat_bias_examples":repeats},"\t"))
	print("MANA FORMULA ANALYSIS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
