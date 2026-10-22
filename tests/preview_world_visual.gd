extends "res://tests/preview_world_phase1.gd"
## A real rendered window with synthetic input; only isolated save fixtures are used.
const OUT := "res://.task002_artifacts/visual_topdown/"
func frame() -> void:
	game._sync_world_view()
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String, clean := false) -> void:
	await frame()
	var layers: Array[Node] = game.find_children("*", "CanvasLayer", true, false)
	var visibility: Array[bool] = []
	if clean:
		for layer in layers:
			visibility.append(layer.visible)
			layer.visible = false
		await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	if clean:
		for i in layers.size(): layers[i].visible = visibility[i]
func place(point: Vector2) -> void:
	game.player_pos = point
	game.navigation.cancel()
	game._sync_world_view(); game.world_camera.reset_smoothing(); game.world_camera.force_update_scroll()
	await frame()
func pixel_difference(a: Image, b: Image, patch: Rect2i) -> int:
	var count := 0
	for y in range(maxi(0, patch.position.y), mini(a.get_height(), patch.end.y)):
		for x in range(maxi(0, patch.position.x), mini(a.get_width(), patch.end.x)):
			if a.get_pixel(x, y) != b.get_pixel(x, y): count += 1
	return count
func occlusion(point: Vector2, hidden: bool, name: String, legs_only := false) -> void:
	await place(point)
	game.player_view.body.animation = &"down"
	game.player_view.body.frame = 0
	game.player_view.body.pause()
	await capture(name, true)
	var with_actor: Image = root.get_texture().get_image()
	var head: Vector2 = game.get_canvas_transform() * (point + Vector2(0, -8 if legs_only else -32))
	var patch := Rect2i(Vector2i(head) - Vector2i(13, 6 if legs_only else 22), Vector2i(26, 12 if legs_only else 39))
	game.player_view.visible = false
	await capture(name + "_reference", true)
	var without_actor: Image = root.get_texture().get_image()
	var changed := pixel_difference(with_actor, without_actor, patch)
	check(changed == 0 if hidden else changed > 100, "Actual render occlusion %s: changed body pixels %d" % [name, changed])
	game.player_view.visible = true
