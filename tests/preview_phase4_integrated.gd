extends "res://tests/preview_world_phase1.gd"
const C=preload("res://scripts/m1_spell_catalog.gd")
const H=preload("res://tests/test_chant.gd")
const OUT="res://.task002_artifacts/phase4_integrated/"
func shot(label:String) -> void:
	game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func point(screen:Vector2) -> void:
	Input.warp_mouse(screen);await process_frame
	var e:=InputEventMouseMotion.new();e.position=screen;e.global_position=screen;Input.parse_input_event(e);await process_frame
func lab_click(world:Vector2,button:=MOUSE_BUTTON_RIGHT) -> void:
	var screen:Vector2=game.laboratory_panel.arena.world_to_screen(world);await point(screen)
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.position=screen;e.global_position=screen;e.button_index=button;e.pressed=pressed
		Input.parse_input_event(e);await process_frame
func chant(element:String,id:String,auto:=true) -> void:
	game._reset_combat_input();await key(KEY_SHIFT,true)
	for e in D.inputs(game.chant_profile,element,C.PROFILES["examples"][id]):await tap(OS.find_keycode_from_string(e["key"]))
	if auto:
		await point(game.laboratory_panel.arena.world_to_screen(game.laboratory_panel.arena.enemies[0]["pos"]))
		check(game.laboratory_panel.arena.aim_world_position().distance_to(game.laboratory_panel.arena.enemies[0]["pos"])<1,"Root cursor round-trip matches the laboratory target after camera movement")
		await key(KEY_SHIFT,false)
func render_stats(debt:float) -> Dictionary:
	game.player_mana=0;game.mana_debt=debt;game._update_mana_exhaustion(2)
	game._update_laboratory_live()
	for i in 60:await process_frame
	var frames:Array[float]=[];var draws:=0.0
	for i in 60:
		var start:=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
		frames.append((Time.get_ticks_usec()-start)/1000.0);draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	frames.sort()
	return {"debt":debt,"median_ms":frames[30],"p95_ms":frames[57],"fps":Performance.get_monitor(Performance.TIME_FPS),"draw_calls":draws/60}
