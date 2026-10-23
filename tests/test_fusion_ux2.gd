extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const F = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const B = preload("res://tests/test_fusion_b.gd")
const H = preload("res://tests/test_chant.gd")
const D = preload("res://scripts/developer_test_data.gd")
const Access = preload("res://scripts/developer_access.gd")
const Save = preload("res://scripts/character_save.gd")
const Router = preload("res://scripts/combat_input.gd")
const DIR := "res://.task002_artifacts/fusion_ux2/"
var game
var checks := 0
var failures := 0
var serial := str(Time.get_ticks_usec())
var counter := 0
var now := 10.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
func fresh(location := "LAB", main: Variant = "WATER") -> void:
	if is_instance_valid(game): game.free()
	counter += 1; now += 2.0
	var doc: Dictionary = F.fixture(main, 1787453028)
	var path := DIR + serial + "_" + str(counter) + ".json"
	A.write(path, doc)
	var original := FileAccess.get_file_as_bytes(path)
	game = Scene.instantiate(); game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	root.gui_release_focus()
	check(game.save_writable and Save.load_file(path)["version"] == Save.SCHEMA_VERSION and FileAccess.get_file_as_bytes(path + ".v3.bak") == original, "Isolated first normal startup migrates v3 to supported schema with exact original backup")
	if location == "LAB": game._enter_laboratory()
	else: game._enter_dungeon("FIXED"); F.reset_arena(game)
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	now += 0.01
	game._input(event)
func tap(code: Key) -> void: key(code, true); key(code, false)
func begin(keys: Array) -> void:
	key(KEY_SHIFT, true)
	for token in keys: tap(OS.find_keycode_from_string(token))
