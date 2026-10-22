extends "res://tests/attribute_helpers.gd"
func run()->void:
	for label in ["attributes","five_rituals"]:
		var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restart_"+label+".json"));var bytes:=FileAccess.get_file_as_bytes(manifest.path)
		game=Scene.instantiate();game.save_path=manifest.path;root.add_child(game);game.set_process(false);await process_frame
		check(game.save_writable and game.research.free_attributes,"Separate process loads new canonical research "+label)
		var actual:Dictionary=game._character_document()
		for field in ["research","chant","active_chant","laboratory","spell_discoveries","inventory","bank"]:check(Equal.equal(actual.get(field),manifest.expected.get(field)),"Separate process preserves "+field+" "+label)
		check(FileAccess.get_file_as_bytes(manifest.path)==bytes,"Restart makes no needless save rewrite "+label)
		game.free();game=null
	await finish("ATTRIBUTES RESTART")
