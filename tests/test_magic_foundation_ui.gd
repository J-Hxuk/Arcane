extends "res://tests/current_options_helpers.gd"
const Schools = preload("res://scripts/magic_schools.gd")
const Model = preload("res://scripts/magic_attunement.gd")
func choose_school(panel, id: String) -> void:
	for i in panel.school_picker.item_count:
		if panel.school_picker.get_item_metadata(i)==id:
			panel.school_picker.select(i); panel.school_picker.item_selected.emit(i); return
	check(false,"Missing UI school " + id)

func run() -> void:
	root.size=Vector2i(1160,720)
	var path:=fresh(); await process_frame
	var original: Dictionary=game._character_document().duplicate(true)
	var bytes:=FileAccess.get_file_as_bytes(path)
	await tap(KEY_F2)
	check(game.developer_panel.panel.visible,"Existing F2 opens safely")
	var panel=game.developer_panel.foundation_panel
	if DisplayServer.get_name()=="headless": game.developer_panel.foundation_button.pressed.emit()
	else: await click_control(game.developer_panel.foundation_button)
	await process_frame
	check(panel.visible and panel.catalog.ok and panel.school_picker.item_count==20,"F2 opens 20-school inspector with validated CSV")
	for school in Schools.all():
		choose_school(panel,school.id)
		check(panel._probe().state=="locked","Unopened QA selection denied " + school.id)
		panel.grant_button.pressed.emit(); panel.select_button.pressed.emit()
		check(panel._probe().state=="design_only" and not panel._probe().castable,"School identifies designs without casting " + school.id)
	choose_school(panel,"EAST_WATER_YANG"); panel.select_button.pressed.emit()
	choose_school(panel,"EAST_WOOD_YIN"); panel.select_button.pressed.emit()
	check(panel.model.to_data().east_choices.WATER=="YANG" and panel.model.to_data().east_choices.WOOD=="YIN","Independent eastern choices through UI")
	check(Equal.equal(original,game._character_document()) and bytes==FileAccess.get_file_as_bytes(path),"Every inspector action leaves character, journal, keymap, debt and isolated disk unchanged")
	panel.reset_button.pressed.emit()
	check(panel.model.to_data().unlocked_schools.is_empty() and panel.model.to_data().active_school==null,"QA reset does not change old awakenings")
	panel.all_button.pressed.emit()
	check(panel.model.to_data().unlocked_schools.size()==20,"Future full access represented in memory without an NG+ schedule")
	if DisplayServer.get_name()!="headless": await capture("magic_foundation_panel",panel)
	panel.hide(); await process_frame
	check(panel.model.to_data().unlocked_schools.is_empty(),"Closing drops temporary choices")
	game.developer_panel.foundation_button.pressed.emit(); await process_frame; await tap(KEY_F2)
	check(not panel.visible and not game.developer_panel.panel.visible,"F2 close cannot leave an orphan inspector")
	check(not game.developer_mode and Equal.equal(original,game._character_document()) and bytes==FileAccess.get_file_as_bytes(path),"F2 lifecycle does not start developer character or write player progression")
	# Test optional-extension persistence only on this fixture, never on user://.
	var model:=Model.new(); model.grant_school("EAST_WOOD_YIN"); model.select_school("EAST_WOOD_YIN")
	var extended:=model.document(game._character_document()); extended.magic_attunement.future={"preserve":true}
	check(game.CharacterSave.write_file(path,extended)==OK,"Optional extension writes to isolated fixture")
	var reloaded:Dictionary=game.CharacterSave.load_file(path)
	check(reloaded.state=="loaded" and Equal.equal(reloaded.data.magic_attunement,extended.magic_attunement),"Optional extension survives save boundary")
	var saved:=FileAccess.get_file_as_bytes(path)
	var bad:=extended.duplicate(true);bad.magic_attunement.unlocked_schools.append("UNKNOWN")
	check(game.CharacterSave.write_file(path,bad)==ERR_INVALID_DATA and saved==FileAccess.get_file_as_bytes(path),"Invalid extension refuses write without touching bytes")
	fresh(extended); await process_frame
	check(Equal.equal(game._character_document().magic_attunement,extended.magic_attunement),"Real game load/serialize preserves extension and unknown fields")
	var before_development:Dictionary=game._character_document().duplicate(true)
	var fixture_bytes:=FileAccess.get_file_as_bytes(game.save_path)
	check(game._set_current_developer_option("all_elements",true),"Existing world developer options still work with optional extension")
	check(game._end_developer_test() and Equal.equal(before_development,game._character_document()) and fixture_bytes==FileAccess.get_file_as_bytes(game.save_path),"Existing F2 restore includes extension, journal and original disk")
	game.developer_tools_enabled=false
	check(not game.developer_panel.foundation_panel.open_for(game),"Disabled developer policy denies inspector")
	await finish("MAGIC FOUNDATION UI")
