extends "res://tests/preview_world_phase1.gd"
const P=preload("res://scripts/chant_profile.gd")
const Sim=preload("res://scripts/mana_simulator.gd")
const R=preload("res://scripts/combat_spell_resolver.gd")
const C=preload("res://scripts/m1_spell_catalog.gd")
const Rules=preload("res://scripts/mana_overdraw.gd")
const Save=preload("res://scripts/character_save.gd")
const Research=preload("res://scripts/character_research.gd")
const H=preload("res://tests/test_chant.gd")
const DIR="res://.task002_artifacts/phase4_integrated/"
func simulated(profile,element:String,actions:Array,context:Dictionary={}) -> Dictionary:
	return Sim.simulate(profile,D.inputs(profile,element,actions),true,context)
func run() -> void:
	var rows:Array=[]
	var names=preload("res://scripts/spell_names.gd")
	check(names.SOURCE["by_catalog_id"].size()==75,"All 75 canonical English names are registered as display metadata, not executable new spells")
	check(names.label("FIRE_LANCE")=="Brandlance" and names.label("FIRE_BLAST")=="Ignition","Legacy fire names follow the explicit v0.5 Korean-to-English register without changing IDs")
	for version in [1,2]:
		for seed_value in [8431,1787453028]:
			var profile=P.new();profile.load_data(P.generate(seed_value) if version==1 else P.generate_current(seed_value))
			for definition in C.definitions():
				var id:=str(definition.catalog_id);var element:=str(definition.attribute)
				var research=Research.new();research.load_data(D.character(profile.to_data(),element)["research"])
				var context:Dictionary=research.simulation_context();var actions:Array=C.PROFILES["examples"][id]
				var simulation:=simulated(profile,element,actions,context);var result:=R.resolve(simulation,element,context)
				check(result.get("spell")!=null and str(result["spell"].catalog_id)==id,id+" exact state recognition v%d seed%d"%[version,seed_value])
				check(definition.display_name==definition.english_name and definition.display_name==preload("res://scripts/spell_names.gd").label(str(definition.spell_id)),id+" authoritative English display name")
				var bad:=actions.duplicate();bad.append_array(["COMPRESS","COMPRESS","COMPRESS","COMPRESS"])
				check(R.resolve(simulated(profile,element,bad,context),element,context).get("spell")==null,id+" overcompression is not an unconditional recipe suffix")
				if seed_value==1787453028:rows.append({"profile_version":version,"id":id,"name":definition.display_name,"keys":D.inputs(profile,element,actions).map(func(e):return e["key"]),"cost":result.get("mana_cost"),"state":simulation["final_state"]})
	var profile=P.new();profile.load_data(P.generate(1787453028))
	for definition in C.definitions():
		var attainable:=true
		for innate in P.OHAENG:
			var actions:Array=C.PROFILES["examples"][str(definition.catalog_id)].duplicate()
			actions.insert(1,"STABILIZE") # Safety control before a shaped shell exists.
			var ctx:Dictionary={"innate_element":innate,"main_attribute":str(definition.attribute)}
			var resolved:=R.resolve(simulated(profile,str(definition.attribute),actions,ctx),str(definition.attribute),ctx)
			attainable=attainable and resolved.get("spell")!=null and resolved["spell"].catalog_id==definition.catalog_id
		check(attainable,str(definition.catalog_id)+" remains attainable across all five innate affinities without rerolling its key table")
	for definition in C.definitions():
		var state:Dictionary=simulated(profile,str(definition.attribute),C.PROFILES["examples"][str(definition.catalog_id)])["final_state"]
		var different:=0
		for other in P.OHAENG:
			if other!=str(definition.attribute) and C.select(state,other)==null:different+=1
		check(different>=3,str(definition.catalog_id)+" is not a universal template under a different first word")
	var changed:=R.resolve(simulated(profile,"WATER",["ACCUMULATE","ACCUMULATE","DIRECT","DIRECT","SHAPE"]),"WATER")
	check(changed.get("spell")!=null and changed["spell"].catalog_id==&"OH-063","Shaping a directed Tidebolt distributes pressure and changes the actual spell to Ebbpulse")
	var auxiliary=D.character(profile.to_data(),"WATER_METAL")["research"]
	var research=Research.new();research.load_data(auxiliary);var context:Dictionary=research.simulation_context()
	for id in ["OH-046","OH-047","OH-048"]:
		check(R.resolve(simulated(profile,"METAL",C.PROFILES["examples"][id],context),"WATER",context)["state"]=="locked",id+" auxiliary single forbidden in resolver")
	for wall in [false,true]:
		var inputs=D.fusion_inputs(profile,"WATER","METAL",wall)
		check(R.resolve(Sim.simulate(profile,inputs,true,context),"WATER",context).get("spell")!=null,"Main+first auxiliary fusion remains executable")
	check(research.ritual_eligibility("FIRE")=="slots_full" and research.start_element_research("FIRE",123)=="slots_full","Second auxiliary cannot be requested or committed via non-UI calls")
	var historical:Dictionary=auxiliary.duplicate(true);historical["auxiliary_attributes"]=["METAL","FIRE"]
	historical["binding_studies"]=["METAL+WATER","FIRE+WATER"]
	check(research.load_data(historical).is_empty() and research.auxiliary_attributes==PackedStringArray(["METAL"]),"Old second auxiliary becomes inactive")
	check(research.to_data()["inactive_attribute_history"]["original_roles"]["auxiliary_attributes"]==["METAL","FIRE"],"Old permanent choice is archived intact")
	var historical_doc:Dictionary=D.character(profile.to_data(),"WATER_METAL");historical_doc["schema_version"]=4;historical_doc["research"]=historical
	var book=preload("res://scripts/spell_discoveries.gd").new()
	book.record("WIND_PRESSURE_BOLT","풍압탄",D.fusion_inputs(profile,"FIRE","WATER"),6,"LAB",["FIRE","WATER"])
	historical_doc["spell_discoveries"]=book.to_data()
	var historical_path:=DIR+"old_second_aux_%d.json"%Time.get_ticks_usec();A.write(historical_path,historical_doc)
	var historical_bytes:=FileAccess.get_file_as_bytes(historical_path)
	var historical_game=Scene.instantiate();historical_game.save_path=historical_path;root.add_child(historical_game);historical_game.set_process(false)
	check(historical_game.save_writable and historical_game.research.auxiliary_attributes==PackedStringArray(["METAL"]),"Real saved second auxiliary migrates and loads with only the first active")
	check(FileAccess.get_file_as_bytes(historical_path+".v4.bak")==historical_bytes,"Second auxiliary migration preserves the exact original backup")
	check(H.equal(historical_game.discovered.to_data(),historical_doc["spell_discoveries"]) and historical_game.discovered.entries()[0]["name"]=="WIND_PRESSURE_BOLT","Historical forbidden-now discovery remains stored verbatim but displays its English ID")
	check(historical_game.research.study_binding("FIRE")=="confirmed_auxiliary_required","An inactive historical auxiliary cannot regain binding authority")
	historical_game.free()
	check(not preload("res://scripts/fusion_rules.gd").authorized(["FIRE","WATER"],"WATER",["METAL","FIRE"]),"Direct fusion authorization ignores a second auxiliary even if manually supplied")
	for p in [0.0,0.0001,0.25,0.5,0.75,1.0]:
		check(is_equal_approx(Rules.speed(30*p,100),1-.5*p) and is_equal_approx(Rules.blur(30*p,100),0 if p==0 else .075+.425*p),"Nonnegative debt keeps continuous speed/blur "+str(p))
	var q:=Rules.quote(5,100,15)
	check(q["allowed"] and q["next_mana"]==0 and q["next_debt"]==10,"Five mana pays fifteen automatically without a negative wallet")
	check(Rules.quote(0,100,20,10)["allowed"] and not Rules.quote(0,100,20.001,10)["allowed"],"Existing debt is included in the 30% limit")
	check(Rules.recover(0,10,100,6)==Vector2(0,4) and Rules.recover(0,10,100,12)==Vector2(2,0),"Recovery repays debt before refilling visible mana")
	var duplicate:Dictionary={"world":{"vitals":{"mana":-15,"mana_debt":15}}}
	var upgrade=preload("res://scripts/save_upgrade.gd")
	var upgraded:Dictionary=upgrade.document(duplicate)
	check(upgraded["world"]["vitals"]=={"mana":0.0,"mana_debt":15.0} and H.equal(upgrade.document(upgraded),upgraded),"Mixed legacy negative mana/debt is never added twice and migration is idempotent")
	check(not Save.valid_resources({"world":{"vitals":{"mana":1,"mana_debt":1}}}),"Persistence rejects a positive wallet while internal debt remains")
	for action in P.ADVANCED_ACTIONS:
		var current=P.new();current.load_data(P.generate_current(1787453028))
		check(simulated(current,"WATER",["ACCUMULATE",action])["state"]=="failed",action+" locked without research")
		var allowed:=simulated(current,"WATER",["ACCUMULATE","SHAPE",action],{"advanced_operations":[action],"technique_rank":4})
		check(allowed["final_state"]["advanced_used"] and allowed["final_state"]!=allowed["casting_steps"][-1]["before"],action+" has a real unlocked state effect")
		check(simulated(current,"WATER",["ACCUMULATE",action],{"advanced_operations":[action],"technique_rank":3})["state"]=="failed",action+" independently requires the technique rank")
	var ordinary:=simulated(profile,"WATER",["ACCUMULATE","ACCUMULATE","DIRECT","DIRECT"])
	var reordered:=simulated(profile,"WATER",["DIRECT","DIRECT","ACCUMULATE","ACCUMULATE"])
	check(H.equal(ordinary["final_state"],reordered["final_state"]),"Different paths really reach the exact same final state")
	check(R.resolve(ordinary,"WATER")["spell"].catalog_id==R.resolve(reordered,"WATER")["spell"].catalog_id,"Same state selects same spell without inspecting raw keys")
	var raw=F.fixture("WATER",1787453028);raw["schema_version"]=4;raw["world"]=preload("res://scripts/world/world_progress.gd").defaults();raw["world"]["vitals"]={"hp":100,"mana":-15,"focus":83};raw["unknown"]="keep"
	var path:=DIR+"legacy_negative_%d.json"%Time.get_ticks_usec();A.write(path,raw);var original:=FileAccess.get_file_as_bytes(path)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false)
	check(game.save_writable and game.player_mana==0 and game.mana_debt==15,"v4 negative mana loads as zero plus internal debt")
	check(FileAccess.get_file_as_bytes(path+".v4.bak")==original,"Migration creates an exact original v4 backup")
	var after:Dictionary=Save.load_file(path)["data"]
	check(after["schema_version"]==5 and after["world"]["vitals"]["mana"]==0 and after["world"]["vitals"]["mana_debt"]==15 and after["unknown"]=="keep","v5 persistence carries debt and unknown fields")
	game.free();game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false)
	check(game.player_mana==0 and game.mana_debt==15,"Restart never doubles legacy debt")
	game._recover_mana(16);check(game.player_mana==1 and game.mana_debt==0,"Actual controller recovery follows debt-first repayment")
	game._start_developer_test("WATER_METAL","LAB");game.laboratory_panel.arena.set_process(false)
	game.laboratory_panel.show_trial();game.player_mana=5;game.mana_debt=0
	A.enter_keys(game,D.inputs(game.chant_profile,"WATER",C.PROFILES["examples"]["OH-061"]).map(func(e):return e["key"]))
	game._cast_spell();check(game.player_mana==0 and game.mana_debt==4 and game.journal.records().size()==1,"Actual cast manifests, records and commits one internal shortage payment")
	var arena=game.laboratory_panel.arena
	var previous_missiles:int=arena.missiles.size();var previous_debt:float=game.mana_debt
	A.enter_keys(game,D.inputs(game.chant_profile,"METAL",C.PROFILES["examples"]["OH-046"]).map(func(e):return e["key"]))
	game._cast_spell();check(arena.missiles.size()==previous_missiles and game.mana_debt==previous_debt and game.cast_feedback.contains("주속성"),"Auxiliary denied before payment and manifestation with an explanation")
	check(not arena.combat.cast(arena,C.find("OH-046"),Vector2.RIGHT),"Direct executor call cannot bypass auxiliary permission")
	for rank in [0,1,2,3,4]:
		var forbidden=C.find("OH-046").duplicate();forbidden.combat_rank=rank
		check(not arena.combat.cast(arena,forbidden,Vector2.RIGHT) and game.mana_debt==previous_debt,"Auxiliary single executor denies grade %d independently of UI or resource payment"%rank)
	check(arena.player_view.get_script()==game.player_view.get_script() and arena.body.scale==game.player_view.body.scale and arena.camera.zoom==Vector2.ONE and arena.actors.y_sort_enabled,"Lab reuses world character, scale, camera zoom and Y sorting")
	check(arena.navigation.request(arena,Vector2(695,390)) and arena.navigation.corrected and not arena._is_blocked(arena.navigation.destination),"Lab corrects blocked prop clicks to a reachable radius-safe destination")
	var state_before:=Vector2(game.player_mana,game.mana_debt);var pos_before:Vector2=arena.player_pos
	game.laboratory_panel.show_journal();game.laboratory_panel.show_trial()
	check(Vector2(game.player_mana,game.mana_debt)==state_before and arena.player_pos==pos_before,"Observation/trial switching does not reset actor resources or position")
	game._end_developer_test();game.free()
	var learned_fixture:Dictionary=F.fixture("WATER",1787453028)
	learned_fixture["learned"]=["MANA_BOLT","WATER_PUSH","OH-062","OH-063","ICE_CRYSTAL_NEEDLE","ICE_CRYSTAL_BARRIER","OH-047","OH-048"]
	var learned_path:=DIR+"detached_learned_%d.json"%Time.get_ticks_usec();A.write(learned_path,learned_fixture)
	game=Scene.instantiate();game.save_path=learned_path;root.add_child(game);game.set_process(false)
	var detached:Dictionary=game._character_document()
	game.learned_spells.append("DETACHMENT_PROBE")
	check("DETACHMENT_PROBE" not in detached["learned"],"Character snapshots do not alias the live learned-spell array")
	game.learned_spells.pop_back()
	var independent:Dictionary=game._character_document().duplicate(true)
	var learned_disk:=FileAccess.get_file_as_bytes(learned_path)
	for option in D.OPTIONS:
		game._start_developer_test(option,"LAB")
		check(detached["learned"]==learned_fixture["learned"],"Starting "+option+" never clears the independent original snapshot")
		check(game._end_developer_test() and H.equal(game._character_document(),independent) and FileAccess.get_file_as_bytes(learned_path)==learned_disk,"Ending "+option+" restores all original learned IDs and character fields")
	game.free()
	var report:=FileAccess.open(DIR+"verified_paths.json",FileAccess.WRITE);report.store_string(JSON.stringify(rows,"\t"));report.close()
	print("PHASE4 INTEGRATED: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
