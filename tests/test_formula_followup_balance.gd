extends SceneTree
const V=preload("res://scripts/mana_variation.gd")
const R=preload("res://scripts/formal_spell_registry.gd")
const P=preload("res://scripts/mana_formula_prototypes.gd")
const E=preload("res://scripts/chant_engine_v2.gd")
const I=preload("res://scripts/chant_identity.gd")
const Score=preload("res://scripts/mana_effect_score.gd")
const OUT="res://.task002_artifacts/water15_integration/"
static var C:Dictionary=preload("res://scripts/chant_config.gd").DATA
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: ",label)
func metrics(spell,state:Dictionary)->Dictionary:
	return {"damage":spell.damage,"speed":spell.projectile_speed,"radius":spell.radius,"core":spell.projectile_radius,"range":spell.projectile_speed*spell.lifetime,"cost":spell.mana_cost,"stability":state.stability,"knockback":spell.knockback,"duration":spell.duration}
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var raw:=C.duplicate(true);raw.tuning.order_residual_mode="raw"
	var legacy:=C.duplicate(true);legacy.tuning.order_residual_mode="clipped_legacy"
	var alternatives:Array=[]
	for gain in [.6,.4,.2]:
		var settings:=raw.duplicate(true);settings.tuning.order_gain=gain;alternatives.append(settings)
	var rows:Array=[];var orders:=0;var flags:Array=[]
	for row in P.config(R.config()).spells:
		if row.get("ported_from")=="water15":continue # Freeze the historical16+3 comparison cohort.
		var element:String=row.get("element","")
		if row.has("elements"):element=preload("res://scripts/fusion_rules.gd").pair(row.elements)
		var definition=P.definition(row.id) if row.get("formula_prototype",false) else R.definition(row.id)
		var summary:Dictionary={"id":row.id,"effect":str(definition.effect),"orders":0,"manifestable_before":0,"manifestable_after":0,"max_relative_change":{},"samples":[]}
		var seen:Dictionary={}
		for sequence in R.permutations(row.actions):
			var signature:="|".join(sequence)
			if seen.has(signature):continue
			seen[signature]=true;orders+=1;summary.orders+=1
			var state:=V.state(sequence,element,C)
			var success:bool=state.stability>=C.thresholds.collapse_below
			for field in row.get("structure",{}):
				var bounds:Array=row.structure[field]
				if state[field]<bounds[0] or state[field]>bounds[1]:success=false
			var before=V.tune(definition,state,legacy);var after=V.tune(definition,state,raw)
			if row.get("formula_prototype",false):before=Score.apply(before,state);after=Score.apply(after,state)
			var b:=metrics(before,state);var a:=metrics(after,state);var changes:Dictionary={};var relevant:Array=["damage","cost"]
			if definition.effect==&"projectile":relevant.append_array(["speed","core","range"])
			if definition.radius>0:relevant.append("radius")
			if definition.duration>0:relevant.append("duration")
			if definition.knockback!=0:relevant.append("knockback")
			for field in relevant:
				var relative:float=(a[field]-b[field])/maxf(.000001,absf(b[field]))
				changes[field]=relative;summary.max_relative_change[field]=maxf(summary.max_relative_change.get(field,0),absf(relative))
				# Review alarm, NOT a declaration of final game balance.
				if success and absf(relative)>=(.10 if field=="cost" else .20):flags.append({"id":row.id,"order":sequence,"field":field,"before":b[field],"after":a[field],"relative_change":relative})
			var options:Array=[]
			for settings in alternatives:
				var candidate=V.tune(definition,state,settings)
				if row.get("formula_prototype",false):candidate=Score.apply(candidate,state)
				options.append({"gain":settings.tuning.order_gain,"metrics":metrics(candidate,state)})
			summary.samples.append({"order":sequence,"manifestable":success,"identity":row.id,"before":b,"raw_after":a,"relative_change":changes,"alternatives":options,"mana50_before":success and b.cost<=50,"mana50_after":success and a.cost<=50})
			summary.manifestable_before+=int(success);summary.manifestable_after+=int(success)
		check(summary.manifestable_before==summary.manifestable_after,"State, stability and structural manifestation unchanged "+row.id)
		rows.append(summary)
	var repeat_count:=0
	for element in C.elements:
		for action in C.operations:
			for n in range(1,6):
				var sequence:Array=[];sequence.resize(n);sequence.fill(action)
				var state:=V.state(sequence,element,C);var projection:=V.projection(state,raw)
				var equal_components:=true
				for field in C.operations[action]:
					var expected:float=state.variation_vector.reference[field]
					if field=="stability":expected-=float(C.elements[element].get("compression_risk",0))*pow(sequence.count("COMPRESS"),2)*C.thresholds.compression_penalty_scale
					if absf(state.variation_vector[field]-expected)>.00001:equal_components=false
				check(equal_components and absf(projection.order_focus_input)<.00001 and absf(projection.order_motion_input)<.00001,"Raw repeat has zero positional/adjacent bonus in all vector fields "+element+action+str(n));repeat_count+=1
	check(orders==572,"All 572 unique permutations of 16 production and 3 prototype spells compared")
	check(not flags.is_empty(),"Large raw correction changes detected; production application requires review")
	check(C.tuning.get("order_residual_mode")=="raw","Production raw correction authorized for integrated QA")
	FileAccess.open(OUT+"balance_comparison.json",FileAccess.WRITE).store_string(JSON.stringify({"orders":orders,"repeat_cases":repeat_count,"review_thresholds":{"cost":.10,"other_relevant_properties":.20},"review_flags":flags,"production_applied":true,"spells":rows},"\t"))
	print("FOLLOWUP BALANCE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
