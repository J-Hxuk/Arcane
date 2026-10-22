extends "res://tests/preview_world_phase1.gd"
const Save=preload("res://scripts/character_save.gd")
const H=preload("res://tests/test_chant.gd")
const DIR:="res://.task002_artifacts/phase4_m1/"
func run() -> void:
	var source:=DIR+"user_save_resume.json"
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	var snapshot:=FileAccess.get_file_as_bytes(source)
	var path:=DIR+"compat_isolated.json"
	DirAccess.copy_absolute(source,path)
	game=Scene.instantiate(); game.save_path=path; root.add_child(game); game.set_process(false)
	check(game.save_writable,"Copied current user schema-v4 save remains writable: "+game.save_error)
	if not game.save_writable:game.free();quit(1);return
	var loaded:Dictionary=game._character_document()
	var expected:Dictionary=preload("res://scripts/save_upgrade.gd").document(original)
	var evidence_model=preload("res://scripts/character_research.gd").new();evidence_model.load_data(expected.research);evidence_model.detach_evidence(expected.laboratory.records);expected.research=evidence_model.to_data()
	for field in ["magic","body","chant","laboratory","research","spell_discoveries","world"]:
		check(H.equal(expected[field],loaded[field]),"Read current user copy preserves "+field)
	var commands:=[]
	for source_spell in preload("res://scripts/m1_spell_catalog.gd").SOURCE["spells"]:
		if source_spell["element"] not in ["WATER","METAL"]: continue
		var inputs:=D.inputs(game.chant_profile,source_spell["element"],preload("res://tests/test_phase4_m1.gd").actions_for(source_spell["id"]))
		var simulation:=preload("res://scripts/mana_simulator.gd").simulate(game.chant_profile,inputs,false,game.research.simulation_context())
		var resolved:=preload("res://scripts/combat_spell_resolver.gd").resolve(simulation,game.research.main_attribute,game.research.simulation_context())
		check((resolved.get("spell")!=null and str(resolved["spell"].catalog_id)==source_spell["id"]) if source_spell["element"]=="WATER" else resolved["state"]=="locked","Current copied character obeys main-only single spell access: "+source_spell["id"])
		commands.append({"id":source_spell["id"],"name":source_spell["english_name"],"inputs":inputs.map(func(input):return input["key"]),"cost":resolved["mana_cost"]})
	var output:=FileAccess.open(DIR+"current_commands_verified.json",FileAccess.WRITE);output.store_string(JSON.stringify(commands,"\t"));output.close()
	check(game._save_character(),"Current user copy round-trips through the transactional save writer")
	game.free(); game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false)
	for field in ["chant","laboratory","research","spell_discoveries"]:
		check(H.equal(game._character_document()[field],loaded[field]),"Reload of current user copy preserves "+field)
	check(FileAccess.get_file_as_bytes(source)==snapshot,"Read-only source copy remains byte-identical after all compatibility operations")
	game.free();print("PHASE4 COMPAT: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
