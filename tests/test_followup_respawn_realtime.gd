extends "res://tests/followup_helpers.gd"
func run()->void:
	fresh();await process_frame
	var system=game.field_system;var old:Dictionary=system.actors[0]
	game.player_pos=Vector2(2500,1650);old.hp=0;system.advance(game,.01);game._sync_world_view();game.world_camera.reset_smoothing()
	check(old.state=="DEAD" and old.field_id=="N01","Real-time test begins with persisted dead generation zero")
	var gold:int=game.bank_gold;var started:=Time.get_ticks_msec();game.set_process(true)
	await create_timer(58).timeout
	check(system.actors[0].state=="DEAD" and system.actors[0].field_id=="N01","Actual running window does not respawn before sixty seconds")
	await create_timer(4).timeout;game.set_process(false)
	var elapsed:=Time.get_ticks_msec()-started
	check(elapsed>=61000 and system.actors[0].hp>0 and system.actors[0].field_id=="N01@1","Actual wall-clock run respawns a fresh offscreen body after sixty seconds")
	check(game.bank_gold==gold and game.world_progress.data.field.drops.any(func(drop):return drop.id=="N01"),"Real-time respawn neither pays gold nor destroys the old drop")
	game.player_pos=Vector2(600,-220);game._sync_world_view();game.world_camera.reset_smoothing();await capture("respawn_realtime_after")
	FileAccess.open(OUT+"realtime_respawn_measurement.json",FileAccess.WRITE).store_string(JSON.stringify({"wall_clock_ms":elapsed,"new_id":system.actors[0].field_id,"old_drop_retained":true,"extra_gold":game.bank_gold-gold}))
	await finish("FOLLOWUP REALTIME RESPAWN")
