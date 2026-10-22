extends "res://tests/test_water15_integration.gd"
func run()->void:
	DirAccess.make_dir_recursive_absolute(AUDIT);root.size=Vector2i(1160,720);fresh();await process_frame;game._water_qa_start("WORLD");game.guardian.stop();game.enemies.clear();game.field_system.suppressed=true;game.player_pos=Vector2(3300,910);game._sync_world_view();game.world_camera.reset_smoothing();await process_frame
	var rows:Array=[]
	for id in ["OH-073","OH-074","OH-075"]:
		game._water_qa_prepare(id,"on");var d=game._inspect_chant(false).spell;game._reset_combat_input();game.elemental_combat.clear();game.missiles.clear()
		game.enemies.assign([target(Vector2(3490,910),100000)])
		var frames:Array=[];var cpu:Array=[];var peak_missiles:=0;var peak_states:=0;var peak_vfx:=0;var peak_nodes:=0;var started:=Time.get_ticks_usec();var previous:=started;var next_cast:=0.0;var casts:=0
		var memory_before:int=Performance.get_monitor(Performance.MEMORY_STATIC)
		while (Time.get_ticks_usec()-started)/1000000.0<5.0:
			var now:=Time.get_ticks_usec();var elapsed:float=(now-started)/1000000.0;var delta:float=clampf((now-previous)/1000000.0,.001,.1);previous=now
			if elapsed>=next_cast:
				game.elemental_combat.cast(game,d,Vector2.RIGHT,game.player_pos+Vector2(190,0));game.spell_audio.cue(id,str(d.effect));next_cast+=.5;casts+=1
			var begin:=Time.get_ticks_usec();game.elemental_combat.update(game,delta);game.elemental_combat.update_missiles(game,delta,1);cpu.append((Time.get_ticks_usec()-begin)/1000.0)
			peak_missiles=maxi(peak_missiles,game.missiles.size());peak_states=maxi(peak_states,game.elemental_combat.water_states.size());peak_vfx=maxi(peak_vfx,game.elemental_combat.visuals.size());peak_nodes=maxi(peak_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			game._sync_world_view();await process_frame;frames.append((Time.get_ticks_usec()-now)/1000.0)
		var memory_peak:int=Performance.get_monitor(Performance.MEMORY_STATIC)
		await snap_water(id+"_stress")
		# Drain with real renders so audio and GPU objects also receive time.
		var drain:=Time.get_ticks_usec();var last:=drain
		while (Time.get_ticks_usec()-drain)/1000000.0<9.0:
			var now:=Time.get_ticks_usec();var delta:float=minf(.1,(now-last)/1000000.0);last=now
			game.elemental_combat.update(game,delta);game.elemental_combat.update_missiles(game,delta,1);game._sync_world_view();await process_frame
		frames.sort();cpu.sort();var sum:=0.0;var work:=0.0
		for value in frames:sum+=value
		for value in cpu:work+=value
		var row={"id":id,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":[root.size.x,root.size.y],"casts":casts,"measured_frames":frames.size(),"mean_frame_ms":sum/frames.size(),"p95_frame_ms":frames[int(frames.size()*.95)],"max_frame_ms":frames.back(),"observed_fps":1000/(sum/frames.size()),"mean_combat_cpu_ms":work/cpu.size(),"p95_combat_cpu_ms":cpu[int(cpu.size()*.95)],"peak_projectiles":peak_missiles,"peak_water_states":peak_states,"peak_visuals":peak_vfx,"peak_nodes":peak_nodes,"static_memory_before":memory_before,"static_memory_after_casts":memory_peak,"static_memory_after_drain":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"remaining_projectiles":game.missiles.size(),"remaining_states":game.elemental_combat.water_states.size(),"remaining_visuals":game.elemental_combat.visuals.size(),"audio_playing_after_drain":game.spell_audio.playing}
		rows.append(row)
		check(casts>=9 and frames.size()>20,id+" repeated actual-window stress measured")
		check(game.missiles.is_empty() and game.elemental_combat.water_states.is_empty() and game.elemental_combat.visuals.is_empty() and not game.spell_audio.playing,id+" no projectile/VFX/field/audio residue after real-time drain")
	FileAccess.open(AUDIT+"performance.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	game._end_developer_test();await finish("WATER15 PERFORMANCE")
