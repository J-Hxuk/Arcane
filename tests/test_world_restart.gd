extends SceneTree
const Scene = preload("res://scenes/world_main.tscn")
const H = preload("res://tests/test_chant.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/phase3a/world_restart_path.json"))
	var path: String = manifest["path"]; var bytes := FileAccess.get_file_as_bytes(path)
	var game = Scene.instantiate(); game.save_path = path; game.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(game)
	check(game.save_writable and game.player_pos.distance_to(Vector2(430, 1190)) < 1, "New Godot process restores the actual expedition's final town position")
	check(game.world_progress.data["bosses"].has("RUIN_GUARDIAN") and game.bank_gold == 160, "New process retains the boss victory and exactly one reward")
	check(game.research.main_attribute == "WATER" and game.chant_profile.to_data()["first_words"].get("X") == "WATER", "New process retains main element and original personal key table")
	check(game.journal.records().size() == 1 and game.discovered.entries()[0]["favorite"], "New process retains exact lab record and J favorite")
	var expected: Dictionary = manifest["expected"].duplicate(true)
	var progress := preload("res://scripts/world/world_progress.gd").new()
	progress.load_data(expected["world"]); expected["world"] = progress.to_data()
	check(H.equal(game._character_document(), expected), "Whole v4 document including world and unknown fields survives restart with optional defaults")
	check(FileAccess.get_file_as_bytes(path) == bytes, "Current v4 restart does not rewrite the player's isolated save")
	print("WORLD RESTART: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
