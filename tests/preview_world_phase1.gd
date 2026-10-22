extends SceneTree
const Scene = preload("res://scenes/world_main.tscn")
const F = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const D = preload("res://scripts/developer_test_data.gd")
var game
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
	create_timer(180).timeout.connect(func(): push_error("World window watchdog timeout"); quit(1))
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + title)
	else: print("PASS: ", title)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event); await process_frame
func tap(code: Key) -> void: await key(code, true); await key(code, false)
func aim(world: Vector2) -> Vector2:
	game.world_camera.reset_smoothing()
	game.world_camera.force_update_scroll()
	var point: Vector2 = game.get_canvas_transform() * world
	Input.warp_mouse(point); await process_frame
	var event := InputEventMouseMotion.new(); event.position = point; event.global_position = point; Input.parse_input_event(event); await process_frame
	return point
func click_world(world: Vector2, button := MOUSE_BUTTON_RIGHT) -> void:
	var point: Vector2 = await aim(world)
	var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = button; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event.pressed = false; Input.parse_input_event(event); await process_frame
func walk_step(goal: Vector2) -> void:
	await click_world(goal)
	for i in 1000:
		game._process(1.0 / 60)
		if i % 10 == 0: await process_frame
		if not game.navigation.active: break
func screenshot(name: String) -> void:
	game._sync_world_view(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.task002_artifacts/phase3a/" + name + ".png")
func click_control(control: Control) -> void:
	await process_frame
	var point := control.get_global_rect().get_center()
	Input.warp_mouse(point); await process_frame
	var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	root.push_input(event, true); await process_frame
	event.pressed = false; root.push_input(event, true); await process_frame
func choose(control: OptionButton, index: int) -> void:
	await click_control(control); await tap(KEY_HOME)
	for i in range(index + 1): await tap(KEY_DOWN)
	await tap(KEY_ENTER); await process_frame
func run() -> void:
	root.size = Vector2i(1160, 720)
	A.write("res://.task002_artifacts/phase3a/window_p1.json", F.fixture("WATER", 1787453028))
	game = Scene.instantiate(); game.save_path = "res://.task002_artifacts/phase3a/window_p1.json"; root.add_child(game); game.set_process(false)
	await process_frame; game.world_camera.reset_smoothing(); game.world_camera.force_update_scroll()
	check(game.world_camera.enabled and game.layout.region(game.player_pos) == "TOWN", "Actual window renders the Camera2D town")
	await screenshot("01_town")
	await walk_step(Vector2(580, 600)); await walk_step(game.layout.LAB_DOOR)
	check(game.player_pos.distance_to(game.layout.LAB_DOOR) < 2, "Actual RMB clicks move the character around the laboratory footprint")
	await tap(KEY_E)
	check(game.game_state == "LAB" and game.laboratory_panel.visible, "Actual E event enters the original lab UI")
	await key(KEY_SHIFT, true)
	for event in D.inputs(game.chant_profile, "WATER", ["ACCUMULATE", "DIRECT"]): await tap(OS.find_keycode_from_string(event["key"]))
	await key(KEY_SHIFT, false)
	check(game.journal.records().size() == 1 and game.laboratory_panel.arena.missiles.size() > 0, "Actual Shift-up manifests one existing spell and records once")
	await screenshot("02_existing_lab")
	game._leave_laboratory(); await process_frame
	check(game.world_camera.enabled and game.player_pos == game.layout.LAB_DOOR, "Lab exit restores the top-down camera at its doorway")
	await walk_step(Vector2(800, 700)); await walk_step(Vector2(1100, 750)); await walk_step(Vector2(1400, 850)); await walk_step(Vector2(1750, 900))
	check(game.player_pos.x > 1620 and not game._is_blocked(game.player_pos), "Actual successive RMB clicks cross the open gate into the exterior")
	await screenshot("03_gate_exterior")
	await tap(KEY_F2)
	check(game.developer_panel.panel.visible, "F2 developer panel opens from the world without CMD")
	await screenshot("04_world_f2")
	var document: Dictionary = game._character_document(); var disk := FileAccess.get_file_as_bytes(game.save_path)
	await choose(game.developer_panel.location, 2); await click_control(game.developer_panel.start_button)
	check(game.developer_mode and game.world_enabled and game.guardian.active, "Actual F2 dropdown and start button launch the new isolated world-boss location")
	await screenshot("14_world_boss_developer")
	await tap(KEY_F2); await click_control(game.developer_panel.end_button)
	check(not game.developer_mode and game._character_document() == document and FileAccess.get_file_as_bytes(game.save_path) == disk, "Actual F2 end button restores world, lab record and original disk")
	var path: String = game.save_path; game.free()
	game = Scene.instantiate(); game.save_path = path; game.developer_tools_enabled = false; root.add_child(game); game.set_process(false); await process_frame; await tap(KEY_F2)
	check(game.developer_panel == null and not game._start_developer_test("WOOD", "WORLD"), "Disabled developer policy exposes no world panel or world-boss launch")
	print("WORLD PHASE1 WINDOW: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
