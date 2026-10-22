extends "res://tests/preview_world_phase1.gd"
const Equal=preload("res://tests/test_chant.gd")
func run()->void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/formal_world/restart_manifest.json"))
	var before:=FileAccess.get_file_as_bytes(manifest.path)
	game=Scene.instantiate();game.save_path=manifest.path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and game.formal_rules,"New process loads saved production character")
	var after:Dictionary=game._character_document()
	for field in ["chant","active_chant","research","laboratory","spell_discoveries","inventory","world","bank"]:check(Equal.equal(after[field],manifest.document[field]),"Restart preserves "+field)
	check(FileAccess.get_file_as_bytes(manifest.path)==before,"Current production restart does not rewrite source bytes")
	game.free();print("FORMAL RESTART: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
