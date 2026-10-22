extends "res://tests/current_options_helpers.gd"
const AUDIT="res://.task002_artifacts/formula_followup/"
func chord(code:int)->void:
	await key(KEY_ALT,true);await tap(code);await key(KEY_ALT,false)
func wheel(up:bool)->void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN;event.position=Vector2(580,350);event.global_position=event.position;event.pressed=true
	Input.parse_input_event(event);await process_frame;event.pressed=false;Input.parse_input_event(event);await process_frame
func snap(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	game._sync_world_view();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(AUDIT+name+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute(AUDIT);root.size=Vector2i(1160,720);var path:=fresh();await process_frame
	var innate:Dictionary=game.research.innate_affinity;var profile:Dictionary=game._active_profile().to_data()
	game.inventory.add("HP_POTION",4);game.inventory.add("MANA_POTION",4)
	game.player_hp=10;game.player_mana=10;var inventory:Dictionary=game.inventory.to_data();var hp:float=game.player_hp;var mana:float=game.player_mana
	await chord(KEY_1);check(game.research.main_attribute=="WATER" and game.inventory.to_data()==inventory and game.player_hp==hp,"Unawakened Alt+1 fire rejected without drinking HP potion")
	await chord(KEY_6);check(game.research.main_attribute=="WATER","Primary none is rejected")
	await tap(KEY_TAB);check(game.research.selected_attribute_slot=="auxiliary" and not game._world_modal_open(),"Tab changes target slot without opening a panel")
	await chord(KEY_2);check(game.research.auxiliary_attributes.is_empty(),"Equipping same element in both slots is rejected")
	await chord(KEY_6);check(game.research.auxiliary_attributes.is_empty(),"Auxiliary none is accepted")
	check(game.inventory.to_data()==inventory and game.player_mana==mana,"Alt+2/6 never drinks MP potion")
	await key(KEY_ALT,true);game.world_hud.attribute_selector.advance(.3)
	check(not game.developer_mode and game.attribute_selector_visible(),"Ordinary world exposes the selector without developer mode")
	await snap("alt_selector_normal_world");await key(KEY_ALT,false)
	game._set_current_developer_option("all_elements",true)
	if game.research.selected_attribute_slot!="main":await tap(KEY_TAB)
	for i in 5:
		await chord(KEY_1+i)
		check(game.research.main_attribute==game.ATTRIBUTE_SHORTCUTS[i],"Actual Alt+digit map "+str(i+1))
	await tap(KEY_TAB);await chord(KEY_4);check(Array(game.research.auxiliary_attributes)==["METAL"],"Auxiliary metal shortcut applies to selected slot")
	await chord(KEY_5);check(Array(game.research.auxiliary_attributes)==["METAL"],"Auxiliary cannot duplicate earth main")
	await chord(KEY_6);check(game.research.auxiliary_attributes.is_empty(),"Alt+6 clears only auxiliary")
	await tap(KEY_TAB);await chord(KEY_2)
	var before_zoom:float=game.world_camera.zoom.x;await wheel(true);check(game.world_camera.zoom.x>before_zoom and game.research.main_attribute=="WATER","Wheel up zooms in without changing main")
	await wheel(false);check(is_equal_approx(game.world_camera.zoom.x,before_zoom),"Wheel down zooms out")
	await key(KEY_ALT,true);var selector=game.world_hud.attribute_selector;selector.advance(.3)
	check(game.attribute_selector_visible() and selector.opacity>.9,"Alt hold opens animated bottom selector")
	var phase:float=selector.animation_time;await snap("alt_selector_a");selector.advance(.5);await snap("alt_selector_b")
	check(selector.animation_time>phase,"Catalyst icons have advancing animation time")
	if DisplayServer.get_name()!="headless":
		var a:=Image.load_from_file(AUDIT+"alt_selector_a.png");var b:=Image.load_from_file(AUDIT+"alt_selector_b.png")
		check(a.get_region(Rect2i(310,580,540,115)).get_data()!=b.get_region(Rect2i(310,580,540,115)).get_data(),"Actual rendered selector icon region changes across frames")
	await key(KEY_ALT,false);selector.advance(.3);check(selector.opacity==0,"Alt release fades the selector out")
	game.player_mana=game._max_mana();await key(KEY_SHIFT,true)
	var frozen:Dictionary=game._prototype_context();await chord(KEY_1)
	check(game.research.main_attribute=="WATER" and game._prototype_context()==frozen,"Alt attribute choice is blocked during Shift session")
	for event in E.inputs(game._active_profile(),["ACCUMULATE","SHAPE","DIRECT"]):await tap(OS.find_keycode_from_string(event.key))
	check(game._inspect_chant(true).identity=="OH-061","Alt chord did not pollute the personal chant sequence")
	await tap(KEY_ESCAPE);await key(KEY_SHIFT,false)
	await tap(KEY_SHIFT);await tap(KEY_SHIFT);check(game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST,"Double Shift focus remains available")
	await chord(KEY_1);check(game.research.main_attribute=="WATER","Focus session locks shortcut selection")
	await tap(KEY_ESCAPE);await tap(KEY_I);var equipment:Dictionary=game.research.to_data();before_zoom=game.world_camera.zoom.x
	await wheel(true);await chord(KEY_1);await tap(KEY_TAB)
	check(Equal.equal(game.research.to_data(),equipment) and game.world_camera.zoom.x==before_zoom and not game.attribute_selector_visible(),"Inventory owns wheel, Alt digits and Tab")
	await tap(KEY_I);game.spell_record_hud.expanded=true;before_zoom=game.world_camera.zoom.x;await wheel(false);await chord(KEY_1)
	check(game.research.main_attribute=="WATER" and game.world_camera.zoom.x==before_zoom,"Expanded J record owns scroll and shortcut input")
	game.spell_record_hud.expanded=false;await key(KEY_ALT,true);game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.attribute_selector_visible(),"Focus loss clears the held selector safely");await key(KEY_ALT,false)
	# Delayed digit release after Alt release must not become a potion input.
	await key(KEY_ALT,true);await key(KEY_1,true);await key(KEY_ALT,false);await key(KEY_1,false)
	check(game.inventory.to_data()==inventory,"Delayed chord key-up does not use any potion")
	game._end_developer_test();game.player_hp=10;game.player_mana=10
	var hp_count:int=game.inventory.count("HP_POTION");var mp_count:int=game.inventory.count("MANA_POTION")
	await tap(KEY_1);await tap(KEY_2)
	check(game.inventory.count("HP_POTION")==hp_count-1 and game.inventory.count("MANA_POTION")==mp_count-1,"Plain 1 and 2 still use their original potions")
	check(game.research.innate_affinity==innate and game._active_profile().to_data()==profile,"Input changes preserve affinity and personal key mapping")
	# Persist final legitimate equipment, restart the actual world scene.
	game.research.developer_reset("all_elements","");game._change_active_attributes("WOOD","METAL");game.research.selected_attribute_slot="auxiliary";game._save_character()
	game.free();game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.research.main_attribute=="WOOD" and Array(game.research.auxiliary_attributes)==["METAL"] and game.research.selected_attribute_slot=="auxiliary","Restart restores selected slot and equipped elements")
	await finish("FOLLOWUP UI")
