extends "res://tests/followup_helpers.gd"
func run()->void:
	for label in ["blink","field"]:
		var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restart_"+label+".json"));var bytes:=FileAccess.get_file_as_bytes(manifest.path)
		if is_instance_valid(game):game.free()
		game=Scene.instantiate();game.save_path=manifest.path;root.add_child(game);game.set_process(false);await process_frame
		check(game.save_writable,"New Godot process accepts "+label+" progress")
		var document:Dictionary=game._character_document()
		for field in ["research","inventory","bank","chant","active_chant","spell_discoveries","laboratory","world"]:check(Equal.equal(document[field],manifest.expected[field]),"Restart preserves "+label+" "+field)
		check(bytes==FileAccess.get_file_as_bytes(manifest.path),"Restart does not rewrite saved "+label+" bytes")
		if label=="blink":check(game.research.blink_unlocked(),"Permanent movement research remains unlocked in a separate process")
	await finish("FOLLOWUP RESTART")
