extends SceneTree
## Real rendered window and GUI dispatch, isolated fixture characters only.
const T = preload("res://tests/test_phase2b25b.gd")
const Fixture = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const Helper = preload("res://tests/test_chant.gd")
const SCENE = preload("res://scenes/main.tscn")
const DIR := "res://.task002_artifacts/2b25b/"
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _new(element: Variant) -> void:
	var path := DIR + "window_" + ("unawakened" if element == null else str(element)) + ".json"
	A.write(path, Fixture.fixture(element, 98765))
	game = SCENE.instantiate()
	game.save_path = path
	root.add_child(game)
	game.set_process(false)
	game._enter_laboratory()
	game.laboratory_panel.arena.set_process(false)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Requires a visible Godot window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size = Vector2i(1160, 720)
	DisplayServer.window_set_title("Arcane Legacy · Phase 2B-2.5B verification")
	await create_timer(0.4).timeout
	for element in ["WOOD", "EARTH", "METAL", "WATER", "VOID", "FIRE"]:
		_new(element)
		var ui = game.laboratory_panel
		await _chant(T.keys(game.chant_profile, element))
		var result: Dictionary = game._inspect_chant(true)
		await _click(ui.release_button)
		await _key(KEY_SHIFT, false)
		check(ui.trial_panel.visible and ui.trial_banner.text.begins_with("발현 성공 · " + result["spell"].display_name), element + " GUI immediately shows a large named success banner and the actual arena")
		check(ui.trial_banner.get_global_rect().end.x < 1140 and ui.arena.get_global_rect().end.y < 686, element + " named success and targets fit the 1160x720 screen")
		ui.arena.advance(0.12)
		await _capture("lab_" + element.to_lower() + "_manifestation")
		ui.arena.advance(0.48)
		if element != "VOID": ui.arena.advance(0.15)
		var hit := 0
		for target in ui.arena.enemies:
			if target["hp"] < 200.0: hit += 1
		check((not ui.arena.combat.barriers.is_empty() if element == "EARTH" else hit > 0) and ui.arena.player_hp == 100.0, element + " actual target reaction is visible without hostile attacks")
		if element in ["WOOD", "FIRE", "WATER"]: await _capture("lab_" + element.to_lower() + "_impact")
		await _click(ui.journal_button)
		check(ui.panel.visible and ui.views[0].text.contains("전투 발현"), element + " stored visual replay remains available after real manifestation")
		if element != "FIRE": game.free()
	# Keep this isolated FIRE character for actual experimental discoveries.
	for kind in ["FIRE_LANCE", "FIRE_BLAST"]:
		game._laboratory_recover()
		var ui = game.laboratory_panel
		await _chant(T.keys(game.chant_profile, "FIRE", T.fire_actions(kind)))
		var result: Dictionary = game._inspect_chant(true)
		await _click(ui.release_button)
		await _key(KEY_SHIFT, false)
		check(str(result["spell"].spell_id) == kind and ui.trial_banner.text.contains(result["spell"].display_name), kind + " real engine input discovers the named advanced form")
		ui.arena.advance(0.13)
		await _capture("lab_" + kind.to_lower())
		ui.arena.advance(0.47)
		var hit := 0
		for target in ui.arena.enemies:
			if target["hp"] < 200: hit += 1
		check(hit == (3 if kind == "FIRE_LANCE" else 2), kind + " window verifies different piercing and radial target patterns")
		await _click(ui.journal_button)
	# Add a second genuinely successful ember path through the GUI.
	game._laboratory_recover()
	await _chant(T.keys(game.chant_profile, "FIRE", ["ACCUMULATE", "SHAPE", "COMPRESS", "DIRECT"]))
	await _click(game.laboratory_panel.release_button)
	await _key(KEY_SHIFT, false)
	game._enter_dungeon("FIXED")
	Fixture.reset_arena(game)
	await _tap(KEY_J)
	var hud = game.spell_record_hud
	check(hud.expanded and game.discovered.entries().size() == 3, "J opens the three real personal FIRE discoveries in the dungeon")
	while hud.page > 0: await _click(hud.previous_button)
	await _click(hud.next_button)
	check(hud.page == 1, "GUI paging browses discovered spells")
	await _click(hud.previous_button)
	# Entries sort by spell id; FIRE_BLAST, FIRE_EMBER, FIRE_LANCE.
	await _click(hud.next_button)
	await _click(hud.variant_button)
	check(hud.title.text.contains("영창 2/2"), "Representative chant can be changed through the actual HUD")
	await _chant(T.keys(game.chant_profile, "FIRE"))
	var mana: float = game.player_mana
	await _click(hud.favorite_button)
	check(game.missiles.is_empty() and game.player_mana == mana and game.runes.size() == 5 and game.discovered.entries()[0]["favorite"], "Favorite click with a ready chant never auto-casts, clears input or consumes mana")
	hud.update_current(game.runes, game.cast_feedback)
	await _capture("dungeon_discovered_chants")
	await _tap(KEY_ESCAPE)
	await _key(KEY_SHIFT, false)
	for kind in ["FIRE_LANCE", "FIRE_BLAST"]:
		Fixture.reset_arena(game)
		var direction: Vector2 = (game.get_global_mouse_position() - game.player_pos).normalized()
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		for distance in [100, 160, 220]: game.enemies.append(Fixture.target(game.player_pos + direction * distance))
		await _chant(T.keys(game.chant_profile, "FIRE", T.fire_actions(kind)))
		var event := InputEventMouseButton.new()
		event.position = game.player_pos + direction * 30
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		root.push_input(event, true)
		await process_frame
		event.pressed = false
		root.push_input(event, true)
		await process_frame
		await _key(KEY_SHIFT, false)
		game._update_missiles(0.1, 1.0)
		game.elemental_combat.update(game, 0.2)
		hud.update_current(game.runes, game.cast_feedback)
		await _capture("dungeon_" + kind.to_lower())
		game._update_missiles(0.4, 1.0)
		check(game.enemies.all(func(enemy): return enemy["hp"] < 100) and game.player_mana < 100 and game.runes.is_empty(), kind + " real dungeon window dispatches personal input and damages three aligned test targets")
	game.free()
	_new(null)
	await _chant(A.sequence(game.chant_profile, "FIRE"))
	await _click(game.laboratory_panel.release_button)
	await _key(KEY_SHIFT, false)
	check(game.laboratory_panel.message.text.contains("공명 성공") and game.laboratory_panel.message.text.contains("아직 발현되지") and not game.laboratory_panel.trial_panel.visible, "Resonance-only success stays visibly distinct from a completed combat spell")
	await _capture("lab_resonance_only")
	game.free()
	print("PHASE 2B25B WINDOW TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _chant(keys: Array) -> void:
	root.gui_release_focus()
	await _key(KEY_SHIFT, true)
	for key in keys: await _tap(OS.find_keycode_from_string(key))

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
	game.laboratory_panel.arena.queue_redraw()
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(DIR + label + ".png") == OK and screenshot.get_size() == Vector2i(1160, 720), "Rendered " + label)
