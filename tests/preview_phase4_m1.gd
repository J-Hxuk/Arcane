extends "res://tests/preview_world_phase1.gd"
const Catalog = preload("res://scripts/m1_spell_catalog.gd")
const M1 = preload("res://tests/test_phase4_m1.gd")
const OUT := "res://.task002_artifacts/phase4_m1/"
func shot(name: String) -> void:
	game._sync_world_view(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
func aim_trial(point: Vector2) -> void:
	var screen: Vector2 = game.laboratory_panel.arena.world_to_screen(point)
	Input.warp_mouse(screen); await process_frame
	var event := InputEventMouseMotion.new(); event.position = screen; event.global_position = screen
	Input.parse_input_event(event); await process_frame
func chant(element: String, id: String, location: String) -> void:
	game._reset_combat_input(); await key(KEY_SHIFT, true)
	for input in D.inputs(game.chant_profile, element, M1.actions_for(id)): await tap(OS.find_keycode_from_string(input["key"]))
	var definition = game._inspect_chant(true).get("spell")
	check(definition != null and str(definition.catalog_id) == id, id+" actual personal keys select the intended final structure in "+location)
	if location == "LAB":
		await aim_trial(game.laboratory_panel.arena.enemies[0]["pos"])
		await key(KEY_SHIFT, false)
	else: await click_world(game.guardian.actor["pos"], MOUSE_BUTTON_LEFT); await key(KEY_SHIFT, false)
func run() -> void:
	root.size = Vector2i(1160,720); root.gui_embed_subwindows = true
	var path := OUT + "m1_window_"+str(Time.get_ticks_usec())+".json"
	A.write(path,F.fixture("WATER",1787453028)); game=Scene.instantiate(); game.save_path=path; root.add_child(game); game.set_process(false)
	await process_frame
	var original: Dictionary = game._character_document(); var bytes := FileAccess.get_file_as_bytes(path)
	await tap(KEY_F2); check(game.developer_panel.panel.visible,"F2 panel remains accessible"); await tap(KEY_F2)
	for source in Catalog.SOURCE["spells"]:
		game._start_developer_test(source["element"],"LAB"); game.laboratory_panel.show_trial(); await process_frame
		var arena = game.laboratory_panel.arena
		arena.set_process(false); arena.reset_targets(); arena.player_pos=Vector2(180,210)
		var definition = Catalog.find(source["id"])
		var distance := 160.0 if definition.effect == &"point" else 65.0 if definition.effect in [&"cone",&"shockwave"] else 180.0
		arena.enemies.assign([{"pos":arena.player_pos+Vector2(distance,0),"home":arena.player_pos+Vector2(distance,0),"hp":200.0,"shot":INF}])
		var mana: float = game.player_mana; await aim_trial(arena.enemies[0]["pos"])
		await chant(source["element"],source["id"],"LAB"); arena.advance(0.08); await shot("m1_"+source["id"])
		for i in 15: arena.advance(0.04)
		check((arena.combat.barriers.size()==1 if definition.effect==&"barrier" else arena.enemies[0]["hp"]<200) and game.journal.records().size()==1 and game.player_mana<mana,source["id"]+" actual Shift-up manifests, spends and records exactly once")
		game._end_developer_test()
		game._start_developer_test(source["element"],"WORLD")
		game.player_pos=game.guardian.actor["pos"]-Vector2(distance if definition.effect!=&"barrier" else 230,0)
		game._sync_world_view(); game.world_camera.reset_smoothing(); await process_frame
		var hp: float = game.guardian.actor["hp"]
		await aim(game.guardian.actor["pos"]); await chant(source["element"],source["id"],"WORLD")
		for i in 30: game._process(0.02)
		check(game.elemental_combat.barriers.size()==1 if definition.effect==&"barrier" else game.guardian.actor["hp"]<hp,source["id"]+" works against the real guardian collision/combat executor")
		if source["id"] in ["OH-001","OH-017","OH-031","OH-048","OH-063"]: await shot("boss_"+source["id"])
		game._end_developer_test()
	check(game._character_document()==original and FileAccess.get_file_as_bytes(path)==bytes,"All fifteen lab/world trials restore original character, mapping, journal and save bytes")
	game.player_pos=Vector2(1000,530); game._sync_world_view(); await process_frame
	await tap(KEY_F); check(not game.world_dialog.visible,"F does not interact in normal world context")
	await tap(KEY_E); check(game.world_dialog.visible,"E opens exactly the library interaction")
	game._read_world_book("WOOD"); await shot("library_WOOD")
	game._read_world_book("WATER"); await shot("library_WATER"); game.world_dialog.hide()
	game.player_pos=Vector2(500,1260); game._sync_world_view(); await process_frame; await tap(KEY_E)
	check(game.mentor_dialog.visible,"E reaches the physical elemental mentor"); await shot("mentor_dialog"); game.mentor_dialog.hide()
	game.player_pos=game.layout.LAB_DOOR; game._enter_laboratory(); await process_frame
	await shot("research_coach")
	game.laboratory_panel.show_trial(); game._process(0); await process_frame; await shot("controllable_trial")
	print("PHASE4 M1 WINDOW: %d checks, %d failures" % [checks,failures]); game.free(); quit(1 if failures else 0)
