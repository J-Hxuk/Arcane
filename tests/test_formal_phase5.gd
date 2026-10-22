extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/formal_world/"
func run()->void:
	var path:=OUT+"phase5_%d.json"%Time.get_ticks_usec();A.write(path,F.fixture("WATER",8431))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	game.player_pos=Vector2(1150,1180);game.bank_gold=100;game._interact();await process_frame
	check(game.shop_dialog.visible,"Smith E opens supply shop")
	check(game._buy_item("HP_POTION",2) and game.bank_gold==76 and game.inventory.count("HP_POTION")==2,"Quantity purchase charges exact price")
	check(not game._buy_item("MANA_POTION",99) and game.bank_gold==76,"Insufficient gold is atomic")
	check(not game._buy_item("HP_POTION",-1),"Invalid purchase rejected")
	check(game._buy_item("MANA_POTION",2),"Mana potions purchased")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw;game.shop_dialog.get_viewport().get_texture().get_image().save_png(OUT+"phase5_shop.png")
	game.shop_dialog.hide();game.player_hp=game._max_hp()-5;game.player_mana=0;game.mana_debt=15
	if DisplayServer.get_name()!="headless":await tap(KEY_1);await tap(KEY_2)
	else:game._use_potion("HP_POTION");game._use_potion("MANA_POTION")
	check(game.player_hp==game._max_hp() and game.inventory.count("HP_POTION")==1,"Potion hotkey heals without overheal and consumes once")
	check(game.mana_debt==0 and game.player_mana==25 and game.inventory.count("MANA_POTION")==1,"Mana potion repays existing debt first")
	check(not game._use_potion("HP_POTION") and game.inventory.count("HP_POTION")==1,"Full health does not consume potion")
	game.player_hp-=20;var real_path:String=game.save_path;game.save_path=OUT+"missing_directory/no_save.json"
	check(not game._use_potion("HP_POTION") and game.inventory.count("HP_POTION")==1 and game.player_hp==game._max_hp()-20,"Failed persistence restores quantity and health")
	game.save_path=real_path
	var saved:Dictionary=game.CharacterSave.load_file(path);check(saved.data.inventory.items.HP_POTION==1 and saved.data.bank==46,"Items and gold survive reload")
	check(not game.Inventory.valid({"items":{"HP_POTION":-1}}),"Malformed inventory is protected")
	if DisplayServer.get_name()!="headless":
		await tap(KEY_I);check(game.inventory_dialog.visible,"I opens inventory")
		await process_frame;await RenderingServer.frame_post_draw;game.inventory_dialog.get_viewport().get_texture().get_image().save_png(OUT+"phase5_inventory.png")
		await tap(KEY_I);check(not game.inventory_dialog.visible,"I closes inventory")
	game.free();print("FORMAL PHASE5: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
