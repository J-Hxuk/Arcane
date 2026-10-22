extends "res://tests/preview_world_phase1.gd"
const H=preload("res://tests/test_chant.gd")
func run()->void:
	root.size=Vector2i(1160,720)
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/phase4_qa_v2/user_before.json"))
	var path="res://.task002_artifacts/phase4_qa_v2/qa0_%d.json"%Time.get_ticks_usec();A.write(path,source)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes=FileAccess.get_file_as_bytes(path)
	game._start_developer_test("WATER_METAL","WORLD");game.guardian.state="RECOVERY"
	for pattern in ["SWEEP","SLAM"]:
		game.player_pos=game.guardian.actor["pos"]+Vector2(-60,0);game.player_hp=100
		game.guardian._begin_pattern(game,pattern);game.guardian.state="ACTIVE";game.guardian.timer=.1
		game.combat_input.mode=game.CombatInput.Mode.MOBILE_CAST;game.runes.assign(["X","T"])
		game.guardian.advance(game,.01);game.player_view.update_presentation(0)
		check(game.player_hp==100-game.guardian.attack_data()["damage"],pattern+" collision applies the exact HP damage")
		check(game.hit_feedback.remaining>0 and game.player_view.body.modulate!=Color.WHITE,pattern+" visible hit flash")
		check(game.hit_feedback.heavy==(pattern=="SLAM"),pattern+" normal/strong feedback distinguished")
		check(game.runes.size()==2 and game.combat_input.mode==game.CombatInput.Mode.MOBILE_CAST,"Normal/default strong feedback does not invent automatic chant interruption")
		var hp:float=game.player_hp;game.guardian.advance(game,.01);check(game.player_hp==hp,"One attack damages only once")
		if not DisplayServer.get_name()=="headless":
			game._sync_world_view();game.world_camera.reset_smoothing();await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.task002_artifacts/phase4_qa_v2/hit_"+pattern+".png")
	game.player_hp=1;game.guardian._begin_pattern(game,"SWEEP");game.guardian.state="ACTIVE";game.guardian.timer=.1
	game._process(.01);check(not game.guardian.active and game.player_hp==game._max_hp(),"Lethal ACTIVE attack completes death in the same update")
	game._end_developer_test()
	check(H.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"F2 restores all fields and exact original disk")
	game._start_developer_test("WOOD","LAB");game.discovered.load_data({"version":1,"spells":{}});game._update_laboratory_live()
	var coach=game.laboratory_panel.coach
	check(coach.target.item_count==1 and not coach.target.get_item_text(0).contains("Briarbind"),"Public research receives no undiscovered catalog rows or IDs")
	game.laboratory_panel.arena._receive_player_damage(10,false,Vector2.RIGHT)
	check(game.player_hp==game._max_hp()-10,"Laboratory uses the same player damage path")
	game._end_developer_test();game.free()
	print("PHASE4 QA0: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
