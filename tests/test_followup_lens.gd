extends "res://tests/followup_helpers.gd"
const Lens=preload("res://scripts/observation_lens.gd")
func run()->void:
	var path:=fresh();await process_frame;game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.arena.set_process(false)
	var panel=game.laboratory_panel;var clues:Array=game.research.research_clues;var journal:Dictionary=game.journal.to_data()
	check(panel.observation_lens!=null and not panel.observation_lens.button_pressed and not panel.lens_readout.visible,"Interpretation lens exists and starts folded off")
	panel._lens_changed(true)
	var events:=chant(["ACCUMULATE","COMPRESS","STABILIZE"]);game._update_laboratory_live()
	for event in events:
		var expected:String=Lens.WORDS[game._active_profile().manipulation(event.key)]
		check(panel.lens_readout.text.contains(event.key+" — "+expected),"Lens reads actual personal active mapping "+event.key)
	check(panel.lens_caption.text=="안정화" and panel.lens_readout.text.contains("안정화 진행"),"Latest subtitle and qualitative reading follow the actual state delta")
	check(not panel.lens_readout.text.contains("OH-") and not panel.lens_readout.text.contains("정답") and not panel.lens_readout.text.contains("마나 1"),"Lens does not print recipe IDs, answers or developer metrics")
	var data:Dictionary=game._active_profile().to_data();var keys:Array=data.manipulations.keys();var first:String=keys[0];var second:String=keys[1];var operation=data.manipulations[first];data.manipulations[first]=data.manipulations[second];data.manipulations[second]=operation
	var other=game.ChantProfile.new();other.load_data(data)
	var reading:=Lens.interpret(other,[first],{},{});check(reading.meanings==first+" — "+Lens.WORDS[other.manipulation(first)],"Lens follows a changed valid personal mapping instead of hardcoded keys")
	check(game.journal.to_data()==journal and game.research.research_clues==clues,"Lens observation alone writes no journal or research progress")
	panel.awakening_panel.refresh();check(not panel.awakening_panel.journal_view.visible and panel.awakening_panel.journal_view.text.is_empty(),"Clue list header, text and scroll are removed from public research UI")
	check(game.research.research_clues==clues,"Clue data remains available to catalyst and awakening validation")
	if DisplayServer.get_name()!="headless":
		game._clear_chant();await enter_keys(["ACCUMULATE","COMPRESS","STABILIZE"])
		check(panel.lens_caption.text=="안정화","Actual key input produces matching caption")
		await capture("lens_live");game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await key(KEY_SHIFT,false)
		panel.awakening_panel.open();await capture("research_without_clues");check(panel.awakening_panel.size.y<450,"Removed clue history leaves a compact panel without a blank lower half");panel.awakening_panel.close()
	panel._lens_changed(false);check(not panel.lens_readout.visible and not panel.lens_caption.visible,"Turning lens off folds all interpretation text")
	game._leave_laboratory();check(not panel.lens_readout.is_visible_in_tree(),"Interpretation never leaks into world combat HUD")
	check(FileAccess.file_exists(path),"Lens tests use an isolated character")
	await finish("FOLLOWUP LENS")
