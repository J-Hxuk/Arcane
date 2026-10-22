extends "res://tests/preview_world_phase1.gd"
# Historical interpreter/UI fixture. Production acceptance is test_formal_phase1..9.
const E=preload("res://scripts/chant_engine_v2.gd")
const H=preload("res://tests/test_chant.gd")
const Perm=preload("res://tests/test_chant_v2.gd")
func set_chant(events:Array)->void:
	game._clear_chant();game.runes.assign(events.map(func(e):return str(e.key)));game.chant_inputs=events.duplicate(true)
	for event in game.chant_inputs:event["released"]=true
func run()->void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/phase4_qa_v2/user_before.json"))
	var path="res://.task002_artifacts/phase4_qa_v2/combat_%d.json"%Time.get_ticks_usec();A.write(path,data)
	game=Scene.instantiate();game.formal_rules=false;game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes:=FileAccess.get_file_as_bytes(path)
	check(game._start_prototype_all("LAB"),"F2 opens a single isolated all-element prototype context")
	var arena=game.laboratory_panel.arena;arena.set_process(false);game.laboratory_panel.show_trial()
	var roles:Dictionary=game.research.to_data().duplicate(true)
	for row in E.CONFIG.spells:
		for order in Perm.permutations(row.actions):
			arena.reset_targets();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
			if DisplayServer.get_name()=="headless":game.laboratory_panel.trial_panel.hide() # Fixed rightward aim in an inputless renderer.
			set_chant(E.inputs(game.prototype_profile,order))
			var preview:Dictionary=game._inspect_chant(true);var definition=preview.spell;var mana:float=game.player_mana
			game._cast_spell()
			check(is_equal_approx(mana-game.player_mana,preview.mana_cost) and game.developer_metrics.spell==definition.display_name,"Prediction and real identity/cost match "+row.id+" "+str(order))
			var actual_damage:=0.0
			if definition.effect==&"barrier":
				check(arena.combat.barriers.size()==1 and is_equal_approx(arena.combat.barriers[0].life,definition.duration),"Stoneward has the predicted physical barrier lifetime")
			else:
				check(not arena.missiles.is_empty() and is_equal_approx(arena.missiles[-1].dmg,definition.damage),"Real projectile carries the predicted variant damage")
				arena.combat.update_missiles(arena,.9,1)
				actual_damage=200-float(arena.enemies[0].hp)
				check(actual_damage>0,"Variant projectile actually hits "+row.id)
				if row.id=="OH-001":check(arena.enemies[0].get("root_remaining",0)>0,"Briarbind roots the target")
				if row.id=="OH-016":check(arena.enemies[0].get("burn_remaining",0)>0,"Emberbolt burns the target")
				if row.id=="OH-046":check(arena.enemies[1].hp<200,"Ironlance actually pierces a second target")
				if row.id=="OH-061":check(arena.enemies[0].pos.x>330,"Tidebolt actually pushes the target")
			var record:Dictionary=game.journal.records().back()
			check(record.rules_version==8 and record.profile_version==2 and record.grammar_profile==game.prototype_profile.to_data(),"Journal stores grammar v8 and the separate v2 personal table without changing original v1")
			var stored:Dictionary=game.journal.replay(int(record.id),record.steps.size()-1)
			check(stored.after==preview.simulation.casting_steps.back().after,"Replay uses the exact saved variant state, without resimulation")
			if order==row.actions:
				game._update_laboratory_live()
				check(game.laboratory_panel.live_orb.descriptor==preload("res://scripts/mana_visual_model.gd").project(stored.after),"Live and archived visual projection use identical variant state "+row.id)
	check(game.research.to_data()==roles,"All five elements and fusion were tested without changing temporary roles between casts")
	game._end_developer_test();check(H.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"All-element test exit restores latest original disk and every character field")
	check(not game.prototype_enabled and not game._prototype_all,"Developer all-element authority cannot survive exit")
	game._start_prototype_all("LAB",false)
	var legacy_count:=0
	for preset in D.OPTIONS:
		var character:Dictionary=D.character(game.chant_profile.to_data(),preset);var research=game.CharacterResearch.new();research.load_data(character.research)
		for example in D.examples(game.chant_profile,preset,research.simulation_context()):
			set_chant(example.inputs)
			var result:Dictionary=game._inspect_chant(true)
			if result.get("spell")==null or str(result.spell.spell_id)!=str(example.spell_id):print("COMPAT_MISMATCH ",JSON.stringify({"wanted":example.spell_id,"actual":str(result.get("spell")),"simulation":result.simulation,"context":game._legacy_simulation_context()}))
			check(result.get("spell")!=null and str(result.spell.spell_id)==str(example.spell_id),"All-element compatibility resolves "+example.name)
			legacy_count+=1
	check(legacy_count==21,"Existing 15 M1 + fire 2 + fusion 3 + neutral wave remain in the compatibility catalog")
	for pair in [["METAL","WATER"],["WATER","FIRE"]]:
		set_chant(D.fusion_inputs(game.chant_profile,pair[0],pair[1],false))
		var result:Dictionary=game._inspect_chant(true)
		check(result.get("spell")!=null and str(result.spell.spell_id)==("ICE_CRYSTAL_NEEDLE" if pair[0]=="METAL" else "WIND_PRESSURE_BOLT"),"All-element legacy fusion also accepts reversed declarations "+str(pair))
	set_chant([{"key":"Q","at_ms":0,"hold_ms":0},{"key":"E","at_ms":100,"hold_ms":0}])
	check(game._inspect_chant(true).get("spell")==game.spell_book.MANA_BOLT,"The 22nd legacy spell, pure Mana Bolt, remains available")
	game._end_developer_test();game.free()
	print("PHASE4 QA COMBAT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
