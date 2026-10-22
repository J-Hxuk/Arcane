extends "res://tests/preview_world_phase1.gd"
const LegacyScene = preload("res://scenes/main.tscn")
const H = preload("res://tests/test_chant.gd")
const B = preload("res://tests/test_fusion_b.gd")
const Save = preload("res://scripts/character_save.gd")
var serial := 0
func fresh(world := false, document: Dictionary = {}) -> void:
	if is_instance_valid(game): game.free()
	serial += 1
	var path := "res://.task002_artifacts/balance_01/window_" + str(Time.get_ticks_usec()) + "_" + str(serial) + ".json"
	A.write(path, F.fixture("WATER", 1787453028) if document.is_empty() else document)
	game = (Scene if world else LegacyScene).instantiate(); game.save_path = path; root.add_child(game); game.set_process(false)
	await process_frame; await process_frame
	if not world: game._enter_dungeon("FIXED"); F.reset_arena(game)
func mouse(point: Vector2) -> void:
	Input.warp_mouse(point); await process_frame
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; Input.parse_input_event(motion); await process_frame
	var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	Input.parse_input_event(event); await process_frame; event.pressed = false; Input.parse_input_event(event); await process_frame
func lab_cast(keys: Array) -> void:
	game._reset_combat_input(); root.gui_release_focus()
	await key(KEY_SHIFT, true)
	for token in keys: await tap(OS.find_keycode_from_string(token))
	await key(KEY_SHIFT, false)
func capture_balance(name: String) -> void:
	game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.task002_artifacts/balance_01/" + name + ".png")
func run() -> void:
	root.size = Vector2i(1160, 720); root.gui_embed_subwindows = true
	await fresh()
	game.enemies.assign([F.target(Vector2(370, 300))]); game.enemies[0]["stagger_remaining"] = 5.0
	await mouse(Vector2(700, 300))
	check(absf(game.enemies[0]["hp"] - 90.6) < 0.001 and is_equal_approx(game.player_attack_cooldown, 0.8), "Legacy real LMB deals 9.4 at body 35 with the new 0.8-second interval")
	await mouse(Vector2(700, 300)); game._process(0.79); await mouse(Vector2(700, 300))
	check(absf(game.enemies[0]["hp"] - 90.6) < 0.001, "Repeated clicks cannot attack again before the full new interval")
	game._process(0.02); await mouse(Vector2(700, 300))
	check(absf(game.enemies[0]["hp"] - 81.2) < 0.001, "Attack becomes available after the interval elapses")
	await fresh(true); game._start_developer_test("WATER", "WORLD"); game.player_pos = game.guardian.actor["pos"] + Vector2(-70, 0); game._sync_world_view()
	var hp: float = game.guardian.actor["hp"]
	await click_world(game.guardian.actor["pos"], MOUSE_BUTTON_LEFT)
	check(is_equal_approx(hp - game.guardian.actor["hp"], 10) and is_equal_approx(game.player_attack_cooldown, 0.8), "World sword uses the same nerf (body 50 gives 10) rather than its old duplicate tuning")
	await click_world(game.guardian.actor["pos"], MOUSE_BUTTON_LEFT)
	check(is_equal_approx(hp - game.guardian.actor["hp"], 10), "World click spam also respects the slower attack interval")
	await fresh(); game.game_state = "HUB"; game._enter_laboratory(); game.laboratory_panel.arena.set_process(false)
	for keys in [["Q", "E"], H.path_for(game.chant_profile, ["ACCUMULATE", "DIRECT"])]:
		game._laboratory_recover(); var mana: float = game.player_mana
		await lab_cast(keys)
		var arena = game.laboratory_panel.arena
		check(arena.missiles.size() == 1 and arena.missiles[0]["definition"].damage == 10 and is_equal_approx(mana - game.player_mana, 15), "Real mana bolt input path deals 10 and retains cost 15: " + str(keys))
		arena.advance(0.45)
		check(is_equal_approx(arena.enemies[0]["hp"], 190), "Actual neutral projectile impact applies the nerfed damage")
	game._laboratory_recover(); await lab_cast(D.inputs(game.chant_profile, "WATER", ["ACCUMULATE", "DIRECT"]).map(func(event): return event["key"]))
	game.laboratory_panel.arena.advance(0.5)
	check(is_equal_approx(game.laboratory_panel.arena.enemies[0]["hp"], 188) and game.laboratory_panel.arena.enemies[0]["pos"].x > 400, "Water retains its 12 damage and distinct physical push")
	await capture_balance("water_keeps_control")
	var source := "user://arcane_legacy_save.json"; var original_hash := FileAccess.get_sha256(source)
	var actual: Dictionary = Save.load_file(source)["data"]
	await fresh(true, actual); game.player_pos = game.layout.LAB_DOOR; game._enter_laboratory(); game.laboratory_panel.arena.set_process(false)
	var ritual_keys := B.ritual(game.chant_profile, "METAL")
	for i in 2:
		game._laboratory_recover(); await lab_cast(ritual_keys)
	check(game.research.stable_count("METAL") >= 2 and game.research.interference_count("METAL") >= 1 and game.research.ritual_eligibility("METAL") == "available", "Current character copy: exact 14-key metal sequence supplies both stable and interference prerequisites")
	game.laboratory_panel.show_journal(); await click_control(game.laboratory_panel.research_button)
	await choose(game.laboratory_panel.awakening_panel.target, 3); await click_control(game.laboratory_panel.awakening_panel.ritual_button)
	check(game.research.ritual_target == "METAL", "Actual Metal selection and ritual-start button start the auxiliary ritual")
	game._laboratory_recover(); await lab_cast(ritual_keys)
	check(game.laboratory_panel.awakening_panel.confirmation.visible and game.research.main_attribute == "WATER" and game.research.auxiliary_attributes.is_empty(), "Same exact sequence opens manual Metal auxiliary confirmation without changing Water or auto-confirming")
	await capture_balance("metal_manual_confirmation")
	check(FileAccess.get_sha256(source) == original_hash, "Real user save remains byte-identical; all experiments used isolated copies")
	print("BALANCE WINDOW: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
