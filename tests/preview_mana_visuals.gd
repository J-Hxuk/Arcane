extends SceneTree
## Visible-window validation: real lab UI, input events, rendered pixel comparisons.
const SCENE = preload("res://scenes/main.tscn")
const Model = preload("res://scripts/mana_visual_model.gd")
const Orb = preload("res://scripts/mana_orb_view.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Helper = preload("res://tests/test_chant.gd")
const Fixture = preload("res://tests/test_elemental_combat.gd")
const Data = preload("res://tests/test_mana_visuals.gd")
const DIR := "res://.task002_artifacts/mana_visuals/"
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
		push_error("Run without --headless.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size = Vector2i(1160, 720)
	DisplayServer.window_set_title("Arcane Legacy - Mana Observatory Verification")
	var path := DIR + "window_character.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(Fixture.fixture(null, 71)))
	file.close()
	game = SCENE.instantiate()
	game.save_path = path
	root.add_child(game)
	game.set_process(false)
	await _tap(KEY_L)
	var ui = game.laboratory_panel
	check(game.game_state == "LAB" and ui.live_orb.is_visible_in_tree(), "Live observatory is in the actual laboratory")
	await _capture("observatory_empty")
	await _key(KEY_SHIFT, true)
	await _tap(KEY_C)
	check(ui.live_orb.descriptor == Model.project(Sim.initial_state()), "First pure/attribute declaration remains visually neutral")
	await _capture("first_word_neutral")
	var accumulate := OS.find_keycode_from_string(Helper.key_for(game.chant_profile, "ACCUMULATE"))
	await _key(accumulate, true)
	await create_timer(0.32).timeout
	game._update_laboratory_live()
	check(ui.live_orb.snapshot["mana_amount"] >= 15.0, "Held accumulation updates the live orb before key release")
	await _key(accumulate, false)
	await _tap(OS.find_keycode_from_string(Helper.key_for(game.chant_profile, "COMPRESS")))
	await _capture("live_compression")
	for action in ["SHAPE", "DIRECT", "STABILIZE"]:
		await _tap(OS.find_keycode_from_string(Helper.key_for(game.chant_profile, action)))
	await _click(ui.release_button)
	await _key(KEY_SHIFT, false)
	await _click(ui.journal_button)
	check(game.journal.records().size() == 1, "Real chant release creates its normal archived experiment")
	var record: Dictionary = game.journal.records()[0]
	ui.steppers[0].value = record["steps"].size()
	check(ui.live_orb.descriptor == ui.after_orbs[0].descriptor, "Actual live final orb and saved replay after-state have identical sensory descriptors")
	await _capture("live_and_saved_state")
	# Make this archived replay's timing long enough to observe normal transport.
	# This is an isolated fixture; snapshots and observations are unmodified.
	var timed: Dictionary = game.journal.to_data()
	for i in timed["records"][0]["steps"].size():
		timed["records"][0]["steps"][i]["input"]["at_ms"] = i * 700
		timed["records"][0]["steps"][i]["input"]["hold_ms"] = 100
	timed["records"][0]["result"]["elapsed_ms"] = (record["steps"].size() - 1) * 700 + 100
	game.journal.load_data(timed)
	ui.refresh()
	ui.timelines[0].value = 0.0
	var unchanged: Array = [game.player_mana, game.research.to_data(), game.chant_profile.to_data(), game.journal.to_data(), game.missiles.duplicate(true), FileAccess.get_sha256(path)]
	await _click(ui.play_buttons[0])
	await create_timer(0.9).timeout
	await _click(ui.play_buttons[0])
	check(not ui.playing[0] and ui.playheads[0] >= 700.0 and ui.steppers[0].value >= 2, "Real Play/Pause buttons move through stored timestamps")
	await _click(ui.next_buttons[0])
	var index := int(ui.steppers[0].value) - 1
	check(ui.after_orbs[0].snapshot == timed["records"][0]["steps"][index]["after"], "GUI next step shows its exact archived state")
	await _capture("timeline_step_comparison")
	ui.timelines[0].value = ui.timelines[0].max_value
	check(not ui.playing[0] and ui.steppers[0].value == record["steps"].size(), "Timeline slider seeks to the last stored step without casting")
	check(unchanged == [game.player_mana, game.research.to_data(), game.chant_profile.to_data(), game.journal.to_data(), game.missiles.duplicate(true), FileAccess.get_sha256(path)], "Visible replay has no combat, mana, research, mapping, journal or disk-save side effects")
	var scroll: ScrollContainer = ui.panel.get_child(0)
	scroll.ensure_control_visible(ui.save_note_button); await process_frame; await process_frame
	check(ui.panel.get_global_rect().end.x <= 1160 and ui.panel.get_global_rect().end.y <= 720 and ui.save_note_button.get_global_rect().end.y <= 700, "Observatory and scrollable note controls fit the 1160x720 window: panel=%s note=%s" % [ui.panel.get_global_rect(),ui.save_note_button.get_global_rect()])
	await _gallery()
	game.free()
	print("MANA VISUAL WINDOW TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _gallery() -> void:
	game.laboratory_panel.panel.hide()
	var layer := CanvasLayer.new()
	layer.layer = 40
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("111c2a")
	background.size = Vector2(1160, 720)
	layer.add_child(background)
	var title := Label.new()
	title.text = "MANA OBSERVATORY / ISOLATED VISUAL VERIFICATION"
	title.position = Vector2(30, 24)
	title.add_theme_font_size_override("font_size", 22)
	layer.add_child(title)
	var labels := ["기준 장면", "커지는 잔광", "모여드는 입자", "가라앉은 떨림", "둘레의 회전", "이어지는 윤곽", "한 방향의 흐름", "사라진 덩어리", "갈라진 흔들림", "깨진 윤곽"]
	var names := ["BASE", "ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE", "SHAPE", "DIRECT", "DISSIPATE", "UNSTABLE", "COLLAPSED"]
	var samples := Data.states()
	var orbs: Array[Control] = []
	for i in names.size():
		var column := VBoxContainer.new()
		column.position = Vector2(25 + (i % 5) * 225, 100 + (i / 5) * 280)
		column.size = Vector2(210, 250)
		layer.add_child(column)
		var label := Label.new()
		label.text = labels[i]
		label.theme = game.research_panel.opener.theme
		column.add_child(label)
		var orb := Orb.new()
		orb.custom_minimum_size = Vector2(210, 215)
		column.add_child(orb)
		orb.show_snapshot(samples[names[i]], 2.0)
		orbs.append(orb)
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var hashes: Array = []
	for i in orbs.size():
		var crop := screenshot.get_region(Rect2i(orbs[i].get_global_rect()))
		var signature := crop.get_data().hex_encode().sha256_text()
		check(not hashes.has(signature), "Distinct rendered pixels for state " + names[i])
		hashes.append(signature)
	check(screenshot.save_png(DIR + "visual_gallery.png") == OK, "Saved ten-state actual Godot render gallery")
	var moving = orbs[4]
	moving.show_snapshot(samples["RESONATE"], 2.3)
	await RenderingServer.frame_post_draw
	var next := root.get_texture().get_image().get_region(Rect2i(moving.get_global_rect()))
	check(next.get_data().hex_encode().sha256_text() != hashes[4], "Rotation/motion changes rendered pixels with visual time")
	layer.free()

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
	check(screenshot.save_png(DIR + label + ".png") == OK, "Rendered " + label + " in actual Godot window")