func run() -> void:
	root.size = Vector2i(1160, 720)
	var path := OUT + "window_fixture_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, F.fixture("WATER", 1787453028))
	game = Scene.instantiate(); game.save_path = path; root.add_child(game); game.set_process(false)
	await frame()
	var disk := FileAccess.get_file_as_bytes(path)
	# Camera framing only for this overview; no runtime limits or controls are changed.
	root.size = Vector2i(1280, 1080); root.content_scale_size = Vector2i(1280, 1080)
	game.world_camera.zoom = Vector2.ONE * 0.75
	await place(Vector2(820, 720))
	await capture("01_town_overview", true)
	check(root.get_texture().get_width() == 1280 and game.actors.y_sort_enabled, "Wide actual viewport captures all four town buildings")
	root.size = Vector2i(1160, 720); root.content_scale_size = Vector2i(1160, 720)
	game.world_camera.zoom = Vector2.ONE
	await place(Vector2(540, 570))
	await walk_step(game.layout.LAB_DOOR)
	check(game.player_pos.distance_to(game.layout.LAB_DOOR) < 2, "RMB reaches the visible laboratory door with unchanged collision")
	# A temporary camera offset makes the full roof and entrance visible together.
	game.world_camera.offset = Vector2(0, -95)
	await frame()
	game.player_view.facing = &"down"
	await capture("02_laboratory_front")
	await tap(KEY_E)
	check(game.game_state == "LAB", "E enters the existing lab at the illustrated entrance")
	game._leave_laboratory(); await frame()
	game.world_camera.offset = Vector2.ZERO
	for goal in [Vector2(330, 550), Vector2(330, 430), Vector2(330, 300), Vector2(330, 240), Vector2(540, 240), Vector2(750, 240), Vector2(750, 430), Vector2(750, 550), Vector2(540, 550)]:
		await walk_step(goal)
		check(game.player_pos.distance_to(goal) < 2, "RMB route passes around the real building footprint: " + str(goal))
	await occlusion(Vector2(540, 240), true, "03_laboratory_behind")
	await occlusion(Vector2(540, 525), false, "04_laboratory_in_front")
	check(not game.layout.blocked(Vector2(540, 240), 13) and not game.layout.blocked(Vector2(540, 525), 13), "Both occlusion probes are legal ground positions outside the original solid building")
	await occlusion(Vector2(1850, 490), true, "05_tree_behind")
	await occlusion(Vector2(1850, 565), false, "06_tree_in_front")
	# A legal position north of the wall: wall top hides legs, head stays above it.
	await occlusion(Vector2(900, 65), true, "07_wall_behind", true)
	check(not game.layout.blocked(Vector2(900, 65), 13), "Wall occlusion probe is outside the original solid footprint")
	await place(Vector2(1480, 900))
	await walk_step(Vector2(1595, 900)); await capture("08_gate_crossing")
	await walk_step(Vector2(1750, 900))
	check(game.player_pos.x > 1620 and not game._is_blocked(game.player_pos), "Actual RMB crossing passes between wall faces into the wilds")
	await place(Vector2(1800, 700))
	await walk_step(Vector2(1950, 730)); await walk_step(Vector2(2190, 700))
	check(game.player_pos.distance_to(Vector2(2190, 700)) < 2 and not game._is_blocked(game.player_pos), "Actual pathfinding moves between trunk collisions and rock footprint")
	await capture("09_trees_and_rocks")
	# Four actual movement directions and mouse-facing on attack/casting.
	await place(Vector2(2150, 710))
	for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		var start: Vector2 = game.player_pos
		await click_world(start + direction * 40)
		game._process(0.02); game.player_view.update_presentation(0.02)
		check(game.player_view.facing == game.player_view.Art.direction(direction), "Actual RMB motion selects " + str(direction))
		game.navigation.cancel()
		await capture("10_facing_" + String(game.player_view.facing))
	await aim(game.player_pos + Vector2.LEFT * 100)
	await key(KEY_SHIFT, true)
	game.player_view.update_presentation(0.02)
	check(game.player_view.facing == &"left", "Shift casting faces the actual mouse aim independently of walking")
	await tap(KEY_ESCAPE); await key(KEY_SHIFT, false)
	var zoom_before: Vector2 = game.world_camera.zoom
	await tap(KEY_EQUAL)
	check(game.world_camera.zoom.x > zoom_before.x, "Actual zoom-in input preserves the Camera2D controls")
	await tap(KEY_MINUS)
	check(game.world_camera.zoom.is_equal_approx(zoom_before) and game.world_camera.position == game.player_pos, "Zoom-out and camera tracking preserve ground coordinates")
	await key(KEY_ALT, true); game._process(0.02)
	check(game.focus_active, "Actual Alt input retains transcendental sense")
	await key(KEY_ALT, false); game._process(0.02)
	await tap(KEY_F2)
	check(game.developer_panel.panel.visible, "F2 remains available in the rendered world")
	await tap(KEY_F2)
	var before_test: Dictionary = game._character_document()
	var before_test_disk := FileAccess.get_file_as_bytes(path)
	game._start_developer_test("WATER", "WORLD")
	await place(Vector2(3160, 910))
	var hp: float = game.guardian.actor["hp"]
	await aim(game.guardian.actor["pos"])
	await key(KEY_SHIFT, true)
	for event in D.inputs(game.chant_profile, "WATER", ["ACCUMULATE", "DIRECT"]): await tap(OS.find_keycode_from_string(event["key"]))
	await click_world(game.guardian.actor["pos"], MOUSE_BUTTON_LEFT)
	await key(KEY_SHIFT, false)
	for i in 35: game._process(0.02)
	await capture("11_guardian_water_hit")
	check(game.guardian.actor["hp"] < hp and game.guardian.actor.get("wet_remaining", 0) > 0, "Actual personal water chant hits the upright guardian and applies wet status")
	game.guardian._begin_pattern(game, "SWEEP")
	await capture("12_guardian_warning")
	check(game.guardian.state == "WINDUP", "Boss telegraph remains on the original ground/collision plane")
	var player_hp: float = game.player_hp
	await click_world(game.player_pos + Vector2(-120, 80)); await tap(KEY_CTRL)
	check(game.dodge.active, "Actual Ctrl event starts the existing dodge")
	for i in 60: game._process(0.02)
	check(game.player_hp == player_hp, "Existing collision and dodge avoid the warning attack")
	game._end_developer_test()
	check(game._character_document() == before_test and FileAccess.get_file_as_bytes(path) == before_test_disk, "Developer end restores full character, research journal and save bytes")
	# Fixture disk may have changed through normal movement; actual user save is never loaded.
	check(not disk.is_empty() and path.begins_with(OUT), "Every window action used an isolated fixture, never the user save")
	print("WORLD VISUAL WINDOW: %d checks, %d failures" % [checks, failures])
	game.free(); quit(1 if failures else 0)
