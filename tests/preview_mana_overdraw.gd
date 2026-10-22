extends "res://tests/preview_world_phase1.gd"
const Rules=preload("res://scripts/mana_overdraw.gd")
const DIR:="res://.task002_artifacts/mana_overdraw/"
var measurements:=[]
func shot(name:String) -> void:
	game._sync_world_view();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+name+".png")
func cast_water() -> void:
	game._reset_combat_input();await key(KEY_SHIFT,true)
	for input in D.inputs(game.chant_profile,"WATER",["ACCUMULATE","ACCUMULATE","DIRECT","DIRECT"]):await tap(OS.find_keycode_from_string(input["key"]))
	await click_world(game.guardian.actor["pos"],MOUSE_BUTTON_LEFT);await key(KEY_SHIFT,false)
func level(p:float) -> void:
	game.player_mana=0;game.mana_debt=Rules.limit(game._max_mana())*p
	game.mana_exhaustion_view.advance(game.mana_debt,game._max_mana(),2)
	game._sync_world_view();await process_frame
func render_profile(p:float) -> Dictionary:
	if root.mode==Window.MODE_MINIMIZED:root.mode=Window.MODE_WINDOWED
	root.grab_focus()
	await level(p)
	for i in 20:await process_frame
	var samples:Array[float]=[];var draws:=0.0
	for i in 90:
		var start:=Time.get_ticks_usec();await process_frame
		# A minimized/background Windows swapchain may stop frame_post_draw while
		# SceneTree timers continue. Explicit draw avoids an unbounded test wait.
		RenderingServer.force_draw(false)
		samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	samples.sort()
	return {"p":p,"samples":samples.size(),"median_frame_ms":samples[45],"p95_frame_ms":samples[85],"mean_draw_calls":draws/90,"reported_fps":Performance.get_monitor(Performance.TIME_FPS)}
func run() -> void:
	root.size=Vector2i(1160,720)
	var data:=F.fixture("WATER",1787453028);data["magic"]=50;var path:=DIR+"window.json";A.write(path,data)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	game._start_guardian();game.player_pos=Vector2(3160,910);game._sync_world_view();await process_frame
	var original_mapping:Dictionary=game.chant_profile.to_data()
	game.player_mana=8.99;await cast_water()
	check(game.player_mana==0 and absf(game.mana_debt-0.01)<0.001 and game.missiles.size()==1,"Actual Shift/keys/LMB automatically spends mental reserve and spawns exactly once")
	check(game.mana_exhaustion_view.entry_warning>0 and game.mana_exhaustion_view.displayed_blur>=0.075,"Actual first negative frame immediately enables edge warning and 7.5% minimum blur")
	await shot("01_first_negative_warning")
	await level(1);var before:int=game.missiles.size();var entries:int=game.mana_exhaustion_view.entry_count;await cast_water()
	check(game.player_mana==0 and game.mana_debt==30 and game.missiles.size()==before and game.mana_exhaustion_view.entry_count==entries,"Actual over-limit release has no mana-only loss, extra effect or false entry warning")
	game._reset_combat_input();game.missiles.clear()
	for p in [0.0,0.25,0.5,0.75,1.0]:
		await level(p);game.player_pos=Vector2(3100,1000);game._sync_world_view();await process_frame
		var start:Vector2=game.player_pos;await click_world(start+Vector2(120,0));game.navigation.advance(game,0.1,game._movement_speed());game.navigation.cancel()
		var speed:float=game.player_pos.distance_to(start)/0.1
		check(absf(speed-200*(1-0.5*p))<0.2,"Actual RMB movement matches the continuous exhaustion speed: p="+str(p))
		check(absf(game.mana_exhaustion_view.displayed_blur-Rules.blur(game.mana_debt,100))<0.001,"Rendered shader strength matches the continuous target after settling: p="+str(p))
		measurements.append({"p":p,"mana":game.player_mana,"mana_debt":game.mana_debt,"normal_speed_px_s":speed,"mobile_speed_px_s":speed*0.8,"target_blur":Rules.blur(game.mana_debt,100),"displayed_blur":game.mana_exhaustion_view.displayed_blur})
		game.player_pos=game.guardian.actor["pos"]-Vector2(95,0);game.guardian._begin_pattern(game,"SWEEP");await shot("02_ratio_%03d"%roundi(p*100))
		check(game.world_hud.get_parent().layer>game.mana_exhaustion_view.layer,"Critical HUD stays above the blur pass")
	for pattern in ["CHARGE","SLAM","THROW"]:
		game.guardian._begin_pattern(game,pattern);await shot("03_maximum_"+pattern)
	# Resume actual combat progression at maximum debt, without HP edits or invincibility.
	var hp:float=game.player_hp;await click_world(game.player_pos+Vector2(0,160));await tap(KEY_CTRL)
	for i in 60:game._process(0.02)
	check(game.player_hp==hp and game.guardian.active,"Actual RMB/Ctrl evades a live boss throw while exhausted")
	game._reset_combat_input();await level(1)
	for down in [true,false,true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_SHIFT;event.physical_keycode=KEY_SHIFT;event.pressed=down;Input.parse_input_event(event)
	Input.flush_buffered_events();await process_frame
	var position:Vector2=game.player_pos;await click_world(position+Vector2(100,0));game._process(0.5)
	check(game.player_pos==position and game._movement_speed()==0 and game.player_mana==0 and game.mana_debt==27,"Actual double Shift blocks movement and recovers negative mana at double speed")
	await tap(KEY_SPACE);game.player_mana=0;game.mana_debt=0.1;game._process(0.2)
	check(game.player_mana>0 and game._movement_speed()==200 and not game.mana_exhaustion_view.overlay.visible,"Actual recovery fully restores movement and clears the screen effect")
	await shot("04_recovered")
	var view=game.mana_exhaustion_view;view.reset();entries=view.entry_count
	for i in 120:
		game.player_mana=0;game.mana_debt=0.01 if i%2==0 else 0;view.advance(game.mana_debt,100,1.0/60);await process_frame
	check(view.entry_count==entries+1,"Actual rendered near-zero oscillation avoids repeated warning flashes")
	game.guardian._begin_pattern(game,"SLAM");var performance:=[await render_profile(0),await render_profile(1)]
	var output:=FileAccess.open(DIR+"window_measurements.json",FileAccess.WRITE);output.store_string(JSON.stringify({"levels":measurements,"performance":performance},"\t"));output.close()
	print("OVERDRAW_RENDER_PROFILE ",JSON.stringify(performance))
	await level(1);game._save_character();game.free();game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.player_mana==0 and game.mana_debt==30 and game.chant_profile.to_data()==original_mapping,"Actual rendered reload retains debt and the personal mapping")
	game.free();print("MANA OVERDRAW WINDOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
