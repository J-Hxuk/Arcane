extends SceneTree
## Display-driver integration: real key and GUI event routing, isolated save.
const SCENE = preload("res://scenes/main.tscn")
const Helper = preload("res://tests/test_chant.gd")
const DIR := "res://.task002_artifacts/phase2b1/"
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a display driver for laboratory preview.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size = Vector2i(1160, 720)
	root.gui_embed_subwindows = true
	var path := DIR + "preview_lab.json"
	var fixture := FileAccess.open(path, FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"magic": 67, "body": 34, "fixed_seed": 12345, "learned": ["EMBER"]}))
	fixture.close()
	game = SCENE.instantiate()
	game.save_path = path
	root.add_child(game)
	game.set_process(false)
	await _tap(KEY_L)
	var ui = game.laboratory_panel
	ui.arena.set_process(false) # Explicitly freeze world time for read-only replay checks.
	check(game.game_state == "LAB" and ui.panel.visible, "Engine L enters the laboratory screen")
	if OS.get_cmdline_user_args().has("--chant-debug"):
		check(ui.debug_window != null and ui.debug_window.visible and ui.debug_view.text.contains("first_words"), "Explicit developer flag opens mapping/state debug window")
		await _capture("lab_developer_debug")
		game.free()
		print("LAB DEVELOPER DEBUG: %d checks, %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	check(ui.debug_window == null, "Normal executable session has no mapping answers/debug window")
	await _capture("lab_empty")
	var fire: String = Helper.first_for(game.chant_profile, "FIRE")
	await _key(KEY_SHIFT, true)
	await _tap(OS.find_keycode_from_string(fire))
	check(game.runes == [fire] and ui.live.text.contains("뚜렷한 변화가 관찰되지"), "Single real attribute key shows no completed or affinity response")
	await _capture("lab_first_word")
	await _key(KEY_SHIFT, false)
	check(game.journal.records().size() == 1 and game.journal.records()[0]["result"]["outcome"] == "failed", "Shift release submits the unfinished experiment once as a failed observation")
	await _click(ui.recover_button) # A submitted failure can now cause instability.
	await _chant(Helper.path_for(game.chant_profile, ["ACCUMULATE", "COMPRESS", "SHAPE", "DIRECT", "STABILIZE"]))
	await _click(ui.release_button)
	check(ui.arena.missiles.size() == 1 and game.journal.records().size() == 2, "Real personal chant and release button create a safe-arena bolt and automatic record")
	await _click(ui.journal_button)
	await _key(KEY_SHIFT, false)
	await _chant(Helper.path_for(game.chant_profile, ["ACCUMULATE", "SHAPE", "COMPRESS", "DIRECT", "STABILIZE"]))
	await _click(ui.release_button)
	check(game.journal.records().size() == 3 and ui.arena.missiles.size() == 2, "Alternative direct chant records the same effect via another path")
	await _click(ui.journal_button)
	await _key(KEY_SHIFT, false)
	# Change replay steps through real SpinBox controls, with no live effects.
	var mana: float = game.player_mana
	var count: int = game.journal.records().size()
	var research: Dictionary = game.research.to_data()
	await _click(ui.next_buttons[0])
	await _click(ui.next_buttons[0])
	await _click(ui.next_buttons[1])
	await _click(ui.next_buttons[1])
	check(ui.steppers[0].value == 3 and ui.steppers[1].value == 3 and ui.views[0].text != ui.views[1].text, "GUI next buttons show different inputs and observations for the selected steps")
	check(game.player_mana == mana and game.journal.records().size() == count and ui.arena.missiles.size() == 2 and game.research.to_data() == research, "Real step replay/side-by-side comparison has no mana, casting or slot side effects")
	await _capture("lab_compare")
	await _click(ui.note)
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.physical_keycode = KEY_Q
	event.unicode = 113
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	check(game.runes.is_empty() and ui.note.text.contains("q"), "Typing a player note never enters chant commands")
	await _click(ui.save_note_button)
	check(game.journal.records()[-1]["note"].contains("q"), "GUI note save persists the player hypothesis")
	await _chant(Helper.path_for(game.chant_profile, ["ACCUMULATE", "COMPRESS", "RESONATE"], fire))
	await _click(ui.release_button)
	check(game.journal.records()[-1]["result"]["kind"] == "unstable" and game.exhaustion_seconds == 1.0, "Unstable FIRE experiment records failure cost and exhaustion")
	await _capture("lab_unstable")
	await _key(KEY_SHIFT, false)
	await _click(ui.recover_button)
	check(game.player_mana == game._max_mana() and game.exhaustion_seconds == 0.0, "GUI lab recovery restores resources")
	await _chant(Helper.path_for(game.chant_profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], fire))
	await _capture("lab_resonance_ready")
	await _click(ui.release_button)
	check(game.journal.records()[-1]["result"]["kind"] == "fire_resonance" and game.research.researched_base_elements.is_empty(), "Real stable resonance is recorded without confirming an element")
	await _key(KEY_SHIFT, false)
	await _capture("lab_success")
	game._reset_combat_input()
	await _tap(KEY_SHIFT)
	await _tap(KEY_SHIFT)
	await _tap(KEY_W)
	check(game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST and game.runes == ["W"], "Lab also dispatches Shift double tap and focus WASD commands")
	await _tap(KEY_ESCAPE)
	check(game.runes.is_empty() and game.combat_input.mode == game.CombatInput.Mode.NORMAL, "Lab Escape leaves focus and records the unfinished experiment")
	await _click(ui.exit_button)
	await _tap(KEY_1)
	check(game.game_state == "DUNGEON" and not ui.panel.visible, "GUI exit returns to hub and original dungeon entry still works")
	game.free()
	print("LAB RENDER / GUI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _chant(keys: Array) -> void:
	root.gui_release_focus()
	await _key(KEY_SHIFT, true)
	for token in keys: await _tap(OS.find_keycode_from_string(token))

func _tap(code: Key) -> void:
	await _key(code, true)
	await _key(code, false)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _click(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control); await process_frame; await process_frame
			break
		ancestor = ancestor.get_parent()
	# Historical tests now use the public Shift-up / focus LMB controls.
	if control == game.laboratory_panel.release_button or control == game.laboratory_panel.trial_release_button:
		var ui = game.laboratory_panel
		if game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST:
			ui.show_trial(false); await process_frame
		if ui.trial_panel.visible:
			var point: Vector2 = ui.arena.world_to_screen(ui.arena.player_pos+Vector2(160,0))
			Input.warp_mouse(point); await process_frame
			var motion := InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
			Input.parse_input_event(motion); await process_frame
		if game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST:
			var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT
			event.position=ui.arena.world_to_screen(ui.arena.player_pos+Vector2(160,0)); event.global_position=event.position; event.pressed=true
			Input.parse_input_event(event); await process_frame
			event.pressed=false; Input.parse_input_event(event); await process_frame
		else: await _key(KEY_SHIFT,false)
		return
	await process_frame
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await process_frame

func _capture(label: String) -> void:
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(DIR + label + ".png") == OK and screenshot.get_size() == Vector2i(1160, 720), "Rendered " + label + " at 1160 x 720")
