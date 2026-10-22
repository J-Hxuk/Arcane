extends "res://tests/preview_world_phase3.gd"
const Policy = preload("res://tests/world_battle_policy.gd")
var driving := false
var cpu_microseconds: Array[float] = []
func drive() -> void:
	if driving and is_instance_valid(game):
		var started := Time.get_ticks_usec()
		game._process(0.04)
		cpu_microseconds.append(float(Time.get_ticks_usec() - started))
func complete_battle(element: String, name: String) -> bool:
	var pilot := Policy.new()
	var result: Dictionary = game._inspect_chant()
	var basic = game.CombatSpellResolver.DEFINITIONS[element]
	driving = true
	for frame in 6500:
		if not game.guardian.active: break
		if frame % 300 == 0: print("WINDOW_BATTLE_PROGRESS ", JSON.stringify({"name": name, "frame": frame, "hp": game.player_hp, "boss_hp": game.guardian.actor["hp"], "player": game.player_pos, "boss": game.guardian.actor["pos"], "state": game.guardian.state, "feedback": game.cast_feedback, "mana": game.player_mana}))
		var action := pilot.decide(game, 0.04, element, basic.mana_cost)
		if action.has("move"): await click_world(action["move"])
		if action.get("dodge", false):
			var escape: Vector2 = action.get("move",game.navigation.destination if game.navigation.active else game.player_pos+(game.player_pos-Vector2(game.guardian.actor["pos"])).normalized()*100)
			await aim(escape); await tap(KEY_CTRL); pilot.dodges += 1
		if action.get("cast", false): await chant(element)
		if action.get("sword", false): await click_world(game.guardian.actor["pos"], MOUSE_BUTTON_LEFT)
		await process_frame
	driving = false
	var won: bool = game.guardian.state == "VICTORY" and "RUIN_GUARDIAN" in game.world_progress.data["bosses"]
	print("WINDOW_BATTLE ", JSON.stringify({"element": element, "won": won, "hp": game.player_hp, "pilot_seconds": pilot.elapsed, "casts": pilot.casts, "swords": pilot.swings, "patterns": game.guardian.metrics.get("attacks", {})}))
	await screenshot(name)
	return won and pilot.casts > 0
func run() -> void:
	root.size = Vector2i(1160, 720); process_frame.connect(drive)
	var path := "res://.task002_artifacts/phase3a/window_p4_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, F.fixture("WATER", 1787453028)); game = Scene.instantiate(); game.save_path = path; root.add_child(game); game.set_process(false); await process_frame
	await walk_step(Vector2(580, 600)); await walk_step(game.layout.LAB_DOOR); await tap(KEY_E)
	await key(KEY_SHIFT, true)
	for event in D.inputs(game.chant_profile, "WATER", D.basic_actions("WATER")): await tap(OS.find_keycode_from_string(event["key"]))
	await key(KEY_SHIFT, false)
	check(game.journal.records().size() == 1, "Complete trip starts with a real laboratory experiment")
	game._leave_laboratory(); game._change_spell_preference("WATER_PUSH", true, 0)
	var original: Dictionary = game._character_document(); var disk := FileAccess.get_file_as_bytes(path)
	for element in ([] if OS.get_cmdline_user_args().has("--normal-only") else ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]):
		await battle(element)
		check(await complete_battle(element, "10_clear_" + element), element + " full unmodified boss AI defeated using actual RMB/Shift/keys/LMB/Ctrl; no HP edit or healing")
		game._end_developer_test()
	check(game._character_document() == original and FileAccess.get_file_as_bytes(path) == disk and game.discovered.entries()[0]["favorite"], "All five actual-input trials preserve original journal, J favorite, personal profile and disk")
	for point in [Vector2(800, 700), Vector2(1100, 750), Vector2(1400, 850), Vector2(1750, 900), Vector2(2250, 1080), game.layout.CHECKPOINT]: await walk_step(point)
	await tap(KEY_E)
	check(game.player_pos.distance_to(game.layout.CHECKPOINT) < 2 and game.world_progress.safe_position() == game.layout.CHECKPOINT, "Continuous real mouse trip reaches and saves exterior checkpoint")
	await walk_step(Vector2(2910, 910)); await tap(KEY_E)
	check(game.guardian.active and not game.developer_mode, "Normal play reaches the physical boss entrance and starts the real encounter")
	check(await complete_battle("WATER", "11_normal_clear"), "Normal isolated player defeats the full boss using personal water chant and combat input")
	for point in [Vector2(2910, 910), game.layout.CHECKPOINT, Vector2(2250, 1080), Vector2(1750, 900), Vector2(1400, 850), Vector2(1100, 750), Vector2(800, 900), Vector2(800, 1040), Vector2(650, 1190), Vector2(430, 1190)]: await walk_step(point)
	await tap(KEY_E)
	check(game.layout.region(game.player_pos) == "TOWN" and game.bank_gold == 160 and game.world_progress.safe_position().distance_to(Vector2(430, 1190)) < 1, "Boss -> exterior -> gate -> town -> rest is one connected complete play loop")
	await screenshot("12_returned_town")
	await tap(KEY_J)
	check(game.spell_record_hud.expanded and game.discovered.entries()[0]["favorite"] and game.journal.records().size() == 1, "J HUD, favorite chant and existing research journal survive the full expedition")
	await screenshot("13_preserved_j_hud")
	game._save_character(); game.free(); game = Scene.instantiate(); game.save_path = path; root.add_child(game); game.set_process(false); await process_frame
	check(game.player_pos.distance_to(Vector2(430, 1190)) < 1 and "RUIN_GUARDIAN" in game.world_progress.data["bosses"] and game.bank_gold == 160 and game.journal.records().size() == 1, "Fresh rendered scene restores safe town return, real victory and journal")
	var manifest := FileAccess.open("res://.task002_artifacts/phase3a/world_restart_path.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"path": path, "expected": game._character_document()})); manifest.close()
	var total := 0.0; var peak := 0.0
	for sample in cpu_microseconds: total += sample; peak = maxf(peak, sample)
	print("WINDOW_CPU_PROFILE ", JSON.stringify({"simulation_frames": cpu_microseconds.size(), "mean_process_ms": total / maxf(1, cpu_microseconds.size()) / 1000, "peak_process_ms": peak / 1000, "render_fps_monitor": Performance.get_monitor(Performance.TIME_FPS), "simulated_delta": 0.04}))
	print("WORLD PHASE4 WINDOW: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
