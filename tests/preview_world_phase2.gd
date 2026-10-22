extends "res://tests/preview_world_phase1.gd"
func run() -> void:
	root.size = Vector2i(1160, 720); root.gui_embed_subwindows = true
	var path := "res://.task002_artifacts/phase3a/window_p2_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, F.fixture("WATER", 1787453028))
	game = Scene.instantiate(); game.save_path = path; root.add_child(game); game.set_process(false)
	await process_frame
	game.player_pos = Vector2(1000, 530); game._sync_world_view(); await process_frame
	await tap(KEY_E)
	check(game.world_dialog.visible, "Actual E opens the physical library's clue window")
	await screenshot("05_library")
	var button: Button = game.world_dialog.find_child("Book_WATER", true, false)
	var point := button.get_global_rect().get_center() + Vector2(game.world_dialog.position)
	var mouse := InputEventMouseButton.new(); mouse.position = point; mouse.global_position = point; mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true
	Input.parse_input_event(mouse); await process_frame; mouse.pressed = false; Input.parse_input_event(mouse); await process_frame
	check(game.research.has_clue("WATER", "book") and game.research.researched_base_elements.size() == 1, "Actual GUI book click records a clue with no new slot")
	game.world_dialog.hide(); root.gui_release_focus()
	game.player_pos = game.layout.CHECKPOINT; game.player_hp = 20; game._sync_world_view(); await process_frame; await tap(KEY_E)
	check(game.player_hp == game._max_hp() and game.world_progress.safe_position() == game.layout.CHECKPOINT, "Actual checkpoint interaction saves and recovers")
	await screenshot("06_checkpoint")
	game.player_pos = Vector2(2810, 900); game.player_hp = 0; game._die(); game._sync_world_view(); await process_frame
	check(game.player_pos == game.layout.CHECKPOINT and game.world_progress.data["deaths"] == 1, "Rendered death transition returns to the selected checkpoint")
	var expected: Dictionary = game._character_document(); game.free()
	game = Scene.instantiate(); game.save_path = path; root.add_child(game); game.set_process(false); await process_frame
	check(game.world_progress.data["deaths"] == 1 and game.player_pos == game.layout.CHECKPOINT and game.research.has_clue("WATER", "book"), "Fresh rendered scene reloads progress, checkpoint and library clue")
	print("WORLD PHASE2 WINDOW: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
