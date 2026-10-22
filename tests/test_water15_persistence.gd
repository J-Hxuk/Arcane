extends "res://tests/test_water15_integration.gd"
func run()->void:
	root.size=Vector2i(1160,720);var path:=fresh();await process_frame
	var old_records:Array=game.journal.records();var mapping:Dictionary=game._active_profile().to_data()
	game.research.developer_reset("all_elements","");game.research.set_active("WATER",null);game.magic_talent=80
	game._water_qa_build_cases();game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();var arena=game.laboratory_panel.arena;arena.set_process(false)
	for item in WATER.DATA.spells:
		game._reset_combat_input();arena.reset_targets();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
		chant(game.water_qa_cases[item.id].off.actions);game._cast_spell()
		check(game.discovered.to_data().spells.has(item.id),item.id+" ordinary character automatically discovers without learning gate")
	check(game._save_character(),"All15 discoveries and actual lab snapshots save through normal persistence")
	var expected:Dictionary=game._character_document();var retained:Array=game.journal.records()
	game.free();game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and game.discovered.to_data().spells.size()>=15,"Real scene restart restores all15 discoveries")
	check(Equal.equal(game.journal.records(),retained) and Equal.equal(game._active_profile().to_data(),mapping),"Restart retains exact stored snapshots and original personal mapping")
	# Old snapshots are opaque historical data, never rerun through raw/F effects.
	var journal=preload("res://scripts/experiment_journal.gd").new();var data=game.journal.to_data()
	var historic:Dictionary=data.records.back().duplicate(true);historic.id=data.next_id;data.next_id+=1
	historic.erase("property_version");historic.result.terminal_snapshot.erase("property_version");historic.result.terminal_snapshot.erase("formula_effect");historic.result.terminal_snapshot["historic_marker"]="clipped calculation retained";data.records.append(historic)
	check(journal.load_data(data).is_empty() and journal.records().back()==historic,"Legacy clipped snapshot loads unchanged without calculation version rewrite")
	game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();arena=game.laboratory_panel.arena;arena.set_process(false)
	for item in WATER.DATA.spells:
		game._reset_combat_input();arena.reset_targets();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
		chant(game.water_qa_cases.get(item.id,{}).get("on",{}).get("actions",item.actions))
		# Rebuild after restart when transient QA cases intentionally are absent.
		if game._inspect_chant(true).get("spell")==null:chant(item.actions)
		var effects_before={"enemies":arena.enemies.duplicate(true),"missiles":arena.missiles.duplicate(true),"states":arena.combat.water_states.duplicate(true),"metrics":arena.combat.water_metrics.duplicate(true),"visuals":arena.combat.visuals.duplicate(true)}
		var mana:float=game.player_mana;var debt:float=game.mana_debt;var book:Dictionary=game.discovered.to_data();var records:Dictionary=game.journal.to_data()
		game.save_path=AUDIT+"missing_parent/no_save.json";game._cast_spell();game.save_path=path
		check(game.player_mana==mana and game.mana_debt==debt and game.journal.to_data()==records and game.discovered.to_data()==book,item.id+" save failure atomically restores payment, journal and discovery")
		check(arena.enemies==effects_before.enemies and arena.missiles==effects_before.missiles and arena.combat.water_states==effects_before.states and arena.combat.water_metrics==effects_before.metrics and arena.combat.visuals==effects_before.visuals,item.id+" save failure rolls back transient fields, shields, scheduled rings and visual state")
	# Mana shortage is denied before any combat effect or partial payment.
	game._reset_combat_input();arena.reset_targets();game.player_mana=0;game.mana_debt=game.ManaOverdraw.limit(game._max_mana());chant(WATER.DATA.spells.back().actions)
	var mana:float=game.player_mana;var debt:float=game.mana_debt;game._cast_spell()
	check(game.player_mana==mana and game.mana_debt==debt and arena.missiles.is_empty() and arena.combat.water_states.is_empty(),"Overdraw cap rejects expensive water spell without partial payment/effects")
	check(not preload("res://scripts/developer_access.gd").allowed(false,true,true,true),"Release policy denies QA and all developer controls")
	await finish("WATER15 PERSISTENCE")
