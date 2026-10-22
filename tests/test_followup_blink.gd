extends "res://tests/followup_helpers.gd"
const Blink=preload("res://scripts/blink_motion.gd")
class Actor:
	extends RefCounted
	var player_pos:=Vector2(100,100)
	var wall:=INF
	func _blink_position_blocked(point:Vector2,radius:float)->bool:return point.x+radius>=wall
func run()->void:
	var actor=Actor.new()
	for cursor in [Vector2(900,100),Vector2(100,-900),Vector2(-900,100),Vector2(900,900)]:
		var result:=Blink.destination(actor,cursor);check(result.allowed and is_equal_approx(actor.player_pos.distance_to(result.position),216),"Independent blink caps all directions at exactly two dodge distances")
	check(Blink.destination(actor,Vector2(145,100)).position==Vector2(145,100),"Near cursor is the exact destination, never overshot")
	check(not Blink.destination(actor,actor.player_pos).allowed,"Zero displacement consumes no blink")
	actor.wall=200;check(Blink.destination(actor,Vector2(700,100)).position.x<187,"Sweep stops before wall using player radius")
	var path:=fresh();await process_frame;game.player_pos=Vector2(780,760);game._sync_world_view();game.world_camera.reset_smoothing()
	check(not game.research.blink_unlocked(),"Existing character does not receive a free research reward")
	var mana:float=game.player_mana
	if DisplayServer.get_name()!="headless":await aim(game.player_pos+Vector2(500,0));await tap(KEY_CTRL)
	else:game.dodge.begin(game.player_pos,Vector2.RIGHT)
	game._process(.04);check(game.dodge.active and is_equal_approx(game.player_mana,mana),"Before unlock Ctrl immediately evades without mana cost")
	game.dodge.reset();game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.arena.set_process(false)
	check(game._begin_movement_research(),"Lab exposes deliberate movement research")
	chant(["ACCUMULATE","ACCUMULATE","DIRECT"]);game._cast_spell();check(not game.research.blink_unlocked(),"Wrong structure cannot unlock blink")
	game.exhaustion_seconds=0;chant(["ACCUMULATE","STABILIZE","DIRECT"]);var preview:Dictionary=game._inspect_chant(true)
	check(preview.state=="ready" and preview.get("spell")==null and preview.final_state.base_attributes.is_empty(),"Movement ritual uses neutral current simulator without a combat spell or slot")
	var roles:Array=Array(game.research.active_elements);var bytes:=FileAccess.get_file_as_bytes(path);game.save_path=OUT+"missing_directory/unlock.json";game._cast_spell()
	check(not game.research.blink_unlocked() and FileAccess.get_file_as_bytes(path)==bytes,"Unlock and proof roll back if saving fails")
	game.save_path=path;chant(["ACCUMULATE","STABILIZE","DIRECT"])
	if DisplayServer.get_name()!="headless":game._clear_chant();await enter_keys(["ACCUMULATE","STABILIZE","DIRECT"]);await key(KEY_SHIFT,false)
	else:game._cast_spell()
	check(game.research.blink_unlocked() and Array(game.research.active_elements)==roles,"Successful real lab research unlocks blink without taking an element slot")
	var saved:Dictionary=game.CharacterSave.load_file(path);var restored=game.CharacterResearch.new();check(saved.state=="loaded" and restored.load_data(saved.data.research).is_empty() and restored.blink_unlocked(),"Research proof survives JSON save and reload")
	for scenario in [{"start":Vector2(150,760),"cursor":Vector2(10,760),"axis":"x","minimum":133.0},{"start":Vector2(230,365),"cursor":Vector2(230,250),"axis":"y","minimum":340.0},{"start":Vector2(1000,540),"cursor":Vector2(1000,400),"axis":"y","minimum":493.0},{"start":Vector2(25,-800),"cursor":Vector2(-500,-800),"axis":"x","minimum":13.0}]:
		game.player_pos=scenario.start;var endpoint:=Blink.destination(game,scenario.cursor)
		check(endpoint.allowed and endpoint.position[scenario.axis]>=scenario.minimum and not game._is_blocked(endpoint.position,13),"Real wall, tree, building and map boundary stop at a valid last point "+scenario.axis+str(scenario.minimum))
	game.player_pos=Vector2(780,760);game.dodge.reset();game.dodge.begin(game.player_pos,Vector2.RIGHT);var during_mana:float=game.player_mana
	check(not game._try_blink(game,game.dodge,Vector2(1000,760)) and game.player_mana==during_mana,"Independent blink never upgrades an active evasion")
	game._leave_laboratory();game.player_pos=Vector2(780,760);game.dodge.reset();game.player_mana=50;game.mana_debt=0;game._sync_world_view();game.world_camera.reset_smoothing()
	if DisplayServer.get_name()!="headless":
		await process_frame;await process_frame;game.world_camera.force_update_scroll() # Let the lab layout/canvas transition settle before cursor-based input.
	if DisplayServer.get_name()!="headless":await aim(Vector2(840,760));await tap(KEY_CTRL)
	else:game._try_blink(game,game.dodge,Vector2(840,760))
	check(game.player_pos.distance_to(Vector2(840,760))<1 and game.player_mana==45 and not game.dodge.active,"One Ctrl after unlock reaches near cursor and spends exactly five")
	if DisplayServer.get_name()!="headless":await capture("blink_researched")
	if DisplayServer.get_name()!="headless":await tap(KEY_CTRL)
	else:game._try_blink(game,game.dodge,Vector2(1000,760))
	check(game.player_mana==45 and game.player_pos.distance_to(Vector2(840,760))<1,"Repeated Ctrl cannot bypass cooldown or charge twice")
	game.dodge.reset();game.player_mana=4;check(not game._try_blink(game,game.dodge,Vector2(1000,760)) and game.player_mana==4,"Insufficient positive mana rejects independent blink")
	game.player_mana=50;game.save_path=OUT+"missing_directory/blink.json";var origin:Vector2=game.player_pos
	check(not game._try_blink(game,game.dodge,origin+Vector2(100,0)) and game.player_pos==origin and game.player_mana==50 and game.dodge.cooldown==0,"Failed blink save restores endpoint, cost and cooldown")
	game.save_path=path;game.combat_input.mode=game.CombatInput.Mode.FOCUS_CAST;check(not game._try_blink(game,game.dodge,origin+Vector2(100,0)),"Focus immobility also blocks independent blink")
	game.combat_input.mode=game.CombatInput.Mode.NORMAL
	restart_fixture("blink")
	await finish("FOLLOWUP BLINK")
