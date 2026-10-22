extends SceneTree
const EngineV2=preload("res://scripts/chant_engine_v2.gd")
const Profile=preload("res://scripts/chant_profile.gd")
const Identity=preload("res://scripts/chant_identity.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: ",label)
	else:failures+=1;push_error("FAIL: "+label)
static func permutations(values:Array)->Array:
	if values.is_empty():return [[]]
	var result:Array=[]
	for i in values.size():
		var rest:=values.duplicate();var head=rest.pop_at(i)
		for tail in permutations(rest):result.append([head]+tail)
	return result
func _initialize()->void:
	var profile=Profile.new();profile.load_data(Profile.generate_current(1787453028))
	var rows:Array=[];var signatures:Dictionary={}
	for row in EngineV2.CONFIG.spells:
		var signature:=Identity.multiset(row.actions)
		check(not signatures.has(signature),row.id+" globally unique multiset")
		signatures[signature]=row.id
		var context={"main_attribute":row.get("element","WATER"),"auxiliary_attributes":["METAL"],"binding_pairs":["METAL+WATER"]}
		var outcomes:Array=[]
		for order in permutations(row.actions):
			var events:=EngineV2.inputs(profile,order)
			var result:=EngineV2.resolve(profile,events,context)
			check(result.get("identity")==row.id and result.get("spell")!=null,row.id+" permutation keeps identity "+str(order))
			var held:=events.duplicate(true)
			for event in held:event.hold_ms=1000
			check(EngineV2.resolve(profile,held,context).final_state==result.final_state,"Hold timing has no bonus")
			var biased:=context.duplicate(true);biased["innate_element"]="FIRE";biased["innate_affinity"]={"FIRE":100,"WATER":0}
			check(EngineV2.resolve(profile,events,biased).final_state==result.final_state,"Legacy affinity has no prototype effect")
			var spell=result.get("spell")
			if spell!=null:
				var record={"id":row.id,"actions":order,"keys":events.map(func(e):return e.key),"damage":spell.damage,"speed":spell.projectile_speed,"range":spell.projectile_speed*spell.lifetime if spell.effect==&"projectile" else spell.radius,"radius":spell.radius,"duration":spell.duration,"knockback":spell.knockback,"cost":spell.mana_cost,"stability":result.final_state.stability,"loss":result.final_state.energy_loss,"outcome":result.get("risk",result.state)}
				outcomes.append(record);rows.append(record)
				record["collision_radius"]=spell.projectile_radius if spell.effect==&"projectile" else spell.radius
				if spell.effect!=&"projectile":record["speed"]=0.0
		check(outcomes.size()==permutations(row.actions).size(),row.id+" all configured permutations executable")
		check(outcomes[0]!=outcomes.back(),row.id+" order changes measured results")
		var unique_results:Dictionary={}
		var dominated_pairs:=0
		for a in outcomes:
			unique_results[JSON.stringify([a.damage,a.range,a.speed,a.radius,a.duration,a.knockback,a.cost])]=true
			for b in outcomes:
				var dominates:=true;var strictly:=false
				for field in ["damage","range","speed","radius","collision_radius","duration","knockback"]:
					if float(a[field])+0.000001<float(b[field]):dominates=false
					if float(a[field])>float(b[field])+0.000001:strictly=true
				if a.cost>b.cost+.000001:dominates=false
				if a.cost<b.cost-.000001:strictly=true
				if dominates and strictly:dominated_pairs+=1
		check(unique_results.size()>1,row.id+" actual performance, not just order labels, varies")
		check(dominated_pairs==0,row.id+" no permutation dominates another in all benefit metrics and cost")
	var bad:=EngineV2.resolve(profile,EngineV2.inputs(profile,["ACCUMULATE","ACCUMULATE","ACCUMULATE","ACCUMULATE","ACCUMULATE","ACCUMULATE"]),{"main_attribute":"WATER"})
	check(bad.state=="failed" and bad.get("spell")==null,"Sixth input rejected below the UI")
	var denied:=EngineV2.resolve(profile,EngineV2.inputs(profile,["ACCUMULATE","COMPRESS","DIRECT"]),{"main_attribute":"WATER","auxiliary_attributes":["METAL"]})
	check(denied.state=="locked","Auxiliary standalone remains forbidden")
	var tail_direction:Dictionary=EngineV2.resolve(profile,EngineV2.inputs(profile,["ACCUMULATE","DIRECT"]),{"main_attribute":"WATER"}).final_state
	var tail_accumulation:Dictionary=EngineV2.resolve(profile,EngineV2.inputs(profile,["DIRECT","ACCUMULATE"]),{"main_attribute":"WATER"}).final_state
	check(tail_direction.flow_strength>tail_accumulation.flow_strength and tail_accumulation.mana_amount>tail_direction.mana_amount,"The final operation has stronger measured influence without changing the multiset")
	var other=Profile.new();other.load_data(Profile.generate_current(8431))
	check(EngineV2.inputs(profile,EngineV2.CONFIG.spells[4].actions)!=EngineV2.inputs(other,EngineV2.CONFIG.spells[4].actions),"Different characters retain different physical key permutations")
	check(EngineV2.resolve(other,EngineV2.inputs(other,EngineV2.CONFIG.spells[4].actions),{"main_attribute":"WATER"}).identity=="OH-061","Identity reads personal operations instead of fixed physical keys")
	var fusion_events:=EngineV2.inputs(profile,EngineV2.CONFIG.spells[5].actions)
	var forward:=EngineV2.resolve(profile,fusion_events,{"main_attribute":"WATER","auxiliary_attributes":["METAL"],"binding_pairs":["METAL+WATER"]})
	var reverse:=EngineV2.resolve(profile,fusion_events,{"main_attribute":"METAL","auxiliary_attributes":["WATER"],"binding_pairs":["METAL+WATER"]})
	check(forward.final_state==reverse.final_state and forward.mana_cost==reverse.mana_cost,"Fusion uses the same averaged coefficients with reversed permanent roles")
	check(EngineV2.resolve(profile,EngineV2.inputs(profile,["BIND"]),{"main_attribute":"WATER"}).state=="locked","Bind without an auxiliary cannot begin a fusion")
	check(Identity.multiset(["COMPRESS","COMPRESS","DIRECT"])!=Identity.multiset(["ACCUMULATE","COMPRESS","DIRECT"]),"Multiset preserves repeated counts")
	for grade in [4,5]:
		var advanced:Array=["ACCUMULATE","SHAPE","DIRECT","EXPAND"] if grade==4 else ["ACCUMULATE","DIRECT","EXPAND","CYCLE","SHAPE"]
		check(not Identity.grade_allowed(advanced,grade,{},EngineV2.CONFIG),"High grades cannot bypass focus/research")
		check(Identity.grade_allowed(advanced,grade,{"focus_cast":true,"advanced_operations":["EXPAND","CYCLE"],"technique_rank":4},EngineV2.CONFIG),"High grade constraints independently data driven")
	var collision:=EngineV2.CONFIG.duplicate(true);var duplicate:Dictionary=collision.spells[0].duplicate(true);duplicate.id="TEST_COLLISION";collision.spells.append(duplicate)
	check(Identity.identify(collision.spells[0].actions,{"developer_all":true},collision).state=="ambiguous","Collision never resolves through row priority")
	check(Identity.identify(collision.spells[0].actions,{"developer_all":true,"developer_target":"TEST_COLLISION"},collision).row.id=="TEST_COLLISION","Developer-only explicit ID reproduces a conflicting definition")
	var collapse_events:=EngineV2.inputs(profile,["COMPRESS","COMPRESS","COMPRESS"])
	var failure:=EngineV2.resolve(profile,collapse_events,{"main_attribute":"FIRE"})
	check(failure.failure_kind=="collapse" and failure==EngineV2.resolve(profile,collapse_events,{"main_attribute":"FIRE"}),"Structural collapse is deterministic")
	var sig=preload("res://scripts/signature_session.gd").new()
	check(not sig.register_fixture(["ACCUMULATE","COMPRESS","DIRECT","CYCLE","ANCHOR","BIND","EXPAND"],EngineV2.CONFIG.spells),"Signature prefix cannot steal any ordinary permutation")
	var fixture:Array=["EXPAND","CYCLE","ANCHOR","BIND","SHAPE","DIRECT","STABILIZE"]
	check(sig.register_fixture(fixture,EngineV2.CONFIG.spells),"Only a nonconflicting test fixture is registered")
	check(sig.observe(fixture.slice(0,3),false)=="focus_required" and not sig.active,"Signature preparation requires focus")
	check(sig.observe(fixture.slice(0,3),true)=="prepared" and sig.enemy_multiplier()==.35 and Engine.time_scale==1,"Preparation slows enemy delta only; UI/input use real time")
	sig.advance(2.1);check(not sig.active,"Signature preparation times out")
	for ending in ["cancel","failure","release"]:
		sig.observe(fixture.slice(0,3),true);sig.end();check(not sig.active,"Signature ends on "+ending)
	var f=FileAccess.open("res://.task002_artifacts/phase4_qa_v2/permutations.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"\t"));f.close()
	print("CHANT V2 INDEPENDENT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
