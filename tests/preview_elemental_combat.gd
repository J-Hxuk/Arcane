extends SceneTree
## Visible Godot window: synthetic engine input -> real Main -> actual combat effects.
const SCENE = preload("res://scenes/main.tscn")
const Test = preload("res://tests/test_elemental_combat.gd")
const Awakening = preload("res://tests/test_awakening.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const DIR := "res://.task002_artifacts/phase2b25/"
var checks := 0
var failures := 0
var game
var overlay: Label
var last_aim := Vector2.RIGHT
var target_positions: Array[Vector2] = []

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
		push_error("This verification requires a visible Godot window.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size = Vector2i(1160, 720)
	DisplayServer.window_set_title("Arcane Legacy - Phase 2B-2.5A Combat Verification")
	await create_timer(0.5).timeout
	for element in Profile.ELEMENTS:
		var path: String = DIR + "window_" + element + ".json"
		Awakening.write(path, Test.fixture(element, 98765))
		game = SCENE.instantiate()
		game.save_path = path
		root.add_child(game)
		game.set_process(false)
		await _tap(KEY_1)
		check(game.game_state == "DUNGEON", element + " real window dispatches dungeon entry")
		Test.reset_arena(game)
		game.player_pos = game.AREA.get_center()
		_overlay()
		await process_frame
		await _chant(element, false)
		check(game.combat_input.mode == game.CombatInput.Mode.MOBILE_CAST and game._inspect_chant()["state"] == "ready", element + " mobile mode interprets personal chant")
		await _release(element)
		await _key(KEY_SHIFT, false)
		game._update_missiles(0.6, 1.0)
		match element:
			"WOOD":
				game._update_enemies(0.5)
				check(game.enemies[0]["hp"] == 88.0 and game.enemies[0]["pos"] == target_positions[0], "Window WOOD: root prevents movement")
				overlay.text = "TEST CHARACTER / WOOD: 12 damage + root 2.4s; target stays still"
			"FIRE":
				game.elemental_combat.update(game, 1.0)
				check(game.enemies[0]["hp"] == 75.0, "Window FIRE: impact plus one second of burning")
				overlay.text = "TEST CHARACTER / FIRE: HP 100 -> 82 impact -> 75 burn (1s)"
			"EARTH":
				var position: Vector2 = game.elemental_combat.barriers[0]["pos"]
				game.enemies.append(Test.target(position + last_aim * 60.0))
				game._try_move_player(last_aim * 95.0)
				game._update_enemies(0.5)
				game.missiles.append({"pos": position + last_aim * 60.0, "dir": -last_aim, "hostile": true, "life": 2.0, "dmg": 16.0})
				game._update_missiles(0.5, 1.0)
				check(game.player_pos.distance_to(position) >= 35.0 and game.enemies[0]["pos"].distance_to(position) >= 35.0 and game.missiles.is_empty() and game.player_hp == 100.0, "Window EARTH: barrier blocks both actors and hostile shot")
				overlay.text = "TEST CHARACTER / EARTH: 5s barrier; player / enemy / shot blocked"
			"METAL":
				check(game.enemies[0]["hp"] == 76.0 and game.enemies[1]["hp"] == 76.0 and game.enemies[2]["hp"] == 76.0 and game.enemies[3]["hp"] == 100.0, "Window METAL: three pierced targets and untouched fourth")
				overlay.text = "TEST CHARACTER / METAL: four targets HP [76, 76, 76, 100]; 3-target pierce"
			"WATER":
				check(game.enemies[0]["hp"] == 90.0 and game.enemies[0]["pos"].distance_to(target_positions[0] + last_aim * 100.0) < 0.01, "Window WATER: impact and 100-unit displacement")
				overlay.text = "TEST CHARACTER / WATER: HP 90; target pushed 100 units along actual aim"
			"VOID":
				check(game.enemies[0]["hp"] == 84.0 and game.enemies[1]["hp"] == 84.0 and game.enemies[2]["hp"] == 100.0 and game.enemies[0]["stagger_remaining"] > 0.0, "Window VOID: radial multi-target impact + stagger")
				overlay.text = "TEST CHARACTER / VOID: radial HP [84, 84, 100]; 0.65s stagger + push"
		# Advance only the cosmetic wave, leaving tested combat status visible.
		for visual in game.elemental_combat.visuals: visual["life"] = 0.1
		await _capture(element.to_lower() + "_effect")
		await create_timer(0.8).timeout
		Test.reset_arena(game)
		game.player_pos = game.AREA.get_center()
		await _chant(element, true)
		var before: Vector2 = game.player_pos
		await _release()
		check(game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST and game.player_pos == before and game.runes.is_empty() and game.player_mana < 100.0, element + " focus mode releases while stationary")
		await _tap(KEY_ESCAPE)
		check(game.combat_input.mode == game.CombatInput.Mode.NORMAL, element + " Esc still exits focus")
		game.free()
	# Leave an inspectable final window with an isolated WATER character if requested.
	if OS.get_cmdline_user_args().has("--hold-window"):
		Awakening.write(DIR + "inspect_water.json", Test.fixture("WATER", 98765))
		game = SCENE.instantiate()
		game.save_path = DIR + "inspect_water.json"
		root.add_child(game)
		game.set_process(false)
		game._enter_dungeon("FIXED")
		Test.reset_arena(game)
		game.player_pos = game.AREA.get_center()
		_overlay()
		overlay.text = "TEST ONLY / All six effects verified. Isolated WATER character, real save untouched."
		await _chant("WATER", false)
		await _release("WATER")
		await _key(KEY_SHIFT, false)
		game._update_missiles(0.4, 1.0)
		game.queue_redraw()
		print("WINDOW READY FOR INSPECTION")
		await create_timer(45.0).timeout
		game.free()
	print("ELEMENTAL WINDOW TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _overlay() -> void:
	overlay = Label.new()
	overlay.position = Vector2(105, 120)
	overlay.add_theme_font_size_override("font_size", 17)
	overlay.z_index = 100
	game.add_child(overlay)

func _chant(element: String, focus_mode: bool) -> void:
	if focus_mode:
		# Dispatch the gesture in one frame so render stalls cannot turn a fast
		# double-tap into two long holds. The real Input/_input router still runs.
		for pressed in [true, false, true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_SHIFT
			event.physical_keycode = KEY_SHIFT
			event.pressed = pressed
			Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	else: await _key(KEY_SHIFT, true)
	var keys: Array = Test.keys_for(game, element)
	var used_alias := false
	for i in keys.size():
		var key: String = keys[i]
		if focus_mode and i > 0:
			var action: String = game.chant_profile.manipulation(key)
			for alias in Profile.FOCUS_KEYS:
				if game.chant_profile.manipulation(alias) == action:
					key = alias
					used_alias = true
					break
		await _tap(OS.find_keycode_from_string(key))
	if focus_mode: check(used_alias, element + " focus chant includes a personal WASD manipulation alias")

func _release(element := "") -> void:
	# A real window reads the OS cursor. Arrange test targets along the actual aim
	# immediately before dispatch, without warping or taking over the user's mouse.
	var aim: Vector2 = game.get_global_mouse_position() - game.player_pos
	last_aim = Vector2.RIGHT if aim.length() < 1.0 else aim.normalized()
	if not element.is_empty():
		target_positions.clear()
		if element == "METAL":
			for distance in [55.0, 100.0, 145.0, 190.0]: target_positions.append(game.player_pos + last_aim * distance)
		elif element == "VOID":
			for offset in [last_aim * 60.0, last_aim.rotated(PI / 2.0) * 80.0, last_aim * 200.0]: target_positions.append(game.player_pos + offset)
		elif element != "EARTH": target_positions.append(game.player_pos + last_aim * 80.0)
		for position in target_positions: game.enemies.append(Test.target(position))
	var event := InputEventMouseButton.new()
	# Keep synthetic release inside the combat viewport, outside the new HUD.
	# The native cursor may be over the record bar; that intentionally must not cast.
	event.position = game.player_pos + last_aim * 30.0
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
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

func _capture(label: String) -> void:
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(DIR + label + ".png") == OK and screenshot.get_size() == Vector2i(1160, 720), "Rendered " + label + " in visible window")
