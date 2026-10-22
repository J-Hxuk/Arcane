extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/hud_shake_zoom/"
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1160,720)
	var path:=OUT+"fixture.json";A.write(path,F.fixture("WATER",1787453028))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes:=FileAccess.get_file_as_bytes(path)
	game._start_developer_test("WATER_METAL","WORLD")
	game.player_pos=Vector2(3000,910)
	var measurements:Array=[]
	for location in ["WORLD","LAB"]:
		if location=="LAB":game._end_developer_test();game._start_developer_test("WATER","LAB");game.laboratory_panel.show_trial();game.laboratory_panel.arena.set_process(false)
		var camera:Camera2D=game.world_camera if location=="WORLD" else game.laboratory_panel.arena.camera
		var reference:Vector2=Vector2.ZERO
		for zoom in [.65,1.0,1.6]:
			camera.zoom=Vector2.ONE*zoom;game.hit_feedback.shake_remaining=0
			if location=="WORLD":game._sync_world_view()
			else:game.laboratory_panel.arena._update_views()
			camera.reset_smoothing();camera.force_update_scroll();await process_frame
			var origin:Vector2=game.player_pos if location=="WORLD" else game.laboratory_panel.arena.player_pos
			var base:Vector2=game.get_canvas_transform()*origin if location=="WORLD" else game.laboratory_panel.arena.world_to_screen(origin)
			game.hit_feedback.receive(1,true,Vector2.RIGHT);game.hit_feedback.elapsed=.013;game.hit_screen.shake_scale=1
			if location=="WORLD":game._sync_world_view()
			else:game.laboratory_panel.arena._update_views()
			camera.force_update_scroll();await process_frame
			var shifted:Vector2=game.get_canvas_transform()*origin if location=="WORLD" else game.laboratory_panel.arena.world_to_screen(origin)
			var displacement:=shifted-base
			if reference==Vector2.ZERO:reference=displacement
			measurements.append({"location":location,"zoom":zoom,"screen_displacement":str(displacement),"pixels":displacement.length()})
			if "--baseline" not in OS.get_cmdline_user_args():check(displacement.distance_to(reference)<.01,"Screen shake amplitude is zoom-independent "+location+str(zoom))
			check(game.player_pos==origin if location=="WORLD" else game.laboratory_panel.arena.player_pos==origin,"Shake does not move physical player coordinates")
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+location+"_"+str(zoom)+".png")
		game.hit_screen.shake_scale=0
		if location=="WORLD":game._sync_world_view()
		else:game.laboratory_panel.arena._update_views()
		check(camera.offset==Vector2.ZERO,"Shake off setting remains exact "+location)
	game._end_developer_test();check(H_equal(original,game._character_document()) and bytes==FileAccess.get_file_as_bytes(path),"Test sessions restore character and never modify its disk save")
	var suffix:="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
	FileAccess.open(OUT+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	game.free();print("SHAKE ZOOM: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func H_equal(a:Variant,b:Variant)->bool:return preload("res://tests/test_chant.gd").equal(a,b)
