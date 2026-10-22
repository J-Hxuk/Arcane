extends SceneTree
## New process checks CLI gating and persisted normal character preservation.
const SCENE = preload("res://scenes/main.tscn")
const Helper = preload("res://tests/test_chant.gd")
const A = preload("res://tests/test_awakening.gd")
const Data = preload("res://scripts/developer_test_data.gd")
const PATH := "res://.task002_artifacts/ux1/character.json"
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
func _run() -> void:
	if not FileAccess.file_exists(PATH): quit(1); return
	var disk := FileAccess.get_file_as_bytes(PATH)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var game = SCENE.instantiate()
	game.save_path = PATH
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	check(game.developer_panel != null and game.developer_tools_enabled and game.legacy_wasd_enabled and game.combat_input.legacy_wasd_enabled, "Explicit --dev-lab and --legacy-wasd CLI flags enable only developer tools")
	check(game.research.main_attribute == "WATER" and Helper.equal(game.chant_profile.to_data(), saved["chant"]), "New process preserves normal main and exact personal key mapping")
	game._start_developer_test("FIRE", "LAB")
	var example: Dictionary = Data.examples(game.chant_profile, "FIRE", game.research.simulation_context()).filter(func(item): return item["spell_id"] == "FIRE_LANCE")[0]
	A.enter_keys(game, example["inputs"].map(func(event): return event["key"]))
	game._cast_spell()
	check(game.developer_metrics.get("spell") == "Brandlance" and not game.journal.records().is_empty(), "Restarted CLI session can discover/record a temporary fire lance")
	check(game._end_developer_test() and game.research.main_attribute == "WATER" and FileAccess.get_file_as_bytes(PATH) == disk, "Temporary exit restores normal character without any disk write")
	check(not FileAccess.file_exists(PATH + ".tmp") and Helper.equal(game.journal.to_data(), saved["laboratory"]), "No temporary write artifact or developer journal leaks after restart")
	game.free()
	print("UX1 RESTART TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
