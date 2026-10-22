extends "res://tests/preview_phase4_qa_v2.gd"
const OUTPUT="res://.task002_artifacts/chant_v2_visual_qa/"
var marker:Control
var cursor_mark:=Vector2.ZERO
var start_mark:=Vector2.ZERO
var end_mark:=Vector2.ZERO
var body_mark:=Rect2()
func capture(name:String)->void:
	if game.game_state=="LAB":game.laboratory_panel.arena._update_views()
	else:game._sync_world_view()
	marker.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
func draw_markers()->void:
	if cursor_mark==Vector2.ZERO:return
	marker.draw_line(cursor_mark-Vector2(8,0),cursor_mark+Vector2(8,0),Color.YELLOW,2)
	marker.draw_line(cursor_mark-Vector2(0,8),cursor_mark+Vector2(0,8),Color.YELLOW,2)
	marker.draw_line(start_mark,end_mark,Color(1,1,.3,.5),1)
	marker.draw_rect(body_mark,Color(1,.5,.3,.8),false,1)
func sample_render()->Dictionary:
	var samples:Array[float]=[];var calls:=0.0
	for i in 60:
		var started:=Time.get_ticks_usec();await process_frame;RenderingServer.force_draw(false)
		samples.append((Time.get_ticks_usec()-started)/1000.0);calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	samples.sort()
	return {"median_ms":samples[30],"p95_ms":samples[57],"draw_calls":calls/60,"samples":60,"fps":Performance.get_monitor(Performance.TIME_FPS)}
func cast_keys(order:Array)->Dictionary:
	game._reset_combat_input();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
	await key(KEY_SHIFT,true)
	for event in E.inputs(game.prototype_profile,order):await tap(OS.find_keycode_from_string(event.key))
	var predicted:Dictionary=game._inspect_chant(true)
	if game.game_state=="DUNGEON":
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=root.get_mouse_position();event.global_position=event.position;event.pressed=true;Input.parse_input_event(event);await process_frame
		event.pressed=false;Input.parse_input_event(event);await process_frame
	await key(KEY_SHIFT,false)
	return predicted
