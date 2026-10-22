extends "res://tests/attribute_helpers.gd"
func observation_order(element:String)->Array:
	var context:Dictionary=game.research.simulation_context();context.merge({"formal_rules":true,"laboratory":true,"research_only":true,"observation_element":element},true)
	for order in Registry.permutations(["ACCUMULATE","COMPRESS","SHAPE","STABILIZE","STABILIZE"]):
		var result:=E.resolve(game._active_profile(),E.inputs(game._active_profile(),order),context);var s:Dictionary=result.final_state
		if result.state=="ready" and E.research_ready(s) and s.cohesion>=25 and s.stability>=75 and s.form_integrity>=50:return order
	return []
func ritual_order(element:String)->Array:
	var context:Dictionary=game.research.simulation_context();context.merge({"formal_rules":true,"laboratory":true,"research_only":true,"observation_element":element},true)
	for order in Registry.permutations(["ACCUMULATE","SHAPE","SHAPE","STABILIZE","DIRECT"]):
		var result:=E.resolve(game._active_profile(),E.inputs(game._active_profile(),order),context);var s:Dictionary=result.final_state
		if result.state=="ready" and E.research_ready(s) and s.form_integrity>=50 and s.flow_strength>=.5:return order
	return []
func run()->void:
	var data:=F.fixture("WATER",8431);data.research.main_attribute=null;data.research.auxiliary_attributes=[];data.research.binding_studies=[];data.research.resonance_discoveries={}
	var path:=fresh(data);await process_frame;game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.arena.set_process(false)
	check(game.game_state=="LAB","Five-ritual test enters actual laboratory through its doorway")
	var affinity:Dictionary=game.research.innate_affinity
	for element in game.CharacterResearch.Loadout.ORDER:
		game._select_lab_observation(element);game._collect_research_clue(element,"book")
		check(game.research.start_element_research(element)=="confirmation_required","No UI-bypass awakening before ritual "+element)
		var order:=observation_order(element);check(not order.is_empty(),"Existing stable interference composition exists within five inputs "+element)
		if order.is_empty():await finish("ATTRIBUTES RESEARCH");return
		chant(order);game.player_mana=game._max_mana();game.exhaustion_seconds=0;game._cast_spell()
		game._collect_research_clue(element,"environment")
		check(game.research.catalyst_verified(element) and game.research.ritual_eligibility(element)=="available","Books, actual resonance and catalyst unlock ritual "+element)
		check(game._begin_awakening(element)=="ritual_started","Every element can begin its own ritual "+element)
		order=ritual_order(element);check(not order.is_empty(),"Final ritual structure exists "+element)
		chant(order);game.player_mana=game._max_mana();game.exhaustion_seconds=0;game._cast_spell()
		var offer:Dictionary=game.pending_awakening_offer
		check(offer.get("state")=="confirmation_required" and element not in game.research.awakened_attributes,"Automatic release never automatically approves permanent awakening "+element)
		if offer.is_empty():await finish("ATTRIBUTES RESEARCH");return
		check(game._confirm_element_research(element,int(offer.ticket))=="committed" and element in game.research.awakened_attributes,"Manual permanent confirmation commits "+element)
		game.laboratory_panel.awakening_panel.cancel_confirmation()
	check(game.research.awakened_attributes.size()==5 and game.research.innate_affinity==affinity,"All five permanent rituals coexist without rerolling affinity")
	game._change_active_attributes("WATER","METAL");check(game.research.study_binding("METAL")=="binding_studied","Existing interference/catalyst prerequisites still permit binding research")
	game._change_active_attributes("FIRE",null);check("METAL+WATER" in game.research.to_data().binding_studies,"Unequipping the pair preserves earned binding")
	var expected:Dictionary=game._character_document();game._save_character();game.free();game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and game.research.awakened_attributes.size()==5 and game.research.main_attribute=="FIRE","Five real rituals and inactive binding reload through the complete game validator")
	check(Equal.equal(expected.research,game.research.to_data()),"Reload retains all permanent evidence and replaceable equipment")
	if DisplayServer.get_name()!="headless":game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.awakening_panel.open();await capture("five_awakenings_research")
	restart_fixture("five_rituals");await finish("ATTRIBUTES RESEARCH")