func submit(keys: Array) -> void: begin(keys); key(KEY_SHIFT, false)
func water() -> Array: return D.inputs(game.chant_profile, "WATER", D.basic_actions("WATER")).map(func(event): return event["key"])
func routed(router, code: Key, pressed: bool, time: float, location := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed; event.location = location
	router.handle_event(event, time)
func router_boundaries() -> void:
	var router := Router.new()
	var observed := {"submits": 0, "releases": 0, "duration": 0}
	router.mobile_session_finished.connect(func(): observed["submits"] += 1)
	router.command_released.connect(func(_token, duration): observed["releases"] += 1; observed["duration"] = duration)
	routed(router, KEY_SHIFT, true, 0); routed(router, KEY_SHIFT, false, 0.05)
	routed(router, KEY_SHIFT, true, 0.3); routed(router, KEY_SHIFT, false, 0.31)
	check(router.mode == Router.Mode.FOCUS_CAST and observed["submits"] == 0, "Exact 0.3 second double-tap boundary never submits an empty session")
	router.reset()
	routed(router, KEY_SHIFT, true, 1); routed(router, KEY_C, true, 1.01); routed(router, KEY_C, false, 1.02); routed(router, KEY_SHIFT, false, 1.05)
	check(observed["submits"] == 1, "A real rune invalidates the double-tap candidate even for a quick mobile session")
	routed(router, KEY_SHIFT, false, 1.06)
	check(observed["submits"] == 1, "Router itself emits at most one end signal for duplicate Shift up")
	router.reset(); observed["submits"] = 0
	routed(router, KEY_SHIFT, true, 2, 1); routed(router, KEY_SHIFT, true, 2.01, 2)
	routed(router, KEY_C, true, 2.02); routed(router, KEY_C, false, 2.03)
	routed(router, KEY_SHIFT, false, 2.04, 1)
	check(observed["submits"] == 0, "Releasing one of two held Shift sources cannot end a session")
	routed(router, KEY_SHIFT, false, 2.05, 2)
	check(observed["submits"] == 1, "Last held Shift source ends the mobile session exactly once")
	router.reset(); observed["submits"] = 0; observed["releases"] = 0
	routed(router, KEY_SHIFT, true, 3); routed(router, KEY_C, true, 3.01); routed(router, KEY_SHIFT, false, 3.11); routed(router, KEY_C, false, 3.12)
	check(observed["submits"] == 1 and observed["releases"] == 1 and observed["duration"] == 100, "Shift session end finalizes a still-held rune once with its correct hold duration")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	router_boundaries()
	for editor in [false, true]:
		for explicit in [false, true]:
			check(not Access.allowed(false, editor, explicit, true), "Release denies developer access regardless of flags/preference")
			check(Access.allowed(true, editor, explicit) == (editor or explicit), "Debug policy requires editor runtime or explicit developer condition")
	check(not Access.allowed(true, true, true, false), "Isolated normal-play preference can disable developer UI")
	fresh()
	check(OS.has_feature("editor_runtime") and game.developer_panel != null and not game.developer_mode, "F5/editor runtime enables F2 panel without entering any temporary test or using CMD")
	var mana: float = game.player_mana
	submit(water())
	check(game.journal.records().size() == 1 and game.laboratory_panel.arena.missiles.size() == 1 and game.player_mana == mana - 9.0, "Shift chant release manifests and records once for exactly one mana charge")
	key(KEY_SHIFT, false); game._process(0.0)
	check(game.journal.records().size() == 1 and game.player_mana == mana - 9.0 and game.runes.is_empty() and game.combat_input.mode == game.CombatInput.Mode.NORMAL, "Duplicate key-up and subsequent frame cannot resubmit; next session is clean")
	game._laboratory_recover(); submit(water())
	check(game.journal.records().size() == 2, "A fresh Shift session submits a new independent experiment")
	fresh()
	begin(water()); game._cast_spell(); key(KEY_SHIFT, false)
	check(game.journal.records().size() == 1 and game.laboratory_panel.arena.missiles.size() == 1, "Manual fallback release followed by Shift up never duplicates a successful cast")
	fresh()
	begin([H.first_for(game.chant_profile, "WATER")]); game._cast_spell(); key(KEY_SHIFT, false)
	check(game.journal.records().size() == 1, "Manual failed fallback followed by Shift up does not append a duplicate cancellation/save")
	fresh()
	tap(KEY_SHIFT)
	check(game.journal.records().is_empty(), "Lone Shift tap does not record or release")
	tap(KEY_SHIFT)
	check(game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST and game.journal.records().is_empty(), "Double-tap's intermediate release does not submit")
	for token in water(): tap(OS.find_keycode_from_string(token))
	key(KEY_SHIFT, false)
	check(game.journal.records().is_empty() and game.runes.size() == water().size(), "Focus Shift release preserves commands and never auto-submits")
	game._cast_spell()
	check(game.journal.records().size() == 1 and game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST, "Focus explicit release remains functional and stays in focus")
	fresh()
	submit([H.first_for(game.chant_profile, "WATER")])
	check(game.journal.records().size() == 1 and game.journal.records()[0]["result"]["outcome"] == "failed" and game.exhaustion_seconds > 0 and game.runes.is_empty(), "Incomplete chant records one failed attempt with instability and resets its buffer")
	fresh()
	submit(B.ritual(game.chant_profile, "METAL"))
	check(game.journal.records().size() == 1 and game.journal.records()[0]["result"]["kind"] == "metal_resonance" and not game.journal.records()[0]["result"].has("manifestation") and game.discovered.entries().is_empty() and game.laboratory_panel.arena.missiles.is_empty(), "Stable resonance is observation only, never mislabeled as a combat discovery")
	for boundary in ["escape", "focus_out", "study", "editing", "developer", "leave", "preset", "confirmation"]:
		fresh(); begin(water())
		mana = game.player_mana
		match boundary:
			"escape": tap(KEY_ESCAPE)
			"focus_out": game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"study": game.laboratory_panel.awakening_panel.open()
			"editing": game.laboratory_panel.note.grab_focus()
			"developer": game._toggle_developer_menu()
			"leave": game._leave_laboratory()
			"preset": game._start_developer_test("WATER_METAL", "LAB"); mana = game.player_mana
			"confirmation": game.laboratory_panel.awakening_panel.confirmation.popup_centered()
		key(KEY_SHIFT, false)
		var released := false
		for record in game.journal.records(): released = released or record["result"]["outcome"] == "released"
		check(not released and game.player_mana == mana and game.laboratory_panel.arena.missiles.is_empty(), boundary + " cancels/suppresses auto-release without mana consumption or manifestation")
	fresh()
	var original_path: String = game.save_path
	game.save_path = DIR + "missing_parent/blocked.json"
	mana = game.player_mana
	submit(water())
	check(game.player_mana == mana and game.journal.records().is_empty() and game.discovered.entries().is_empty() and game.laboratory_panel.arena.missiles.is_empty(), "Failed automatic success-save refunds mana and rolls back effect, discovery and journal")
	submit([H.first_for(game.chant_profile, "WATER")])
	check(game.player_mana == mana and game.exhaustion_seconds == 0 and game.journal.records().is_empty(), "Failed failure-save also rolls back instability and penalty")
	game.save_path = original_path
	for main in [null, "WATER"]:
		fresh("LAB", main)
		var target := "WOOD" if main == null else "METAL"
		for source in ["book", "mentor", "environment"]: game._collect_research_clue(target, source)
		for i in 2:
			game._laboratory_recover(); submit(B.ritual(game.chant_profile, target))
		check(game._begin_awakening(target) == "ritual_started", "Genuine main/auxiliary evidence permits a direct ritual")
		game._laboratory_recover(); submit(B.ritual(game.chant_profile, target))
		check(game.pending_awakening_offer.get("state") == "confirmation_required" and game.research.main_attribute == main and game.research.auxiliary_attributes.is_empty(), "Automatic ritual release never approves main or auxiliary permanent confirmation")
		var ticket: int = game.pending_awakening_offer.get("ticket", 0)
		check(game._confirm_element_research(target, ticket) == "committed", "Only an explicit permanent-confirm action commits the role")
	fresh("DUNGEON")
	game.navigation.request(game, Vector2(600, 300)); game._process(0.1)
	var normal_distance: float = game.player_pos.x - 300.0
	game.player_pos = Vector2(300, 300); game.navigation.request(game, Vector2(600, 300))
	key(KEY_SHIFT, true); game._process(0.1)
	check(is_equal_approx(game.player_pos.x - 300.0, normal_distance * 0.8), "Dungeon RMB movement during Shift mobile casting is exactly 20 percent slower")
	key(KEY_SHIFT, false)
	var start: Vector2 = game.player_pos
	game._process(0.1)
	check(is_equal_approx(game.player_pos.x - start.x, normal_distance), "Releasing Shift restores normal movement speed")
	game._reset_combat_input(); begin(water()); key(KEY_SHIFT, false)
	check(game.missiles.is_empty() and game.runes.is_empty(), "Dungeon Shift release does not cast and retains its old cancellation rule")
	begin(water())
	var click := InputEventMouseButton.new()
	click.position = Vector2(700, 300); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	game._input(click)
	check(game.missiles.size() == 1, "Dungeon Shift/LMB still explicitly releases the same spell")
	key(KEY_SHIFT, false)
	game.free()
	print("FUSION UX2: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
