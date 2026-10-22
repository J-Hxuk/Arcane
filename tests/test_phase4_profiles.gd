extends "res://tests/preview_world_phase1.gd"
const Profile = preload("res://scripts/chant_profile.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Catalog = preload("res://scripts/m1_spell_catalog.gd")
const M1 = preload("res://tests/test_phase4_m1.gd")
func run() -> void:
	for seed_value in [1, 8431, 1787453028]:
		var legacy := Profile.generate(seed_value)
		var current := Profile.generate_current(seed_value)
		var profile := Profile.new()
		check(profile.load_data(current).is_empty() and profile.version()==2 and current["manipulations"].size()==12, "New profile validates a complete twelve-key permutation")
		check(current["first_words"]==legacy["first_words"] and legacy["version"]==1, "First words remain seed-stable without converting the legacy table")
		for source in Catalog.SOURCE["spells"]:
			var result := Resolver.resolve(Sim.simulate(profile,D.inputs(profile,source["element"],M1.actions_for(source["id"]))),source["element"])
			check(result.get("spell")!=null and result["spell"].catalog_id==StringName(source["id"]), "Twelve-key final-state recognition: "+source["id"])
		for option in ["WATER_METAL","FIRE_WATER"]:
			var model := preload("res://scripts/character_research.gd").new(); model.load_data(D.character(current,option)["research"])
			var context := model.simulation_context()
			for reverse in [false,true]:
				var first: String=context["main_attribute"]; var second: String=context["auxiliary_attributes"][0]
				var inputs := D.fusion_inputs(profile,second if reverse else first,first if reverse else second)
				var result := Resolver.resolve(Sim.simulate(profile,inputs,false,context),first,context)
				check(result.get("spell")!=null and result["spell"].requires_elements.size()==2,"Explicit BIND authorizes one second declaration in either order: "+option)
				inputs.remove_at(3)
				check(Sim.simulate(profile,inputs,false,context)["final_state"]["base_attributes"].size()==1,"Without BIND, the same key is a manipulation, never an implicit second declaration")
		for action in Profile.ADVANCED_ACTIONS:
			check(Sim.simulate(profile,D.inputs(profile,"WATER",["ACCUMULATE",action]))["state"]=="failed","Unresearched advanced operation is gated: "+action)
		var again := Profile.new(); again.load_data(legacy)
		check(again.to_data()==legacy and again.mobile_keys()==Profile.MOBILE_KEYS,"Legacy fourteen-key table is byte-value stable and retains T/G")
	var path := "res://.task002_artifacts/phase4_m1/profile_v2.json"
	var fixture := F.fixture("WATER"); fixture["chant"]=Profile.generate_current(8431); A.write(path,fixture)
	game=Scene.instantiate(); game.save_path=path; root.add_child(game); game.set_process(false)
	check(game.save_writable and game.combat_input.profile_version==2,"Scene load routes the saved profile version to combat input: "+game.save_error)
	if not game.save_writable: game.free(); quit(1); return
	game.player_pos=game.layout.LAB_DOOR; game._enter_laboratory(); A.enter_keys(game,D.inputs(game.chant_profile,"WATER",["ACCUMULATE","DIRECT"]).map(func(input):return input["key"]))
	game._cast_spell(); var mapping:Dictionary=game.chant_profile.to_data(); game.free()
	game=Scene.instantiate(); game.save_path=path; root.add_child(game); game.set_process(false)
	check(game.chant_profile.to_data()==mapping and game.journal.records()[0]["profile_version"]==2,"Restart preserves v2 mapping and versions the actual recorded recipe")
	game.free(); print("PHASE4 PROFILES: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
