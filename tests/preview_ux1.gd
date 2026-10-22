extends SceneTree
## Actual Godot window/input/GUI dispatch. All characters and records are isolated.
const SCENE = preload("res://scenes/main.tscn")
const Fixture = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const Data = preload("res://scripts/developer_test_data.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Helper = preload("res://tests/test_chant.gd")
const Model = preload("res://scripts/mana_visual_model.gd")
const Orb = preload("res://scripts/mana_orb_view.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const DIR := "res://.task002_artifacts/ux1/"
var game
var checks := 0
var failures := 0
var metrics: Array = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size = Vector2i(1160, 720)
	DisplayServer.window_set_title("Arcane Legacy · Phase 2B-UX1 verification")
	A.write(DIR + "window_character.json", Fixture.fixture("WATER", 8431))
	game = SCENE.instantiate()
	game.save_path = DIR + "window_character.json"
	game.developer_tools_enabled = true
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.3).timeout
	await _tap(KEY_1)
	Fixture.reset_arena(game)
	await _world_controls()
	await _developer_windows()
	var output := FileAccess.open(DIR + "window_metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics, "\t"))
	output.close()
	game.free()
	print("UX1 WINDOW TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _world_controls() -> void:
	await _click_point(Vector2(600, 300), MOUSE_BUTTON_RIGHT)
	game._process(0.15)
	var destination: Vector2 = game.navigation.destination
	await _motion(Vector2(250, 180))
	game._process(0.05)
	check(game.navigation.active and game.navigation.destination == destination and game.player_pos.x > 300, "Real RMB click/release moves after release; cursor aim change leaves the destination fixed")
	await _click_point(Vector2(650, 420), MOUSE_BUTTON_RIGHT)
	check(game.navigation.destination == Vector2(650, 420), "Real second RMB updates destination")
	await _chant(Data.inputs(game.chant_profile, "WATER", Data.basic_actions("WATER")))
	await _click_point(Vector2(700, 350), MOUSE_BUTTON_LEFT)
	game._process(0.05)
	check(game.runes.is_empty() and game.navigation.active and game.missiles.size() == 1 and game.player_mana < 100, "Mobile WATER releases with LMB while destination movement continues")
	await _capture("rmb_mobile_cast")
	await _key(KEY_SHIFT, false)
	await _focus()
	var origin: Vector2 = game.player_pos
	await _tap(KEY_W)
	await _click_point(Vector2(700, 450), MOUSE_BUTTON_RIGHT)
	await _tap(KEY_CTRL)
	game._process(0.1)
	check(game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST and game.player_pos == origin and game.runes == ["W"] and not game.navigation.active and not game.dodge.active, "Real focus gesture cancels movement; WASD chants and RMB/Ctrl cannot move")
	await _capture("focus_stationary")
	await _tap(KEY_ESCAPE)
	game._process(0.05)
	check(game.player_pos == origin and not game.navigation.active, "Focus exit does not resume the old destination")
	await _click_point(Vector2(650, 450), MOUSE_BUTTON_RIGHT)
	game._process(0.05)
	await _tap(KEY_CTRL)
	game._process(0.06)
	check(game.dodge.active and not game.navigation.active, "Real Ctrl starts a physical dodge and cancels the destination")
	await _capture("ctrl_dodge")
	game._process(0.13)
	await _tap(KEY_CTRL)
	check(not game.dodge.active and game.dodge.cooldown > 0, "Repeated Ctrl is blocked by the displayed cooldown")
	await _key(KEY_ALT, true)
	game._process(0.05)
	check(game.focus_active and game.focus < 100, "Alt swift sense remains independent of RMB and Ctrl")
	await _key(KEY_ALT, false)
	await _tap(KEY_J)
	var hud = game.spell_record_hud
	await _click_point(hud.panel.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	check(hud.expanded and not game.navigation.active, "RMB on the actual J HUD never becomes a world move")
	await _capture("j_hud_new_controls")
	for i in 150: game.navigation.advance(game, 0.025, game.PLAYER_SPEED)
	# A stationary physical dodge avoids a real projectile trajectory in this window.
	Fixture.reset_arena(game)
	game.dodge.reset()
	await _motion(Vector2(300, 150))
	await _tap(KEY_CTRL)
	game._process(0.18)
	game.missiles.append({"pos": Vector2(250, 300), "dir": Vector2.RIGHT, "hostile": true, "life": 2.0, "dmg": 16.0})
	game._update_missiles(0.5, 1.0)
	check(game.player_hp == 100 and game.player_pos.distance_to(Vector2(300, 300)) > 80, "Real stationary Ctrl input physically avoids the enemy projectile line")
	await _capture("dodge_avoids_projectile")

func _developer_windows() -> void:
	var disk := FileAccess.get_file_as_bytes(game.save_path)
	var original: Dictionary = game._character_document()
	var position: Vector2 = game.player_pos
	await _tap(KEY_F2)
	var dev = game.developer_panel
	check(dev.panel.visible and dev.text.text.contains("ACCUMULATE"), "F2 opens the developer-only mapping and verified-input screen")
	await _tap(KEY_F2)
	check(not dev.panel.visible, "F2 closes the developer menu without stopping the game")
	await _click(dev.opener)
	check(dev.panel.visible, "Visible developer button opens the menu without a keyboard shortcut")
	await _capture("developer_selection")
	for index in Profile.ELEMENTS.size():
		await _select(dev.elements, index)
		await _select(dev.location, 0)
		await _click(dev.start_button)
		var element: String = Profile.ELEMENTS[index]
		check(game.developer_mode and (game.research.main_attribute == element if element != "VOID" else game.research.main_attribute == null and game.research.researched_base_elements.is_empty()) and game.game_state == "LAB", "Actual selector creates a temporary " + element + " elemental/neutral lab character")
		var ui = game.laboratory_panel
		ui.arena.set_process(false)
		for example in Data.examples(game.chant_profile, element, game.research.simulation_context()):
			game._laboratory_recover()
			await _chant(example["inputs"])
			await _click(ui.release_button if ui.panel.visible else ui.trial_release_button)
			await _key(KEY_SHIFT, false)
			check(ui.trial_banner.text.contains("발현 성공 · " + example["name"]) and game.developer_metrics.get("input_count") == example["inputs"].size(), "Visible temporary lab manifestation: " + example["name"])
			var sample: Dictionary = game.developer_metrics.duplicate(true)
			sample["location"] = "LAB"
			metrics.append(sample)
			ui.arena.advance(0.12 if element in ["METAL", "VOID"] or example["spell_id"] == "FIRE_LANCE" else 0.65)
			await _capture("developer_lab_" + str(example["spell_id"]).to_lower())
		await _tap(KEY_F2)
	check(FileAccess.get_file_as_bytes(game.save_path) == disk, "All six actual-window lab sessions leave original save bytes unchanged")
	await _select(dev.elements, 1)
	await _select(dev.location, 1)
	await _capture("developer_fire_comparison")
	await _click(dev.start_button)
	for example in Data.examples(game.chant_profile, "FIRE", game.research.simulation_context()):
		Fixture.reset_arena(game)
		# Keep all three targets inside the arena, independent of the last UI click.
		game.player_pos = game.AREA.get_center()
		await _motion(game.player_pos + Vector2(200, 0))
		var aim: Vector2 = (game.get_global_mouse_position() - game.player_pos).normalized()
		if aim.is_zero_approx(): aim = Vector2.RIGHT
		for distance in [100, 160, 220]: game.enemies.append(Fixture.target(game.player_pos + aim * distance))
		await _chant(example["inputs"])
		await _click_point(game.player_pos + aim * (160 if example["spell_id"] == "OH-018" else 30), MOUSE_BUTTON_LEFT)
		await _key(KEY_SHIFT, false)
		game._update_missiles(0.6, 1.0)
		var sample: Dictionary = game.developer_metrics.duplicate(true)
		sample["location"] = "DUNGEON"
		metrics.append(sample)
		var hit := 0
		for enemy in game.enemies:
			if enemy["hp"] < 100: hit += 1
		check(hit == (1 if example["spell_id"] in ["FIRE_EMBER", "OH-017", "OH-018"] else 3), "Developer dungeon actual input produces the expected target pattern: " + example["name"])
	await _capture("developer_dungeon_fire")
	await _tap(KEY_F2)
	await _click(dev.end_button)
	check(not game.developer_mode and game.game_state == "DUNGEON" and game.player_pos == position and Helper.equal(game._character_document(), original) and FileAccess.get_file_as_bytes(game.save_path) == disk, "GUI End restores original WATER, key table, discoveries, location and unchanged save")
	await _tap(KEY_F2)
	await _select(dev.elements, 4)
	await _select(dev.location, 0)
	await _click(dev.start_button)
	await _progressive_observation()
	await _reaction_gallery()
	game._end_developer_test()

func _progressive_observation() -> void:
	var data: Dictionary = game.research.to_data()
	data["research_clues"] = [] # Controlled temporary character only, no real data.
	game.research.load_data(data)
	var ui = game.laboratory_panel
	ui.arena.set_process(false)
	await _key(KEY_SHIFT, true)
	await _tap(OS.find_keycode_from_string(Helper.first_for(game.chant_profile, "FIRE")))
	check(ui.live_orb.descriptor == Model.project(Sim.initial_state()), "Actual first attribute key is neutral, even with the observation lens available")
	await _capture("first_word_neutral")
	for action in ["ACCUMULATE", "COMPRESS", "STABILIZE"]: await _tap(OS.find_keycode_from_string(Helper.key_for(game.chant_profile, action)))
	for i in 3:
		await _tap(OS.find_keycode_from_string(Helper.key_for(game.chant_profile, "RESONATE")))
		await _tap(OS.find_keycode_from_string(Helper.key_for(game.chant_profile, "STABILIZE")))
		var stage: String = ["faint", "growing", "stable"][i]
		check(ui.live_orb.descriptor["reaction"]["stage"] == stage, "Real opposed FIRE reaction develops: " + stage)
		await _capture("fire_reaction_" + stage)
	await _click(ui.release_button)
	await _key(KEY_SHIFT, false)
	var record: Dictionary = game.journal.records()[-1]
	ui.steppers[0].value = record["steps"].size()
	await _click(ui.observation_lens)
	check(ui.live_orb.descriptor == ui.after_orbs[0].descriptor and ui.observation_lens.button_pressed and ui.live_orb.observation_gain == ui.after_orbs[0].observation_gain, "Actual lens/archived comparison renders the same stored final evidence")
	var scroll: ScrollContainer = ui.panel.get_child(0)
	scroll.ensure_control_visible(ui.save_note_button); await process_frame; await process_frame
	check(ui.panel.get_global_rect().end.y <= 720 and ui.save_note_button.get_global_rect().end.y <= 690, "Scrollable lens/hint and note/replay controls remain accessible in the window")
	await _capture("lens_and_stored_comparison")

func _reaction_gallery() -> void:
	game.laboratory_panel.panel.hide()
	var layer := CanvasLayer.new()
	layer.layer = 35
	root.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(45, 105)
	backdrop.size = Vector2(1070, 570)
	backdrop.color = Color("182334")
	layer.add_child(backdrop)
	var images: Array = []
	for i in Profile.ELEMENTS.size():
		var element: String = Profile.ELEMENTS[i]
		var offset := Vector2(65 + i % 3 * 350, 120 + i / 3 * 270)
		var label := Label.new()
		label.text = "DEVELOPER · " + element + (" · 실제 안정 공명" if element != "VOID" else " · 비원소 동력")
		label.position = offset
		layer.add_child(label)
		var orb := Orb.new()
		orb.position = offset + Vector2(0, 25)
		orb.size = Vector2(330, 225)
		layer.add_child(orb)
		var simulation := Sim.simulate(game.chant_profile, Helper.inputs(A.sequence(game.chant_profile, element)), true, game.research.simulation_context())
		orb.show_snapshot(simulation["final_state"], 2.0, false, simulation["simulation_context"])
		await RenderingServer.frame_post_draw
		images.append(root.get_texture().get_image().get_region(Rect2i(orb.get_global_rect())))
	var distinct := true
	for i in images.size():
		for j in range(i): distinct = distinct and images[i].get_data() != images[j].get_data()
	check(distinct, "Six actual rendered stable reaction images have different pixels and forms")
	await _capture("six_reaction_gallery")
	layer.queue_free()
	await process_frame

func _chant(events: Array) -> void:
	root.gui_release_focus()
	await _key(KEY_SHIFT, true)
	for event in events: await _tap(OS.find_keycode_from_string(event["key"]))
func _focus() -> void:
	for pressed in [true, false, true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SHIFT
		event.physical_keycode = KEY_SHIFT
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func _select(control: OptionButton, index: int) -> void:
	await _click(control)
	await _tap(KEY_HOME)
	for step in range(index + 1): await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await process_frame
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
func _motion(point: Vector2) -> void:
	Input.warp_mouse(point)
	await process_frame
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	# Update Input's mouse position as well as dispatching to the viewport.
	# Viewport.push_input alone leaves get_global_mouse_position() stale.
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
	await _click_point(control.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
func _click_point(point: Vector2, button: MouseButton) -> void:
	await _motion(point)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await process_frame
func _capture(label: String) -> void:
	game.queue_redraw()
	game.laboratory_panel.arena.queue_redraw()
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(DIR + label + ".png") == OK and screenshot.get_size() == Vector2i(1160, 720), "Rendered " + label)
