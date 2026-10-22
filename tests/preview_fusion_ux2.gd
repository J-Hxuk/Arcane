extends "res://tests/preview_fusion.gd"
const B = preload("res://tests/test_fusion_b.gd")
const UXDIR := "res://.task002_artifacts/fusion_ux2/"
var serial := str(Time.get_ticks_usec())
var number := 0
func fresh(main: Variant = "WATER", tools: Variant = null) -> void:
	if is_instance_valid(game): game.free()
	number += 1
	var path := UXDIR + serial + "_window_" + str(number) + ".json"
	A.write(path, F.fixture(main, 1787453028))
	game = Scene.instantiate(); game.save_path = path
	game.developer_tools_enabled = tools
	root.add_child(game); game.set_process(false)
	root.gui_release_focus()
	game._enter_laboratory(); game.laboratory_panel.arena.set_process(false)
func chant(tokens: Array) -> void:
	root.gui_release_focus()
	await key(KEY_SHIFT, true)
	for token in tokens: await tap(OS.find_keycode_from_string(token))
func auto(events: Array) -> void:
	await chant(events.map(func(event): return event["key"]))
	await key(KEY_SHIFT, false)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1160, 720); root.gui_embed_subwindows = true
	DirAccess.make_dir_recursive_absolute(UXDIR)
	fresh()
	check(game.developer_panel != null and OS.has_feature("editor_runtime") and not OS.get_cmdline_user_args().has("--dev-lab"), "Editor runtime opens developer tools without a CMD or --dev-lab")
	await tap(KEY_F2)
	check(game.developer_panel.panel.visible and game.developer_panel.elements.item_count == 8, "Real F2 opens five elements, neutral and both fusion presets")
	await capture("f5_f2_panel"); await tap(KEY_F2)
	var water_events := D.inputs(game.chant_profile, "WATER", D.basic_actions("WATER"))
	var mana: float = game.player_mana
	await auto(water_events)
	check(game.journal.records().size() == 1 and game.player_mana == mana - 9 and game.laboratory_panel.arena.missiles.size() == 1, "Actual Shift release produces one WATER manifestation, record and charge")
	await key(KEY_SHIFT, false)
	check(game.journal.records().size() == 1 and game.runes.is_empty(), "Real repeated Shift up never duplicates the release")
	await capture("water_auto_release")
	game._laboratory_recover(); game._reset_combat_input()
	var count: int = game.journal.records().size()
	await tap(KEY_SHIFT); await tap(KEY_SHIFT)
	check(game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST and game.journal.records().size() == count, "Actual single/double Shift taps enter focus without an automatic record")
	for event in water_events: await tap(OS.find_keycode_from_string(event["key"]))
	await key(KEY_SHIFT, false)
	check(game.runes.size() == water_events.size() and game.journal.records().size() == count, "Focus retains the chant on Shift up")
	await click(game.laboratory_panel.trial_release_button)
	check(game.journal.records().size() == count + 1 and game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST, "Focus manual button still releases exactly once")
	await tap(KEY_ESCAPE)
	for boundary in ["escape", "focus_out", "study", "editing", "leave", "developer"]:
		fresh(); mana = game.player_mana
		await chant(water_events.map(func(event): return event["key"]))
		match boundary:
			"escape": await tap(KEY_ESCAPE)
			"focus_out": game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"study":
				await click(game.laboratory_panel.research_button)
				check(game.laboratory_panel.awakening_panel.visible,"Actual study button opens the research modal")
				await capture("study_boundary")
			"editing": await click(game.laboratory_panel.note)
			"leave": await click(game.laboratory_panel.exit_button)
			"developer": await tap(KEY_F2)
		await key(KEY_SHIFT, false)
		var released := false
		for record in game.journal.records(): released = released or record["result"]["outcome"] == "released"
		check(not released and game.player_mana == mana and game.laboratory_panel.arena.missiles.is_empty(), "Actual window " + boundary + " prevents automatic manifestation")
	for main in [null, "WATER"]:
		fresh(main)
		var target := "WOOD" if main == null else "METAL"
		for source in ["book", "mentor", "environment"]: game._collect_research_clue(target, source)
		for i in 2:
			game._laboratory_recover()
			await chant(B.ritual(game.chant_profile, target)); await key(KEY_SHIFT, false)
		game._begin_awakening(target); game._laboratory_recover()
		await chant(B.ritual(game.chant_profile, target)); await key(KEY_SHIFT, false)
		var ui = game.laboratory_panel.awakening_panel
		check(ui.confirmation.visible and game.research.main_attribute == main and game.research.auxiliary_attributes.is_empty(), "Actual automatic ritual release leaves main/auxiliary permanently unconfirmed")
		await capture("manual_confirmation_" + target)
		await click(ui.confirmation.get_cancel_button())
		check(game.research.main_attribute == main and game.research.auxiliary_attributes.is_empty(), "Real Cancel preserves permanent research roles")
	fresh()
	await auto(water_events)
	game._change_spell_preference("WATER_PUSH", true, 0)
	var disk := FileAccess.get_file_as_bytes(game.save_path)
	var original: Dictionary = game._character_document()
	for option in ["WATER_METAL", "FIRE_WATER"]:
		for location in ["LAB", "DUNGEON"]:
			await tap(KEY_F2)
			await select(game.developer_panel.elements, D.OPTIONS.find(option))
			check(game.developer_panel.elements.selected==D.OPTIONS.find(option),"Actual F2 selector chooses "+option+" selected="+str(game.developer_panel.elements.selected))
			await select(game.developer_panel.location, 0 if location == "LAB" else 1)
			check(game.developer_panel.location.selected==(0 if location=="LAB" else 1),"Actual F2 location chooses "+location)
			await click(game.developer_panel.start_button)
			for example in D.examples(game.chant_profile, option, game.research.simulation_context()):
				if location == "LAB":
					game.laboratory_panel.arena.set_process(false); game._laboratory_recover()
				else:
					F.reset_arena(game)
					game.enemies.append(F.target(Vector2(450, 300)))
				if location == "LAB":
					game.laboratory_panel.show_trial()
					await process_frame
					await motion(game.laboratory_panel.arena.world_to_screen(game.laboratory_panel.arena.player_pos+Vector2(180,0)))
				else: await motion(Vector2(700, 300))
				await chant(example["inputs"].map(func(event): return event["key"]))
				if location == "LAB": await key(KEY_SHIFT, false)
				else:
					await click_point(Vector2(700, 300)); await key(KEY_SHIFT, false)
				check(game.developer_metrics.get("spell") == example["name"], location + " actual new/legacy release path manifests " + example["name"])
				var arena = game.laboratory_panel.arena if location == "LAB" else game
				var runtime = game.laboratory_panel.arena.combat if location == "LAB" else game.elemental_combat
				if example["spell_id"] == "ICE_CRYSTAL_BARRIER": check(runtime.barriers.size() == 1, location + " crystal barrier is physical")
				else:
					runtime.update_missiles(arena, 0.37, 1.0)
					check(arena.enemies[0]["hp"] < (200 if location == "LAB" else 100), location + " released projectile actually affects the target")
				await capture(location + "_" + example["spell_id"])
	await tap(KEY_F2); await click(game.developer_panel.end_button)
	check(H.equal(game._character_document(), original) and FileAccess.get_file_as_bytes(game.save_path) == disk and game.discovered.to_data()["spells"]["WATER_PUSH"]["favorite"], "Actual developer exit preserves original save bytes, personal journal and J favorite")
	game._leave_laboratory(); game._enter_dungeon("FIXED"); F.reset_arena(game)
	await motion(Vector2(700, 300))
	game.navigation.request(game, Vector2(650, 300)); game._process(0.1)
	var distance: float = game.player_pos.x - 300
	game.player_pos = Vector2(300, 300); game.navigation.request(game, Vector2(650, 300))
	await key(KEY_SHIFT, true); game._process(0.1)
	check(is_equal_approx(game.player_pos.x - 300, distance * 0.8), "Actual held Shift slows dungeon destination movement to 80 percent")
	await capture("dungeon_shift_slow")
	game._reset_combat_input()
	await tap(KEY_SHIFT); await tap(KEY_SHIFT)
	var position: Vector2 = game.player_pos
	game._process(0.1)
	check(game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST and game.player_pos == position, "Dungeon focus still stops movement")
	fresh("WATER", false)
	await tap(KEY_F2)
	check(game.developer_panel == null and not game.developer_tools_enabled, "A disabled developer policy exposes no panel or F2 UI")
	game.free()
	print("FUSION UX2 WINDOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func capture(label: String) -> void:
	game.queue_redraw(); game.laboratory_panel.arena.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(UXDIR + label + ".png") == OK, "Rendered " + label)
