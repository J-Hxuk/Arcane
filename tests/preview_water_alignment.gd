extends "res://tests/preview_phase4_qa_v2.gd"
const OUTPUT="res://.task002_artifacts/chant_v2_visual_qa/"
func run()->void:
	root.size=Vector2i(1160,720)
	var path:=OUTPUT+"aim_fixture.json"
	A.write(path,JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"user_before.json")))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	game._start_prototype_all("LAB");game.laboratory_panel.show_trial()
	var arena=game.laboratory_panel.arena
	arena.player_pos=Vector2(180,210);arena.reset_targets();arena.enemies.resize(1);arena._update_views();arena.camera.reset_smoothing();arena.camera.force_update_scroll()
	await process_frame;await RenderingServer.frame_post_draw
	var cursor:Vector2=arena.world_to_screen(arena.enemies[0].pos+Vector2(0,-30))
	await point(cursor)
	var aimed:Vector2=arena.aim_world_position()
	var definition=E.resolve(game.prototype_profile,E.inputs(game.prototype_profile,["ACCUMULATE","SHAPE","DIRECT"]),game._prototype_context()).spell
	arena.manifest(definition)
	var direction:Vector2=arena.missiles[0].dir
	for i in 12:arena.combat.update_missiles(arena,.025,1)
	arena._update_views();await process_frame;await RenderingServer.frame_post_draw
	var name:="aim_after" if "--after" in OS.get_cmdline_user_args() else "aim_before"
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
	for i in 24:arena.combat.update_missiles(arena,.025,1)
	var report={"cursor":str(cursor),"world_aim":str(aimed),"expected_body":str(Vector2(330,180)),"roundtrip_error":arena.world_to_screen(aimed).distance_to(cursor),"direction":str(direction),"hp":arena.enemies[0].hp,"remaining":arena.missiles.size()}
	FileAccess.open(OUTPUT+name+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("WATER_ALIGNMENT ",JSON.stringify(report))
	game._end_developer_test();game.free();quit()
