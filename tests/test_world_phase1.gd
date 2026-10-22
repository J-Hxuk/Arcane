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
	create_timer(90).timeout.connect(func(): push_error("World test watchdog timeout"); quit(1))
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + title)
	else: print("PASS: ", title)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = down
	game._input(event)
func tap(code: Key) -> void: key(code, true); key(code, false)
func walk(goal: Vector2) -> bool:
	if not game.navigation.request(game, goal): return false
	for i in 6000:
		game._process(1.0 / 60)
		if game._is_blocked(game.player_pos): return false
		if not game.navigation.active: return game.player_pos.distance_to(goal) < 1
	return false
func run() -> void:
	var path := "res://.task002_artifacts/phase3a/p1_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, F.fixture("WATER", 1787453028))
	game = Scene.instantiate(); game.save_path = path; game.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(game)
	check(game.save_writable and game.game_state == "DUNGEON" and game.layout.region(game.player_pos) == "TOWN", "New main scene starts a controllable safe town")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/world_main.tscn", "F5 uses the world scene; old fixtures retain their original scene")
	check(game.world_camera is Camera2D and game.actors.y_sort_enabled and game.world_root.get_child_count() == 5, "Camera2D and separate town/wilds/ruins chunks with sorted props")
	check(game.layout.blocked(Vector2(540, 490), 13) and not game.layout.blocked(game.layout.LAB_DOOR, 13), "Visible building footprint blocks; entrance outside footprint remains open")
	check(game.layout.interactions.size() >= 8 and game.enemies.is_empty(), "Five facilities, gate and world landmarks; town has no enemies")
	var skills: Dictionary = game.chant_profile.to_data()
	var mana: float = game.player_mana
	check(walk(game.layout.LAB_DOOR), "RMB movement model reaches the actual laboratory threshold")
	tap(KEY_E)
	check(game.game_state == "LAB" and game.laboratory_panel.visible and not game.world_camera.enabled, "Normal E enters the existing laboratory from its physical entrance")
	game._reset_combat_input(); key(KEY_SHIFT, true)
	for event in D.inputs(game.chant_profile, "WATER", D.basic_actions("WATER")): tap(OS.find_keycode_from_string(event["key"]))
	key(KEY_SHIFT, false)
	check(game.journal.records().size() == 1 and game.laboratory_panel.arena.missiles.size() == 1, "Existing lab Shift-up auto-release and journal survive world shell")
	game._leave_laboratory()
	check(game.game_state == "DUNGEON" and game.player_pos == game.layout.LAB_DOOR and game.chant_profile.to_data() == skills and game.player_mana < mana, "Laboratory returns to threshold without reroll or free mana reset")
	game._reset_combat_input(); key(KEY_SHIFT, true); tap(KEY_E)
	check(game.runes == ["E"] and game.game_state == "DUNGEON", "Shift E stays a personal chant word, never an interaction")
	key(KEY_ESCAPE, true); key(KEY_ESCAPE, false); key(KEY_SHIFT, false)
	var started := Time.get_ticks_usec()
	check(walk(Vector2(2810, 900)), "Town -> gate -> exterior route bypasses walls and large rock on a larger world")
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	print("PATH_BENCHMARK_MS ", elapsed)
	check(game.world_navigation.rebuild_count == 1, "Static navigation grid is built once, never rebuilt every frame")
	check(walk(Vector2(3330, 900)) and walk(game.layout.SPAWN), "Ruins approach and continuous return to town remain connected")
	check(game.world_navigation.rebuild_count == 1 and game.world_navigation.request_count <= 5, "Repeated destinations reuse the cached grid")
	var scale: float = game.world_camera.zoom.x
	tap(KEY_EQUAL)
	check(game.world_camera.zoom.x > scale and game.world_camera.zoom.x <= 1.6, "InputMap camera zoom is bounded and testable")
	game._reset_combat_input(); game.navigation.request(game, game.player_pos + Vector2(100, 0)); key(KEY_SHIFT, true)
	var before: Vector2 = game.player_pos; game._process(0.1)
	check(is_equal_approx(game.player_pos.distance_to(before), 16), "World mobile casting preserves the 80 percent movement speed")
	key(KEY_SHIFT, false)
	var disk := FileAccess.get_file_as_bytes(path); var document: Dictionary = game._character_document(); var position: Vector2 = game.player_pos
	check(game._start_developer_test("WATER_METAL", "LAB"), "F2 temporary fusion laboratory remains accessible")
	check(game._end_developer_test() and game.world_enabled and game.player_pos == position and game._character_document() == document and FileAccess.get_file_as_bytes(path) == disk, "Developer test restores world, character, journal and original isolated disk")
	print("WORLD PHASE1: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