func run()->void:
	root.size=Vector2i(1160,720);root.gui_embed_subwindows=true
	var path:=OUTPUT+"window_%d.json"%Time.get_ticks_usec();A.write(path,JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"user_before.json")))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var bytes:=FileAccess.get_file_as_bytes(path);var original:Dictionary=game._character_document().duplicate(true)
	var overlay:=CanvasLayer.new();overlay.layer=28;root.add_child(overlay);marker=Control.new();marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(marker);marker.draw.connect(draw_markers)
	await tap(KEY_F2)
	var all_button:Button
	for node in game.developer_panel.panel.find_children("*","Button",true,false):
		if node.text=="전속성 동시 시험 · 새 영창 시제품":all_button=node
	await click(all_button);check(game.developer_mode and game._prototype_all,"Actual F2 all-element entry")
	var arena=game.laboratory_panel.arena;arena.set_process(false)
	# Research discovery stays on the research screen with no numeric overlay.
	game.laboratory_panel.show_journal();var before:Dictionary=game.last_laboratory_result.duplicate(true)
	game.journal.append(E.resolve(game.prototype_profile,E.inputs(game.prototype_profile,["ACCUMULATE"]),game._prototype_context()).simulation,"released",0,100,2);game.laboratory_panel.refresh(true)
	var selected_id:int=game.laboratory_panel.selectors[0].get_selected_id();game.laboratory_panel.note.text="비교 중 메모"
	await cast_keys(E.CONFIG.spells[4].actions)
	check(game.laboratory_panel.panel.visible and not game.laboratory_panel.trial_panel.visible,"Real Shift release discovers without changing research screen")
	check(game.laboratory_panel.discovery_text.text.contains("Tidebolt") and not game.laboratory_panel.discovery_text.text.contains("피해"),"Large qualitative discovery banner in 1160x720")
	check(game.laboratory_panel.coach.advice_log.branch=="ready","Mentor recognizes the last successfully manifested structure")
	check(game.laboratory_panel.selectors[0].get_selected_id()==selected_id and game.laboratory_panel.note.text=="비교 중 메모","Discovery preserves the selected replay and unsaved note")
	await capture("discovery_research")
	game.laboratory_panel.show_trial();await process_frame
	# Forward/reverse use the same lab target, zoom, origin and physical key events.
	for row in E.CONFIG.spells:
		for reverse in [false,true]:
			arena.player_pos=Vector2(180,210);arena.reset_targets();arena.enemies.resize(1);arena.enemies[0].pos=Vector2(490,210)
			arena.camera.zoom=Vector2.ONE;arena._update_views();arena.camera.reset_smoothing();arena.camera.force_update_scroll();await process_frame
			cursor_mark=arena.world_to_screen(arena.enemies[0].pos+Vector2(0,-30));start_mark=arena.world_to_screen(arena.player_pos);end_mark=cursor_mark;body_mark=Rect2(arena.world_to_screen(Vector2(472,162)),Vector2(36,66))
			await point(cursor_mark)
			var order:Array=row.actions.duplicate();if reverse:order.reverse()
			var predicted:Dictionary=await cast_keys(order)
			check(predicted.identity==row.id,"Actual input identity "+row.id+str(reverse))
			if predicted.spell.effect!=&"barrier":arena.combat.update_missiles(arena,.25,1)
			await capture("lab_"+row.id+("_reverse" if reverse else "_forward"))
			if predicted.spell.effect==&"barrier":check(arena.combat.barriers.size()==1,"Actual physical barrier variation")
			else:arena.combat.update_missiles(arena,1.8,1);check(arena.enemies[0].hp<200,"Actual lab impact "+row.id+str(reverse))
	# Moving-camera and zoom tests include legacy Droplet, Tidebolt and Ebbpulse.
	for zoom in [.65,1.0,1.6]:
		for id in ["OH-061","OH-062","OH-063"]:
			arena.player_pos=Vector2(600,370);arena.reset_targets();arena.enemies.resize(1);arena.enemies[0].pos=Vector2(660 if id=="OH-063" else 740,370)
			arena.camera.zoom=Vector2.ONE*zoom;arena._update_views();arena.camera.reset_smoothing();arena.camera.force_update_scroll();await process_frame
			arena.player_pos+=Vector2(12,0);arena._update_views() # The camera is still smoothing after movement.
			cursor_mark=arena.world_to_screen(arena.enemies[0].pos+Vector2(0,-30));await point(cursor_mark)
			check(arena.world_to_screen(arena.aim_world_position()).distance_to(root.get_mouse_position())<.01,"Live rendered camera/zoom cursor conversion "+id+str(zoom))
			var definition=preload("res://scripts/m1_spell_catalog.gd").find(id)
			check(arena.manifest(definition),"Legacy water effect manifests "+id)
			arena.combat.update_missiles(arena,1,1)
			check(arena.enemies[0].hp<200,"Body-aim water contact after camera movement "+id+str(zoom))
	# Environmental observation feedback has its own reaction, journal and progress.
	arena.player_pos=Vector2(630,130);arena._update_views();arena.camera.reset_smoothing();await tap(KEY_E)
	check(arena.catalyst_reaction=="WOOD" and game.research.has_clue("WOOD","environment"),"Actual E produces visible environmental evidence")
	await capture("catalyst_reaction")
	game._end_developer_test();check(H.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"Lab session preserves latest original bytes and character")
	game._start_prototype_all("WORLD")
	for row in E.CONFIG.spells:
		for reverse in [false,true]:
			game.guardian.start(game);game.guardian.state="RECOVERY";game.guardian.timer=99
			game.player_pos=game.Guardian.HOME-Vector2(260,0);game.world_camera.zoom=Vector2.ONE;game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll();await process_frame
			var target:Vector2=game.guardian.actor.pos+Vector2(0,-44)
			cursor_mark=await aim(target);start_mark=game.get_canvas_transform()*game.player_pos;end_mark=cursor_mark;body_mark=Rect2(game.get_canvas_transform()*(game.guardian.actor.pos+Vector2(-26,-70)),Vector2(52,96))
			var order:Array=row.actions.duplicate();if reverse:order.reverse()
			var predicted:Dictionary=await cast_keys(order)
			check(game.developer_metrics.spell==predicted.spell.display_name,"Actual world release "+row.id)
			if predicted.spell.effect!=&"barrier":game.elemental_combat.update_missiles(game,.20,1)
			await capture("world_"+row.id+("_reverse" if reverse else "_forward"))
			if predicted.spell.effect!=&"barrier":game.elemental_combat.update_missiles(game,1.8,1);check(game.guardian.actor.hp<game.guardian.definition.max_hp,"World body-aim impact "+row.id)
			else:check(game.elemental_combat.barriers.size()==1,"World barrier blocks physically")
	# Legacy Water casting in the outdoor world, while a real RMB route is moving
	# under held Shift; cursor conversion uses the current smoothing transform.
	game._enable_prototype(false)
	for zoom in [.65,1.0,1.6]:
		for id in ["OH-061","OH-062","OH-063"]:
			game.guardian.start(game);game.guardian.state="RECOVERY";game.guardian.timer=99
			game.player_pos=game.Guardian.HOME-Vector2(75 if id=="OH-063" else 240,0)
			game.world_camera.zoom=Vector2.ONE*zoom;game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll();await process_frame
			game._reset_combat_input();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0;game.player_attack_cooldown=0
			await click_world(game.player_pos+Vector2(0,40));var origin:Vector2=game.player_pos
			await key(KEY_SHIFT,true);game._process(.04)
			check(game.player_pos.distance_to(origin)>0 and game.combat_input.mode==game.CombatInput.Mode.MOBILE_CAST,"Real RMB motion continues during Shift casting "+id+str(zoom))
			for event in D.inputs(game.chant_profile,"WATER",preload("res://scripts/m1_spell_catalog.gd").PROFILES.examples[id]):await tap(OS.find_keycode_from_string(event.key))
			var predicted:Dictionary=game._inspect_chant(true)
			check(predicted.get("spell")!=null and str(predicted.spell.catalog_id)==id,"Legacy water identity while moving "+id)
			cursor_mark=game.get_canvas_transform()*(game.guardian.actor.pos+Vector2(0,-44));await point(cursor_mark)
			check((game.get_canvas_transform()*game.aim_world_position()).distance_to(root.get_mouse_position())<.01,"World current rendered cursor conversion "+str(zoom))
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=root.get_mouse_position();event.global_position=event.position;event.pressed=true;Input.parse_input_event(event);await process_frame
			event.pressed=false;Input.parse_input_event(event);await process_frame;await key(KEY_SHIFT,false)
			game.elemental_combat.update_missiles(game,1.5,1)
			check(game.guardian.actor.hp<game.guardian.definition.max_hp,"World Water actual impact after motion/zoom "+id+str(zoom))
			if id=="OH-061":await capture("water_world_zoom_"+str(zoom))
	cursor_mark=Vector2.ZERO;game.player_hp=game._max_hp()*.1;game.mana_debt=game._max_mana()*.25;game.player_mana=0
	for i in 80:game.hit_screen.advance(game.player_hp,game._max_hp(),.016);game._update_mana_exhaustion(.016)
	game.guardian._begin_pattern(game,"SLAM")
	game._receive_player_damage(1,true,Vector2.RIGHT);game.hit_feedback.advance(.017);await capture("boss_low_hp_and_debt")
	check(game.hit_screen.intensity>.5 and game.mana_exhaustion_view.displayed_blur>0 and game.world_camera.offset.length()>0,"Red low HP edge, mana blur and bounded camera shake compose")
	await click(game.hit_screen.settings_button);check(game.hit_screen.settings.visible,"Actual screen settings button opens above the HUD")
	game.hit_screen.slider.grab_focus();await tap(KEY_HOME);game._sync_world_view();check(game.world_camera.offset==Vector2.ZERO,"Actual slider keyboard setting disables camera shake")
	await capture("screen_settings");game.hit_screen.settings.hide()
	game.player_hp=game._max_hp();game.mana_debt=0;game._update_mana_exhaustion(3);game.hit_screen.advance(game.player_hp,game._max_hp(),3)
	var performance:Array=[await sample_render()]
	game.player_hp=game._max_hp()*.05;game.mana_debt=game._max_mana()*.30;game._update_mana_exhaustion(3);game.hit_screen.advance(game.player_hp,game._max_hp(),3)
	performance.append(await sample_render())
	FileAccess.open(OUTPUT+"render_performance.json",FileAccess.WRITE).store_string(JSON.stringify(performance,"\t"))
	check(performance[1].fps>=30 and performance[1].p95_ms<50,"Low HP plus maximum mana blur renders within the prototype budget")
	game._end_developer_test();check(H.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"World session restores exact original state")
	# Read all ten real book pages, including known-name reveal and mentor dialogue.
	for element in preload("res://scripts/research_lore.gd").DATA:
		game.book_view.element=element;game.book_view.page=1;game._update_book_page();game.world_dialog.popup_centered(Vector2i(880,450));await process_frame
		check(game.library_text.text.length()>100 and game.book_view.page==1,"Real two-page manuscript rendered "+element)
		await capture("book_"+element);game.world_dialog.hide()
		game._talk_to_mentor(element);check(game.mentor_text.text.contains("구술 전승"),"Actual elemental mentor connects data-driven oral lore "+element)
		await capture("mentor_"+element);game.mentor_dialog.hide()
	game.free();overlay.free();print("CHANT V2 VISUAL WINDOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