func run() -> void:
	root.size=Vector2i(1160,720);root.gui_embed_subwindows=true
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"))
	var path:=OUT+"window_user_copy_%d.json"%Time.get_ticks_usec();A.write(path,data)
	var source:=FileAccess.get_file_as_bytes(path)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and FileAccess.get_file_as_bytes(path+".v4.bak")==source,"Actual window loads a copy of the current user and backs up its v4 bytes")
	var original:Dictionary=game._character_document().duplicate(true);var bytes:=FileAccess.get_file_as_bytes(path)
	await tap(KEY_F2);check(game.developer_panel.panel.visible,"F5-compatible debug build exposes F2 without a CMD")
	game.developer_panel.elements.select(D.OPTIONS.find("WATER_METAL"));game.developer_panel.location.select(0);game.developer_panel.start_button.pressed.emit();await process_frame
	var arena=game.laboratory_panel.arena;arena.set_process(false);game.laboratory_panel.show_trial();await process_frame
	check(game.developer_mode and game.research.main_attribute=="WATER" and game.research.auxiliary_attributes==PackedStringArray(["METAL"]),"F2 preset uses an isolated Water+Metal temporary character")
	check(arena.body.sprite_frames.get_animation_names().size()==4 and arena.body.scale==game.player_view.body.scale and arena.camera.zoom==game.world_camera.zoom,"Rendered lab shares four directions, foot scale and default camera zoom")
	var start:Vector2=arena.player_pos;await lab_click(start+Vector2(200,0));arena.advance(.25)
	check(arena.player_pos.distance_to(start+Vector2(50,0))<.5,"Actual lab RMB advances exactly the same 200px/s normal movement")
	check(arena.camera.position==arena.player_pos,"Lab Camera2D tracks the actual simulated player position")
	await shot("01_lab_shared_topdown")
	arena.navigation.cancel()
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		await lab_click(arena.player_pos+direction*40);arena.advance(.1)
		check(arena.body.animation==preload("res://scripts/world/world_art.gd").direction(direction) and arena.body.is_playing(),"Actual directional movement uses the shared walking animation "+str(direction))
		await shot("direction_"+str(arena.body.animation))
	arena.navigation.cancel()
	arena.player_pos=Vector2(600,370);arena._update_views();arena.camera.reset_smoothing();arena.camera.force_update_scroll()
	await process_frame;await RenderingServer.frame_post_draw # Fixture teleport must settle its render transform before synthesizing a screen-space click.
	await lab_click(Vector2(695,390))
	if not arena.navigation.corrected:print("PROP_CLICK_DIAGNOSTIC ",JSON.stringify({"screen":str(arena.world_to_screen(Vector2(695,390))),"mouse":str(root.get_mouse_position()),"rect":str(arena.get_global_rect()),"destination":str(arena.navigation.destination),"player":str(arena.player_pos)}))
	check(arena.navigation.corrected and not arena._is_blocked(arena.navigation.destination),"Actual blocked tree RMB is projected into the reachable player-radius region")
	arena.navigation.cancel();arena.player_pos=Vector2(625,390);arena._update_views();arena.camera.reset_smoothing();await process_frame
	await point(arena.world_to_screen(Vector2(850,390)));await tap(KEY_CTRL);arena.advance(.18)
	check(arena.player_pos.x<667.1 and not arena._is_blocked(arena.player_pos),"Actual cursor dodge stops before a tree and does not cross it")
	await shot("02_lab_tree_collision")
	arena.dodge.reset();arena.player_pos=Vector2(695,345);arena._update_views();arena.camera.reset_smoothing();await shot("03_lab_occlusion_behind")
	arena.player_pos=Vector2(695,440);arena._update_views();arena.camera.reset_smoothing();await shot("04_lab_occlusion_front")
	arena.player_pos=Vector2(180,210);arena.reset_targets();arena._update_views();arena.camera.reset_smoothing();await process_frame
	await point(arena.world_to_screen(arena.enemies[0]["pos"]))
	game.player_mana=5;game.mana_debt=0;var record_count:int=game.journal.records().size()
	await chant("WATER","OH-061");arena.advance(.5)
	check(game.player_mana==0 and game.mana_debt==4 and game.journal.records().size()==record_count+1 and arena.enemies[0]["hp"]<200,"Actual Shift up manifests Tidebolt, pays shortage once and records once")
	check(game.laboratory_panel.trial_banner.text.contains("Tidebolt") and not game.laboratory_panel.trial_commands.text.contains("초과"),"English spell success and public lab UI reveal no debt amount")
	await shot("05_lab_debt_tidebolt")
	var debt:float=game.mana_debt;var effects:int=arena.missiles.size()
	await chant("METAL","OH-046")
	check(game.mana_debt==debt and game.player_mana==0 and arena.missiles.size()==effects and game.laboratory_panel.trial_banner.text.contains("주속성"),"Actual auxiliary single chant is denied with a reason before payment")
	await shot("06_auxiliary_denied")
	game._reset_combat_input()
	for pressed in [true,false,true,false]:
		var e:=InputEventKey.new();e.keycode=KEY_SHIFT;e.physical_keycode=KEY_SHIFT;e.pressed=pressed;Input.parse_input_event(e)
	Input.flush_buffered_events();await process_frame
	start=arena.player_pos;await lab_click(start+Vector2(100,0));arena.advance(.25);game._process(.25)
	check(game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST and arena.player_pos==start and game.mana_debt==0 and game.player_mana==0,"Actual focus stops movement and repays four debt at the unchanged 16/s lab rate")
	await tap(KEY_SPACE);check(game.runes.is_empty() and game.combat_input.mode==game.CombatInput.Mode.NORMAL,"Space still cancels and exits focus")
	game._laboratory_recover();arena.player_pos=Vector2(180,210);arena._update_views();arena.camera.reset_smoothing();await process_frame
	await point(arena.world_to_screen(arena.enemies[0]["pos"]))
	for wall in [false,true]:
		game._laboratory_recover();game._reset_combat_input();await key(KEY_SHIFT,true)
		for input in D.fusion_inputs(game.chant_profile,"WATER","METAL",wall):await tap(OS.find_keycode_from_string(input["key"]))
		await point(arena.world_to_screen(arena.enemies[0]["pos"]))
		await key(KEY_SHIFT,false);arena.advance(.4)
		check(not arena.combat.barriers.is_empty() if wall else arena.enemies[0].get("crystal_remaining",0)>0,"Actual current Water+Metal fusion still manifests "+("barrier" if wall else "needle"))
		await shot("07_fusion_wall" if wall else "07_fusion_needle")
	var preserved:Vector2=Vector2(game.player_mana,game.mana_debt);start=arena.player_pos
	game.laboratory_panel.show_journal();await shot("08_archived_observation")
	game.laboratory_panel.show_trial();check(Vector2(game.player_mana,game.mana_debt)==preserved and arena.player_pos==start,"Journal/trial round trip preserves resources and position")
	var performance:=[await render_stats(0),await render_stats(30)]
	var output:=FileAccess.open(OUT+"lab_performance.json",FileAccess.WRITE);output.store_string(JSON.stringify(performance,"\t"));output.close()
	await shot("10_lab_maximum_exhaustion")
	check(game._end_developer_test() and H.equal(game._character_document(),original) and FileAccess.get_file_as_bytes(path)==bytes,"Ending F2 restores the complete user-copy character, original mapping, journal and disk bytes")
	game._sync_world_view();await shot("09_restored_town")
	game.free();print("PHASE4 INTEGRATED WINDOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
