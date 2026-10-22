extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/formal_world/"
const E=preload("res://scripts/chant_engine_v2.gd")
const Registry=preload("res://scripts/formal_spell_registry.gd")
const Perm=preload("res://tests/test_chant_v2.gd")
const Equal=preload("res://tests/test_chant.gd")
func run()->void:
	root.size=Vector2i(1160,720)
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"))
	var path:=OUT+"phase1_%d.json"%Time.get_ticks_usec();A.write(path,source)
	var initial_bytes:=FileAccess.get_file_as_bytes(path)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and game.formal_rules and game._active_profile().version()==2,"Normal project starts the unified personal interpreter")
	check(FileAccess.get_file_as_bytes(path+".v5.bak")==initial_bytes,"First schema-six integration backs up exact source bytes before rewriting")
	var doc:Dictionary=game._character_document().duplicate(true)
	for field in ["chant","learned","laboratory","spell_discoveries","magic","body"]:check(Equal.equal(source[field],doc[field]),"Integration retains "+field)
	var disk:=FileAccess.get_file_as_bytes(path)
	check(game._start_prototype_all("LAB"),"Developer uses the same interpreter in isolated state")
	var ports:Array=[]
	for row in Registry.config().spells:
		var context={"formal_rules":true,"main_attribute":row.get("element","WATER"),"auxiliary_attributes":["METAL"],"binding_pairs":["METAL+WATER"],"developer_all":true,"developer_target":row.id}
		var successes:=0
		for order in Perm.permutations(row.actions):
			var result:=E.resolve(game._active_profile(),E.inputs(game._active_profile(),order),context)
			if result.get("spell")!=null and result.state=="ready":successes+=1
		ports.append({"id":row.id,"actions":row.actions,"executable_permutations":successes})
		check(successes>0,"Port has an actual executable composition "+row.id)
	game._end_developer_test();check(Equal.equal(doc,game._character_document()) and disk==FileAccess.get_file_as_bytes(path),"Developer returns exact original data without writing disk")
	game._enter_laboratory();game.lab_observation_target="WATER";game._reset_combat_input()
	await process_frame
	check(game.laboratory_panel.live_orb.size.x>=game.laboratory_panel.panel.size.x*.5,"Central live observation occupies at least half the laboratory width")
	check(game.laboratory_panel.live_orb.size.y>=230 and game.laboratory_panel.live_orb.get_global_rect().end.y<690,"Large live orb fits inside 1160x720")
	check(game.laboratory_panel.detailed_observation==null and game.laboratory_panel.observation_lens!=null and not game.laboratory_panel.observation_lens.button_pressed,"Interpretation lens returns folded off while numeric detail controls remain removed")
	game._update_laboratory_live();check(game.laboratory_panel.observation_target.get_item_metadata(game.laboratory_panel.observation_target.selected)=="WATER","Displayed observation target follows the actual laboratory target")
	for button in game.laboratory_panel.panel.find_children("*","Button",true,false):check(not button.text.contains("시제품"),"Production laboratory has no grammar toggle")
	if DisplayServer.get_name()!="headless":
		await tap(KEY_F2);check(game.developer_panel.panel.visible,"F2 opens the independent production debug panel")
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"developer_panel.png")
		await tap(KEY_F2)
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"phase1.png")
		root.size=Vector2i(1366,768);await process_frame;await process_frame
		check(game.laboratory_panel.live_orb.size.x>=game.laboratory_panel.panel.size.x*.5 and game.laboratory_panel.panel.get_global_rect().end.x<=1366,"Laboratory expands cleanly at 1366x768")
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"phase2_large.png")
		root.size=Vector2i(1160,720)
	FileAccess.open(OUT+"spell_ports.json",FileAccess.WRITE).store_string(JSON.stringify(ports,"\t"))
	game.free();print("FORMAL PHASE1: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
