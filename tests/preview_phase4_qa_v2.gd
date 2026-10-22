extends "res://tests/preview_world_phase1.gd"
const E=preload("res://scripts/chant_engine_v2.gd")
const H=preload("res://tests/test_chant.gd")
const OUT="res://.task002_artifacts/phase4_qa_v2/"
func shot(name:String)->void:
	if game.game_state=="LAB":game.laboratory_panel.arena._update_views()
	elif game.get("world_enabled")==true:game._sync_world_view()
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func point(screen:Vector2)->void:
	Input.warp_mouse(screen);await process_frame
	var motion:=InputEventMouseMotion.new();motion.position=screen;motion.global_position=screen;Input.parse_input_event(motion);await process_frame
func click(control:Control)->void:
	await process_frame;await point(control.get_global_rect().get_center())
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_rect().get_center();event.global_position=event.position;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func run()->void:
	root.size=Vector2i(1160,720);root.gui_embed_subwindows=true
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"))
	var path:=OUT+"window_%d.json"%Time.get_ticks_usec();A.write(path,source)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes:=FileAccess.get_file_as_bytes(path)
	await tap(KEY_F2);check(game.developer_panel.panel.visible,"Actual F2 opens from the editor-compatible debug build")
	var all_button:Button
	for node in game.developer_panel.panel.find_children("*","Button",true,false):
		if node.text=="전속성 동시 시험 · 새 영창 시제품":all_button=node
	check(all_button!=null and all_button.get_global_rect().end.y<720,"All-element prototype entry is visible in the real window")
	await click(all_button);check(game.developer_mode and game._prototype_all and game.prototype_enabled,"Real click starts all-element prototype without permanent role changes")
	var arena=game.laboratory_panel.arena;arena.set_process(false);game.laboratory_panel.show_trial();await process_frame
	var outputs:Array=[]
	for row in E.CONFIG.spells:
		arena.player_pos=Vector2(180,210);arena.reset_targets();arena._update_views();arena.camera.reset_smoothing();await process_frame
		game._reset_combat_input();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
		await point(arena.world_to_screen(Vector2(490,210)))
		await key(KEY_SHIFT,true)
		var events:=E.inputs(game.prototype_profile,row.actions)
		for event in events:await tap(OS.find_keycode_from_string(event.key))
		var prediction:Dictionary=game._inspect_chant(true);var mana:float=game.player_mana;var records:int=game.journal.records().size()
		var label:String=prediction.spell.display_name
		check(prediction.state=="ready" and prediction.identity==row.id,"Actual physical keys resolve the prototype identity "+row.id)
		check(not game.laboratory_panel.trial_commands.text.contains(label),"Unknown preview hides the official spell name "+row.id)
		check(arena.missiles.is_empty() and arena.combat.barriers.is_empty() and game.player_mana==mana,"Held Shift preview has no real manifestation or resource change")
		game.laboratory_panel.show_journal() # Switching cancels; type again for the live orb shot.
		await key(KEY_SHIFT,false);game._reset_combat_input();await key(KEY_SHIFT,true)
		for event in events:await tap(OS.find_keycode_from_string(event.key))
		await shot("orb_"+row.id)
		game.laboratory_panel.show_trial();await key(KEY_SHIFT,false);game._reset_combat_input()
		await point(arena.world_to_screen(Vector2(490,210)));await key(KEY_SHIFT,true)
		for event in events:await tap(OS.find_keycode_from_string(event.key))
		prediction=game._inspect_chant(true);mana=game.player_mana
		await key(KEY_SHIFT,false)
		check(is_equal_approx(mana-game.player_mana,prediction.mana_cost) and game.developer_metrics.spell==label,"Shift-up manifests once with exactly the predicted cost: "+row.id)
		if prediction.spell.effect==&"barrier":check(arena.combat.barriers.size()==1,"Real Stoneward forms a physical obstacle")
		else:
			arena.combat.update_missiles(arena,.9,1);check(arena.enemies[0].hp<200,"Real variant affects laboratory targets: "+row.id)
		await shot("combat_"+row.id)
		game._reset_combat_input();await key(KEY_SHIFT,true)
		for event in events:await tap(OS.find_keycode_from_string(event.key))
		check(game.laboratory_panel.trial_commands.text.contains(label) and game.laboratory_panel.trial_commands.text.contains("미리보기"),"After successful discovery, live preview shows the English name and performance")
		await shot("preview_known_"+row.id)
		game._reset_combat_input();await key(KEY_SHIFT,false)
	# Physical key repeat/hold never creates another operation or accumulation bonus.
	await key(KEY_SHIFT,true);var accumulate:String=E.inputs(game.prototype_profile,["ACCUMULATE"])[0].key
	await key(OS.find_keycode_from_string(accumulate),true)
	var state:Dictionary=game._inspect_chant(true).final_state.duplicate(true)
	var echo:=InputEventKey.new();echo.keycode=OS.find_keycode_from_string(accumulate);echo.physical_keycode=echo.keycode;echo.pressed=true;echo.echo=true;Input.parse_input_event(echo);await process_frame
	await key(OS.find_keycode_from_string(accumulate),true)
	check(game.runes.size()==1 and game._inspect_chant(true).final_state==state,"OS repeat and repeated physical down do not add operations or held accumulation")
	game._reset_combat_input();await key(KEY_SHIFT,false)
	game.laboratory_panel.show_journal();await shot("public_research")
	await tap(KEY_F2);await shot("developer_catalog");await click(game.developer_panel.end_button)
	check(not game.developer_mode and not game._prototype_all and H.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"Actual F2 end restores all latest fields, personal mapping, journal and J data")
	check(game._start_prototype_all("WORLD"),"Same all-element context opens the actual guardian arena")
	for row in E.CONFIG.spells:
		var metrics:Array=[]
		var orders:Array=[row.actions.duplicate(),row.actions.duplicate()];orders[1].reverse()
		for order in orders:
			game.guardian.start(game);game.guardian.state="RECOVERY";game.guardian.timer=99
			game.player_pos=game.Guardian.HOME-Vector2(220,0);game._sync_world_view();game.world_camera.reset_smoothing();await process_frame
			game._reset_combat_input();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
			var cursor:Vector2=await aim(game.guardian.actor.pos)
			await key(KEY_SHIFT,true)
			for event in E.inputs(game.prototype_profile,order):await tap(OS.find_keycode_from_string(event.key))
			var predicted:Dictionary=game._inspect_chant(true)
			var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=cursor;press.global_position=cursor;press.pressed=true;Input.parse_input_event(press);await process_frame
			press.pressed=false;Input.parse_input_event(press);await process_frame;await key(KEY_SHIFT,false)
			check(game.developer_metrics.get("spell")==predicted.spell.display_name and is_equal_approx(game.developer_metrics.get("mana_spent",-1),predicted.mana_cost),"World LMB releases the same predicted variant "+row.id)
			if row.id=="OH-031":check(game.elemental_combat.barriers.size()==1,"World Stoneward forms a collision barrier")
			else:
				game.elemental_combat.update_missiles(game,.9,1)
				check(game.guardian.actor.hp<game.guardian.definition.max_hp,"World variant actually affects the guardian "+row.id)
			metrics.append([game.developer_metrics.impact_damage,game.developer_metrics.status_seconds,game.developer_metrics.mana_spent])
		check(metrics[0]!=metrics[1],"Reversing the actual world chant changes its measured performance "+row.id)
		await shot("boss_"+row.id)
	game._end_developer_test();check(H.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"World prototype ends with exact original data restoration")
	game.free();print("PHASE4 QA V2 WINDOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
