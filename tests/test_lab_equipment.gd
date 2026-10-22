extends "res://tests/current_options_helpers.gd"
func picker(slot:String,trial:=false)->OptionButton:
	var matches:Array=game.laboratory_panel.equipment_pickers.filter(func(entry):return entry.slot==slot)
	return matches[0 if trial else 1].picker
func select_value(control:OptionButton,value:Variant)->void:
	var index:=-1
	for i in control.item_count:
		if control.get_item_metadata(i)==value:index=i;break
	check(index>=0,"UI offers equipped candidate "+str(value))
	if index<0:return
	if DisplayServer.get_name()=="headless":control.select(index);control.item_selected.emit(index)
	else:
		await click_control(control);control.get_popup().set_focused_item(index);await tap(KEY_ENTER);await process_frame
func run()->void:
	var path:=fresh();await process_frame
	game._set_current_developer_option("all_elements",true);game._set_current_developer_option("bindings",true)
	game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();var panel=game.laboratory_panel;panel.arena.set_process(false);game._update_laboratory_live();await process_frame
	check(panel.equipment_pickers.size()==4,"Both observation and direct trial contain distinct main and auxiliary selectors")
	await select_value(picker("main"),"METAL");await select_value(picker("auxiliary"),"WATER")
	check(game.research.main_attribute=="METAL" and Array(game.research.auxiliary_attributes)==["WATER"],"Observation selectors update actual equipped main and auxiliary")
	var valid:=true
	for i in picker("main").item_count:
		if picker("main").get_item_metadata(i)=="WATER":valid=false
	check(valid,"Main selector excludes the element equipped in auxiliary")
	if DisplayServer.get_name()!="headless":await capture("lab_equipment_observation")
	panel.show_trial();await process_frame;await select_value(picker("auxiliary",true),null);await select_value(picker("main",true),"WATER");await select_value(picker("auxiliary",true),"METAL")
	check(game.research.main_attribute=="WATER" and Array(game.research.auxiliary_attributes)==["METAL"],"Trial selectors support auxiliary none and changing both slots")
	var row:Dictionary=Registry.config().spells.filter(func(r):return r.id=="ICE_CRYSTAL_NEEDLE")[0];var order:=normal_order(row,game._prototype_context());chant(order);var result:Dictionary=game._inspect_chant(true)
	check(result.identity=="ICE_CRYSTAL_NEEDLE","Lab equipment and current-world binding setting feed the same actual fusion interpreter")
	game._clear_chant();await key(KEY_SHIFT,true);game._update_laboratory_live()
	check(picker("main",true).disabled and picker("auxiliary",true).disabled and not game._select_lab_equipment("main","WOOD"),"Both selectors and direct requests lock throughout an active chant")
	await tap(KEY_ESCAPE);await key(KEY_SHIFT,false);game._begin_movement_research();game._update_laboratory_live()
	check(picker("main",true).disabled and not game._select_lab_equipment("auxiliary",null),"Movement research keeps neutral context safe from equipment changes")
	game._reset_combat_input();game._update_laboratory_live()
	if DisplayServer.get_name()!="headless":await capture("lab_equipment_trial")
	game._end_developer_test();game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();game._update_laboratory_live()
	check(picker("main").item_count==1 and picker("main").get_item_metadata(0)=="WATER" and picker("auxiliary").item_count==1 and picker("auxiliary").get_item_metadata(0)==null,"Normal character selectors expose only genuinely awakened elements and auxiliary none")
	check(not game._select_lab_equipment("main","FIRE"),"Lab selector API refuses unawakened elements without development settings")
	await finish("LAB EQUIPMENT")
