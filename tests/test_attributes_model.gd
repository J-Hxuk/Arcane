extends "res://tests/attribute_helpers.gd"
const Model=preload("res://scripts/character_research.gd")
const Loadout=preload("res://scripts/attribute_loadout.gd")
func run()->void:
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"));var path:=OUT+"raw_copy_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.copy_absolute(OUT+"user_before.json",path);game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and game.research.free_attributes,"Legacy real-character COPY migrates into free equipment")
	check(FileAccess.get_file_as_bytes(path+".v5.bak")==FileAccess.get_file_as_bytes(OUT+"user_before.json"),"Schema-five backup retains exact original copied bytes including whitespace")
	check(game.research.awakened_attributes==["METAL","WATER"] and game.research.main_attribute=="WATER" and Array(game.research.auxiliary_attributes)==["METAL"],"Existing awakenings and selected roles survive migration")
	var doc:Dictionary=game._character_document()
	for field in ["chant","active_chant","laboratory","spell_discoveries","inventory","magic","body","bank"]:check(Equal.equal(source.get(field),doc.get(field)),"Migration retains "+field)
	check(Equal.equal(source.research.innate_affinity,doc.research.innate_affinity) and Equal.equal(source.research.binding_studies,doc.research.binding_studies),"Innate affinity and permanent binding are unchanged")
	check(game._change_active_attributes("METAL",null) and game.research.awakened_attributes==["METAL","WATER"],"Selecting a different main never changes permanent awakenings")
	check(not game._change_active_attributes("FIRE",null) and not game._change_active_attributes("METAL","METAL"),"Unearned or duplicate-slot requests are denied below UI")
	var copy:Dictionary=game.research.to_data();copy.binding_studies=["METAL+WATER"];var model=Model.new();check(model.load_data(copy).is_empty(),"A binding remains valid while its pair is not equipped")
	var old:Dictionary=game.research.to_data();game.save_path=OUT+"missing/selection.json"
	check(not game._change_active_attributes("WATER","METAL") and Equal.equal(old,game.research.to_data()),"Failed equipment save restores both slots")
	var old_slot:String=game.research.selected_attribute_slot;check(not game._toggle_attribute_slot() and old_slot==game.research.selected_attribute_slot,"Failed selected-slot save restores HUD choice")
	game.save_path=path
	model.load_data({"innate_affinity":{"WOOD":99,"WATER":1},"main_attribute":"WATER","auxiliary_attributes":[]});model.enable_free_attributes()
	check(model.slot_candidates("main")==["WATER"] and model.slot_candidates("auxiliary")==[null],"Only one awakening always has one main and no auxiliary")
	check(not model.cycle_active(1) and not model.set_active("WOOD",null),"Affinity cannot grant an unawakened selection")
	model.developer_reset("all_elements","");var combinations:=0
	for main in Loadout.ORDER:
		for aux in [null]+Loadout.ORDER:
			if main==aux:continue
			check(model.set_active(main,aux),"All awakened equipment combination "+str([main,aux]));combinations+=1
	check(combinations==25,"Five main slots each allow none or four distinct auxiliaries")
	var history={"main_attribute":"WATER","auxiliary_attributes":["METAL","FIRE"],"legacy_committed_attributes":[],"innate_affinity":{},"binding_studies":["METAL+WATER","FIRE+WATER"],"fusion_observations":{},"research_clues":[],"resonance_discoveries":{}}
	var historical=Model.new();check(historical.load_data(history).is_empty() and historical.enable_free_attributes().is_empty() and historical.awakened_attributes==["FIRE","METAL","WATER"] and historical.to_data().binding_studies.size()==2,"Previously inactive second auxiliary and binding records are restored losslessly")
	var corrupt:Dictionary=model.to_data();corrupt.active_auxiliary_attribute=corrupt.active_main_attribute
	check(not Loadout.valid(corrupt) and model.load_data(corrupt)!="","Conflicting aliases and invalid canonical slots are rejected")
	var early:=OUT+"early_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()];A.write(early,{"magic":67,"body":34,"bank":123,"unknown":"retain"});var early_bytes:=FileAccess.get_file_as_bytes(early);var migrated:Dictionary=game.CharacterSave.load_file(early)
	check(migrated.state=="loaded" and migrated.data.research.awakened_attributes.is_empty() and migrated.data.magic==67 and migrated.data.unknown=="retain" and FileAccess.get_file_as_bytes(early)==early_bytes,"Versionless saves without research migrate empty awakenings without rerolling or rewriting")
	var broken:Dictionary=source.duplicate(true);broken.research.researched_base_elements=[];A.write(early,broken);early_bytes=FileAccess.get_file_as_bytes(early)
	check(game.CharacterSave.load_file(early).state=="error" and FileAccess.get_file_as_bytes(early)==early_bytes,"Contradictory old role sources remain protected byte-for-byte")
	broken=source.duplicate(true);broken.schema_version=game.CharacterSave.SCHEMA_VERSION+1;A.write(early,broken);early_bytes=FileAccess.get_file_as_bytes(early)
	check(game.CharacterSave.load_file(early).state=="error" and FileAccess.get_file_as_bytes(early)==early_bytes,"Future schema is read-only and never silently downgraded")
	game._change_active_attributes("METAL","WATER");game._toggle_attribute_slot();restart_fixture("attributes")
	await finish("ATTRIBUTES MODEL")
