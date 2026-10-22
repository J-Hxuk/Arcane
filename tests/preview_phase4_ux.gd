extends "res://tests/preview_phase4_m1.gd"
const Journal = preload("res://scripts/experiment_journal.gd")
const Profile = preload("res://scripts/chant_profile.gd")
func click_control(control:Control) -> void:
	if control.get_viewport()==root:
		await super.click_control(control); return
	await process_frame
	var point:=control.get_global_rect().get_center()+Vector2(control.get_viewport().position)
	Input.warp_mouse(point); await process_frame
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; Input.parse_input_event(motion); await process_frame
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); await process_frame
	event.pressed=false; Input.parse_input_event(event); await process_frame
func click_trial(point:Vector2, button:=MOUSE_BUTTON_RIGHT) -> void:
	await aim_trial(point)
	var event:=InputEventMouseButton.new(); event.position=game.laboratory_panel.arena.world_to_screen(point); event.global_position=event.position; event.button_index=button; event.pressed=true
	Input.parse_input_event(event); await process_frame
	event.pressed=false; Input.parse_input_event(event); await process_frame
func focus() -> void:
	for pressed in [true,false,true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_SHIFT; event.physical_keycode=KEY_SHIFT; event.pressed=pressed; Input.parse_input_event(event)
	Input.flush_buffered_events(); await process_frame
func button_named(parent:Node, text:String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text==text: return child
		var found:=button_named(child,text)
		if found!=null:return found
	return null
func run() -> void:
	root.size=Vector2i(1160,720); root.gui_embed_subwindows=true
	var path:=OUT+"ux_window.json"; A.write(path,F.fixture("WATER",1787453028))
	game=Scene.instantiate(); game.save_path=path; root.add_child(game); game.set_process(false); await process_frame
	await key(KEY_ALT,true); game._process(0.1)
	check(not game.focus_active,"Ordinary world no longer exposes the archived Alt sense growth path"); await key(KEY_ALT,false)
	game.player_pos=game.layout.LAB_DOOR; game._enter_laboratory(); await process_frame
	await click_control(game.laboratory_panel.trial_button); var arena=game.laboratory_panel.arena; arena.set_process(false)
	await click_trial(Vector2(530,300)); var goal:Vector2=arena.navigation.destination
	for i in 120:arena.advance(0.025)
	check(not arena.navigation.active and arena.player_pos.distance_to(goal)<1,"Actual RMB moves the controllable experiment character to arrival")
	await aim_trial(arena.player_pos+Vector2(-100,0)); var before:Vector2=arena.player_pos; await tap(KEY_CTRL); arena.advance(0.18)
	check(arena.player_pos.x<before.x-100,"Actual Ctrl in the experiment arena follows cursor heading")
	arena.reset_targets(); arena.player_pos=Vector2(270,210); game.player_attack_cooldown=0
	await click_trial(Vector2(330,210),MOUSE_BUTTON_LEFT)
	check(arena.enemies[0]["hp"]<200,"Actual LMB sword attack affects an experiment target")
	game._reset_combat_input(); await key(KEY_SHIFT,true); await tap(KEY_E); await tap(KEY_F)
	check(game.runes==["E","F"] and not game.laboratory_panel.awakening_panel.visible,"Shift E/F are chant words, never duplicate facility interactions")
	await tap(KEY_SPACE); var count:int=game.journal.records().size(); await key(KEY_SHIFT,false)
	check(game.runes.is_empty() and game.journal.records().size()==count and arena.missiles.is_empty(),"Actual Space cancellation prevents the later Shift-up from releasing")
	game._reset_combat_input(); arena.reset_targets(); arena.player_pos=Vector2(180,210); game.exhaustion_seconds=0; await focus()
	var position:Vector2=arena.player_pos; await click_trial(Vector2(600,300)); game.player_mana=20; game._process(0.5); arena.advance(0.5)
	check(game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST and arena.player_pos==position and game.player_mana==28,"Actual double Shift keeps experiment movement locked and restores 16 mana/s")
	game.player_mana=game._max_mana()
	for input in D.inputs(game.chant_profile,"WATER",D.basic_actions("WATER")):await tap(OS.find_keycode_from_string(input["key"]))
	count=game.journal.records().size(); await click_trial(Vector2(330,210),MOUSE_BUTTON_LEFT)
	for i in 20:arena.advance(0.025)
	check(arena.enemies[0]["hp"]<200 and game.journal.records().size()==count+1 and game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST,"Focus LMB manifests and records once without leaving focus")
	await tap(KEY_SPACE); game.player_mana=20; game._process(0.5)
	check(game.combat_input.mode==game.CombatInput.Mode.NORMAL and game.player_mana==24,"Space exits focus and restores 8 mana/s in the actual window")
	await tap(KEY_J); check(game.spell_record_hud.expanded and game.spell_record_hud.visible,"J HUD remains visible over the experiment arena"); await shot("trial_J_hud"); await tap(KEY_J)
	arena.player_pos=Vector2(630,130); await tap(KEY_E)
	check(game.research.has_clue("WOOD","environment") and game.research.main_attribute=="WATER","Actual E observes an elemental catalyst without changing permanent roles")
	game.laboratory_panel.show_journal(); await process_frame
	var empty:=preload("res://scripts/mana_simulator.gd").simulate(game.chant_profile,[{"key":"X","at_ms":0,"hold_ms":0}])
	for i in 100:game.journal.append(empty,"failed",0,0,1)
	var protected_id:int=game.journal.append(empty,"failed",0,0,1); game.journal.protect(protected_id,true); game._save_character()
	var mapping:Dictionary=game.chant_profile.to_data(); var research:Dictionary=game.research.to_data(); var book:Dictionary=game.discovered.to_data()
	var total:int=game.journal.records().size(); var removable:=0
	for record in game.journal.records():
		if Journal.category(record)=="no_result":removable+=1
	var eligible:int=game.journal.eligible_ids(game.journal.records().filter(func(r):return Journal.category(r)=="no_result").map(func(r):return r.id),[]).size()
	await click_control(button_named(game.laboratory_panel.panel,"기록 관리")); var manager=game.journal_manager
	await choose(manager.filter,2); check(manager.list.item_count==removable,"Actual no-result filter shows exactly the bulk-deletion candidates")
	check(manager.position.y>=0 and manager.position.y+manager.size.y<=720,"Journal manager remains fully inside the actual viewport after layout")
	await click_control(button_named(manager,"결과 없는 기록 일괄삭제")); await shot("journal_delete_confirmation")
	check(manager.confirm.visible and manager.confirm.dialog_text.contains(str(eligible)),"Actual bulk deletion confirms eligible count separately from visible preserved rows")
	await click_control(manager.confirm.get_cancel_button()); check(game.journal.records().size()==total,"Cancel on the actual confirmation changes no records")
	await click_control(button_named(manager,"결과 없는 기록 일괄삭제")); await click_control(manager.confirm.get_ok_button())
	check(game.journal.records().size()==total-eligible and FileAccess.file_exists(path+".journal_delete.bak"),"Actual confirmation deletes only eligible records and creates a recovery backup")
	check(game.chant_profile.to_data()==mapping and game.research.to_data()==research and game.discovered.to_data()==book,"Actual deletion preserves mapping, permanent research and discovered chants")
	await click_control(button_named(manager,"마지막 삭제 복구")); check(game.journal.records().size()==total,"Actual restore button recovers the deleted journal entries")
	await shot("journal_manager"); manager.hide(); game._leave_laboratory(); await process_frame
	check(game.player_pos==game.layout.LAB_DOOR and game.game_state=="DUNGEON","Laboratory exit returns to the physical town doorway")
	game.player_pos=Vector2(1000,530); game._sync_world_view(); await process_frame; await tap(KEY_E)
	for element in Profile.OHAENG:
		await click_control(game.world_dialog.find_child("Book_"+element,true,false)); check(game.book_view.element==element and game.research.has_clue(element,"book"),"Actual library shelf selects and records "+element)
	await click_control(button_named(game.world_dialog,"다음 페이지")); check(game.book_view.page==1,"Actual book navigation changes the displayed page"); await shot("library_page2"); game.world_dialog.hide()
	for entry in game.layout.interactions:
		if not str(entry["id"]).begins_with("mentor_"):continue
		game.player_pos=entry["pos"]; game._sync_world_view(); await process_frame; await tap(KEY_E)
		check(game.mentor_dialog.visible and game.research.has_clue(str(entry["id"]).trim_prefix("mentor_"),"mentor"),"Actual E reaches the physical mentor "+entry["id"]); game.mentor_dialog.hide()
	game.player_pos=Vector2(450,1230);game.world_camera.zoom=Vector2.ONE*0.85;await shot("mentor_house")
	game.free()
	var current:=F.fixture("WATER",8431); current["chant"]=Profile.generate_current(8431); A.write(path,current)
	game=Scene.instantiate(); game.save_path=path; root.add_child(game); game.set_process(false); game.player_pos=game.layout.LAB_DOOR; game._enter_laboratory(); game.laboratory_panel.show_trial(); await process_frame
	await key(KEY_SHIFT,true)
	for physical in Profile.TWELVE_KEYS:await tap(OS.find_keycode_from_string(physical))
	await tap(KEY_T); await tap(KEY_G)
	check(Array(game.runes)==Profile.TWELVE_KEYS,"Actual v2 mobile casting accepts all twelve keys and excludes archived T/G")
	await tap(KEY_SPACE); await key(KEY_SHIFT,false); game._reset_combat_input(); game.exhaustion_seconds=0
	await key(KEY_SHIFT,true)
	for input in D.inputs(game.chant_profile,"WATER",D.basic_actions("WATER")):await tap(OS.find_keycode_from_string(input["key"]))
	await aim_trial(Vector2(360,210)); count=game.journal.records().size(); await key(KEY_SHIFT,false)
	check(game.journal.records().size()==count+1 and game.journal.records()[-1]["profile_version"]==2 and game.discovered.entries().size()==1,"Actual v2 Shift release creates a versioned successful M1 record")
	await shot("twelve_key_trial"); game.free()
	print("PHASE4 UX WINDOW: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
