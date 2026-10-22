extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/formal_world/"
const E=preload("res://scripts/chant_engine_v2.gd")
const R=preload("res://scripts/character_research.gd")
const P=preload("res://scripts/chant_profile.gd")
func run()->void:
	var profile=P.new();profile.load_data(P.generate_current(8431))
	for element in P.OHAENG:
		var model=R.new();model.load_data({"innate_affinity":{}});model.use_current_rules=true
		model.acquire_clue(element,"book",R.Rules.clue_id(element,"book"))
		var context={"formal_rules":true,"laboratory":true,"research_only":true,"observation_element":element}
		var events:=E.inputs(profile,["ACCUMULATE","STABILIZE","DIRECT","SHAPE"])
		var observed:=E.resolve(profile,events,context)
		check(observed.state=="ready" and observed.get("spell")==null,"Same production interpreter observes unawakened resonance "+element)
		model.record_current_resonance(observed.simulation,1)
		check(model.ritual_eligibility(element)=="catalyst_required","New awakening requires catalyst "+element)
		check(model.verify_catalyst(element,{})=="catalyst_rejected","Empty/incorrect mana cannot verify catalyst")
		check(model.verify_catalyst(element,observed.final_state)=="verified","Actual stable matching mana verifies catalyst")
		check(model.begin_ritual(element)=="ritual_started","Verified resonance permits ritual")
		var proof:=model.complete_ritual(profile,events,true)
		check(proof.state=="confirmation_required" and model.main_attribute==null,"Ritual never auto-confirms permanent role")
		check(model.start_element_research(element,proof.ticket)=="committed","Explicit valid ticket confirms primary")
	var path:=OUT+"phase3_%d.json"%Time.get_ticks_usec();A.write(path,F.fixture(null,8431))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.lab_observation_target="WATER";game._collect_research_clue("WATER","book")
	var events:=E.inputs(game._active_profile(),["ACCUMULATE","STABILIZE","DIRECT","SHAPE"])
	game.runes.assign(events.map(func(e):return str(e.key)));game.chant_inputs=events.duplicate(true)
	for event in game.chant_inputs:event["released"]=true
	game._cast_spell()
	check(game.research.stable_count("WATER")==1 and game.research.validate_evidence(game.journal.records()).is_empty(),"Actual cast records durable current research proof")
	game._collect_research_clue("WATER","environment")
	check(game.research.catalyst_verified("WATER"),"Actual catalyst interaction verifies recorded mana")
	game._talk_to_mentor("WATER")
	check(not game.mentor_text.text.contains("간섭 안정화") and not game.mentor_text.text.contains("선택 속성 연구") and not game.mentor_text.text.contains("[E]"),"NPC dialogue contains no system counters or key instructions")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"phase3_mentor.png")
	game.free();print("FORMAL PHASE3: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
