extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const H = preload("res://tests/test_chant.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var paths: Array = JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/fusion/a_restart_paths.json"))["paths"]
	for path in paths:
		var disk := FileAccess.get_file_as_bytes(path)
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var game = Scene.instantiate()
		game.save_path = path
		root.add_child(game)
		game.set_process(false)
		checks += 1
		if not game.save_writable or not H.equal(game._character_document(), original) or FileAccess.get_file_as_bytes(path) != disk:
			failures += 1; push_error("FAIL: New process migration preservation " + path)
		else: print("PASS: New process preserves exact v4 document and old snapshots ", path)
		game.free()
	print("FUSION A RESTART: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
