extends "res://tests/followup_helpers.gd"
func far()->void:
	game.player_pos=Vector2(2500,1650);game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll()
func run()->void:
	var data:=F.fixture("WATER",8431);data.world=game_progress();data.world.field={"defeated":["N01","N02"],"claimed":["N01"],"drops":[{"id":"N02","position":[1020,-300],"gold":7}],"custom_field":"preserve"};data.bank=0
	var path:=fresh(data);await process_frame;var system=game.field_system
	check(FileAccess.file_exists(path+".respawn.bak"),"Old permanent-defeat format receives an exact original backup")
	check(game.world_progress.data.field.version==2 and game.world_progress.data.field.custom_field=="preserve" and game.world_progress.data.field.drops[0].id=="N02","Migration preserves unknown field data and old outstanding drop")
	check(system.actors.size()==5 and system.actors[0].state=="DEAD","Old defeated monster initially stays dead")
	var old:Dictionary=system.actors[0];game.player_pos=old.home+Vector2(100,0);system.advance(game,61)
	check(system.actors[0].state=="DEAD","Expired timer cannot respawn in the player's immediate surroundings")
	far();system.advance(game,.1)
	var actor:Dictionary=system.actors[0]
	check(actor.state=="IDLE" and actor.field_id=="N01@1" and actor.hp==actor.max_hp and actor!=old,"Hidden respawn is a fresh generation and combat body")
	check(game.world_progress.data.field.drops.any(func(d):return d.id=="N02"),"Respawn does not delete an older uncollected drop")
	# Three actual shared-combat kills pay for one mana potion.
	var definition=Registry.definition("MANA_BOLT")
	for cycle in 3:
		actor=system.actors[0];far()
		game.elemental_combat.hit_enemy(game,actor,definition,Vector2.RIGHT);game.elemental_combat.hit_enemy(game,actor,definition,Vector2.RIGHT)
		system.advance(game,.01);check(actor.state=="DEAD","Shared magic damage kills respawned monster "+str(cycle))
		var bank:int=game.bank_gold;game.player_pos=actor.pos;system._collect(game);system._collect(game)
		check(game.bank_gold==bank+7,"Generation drop pays exactly once "+str(cycle))
		far();system.advance(game,61)
	check(game.bank_gold==21,"Three seven-gold kills yield 21 gold")
	game.player_pos=Vector2(1150,1180);game._interact();check(game._buy_item("MANA_POTION",1) and game.bank_gold==6,"Field gold buys the 15-gold mana potion")
	game.shop_dialog.hide();game.player_mana=0;game.mana_debt=0
	if DisplayServer.get_name()!="headless":await tap(KEY_2)
	else:game._use_potion("MANA_POTION")
	check(game.player_mana==40 and game.inventory.count("MANA_POTION")==0,"Purchased potion is actually usable and consumes one item")
	var claimed:Array=game.world_progress.data.field.claimed.duplicate();var bank:int=game.bank_gold
	game._save_character();game._rebuild_field();system=game.field_system;system._collect(game)
	check(game.bank_gold==bank and game.world_progress.data.field.claimed==claimed,"Reload never regenerates a claimed old drop")
	# Bound pending drops and hide all fresh spawns from the current screen.
	for cycle in 3:
		actor=system.actors[0];actor.hp=0;system._death(game,actor);far();system.advance(game,61)
	check(system.actors[0].state=="DEAD" and game.world_progress.data.field.drops.filter(func(d):return d.spawn_id=="N01").size()==2,"Two outstanding drops cap a spawn until collection; no unbounded farm objects")
	check(system.actors.size()==5 and system.routes.size()==5 and game.world_progress.data.field.defeated.size()<=5 and game.world_progress.data.field.claimed.size()<=5,"Runtime bodies, routes and reward ledgers stay bounded")
	var saved:Dictionary=game.CharacterSave.load_file(path);var error:String=game.Progress.new().load_data(saved.data.world) if saved.state=="loaded" else saved.get("message","")
	if not error.is_empty():print("FIELD RELOAD ERROR ",error," field valid=",game.field_system.valid(saved.get("data",{}).get("world",{}).get("field",{})))
	check(saved.state=="loaded" and error.is_empty(),"New generations and pending drops remain valid after serialization")
	restart_fixture("field")
	if DisplayServer.get_name()!="headless":
		game.player_pos=Vector2(650,-260);await capture("respawn_field")
	FileAccess.open(OUT+"field_loop_result.json",FileAccess.WRITE).store_string(JSON.stringify({"kills":3,"gold":21,"mana_potion_price":15,"remaining_gold":6,"respawn_seconds":60,"live_cap":5,"pending_cap_per_spawn":2}))
	await finish("FOLLOWUP FIELD")
func game_progress()->Dictionary:return preload("res://scripts/world/world_progress.gd").defaults()
