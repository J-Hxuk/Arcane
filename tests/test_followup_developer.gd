extends "res://tests/followup_helpers.gd"
func run()->void:
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"));var path:=fresh(source);await process_frame
	var original:Dictionary=game._character_document();var bytes:=FileAccess.get_file_as_bytes(path)
	check(not game._developer_action("research_all") and Equal.equal(original,game._character_document()),"Reset requests outside developer character are denied")
	game._start_developer_test("WATER_METAL","LAB");var affinity:Dictionary=game.research.innate_affinity;var mapping:Dictionary=game._active_profile().to_data()
	check(game._developer_action("blink_unlock") and game.research.blink_unlocked(),"Developer can force independent blink unlock")
	check(not game.CharacterSave.valid_resources(game._character_document()),"Developer-only proof cannot pass the normal persistence boundary")
	check(game._developer_action("research_blink") and not game.research.blink_unlocked(),"Developer can reset blink alone")
	var catalyst_data:Dictionary=game.research.to_data();catalyst_data["catalyst_validations"]={"METAL":{"mana_amount":12,"stability":80,"form_integrity":55}};game.research.load_data(catalyst_data)
	check(game.research.catalyst_verified("METAL"),"Developer catalyst fixture starts verified")
	game._developer_action("research_catalysts");check(game.research.to_data().get("catalyst_validations",{}).is_empty(),"Catalyst validation reset is available")
	check(game._developer_action("research_auxiliary") and game.research.main_attribute=="WATER" and game.research.auxiliary_attributes.is_empty() and game.research.simulation_context().binding_pairs.is_empty(),"Auxiliary reset preserves primary and clears dependent binding")
	game._start_developer_test("WATER_METAL","LAB");game._prototype_all=true
	check(game._developer_action("research_primary") and game.research.main_attribute==null and game.research.auxiliary_attributes.is_empty() and not game._prototype_all,"Primary reset clears dependent auxiliary and all-element bypass")
	game.developer_panel.elements.select(game.DeveloperTestData.OPTIONS.find("WATER"))
	check(game._developer_action("research_toggle") and game.research.main_attribute=="WATER","Selected unawakened element toggles on")
	check(game._developer_action("research_toggle") and game.research.main_attribute==null,"Selected primary toggles off")
	game._start_developer_test("WATER_METAL","LAB");game._developer_action("blink_unlock");game._developer_action("research_all")
	check(game.research.main_attribute==null and game.research.research_clues.is_empty() and not game.research.blink_unlocked() and game.research.to_data().get("binding_studies",[]).is_empty(),"Full research reset clears progress and unlocks")
	check(game.research.innate_affinity==affinity and game._active_profile().to_data()==mapping,"Even full debug reset preserves innate talent and personal active mapping")
	if DisplayServer.get_name()!="headless":await tap(KEY_F2);check(game.developer_panel.panel.visible,"F2 exposes all reset controls only in debug panel");await capture("developer_resets");await tap(KEY_F2)
	game._end_developer_test();check(Equal.equal(original,game._character_document()) and bytes==FileAccess.get_file_as_bytes(path),"Ending all reset tests restores exact player document and disk bytes")
	await finish("FOLLOWUP DEVELOPER")
