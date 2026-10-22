extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/formal_world/"
func run()->void:
	var path:=OUT+"phase7_%d.json"%Time.get_ticks_usec();A.write(path,F.fixture("WATER",8431))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	if DisplayServer.get_name()!="headless":await tap(KEY_M)
	else:game.map_dialog.popup_centered(Vector2i(800,500))
	await process_frame;check(game.map_dialog.visible,"M opens live coordinate map")
	game.map_view.drawing_rect=Rect2(28,35,704,370)
	var a:Vector2=game.map_view.map_point(game.Layout.BOUNDS.position);var b:Vector2=game.map_view.map_point(game.Layout.BOUNDS.end)
	check(a==Vector2(28,35) and b==Vector2(732,405),"Map corners match complete extended world bounds")
	var north:Vector2=game.map_view.map_point(Vector2(790,-550));var town:Vector2=game.map_view.map_point(Vector2(790,760));check(north.y<town.y,"North field maps above town using world coordinates")
	if DisplayServer.get_name()!="headless":
		await tap(KEY_I);check(not game.inventory_dialog.visible,"Inventory cannot overlap map modal")
		await process_frame;await RenderingServer.frame_post_draw;game.map_dialog.get_viewport().get_texture().get_image().save_png(OUT+"phase7_map.png")
		await tap(KEY_M);check(not game.map_dialog.visible,"M closes map")
	game.map_dialog.hide();game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory()
	if DisplayServer.get_name()!="headless":await tap(KEY_M)
	check(not game.map_dialog.visible,"Map cannot cover active laboratory")
	game.free();print("FORMAL PHASE7: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
