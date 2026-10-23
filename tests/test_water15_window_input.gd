extends "res://tests/test_water15_integration.gd"
func click_control(control: Control) -> void:
	await process_frame
	await process_frame
	await super.click_control(control)

func shot_keys(order:Array)->void:
	game._reset_combat_input();await key(KEY_SHIFT,true)
	for event in E.inputs(game._active_profile(),order):await tap(OS.find_keycode_from_string(event.key))
func lab_aim(arena,p:Vector2)->void:
	arena._update_views();arena.camera.reset_smoothing();arena.camera.force_update_scroll();await process_frame
	var point:Vector2=arena.world_to_screen(p);Input.warp_mouse(point);await process_frame
	var mouse:=InputEventMouseMotion.new();mouse.position=point;mouse.global_position=point;Input.parse_input_event(mouse);await process_frame
func run()->void:
	root.size=Vector2i(1160,720);var path:=fresh();await process_frame;var bytes:=FileAccess.get_file_as_bytes(path);var original:Dictionary=game._character_document().duplicate(true)
	await tap(KEY_F2);check(game.developer_panel.panel.visible,"Actual F2 opens from ordinary F5 main scene")
	# Trigger the actual control callback, not a separate standalone preview scene.
	var qa_button:Button
	for button in game.developer_panel.panel.find_children("*","Button",true,false):
		if button.text=="물15 QA 연구실":qa_button=button
	check(qa_button!=null,"F2 exposes integrated water15 QA control")
	await click_control(qa_button);var arena=game.laboratory_panel.arena;arena.set_process(false)
	check(game.water_qa_active and game._max_mana()==1000 and game.research.awakened_attributes.size()==5,"Actual F2 button starts memory-isolated five-element character")
	for item in WATER.DATA.spells:
		arena.reset_targets();arena.enemies.clear();game.player_mana=1000;game.mana_debt=0
		var order:Array=game.water_qa_cases[item.id].off.actions
		await lab_aim(arena,arena.player_pos+Vector2(270,0))
		var next:int=game.journal.to_data().next_id
		await shot_keys(order);var prediction:Dictionary=game._inspect_chant(true);var mana:float=game.player_mana
		await key(KEY_SHIFT,false)
		check(game.journal.to_data().next_id==next+1 and is_equal_approx(mana-game.player_mana,prediction.mana_cost),item.id+" actual lab Shift release charges and records once")
		check(game.journal.records().back().result.get("manifestation",{}).get("catalog_id")==item.id,item.id+" real lab input manifests correct ID")
		await key(KEY_SHIFT,false);check(game.journal.to_data().next_id==next+1,item.id+" duplicate Shift-up never releases twice")
	await tap(KEY_SHIFT);await tap(KEY_SHIFT);check(game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST,"Actual double Shift focus remains optional")
	await tap(KEY_ESCAPE);arena.combat.clear();arena.missiles.clear();var count:int=game.journal.to_data().next_id
	await shot_keys(WATER.DATA.spells[0].actions);await tap(KEY_ESCAPE);await key(KEY_SHIFT,false)
	check(game.journal.to_data().next_id<=count+1 and arena.missiles.is_empty(),"Esc cancels input without a projectile release")
	check(game._water_qa_start("FIELD"),"Integrated ordinary-target world arena starts")
	await process_frame;game._sync_world_view();await process_frame
	check(game.enemies.size()==5 and game.enemies.all(func(e):return not game._is_blocked(e.pos,15)) and game.field_views.filter(func(v):return v.visible and v.actor in game.enemies).size()==5,"All five ordinary QA targets have actual visible world actors at valid coordinates")
	await tap(KEY_F2)
	# The OS-native popup is outside Input.parse_input_event. Set this UI
	# prerequisite explicitly; preparation and return use actual window clicks.
	game.developer_panel.water_picker.select(14)
	check(game.developer_panel.water_picker.selected==14,"Hydra dropdown prerequisite set (native OS popup navigation is not synthesized)")
	var prepare:Button
	for button in game.developer_panel.panel.find_children("*","Button",true,false):
		if button.text=="강한 현상 준비":prepare=button
	await click_control(prepare)
	check(not game.developer_panel.panel.visible and game._inspect_chant(false).identity=="OH-075" and game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST,"Actual F2 prepare button returns a frozen, ready selected Hydra session to the world")
	await snap_water("ordinary_targets_qa")
	game._developer_current_action("clear_enemies");await process_frame;await process_frame;await process_frame
	check(game.enemies.is_empty() and game.field_views.filter(func(v):return v.visible).is_empty(),"Developer clear removes ordinary QA targets from both collision and visible actors")
	game._water_qa_start("WORLD");await process_frame;game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll();await process_frame
	for item in WATER.DATA.spells:
		game._reset_combat_input();game.elemental_combat.clear();game.missiles.clear();game.player_pos=Vector2(3100,910);game.player_mana=1000;game.mana_debt=0;game.exhaustion_seconds=0
		var boss:Dictionary=game.guardian.actor;boss.pos=Vector2(3300,910);boss.hp=boss.max_hp;boss.root_remaining=0;boss.root_applications=0;boss.guarded=false;game.enemies.assign([boss]);game.guardian.state="RECOVERY"
		game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll();await process_frame
		var order:Array=game.water_qa_cases[item.id].on.actions
		await shot_keys(order);var prediction:Dictionary=game._inspect_chant(false);var d=prediction.spell
		var goal:Vector2=boss.pos
		if d.effect in [&"cone",&"shockwave"]:boss.pos=game.player_pos+Vector2(100,0);goal=boss.pos
		var mana:float=game.player_mana;await click_world(goal,MOUSE_BUTTON_LEFT);await key(KEY_SHIFT,false)
		if item.id in ["OH-066","OH-067"]:game.missiles.append({"pos":game.player_pos+Vector2(160,0),"dir":Vector2.LEFT,"hostile":true,"life":2.0,"speed":180.0,"dmg":20.0})
		check(is_equal_approx(mana-game.player_mana,prediction.mana_cost) and game.developer_metrics.get("spell")==d.display_name,item.id+" actual world Shift/LMB releases correct spell and cost")
		for frame in 8:game.elemental_combat.update(game,1.0/60);game.elemental_combat.update_missiles(game,1.0/60,1)
		await snap_water(item.id+"_boss")
		for frame in 480:game.elemental_combat.update(game,1.0/60);game.elemental_combat.update_missiles(game,1.0/60,1)
		if item.id not in ["OH-066","OH-067"]:check(boss.hp<boss.max_hp,item.id+" actual boss HP receives real combat hit")
		else:check(game.elemental_combat.water_metrics.shield_contacts>0 and game.elemental_combat.water_states.is_empty(),item.id+" real world shield contacts hostile projectile and expires")
	await tap(KEY_F2);await snap_water("F2_water15_qa")
	await click_control(game.developer_panel.end_button)
	check(Equal.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"Actual F2 end restores original progression, J records, personal map and save bytes")
	await finish("WATER15 WINDOW INPUT")
