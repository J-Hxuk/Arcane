extends SceneTree
const V=preload("res://scripts/mana_variation.gd")
const P=preload("res://scripts/mana_formula_prototypes.gd")
const R=preload("res://scripts/formal_spell_registry.gd")
const F=preload("res://scripts/mana_effect_score.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: ",label)
func axis_value(axis:String,state:Dictionary)->float:
	var r:Dictionary=state.variation_vector;var b:Dictionary=r.reference
	if axis=="distribution":return .5+.5*tanh((r.spread-b.spread)/.12)
	if axis=="motion":return .5+.5*tanh(((r.flow_strength-.6*r.persistence)-(b.flow_strength-.6*b.persistence))/.16)
	if axis=="persistence":return .5+.5*tanh((r.persistence-b.persistence)/.2)
	return F.readings(state)[axis]
func run()->void:
	var design:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/water_special_phenomena_proposals.json"));var results:Array=[]
	for candidate in design.candidates:
		var row:Dictionary=P.DATA.spells.filter(func(item):return item.id==candidate.prototype)[0]
		var min_score:=INF;var max_score:=-INF;var off:=0;var on:=0;var samples:Array=[]
		for order in R.permutations(row.actions):
			var state:=V.state(order,"WATER",preload("res://scripts/chant_config.gd").DATA)
			var axis:=axis_value(candidate.axis,state)
			var score:float=.65*axis+.2*state.stability/100.0+.15*state.form_integrity/100.0
			var strength:=F.smooth((score-.57)/.18)*F.smooth((state.stability-25)/30.0)
			min_score=minf(min_score,score);max_score=maxf(max_score,score)
			if strength==0:off+=1
			if strength>.1:on+=1
			samples.append({"order":order,"score":score,"strength":strength})
		check(off>0 and on>0,"Same multiset has both unreachable and reachable NEW candidate structure "+candidate.id)
		check(min_score>=0 and max_score<=1,"Proposal score remains bounded "+candidate.id)
		results.append({"id":candidate.id,"orders":samples.size(),"off":off,"on_over_point_one":on,"min_score":min_score,"max_score":max_score,"samples":samples,"implemented":false})
	FileAccess.open("res://.task002_artifacts/formula_followup/phenomena_design_simulation.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("WATER PHENOMENA DESIGN: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
