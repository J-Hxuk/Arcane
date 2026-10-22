extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/formal_world/"
func run()->void:
	var path:=OUT+"phase6_%d.json"%Time.get_ticks_usec();A.write(path,F.fixture("WATER",8431))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.field_system.actors.size()==5 and game.world_camera.limit_top==-960,"Five monsters and extended camera boundary")
	game.player_pos=Vector2(790,180);check(game.world_navigation.request(game,Vector2(790,-180)),"North gate has a connected reachable route")
	for i in 120:game.world_navigation.advance(game,.02,200)
	check(game.player_pos.y<-170 and not game.layout.blocked(game.player_pos,13),"Walking through north gate uses collision-valid positions")
	var actor:Dictionary=game.field_system.actors[0];game.player_pos=actor.home+Vector2(110,0);var before:Vector2=actor.pos
	game.field_system.advance(game,.1);check(actor.state=="CHASE" and actor.pos.distance_to(before)>0,"Nearby monster aggros and chases")
	game.player_pos=actor.pos+Vector2(30,0);game.field_system.advance(game,.1);check(actor.state=="WINDUP","Attack has a visible windup")
	var hp:float=game.player_hp;game.player_pos=actor.target+Vector2(120,0);game.field_system.advance(game,1);check(game.player_hp==hp,"Leaving telegraphed area avoids damage")
	actor.state="CHASE";game.player_pos=actor.pos+Vector2(30,0);game.field_system.advance(game,.1);game.field_system.advance(game,1);check(game.player_hp<hp,"Remaining in telegraph receives shared hit feedback")
	actor.state="CHASE";actor.root_remaining=2;game.player_pos=actor.pos+Vector2(130,0);before=actor.pos;game.field_system.advance(game,.2);check(actor.pos==before,"Existing root prevents monster movement")
	actor.root_remaining=0;actor.hp=0;game.player_pos=actor.pos+Vector2(100,0);game.field_system.advance(game,.1)
	check(actor.state=="DEAD" and game.world_progress.data.field.drops.size()==1,"Death persists a physical gold drop")
	var gold:int=game.bank_gold;game.player_pos=actor.pos;game.field_system.advance(game,.1);game.field_system.advance(game,.1)
	check(game.bank_gold==gold+7 and game.world_progress.data.field.drops.is_empty(),"Proximity pickup credits gold exactly once")
	game._rebuild_field();check(game.field_system.actors.filter(func(a):return a.hp>0).size()==4 and game.world_progress.data.field.spawns.N01.dead,"Reload preserves the dead generation until its respawn timer expires")
	var saved:Dictionary=game.CharacterSave.load_file(path);var progress=game.Progress.new();check(progress.load_data(saved.data.world).is_empty() and saved.data.bank==gold+7,"North position, defeated ID and gold survive persistence")
	var next:Dictionary=game.field_system.actors.filter(func(a):return a.hp>0)[0];game.player_pos=next.pos+Vector2(100,0);next.hp=0
	var valid_path:String=game.save_path;game.save_path=OUT+"missing_directory/drop.json";var field:Dictionary=game.world_progress.data.field.duplicate(true)
	game.field_system.advance(game,.01);check(next.state!="DEAD" and game.world_progress.data.field.drops==field.drops and game.world_progress.data.field.spawns.N02.dead==field.spawns.N02.dead,"Failed death persistence cannot create an unpaid gold drop")
	game.save_path=valid_path;game.field_system.advance(game,1.01);game.player_pos=next.pos;game.save_path=OUT+"missing_directory/pickup.json"
	var bank:int=game.bank_gold;game.field_system.advance(game,.01);check(game.bank_gold==bank and not game.world_progress.data.field.drops.is_empty(),"Failed pickup persistence restores gold and the physical drop")
	game.save_path=valid_path;game.field_system.advance(game,1.01);check(game.bank_gold==bank+7 and game.world_progress.data.field.drops.is_empty(),"Retry collects restored drop exactly once")
	game.player_pos=Vector2(800,-300);game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll()
	if DisplayServer.get_name()!="headless":
		await aim(game.player_pos+Vector2(100,0));await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"phase6_field.png")
	game.free();print("FORMAL PHASE6: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
