extends "res://tests/preview_world_phase1.gd"
const OUT := "res://.task002_artifacts/phase4_m1/"
func place(point: Vector2) -> void:
	game._reset_combat_input(); game.dodge.reset(); game.player_pos=point
	game._sync_world_view(); game.world_camera.reset_smoothing(); await process_frame
func shot(name: String) -> void:
	game._sync_world_view(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.size=Vector2i(1160,720)
	var path := OUT+"movement_window.json"; A.write(path,F.fixture("WATER",1787453028))
	game=Scene.instantiate(); game.save_path=path; root.add_child(game); game.set_process(false); await process_frame
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
		await place(Vector2(2600,1000)); await aim(game.player_pos+direction*100); await tap(KEY_CTRL)
		var start: Vector2=game.player_pos; game.dodge.advance(game,0.18)
		check(game.player_pos.distance_to(start+direction*108)<1.0,"Actual Ctrl follows fresh cursor in direction "+str(direction)+" end="+str(game.player_pos))
	await place(Vector2(2600,1000)); await click_world(Vector2(2700,1000)); game._process(0.1)
	var before: Vector2=game.player_pos; await aim(before-Vector2(100,0)); await tap(KEY_CTRL); game.dodge.advance(game,0.18)
	check(game.player_pos.x<before.x-100 and not game.navigation.active,"Moving right + aiming left + Ctrl dodges left and cancels the RMB route")
	for pair in [[Vector2(1530,300),Vector2(1700,300)],[Vector2(540,550),Vector2(540,350)],[Vector2(1790,530),Vector2(1940,530)]]:
		await place(pair[0]); await aim(pair[1]); await tap(KEY_CTRL); game.dodge.advance(game,0.5)
		check(not game._is_blocked(game.player_pos) and game.player_pos.distance_to(pair[0])<60,"Actual slow-frame Ctrl stops before wall/building/tree")
		await shot("dodge_collision_"+str(pair[0].x))
	for pair in [[Vector2(2600,1000),Vector2(2700,1000)],[Vector2(1790,530),Vector2(1850,530)],[Vector2(540,550),Vector2(540,400)],[Vector2(1700,900),Vector2(4200,900)]]:
		await place(pair[0])
		if pair[1].x>3840:
			# Large zoomed-out viewport exposes an outside-map point for a real RMB event.
			game.world_camera.limit_right=4600; game.world_camera.zoom=Vector2.ONE*0.65
			game.world_camera.offset=Vector2(2300,0); await process_frame
		await click_world(pair[1])
		var destination: Vector2=game.navigation.destination
		check(game.navigation.clicked_destination.distance_to(pair[1])<0.1 and not game._is_blocked(destination),"Actual RMB retains original click and chooses a radius-safe destination")
		for i in 1800:
			game.navigation.advance(game,0.02,200)
			if not game.navigation.active: break
		check(not game.navigation.active and game.player_pos.distance_to(destination)<1 and not game._is_blocked(game.player_pos),"Actual RMB finishes the corrected route without penetrating obstacles")
		game.world_camera.offset=Vector2.ZERO; game.world_camera.zoom=Vector2.ONE; game.world_camera.limit_right=3840
	await place(Vector2(3200,910)); game.guardian.start(game)
	game.layout.solids.append_array([{"rect":Rect2(3330,500,12,400)},{"rect":Rect2(3330,920,12,400)}]); game.layout._index_solids()
	await click_world(Vector2(3450,910))
	check(game.navigation.corrected and game.navigation.destination.x<3330,"Actual window: unreachable floor beyond a 20px slit projects to the current connected side")
	for i in 600: game.navigation.advance(game,0.02,200)
	check(game.player_pos.x<3330 and not game._is_blocked(game.player_pos),"Narrow slit never creates a route through the wall: end=%s goal=%s blocked=%s" % [game.player_pos,game.navigation.destination,game._is_blocked(game.player_pos)])
	print("PHASE4 MOVEMENT WINDOW: %d checks, %d failures" % [checks,failures]); game.free(); quit(1 if failures else 0)
