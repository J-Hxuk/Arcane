extends "res://tests/current_options_helpers.gd"
func toggle(option:String,on:bool)->void:
	var button:CheckButton=game.developer_panel.current_option_buttons[option]
	if DisplayServer.get_name()=="headless":game._set_current_developer_option(option,on)
	else:
		if not game.developer_panel.panel.visible:await tap(KEY_F2)
		if button.button_pressed!=on:await click_control(button)
func run()->void:
	var path:=fresh();await process_frame
	var original:Dictionary=game._character_document();var bytes:=FileAccess.get_file_as_bytes(path);var start:Vector2=game.player_pos;var mapping:Dictionary=game._active_profile().to_data();var actors:Array=game.field_system.actors.duplicate(true)
	await toggle("all_elements",true)
	check(game.current_world_development and game.world_enabled and game.game_state=="DUNGEON" and game.player_pos==start,"Checkbox applies to the current world without a preset character, teleport or lab transition")
	check(game.research.awakened_attributes.size()==5 and game._active_profile().to_data()==mapping and Equal.equal(actors,game.field_system.actors),"All elements become selectable while personal keys and current monsters stay intact")
	check(FileAccess.get_file_as_bytes(path)==bytes,"Enabling current-world options never writes the normal save")
	if DisplayServer.get_name()!="headless":await capture("current_options_panel");await tap(KEY_F2)
	check(game._change_active_attributes("FIRE",null),"Newly opened fire can immediately be equipped in the original world")
	var row:Dictionary=Registry.config().spells.filter(func(r):return r.id=="OH-016")[0];var order:=normal_order(row,game._prototype_context());chant(order);var quote:Dictionary=game._inspect_chant(true);var mana:float=game.player_mana
	game._cast_spell();check(quote.identity=="OH-016" and not game.missiles.is_empty() and is_equal_approx(mana-game.player_mana,quote.mana_cost),"A newly available element manifests an actual world projectile with the exact normal cost")
	if DisplayServer.get_name()!="headless":await capture("current_world_fire")
	await toggle("bindings",true);await toggle("blink",true)
	check(game.research.to_data().binding_studies.size()==10 and game.research.blink_unlocked(),"Independent binding and blink switches apply alongside all-element opening")
	await toggle("all_elements",false)
	check(game.research.awakened_attributes==["WATER"] and game.research.main_attribute=="WATER" and game.research.blink_unlocked(),"Turning all-element override off restores qualified original slots without turning blink off")
	await toggle("blink",false);await toggle("bindings",false)
	check(Equal.equal(original.research,game.research.to_data()),"Turning each override off restores the exact original research")
	check(FileAccess.get_file_as_bytes(path)==bytes,"World casting, option changes and memory autosaves leave disk unchanged")
	game._developer_current_action("gold");game._developer_current_action("items");game.player_pos+=Vector2(30,0);game._save_character()
	check(game.bank_gold==int(original.bank)+100 and FileAccess.get_file_as_bytes(path)==bytes,"Other F2 actions also affect this current session while saves stay isolated")
	game._end_developer_test();check(not game.current_world_development and not game.developer_mode and Equal.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"End settings restores original position, research, inventory, resources and full document")
	check(game._developer_current_action("research_all_elements") and game.current_world_development and game.research.awakened_attributes.size()==5,"Existing all-element button now works immediately without starting a test character")
	game._end_developer_test();game._start_developer_test("WATER_METAL","WORLD")
	check(game._set_current_developer_option("blink",true) and game.current_world_development and game.player_pos==start and not game.guardian.active,"Choosing current-world options from an old preset returns to the original world first")
	game._end_developer_test();game.developer_tools_enabled=false
	check(not game._set_current_developer_option("all_elements",true) and not game._developer_current_action("gold"),"Disabled developer policy rejects all current-world entry paths")
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"));path=fresh(source);await process_frame;original=game._character_document();bytes=FileAccess.get_file_as_bytes(path);start=game.player_pos
	check(game._set_current_developer_option("all_elements",true) and game._set_current_developer_option("bindings",true) and game._set_current_developer_option("blink",true) and game.player_pos==start,"Actual player COPY supports all three live switches without relocation")
	game._set_current_developer_option("all_elements",false);game._set_current_developer_option("bindings",false);game._set_current_developer_option("blink",false)
	check(Equal.equal(original.research,game.research.to_data()) and Equal.equal(original.active_chant,game._active_profile().to_data()),"Actual player's affinity, old evidence, legitimate binding and personal keys survive option off")
	game._end_developer_test();check(Equal.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"Actual player COPY returns byte-identical after current-world settings end")
	game.player_pos=Vector2(3070,910);game._start_guardian();var boss:Dictionary=game.guardian.snapshot();start=game.player_pos
	check(game.guardian.active and game._set_current_developer_option("all_elements",true) and game.guardian.snapshot()==boss and game.player_pos==start,"Enabling current-world options during a boss battle preserves the active boss and position")
	game._end_developer_test();check(game.guardian.active and game.guardian.snapshot()==boss,"Ending settings also restores the original ongoing boss encounter")
	await finish("CURRENT WORLD DEVELOPER")
