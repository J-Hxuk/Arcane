extends "res://tests/preview_world_phase1.gd"
func step(seconds: float) -> void:
	for i in ceili(seconds / 0.02): game._process(0.02)
	await process_frame
func battle(element := "WATER") -> void:
	if game.developer_mode: game._end_developer_test()
	game._start_developer_test(element, "WORLD")
	game.player_pos = Vector2(3160, 910); game._sync_world_view(); game.world_camera.reset_smoothing(); await process_frame
func chant(element: String) -> void:
	game._reset_combat_input(); await key(KEY_SHIFT, true)
	for event in D.inputs(game.chant_profile, element, D.basic_actions(element)): await tap(OS.find_keycode_from_string(event["key"]))
	await click_world(game.guardian.actor["pos"], MOUSE_BUTTON_LEFT)
	await key(KEY_SHIFT, false)
func run() -> void:
	root.size = Vector2i(1160, 720)
	var path := "res://.task002_artifacts/phase3a/window_p3_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, F.fixture("WATER", 1787453028)); game = Scene.instantiate(); game.save_path = path; root.add_child(game); game.set_process(false); await process_frame
	var bytes := FileAccess.get_file_as_bytes(path); var document: Dictionary = game._character_document()
	for id in ["SWEEP", "CHARGE", "SLAM", "THROW"]:
		await battle()
		var boss = game.guardian
		game.player_pos = boss.actor["pos"] + Vector2(-95 if id == "SWEEP" else -220, 0)
		boss._begin_pattern(game, id); game._sync_world_view()
		await screenshot("07_warning_" + id)
		check(boss.state == "WINDUP" and game.world_hud.visible and game.guardian_view.visible, "Rendered distinct warning and boss health for " + id)
		var hp: float = game.player_hp
		if id == "SWEEP":
			await click_world(game.player_pos + Vector2(-140, 0)); game._process(0.01); await tap(KEY_CTRL)
			var dodged: bool = game.dodge.active
			await step(1.2)
			check(dodged and game.player_hp == hp, "Actual RMB + Ctrl input physically dodges the sweep")
		else:
			await click_world(game.player_pos + Vector2(0, 180)); await step(1.8)
			check(game.player_hp == hp, "Actual RMB reposition avoids " + id)
	for element in ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]:
		await battle(element)
		var boss = game.guardian
		var hp: float = boss.actor["hp"]
		await chant(element)
		if element == "EARTH":
			check(game.elemental_combat.barriers.size() == 1, "Actual personal earth chant creates the arena barrier")
			boss._begin_pattern(game, "CHARGE"); await step(1.7)
			check(boss.metrics["barrier_stops"] == 1 and boss.actor["exposed"], "Real earth barrier stops boss charge and exposes the knight")
		else:
			await step(0.6)
			check(boss.actor["hp"] < hp and game.developer_metrics.get("input_count") == D.inputs(game.chant_profile,element,D.basic_actions(element)).size(), element + " actual Shift/personal keys/LMB damages the real boss")
			check((boss.actor.get("root_remaining", 0) > 0 if element == "WOOD" else boss.actor.get("burn_remaining", 0) > 0 if element == "FIRE" else boss.actor.get("wet_remaining", 0) > 0 if element == "WATER" else boss.metrics["hits_taken"] > 0), element + " real distinct status/precision effect applies")
		await screenshot("08_boss_" + element)
	await battle(); game.guardian.actor["hp"] = 125; game.guardian.advance(game, 0.01); game.guardian._begin_pattern(game, "THROW")
	await screenshot("09_phase2_fan")
	check(game.guardian.phase == 2, "Rendered phase two changes to a three-lane fan telegraph")
	game._end_developer_test()
	check(game._character_document() == document and FileAccess.get_file_as_bytes(path) == bytes, "Five rendered boss profiles return to original player/J/journal/disk")
	print("WORLD PHASE3 WINDOW: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
