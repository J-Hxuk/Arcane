extends "res://tests/preview_world_phase1.gd"
const H=preload("res://tests/test_chant.gd")
const J=preload("res://scripts/experiment_journal.gd")
const EngineV2=preload("res://scripts/chant_engine_v2.gd")
func run()->void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/phase4_qa_v2/user_before.json"))
	var path="res://.task002_artifacts/phase4_qa_v2/ux_%d.json"%Time.get_ticks_usec();A.write(path,data)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes=FileAccess.get_file_as_bytes(path)
	check(game.journal.records().size()==data.laboratory.records.size(),"Existing hundreds of observations are not pruned on load")
	var preview:Dictionary=game._preview_journal_retention()
	check(FileAccess.file_exists(path+".journal_retention.bak") and FileAccess.get_file_as_bytes(path+".journal_retention.bak")==bytes,"Retention preview backs up exact original bytes first")
	check(game._character_document()==original and not preview.remove.is_empty(),"Preview gives a selection opportunity without any mutation")
	var first=game.journal.records()[0].id;game._protect_journal_records([first],true)
	preview=game._preview_journal_retention()
	check(first in preview.keep and first not in preview.remove,"User preservation is respected in the migration preview")
	check(game._confirm_journal_retention(preview.remove),"Only explicit confirmation applies initial retention")
	check(game.journal.records().size()==preview.keep.size() and not game.journal.retention_pending(),"Trimmed observations equal the exact reviewed keep set")
	var after:Dictionary=game._character_document()
	for field in ["learned","chant","research","spell_discoveries","world"]:check(H.equal(after[field],original[field]),"Retention preserves permanent "+field)
	check(game._restore_journal_delete(),"Initial retention supports the existing undo mechanism")
	game._start_prototype_all("LAB")
	var arena=game.laboratory_panel.arena;arena.set_process(false)
	var current:Dictionary=game._character_document().duplicate(true)
	var props:Array=[]
	for row in EngineV2.CONFIG.spells:
		game.prototype_target=row.id # Explicit F2 target disambiguates shared compositions across elements.
		var events:=EngineV2.inputs(game.prototype_profile,row.actions)
		game.runes.assign(events.map(func(e):return str(e.key)));game.chant_inputs=events.duplicate(true)
		for event in game.chant_inputs:event["released"]=true
		var before:Dictionary=game._character_document().duplicate(true);var effects:int=arena.missiles.size();var hp:float=arena.enemies[0].hp
		for i in 5:game._update_laboratory_live()
		check(H.equal(before,game._character_document()) and effects==arena.missiles.size() and hp==arena.enemies[0].hp,"Preview has zero writes, cost, debt, discovery, damage or projectiles: "+row.id)
		var projected=preload("res://scripts/mana_visual_model.gd").project(game._inspect_chant().final_state)
		props.append(projected)
		var public=game.laboratory_panel.trial_commands.text
		check(not public.contains(row.id) and not public.contains(game._inspect_chant().spell.display_name),"Undiscovered live preview hides identity: "+row.id)
		game._clear_chant()
	check(props[0].reaction.element=="WOOD" and props[2].reaction.element=="EARTH" and props[0].reaction.strength>.25 and props[2].reaction.strength>.25,"Wood and Earth structures reveal strong progressive traces without requiring the old compressed ritual")
	var advice=preload("res://scripts/mentor_advice.gd")
	check(advice.evaluate({"mana_amount":0},"WATER").text!=advice.evaluate({"mana_amount":25,"cohesion":80},"WATER").text,"Mentor advice depends on the observed state")
	check(advice.evaluate({"stability":20},"FIRE").consulted.stability==20,"Developer advice log identifies actual consulted fields")
	game._clear_chant();game._end_developer_test();game.free()
	var journal=J.new();var fixture:Dictionary=data.laboratory.duplicate(true);fixture.records=[];fixture.next_id=1;fixture.erase("retention");journal.load_data(fixture)
	var p=preload("res://scripts/chant_profile.gd").new();p.load_data(p.generate_current(8431))
	var simulation:Dictionary=EngineV2.resolve(p,EngineV2.inputs(p,EngineV2.CONFIG.spells[0].actions),{"main_attribute":"WOOD"}).simulation
	for i in 25:
		var id:int=journal.append(simulation,"released",1,100,2)
		if i==0:journal.protect(id,true)
		journal.trim_new_records([])
	check(journal.records().size()==11 and journal.records()[0].protected,"New observations keep ten ordinary plus unlimited preserved records")
	print("PHASE4 QA UX: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
