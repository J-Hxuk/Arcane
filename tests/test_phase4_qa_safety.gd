extends "res://tests/preview_world_phase1.gd"
# Historical interpreter/UI fixture. Production acceptance is test_formal_phase1..9.
const E=preload("res://scripts/chant_engine_v2.gd")
const H=preload("res://tests/test_chant.gd")
func chant(events:Array)->void:
	game._clear_chant();game.runes.assign(events.map(func(e):return str(e.key)));game.chant_inputs=events.duplicate(true)
	for event in game.chant_inputs:event["released"]=true
func run()->void:
	var path="res://.task002_artifacts/phase4_qa_v2/safety_%d.json"%Time.get_ticks_usec()
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/phase4_qa_v2/user_before.json"));A.write(path,source)
	game=Scene.instantiate();game.formal_rules=false;game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes:=FileAccess.get_file_as_bytes(path)
	game._start_developer_test("WATER_METAL","LAB");game._enable_prototype(true)
	var arena=game.laboratory_panel.arena;arena.set_process(false)
	var events:=E.inputs(game.prototype_profile,E.CONFIG.spells[4].actions)
	game.developer_mode=false;game.save_path="res://.task002_artifacts/phase4_qa_v2/not_created/save.json"
	game.player_mana=5;game.mana_debt=0;chant(events)
	var before:Dictionary=game._character_document().duplicate(true);var targets:Array=arena.enemies.duplicate(true)
	game._cast_spell()
	check(game.player_mana==5 and game.mana_debt==0 and arena.missiles.is_empty() and targets==arena.enemies,"Save failure rolls back debt, mana, actual projectile and target effects")
	check(H.equal(before,game._character_document()),"Failed v8 transaction preserves journal, discoveries, learned list, keys and research")
	game._clear_chant();game.exhaustion_seconds=0;var empty_mana:float=game.player_mana;game._cast_spell()
	check(game.player_mana==empty_mana,"An empty manual release never spends failure mana")
	check(not preload("res://scripts/chant_identity.gd").allowed({"elements":["WATER","METAL","FIRE"]},{"developer_all":true}),"Even developer all-element permission cannot authorize three-element fusion")
	game.save_path=path+".failed_casts.json";game.player_mana=5;game.mana_debt=0;game.exhaustion_seconds=0
	chant(E.inputs(game.prototype_profile,["ACCUMULATE","ACCUMULATE"]));game._cast_spell()
	check(game.player_mana==4 and game.mana_debt==0 and game.journal.records().back().result.energy_spent==1,"Ordinary misfire pays exactly the separately configured one-point failure cost")
	game.player_mana=5;game.exhaustion_seconds=0;chant(E.inputs(game.prototype_profile,["COMPRESS","COMPRESS","COMPRESS"]));game._cast_spell()
	check(game.player_mana==3 and game.mana_debt==0 and game.journal.records().back().result.energy_spent==2,"Deterministic collapse pays exactly two points without inventing mental debt")
	game.player_mana=0;game.mana_debt=game.ManaOverdraw.limit(game._max_mana());chant(events);game._cast_spell()
	check(game.player_mana==0 and game.mana_debt==game.ManaOverdraw.limit(game._max_mana()) and arena.missiles.is_empty(),"Over-limit v8 spell cannot partially spend resources")
	var invalid:=E.resolve(game.prototype_profile,[false],game._prototype_context())
	check(invalid.state=="failed" and invalid.get("spell")==null,"Malformed non-UI event safely fails")
	var descending:=events.duplicate(true);descending[0].at_ms=500
	check(E.resolve(game.prototype_profile,descending,game._prototype_context()).state=="failed","Invalid non-UI time order is rejected")
	var locked:=E.resolve(game.prototype_profile,E.inputs(game.prototype_profile,["EXPAND","DIRECT","SHAPE"]),game._prototype_context())
	check(locked.state=="locked","An unmatched advanced composition still cannot bypass research")
	for i in 6:game._on_command_entered(str(events[i%3].key))
	check(game.runes.size()<=5 and game._inspect_chant().state=="failed","Physical UI overflow invalidates the session instead of silently casting its prefix")
	game.developer_mode=true;game._end_developer_test()
	check(not game._prototype_all and not game.prototype_enabled and H.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"Even failed normal-mode fixtures restore the exact original F2 character")
	game.free();print("PHASE4 QA SAFETY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
