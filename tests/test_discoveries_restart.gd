extends SceneTree
const SCENE = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/character_save.gd")
const Helper = preload("res://tests/test_chant.gd")
const PATH := "res://.task002_artifacts/2b25b/restart_fire.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var original := Save.load_file(PATH)
	if original["state"] != "loaded":
		push_error("Missing isolated restart fixture")
		quit(1)
		return
	var game = SCENE.instantiate()
	game.save_path = PATH
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var ok: bool = game.save_writable and game.research.main_attribute == "FIRE" and game.discovered.entries().size() == 3 and game.discovered.entries()[0]["spell_id"] == "FIRE_LANCE" and game.discovered.entries()[0]["favorite"] and Helper.equal(game.chant_profile.to_data(), original["data"]["chant"]) and Helper.equal(game.journal.to_data(), original["data"]["laboratory"])
	print("DISCOVERY PROCESS RESTART: 1 check, ", 0 if ok else 1, " failures")
	game.free()
	quit(0 if ok else 1)
