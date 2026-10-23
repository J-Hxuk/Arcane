extends "res://tests/current_options_helpers.gd"
const O = preload("res://scripts/mana_observation.gd")
const Unit = preload("res://tests/test_mana_observation.gd")
const DIR = "res://.task002_artifacts/mana_observation/"

func cell(view, field: String, column: int) -> String:
	var item: TreeItem=view.matrix.get_root().get_first_child() if view.matrix.get_root()!=null else null
	while item!=null:
		if item.get_text(0)==O.LABELS[field]: return item.get_text(column)
		item=item.get_next()
	return ""

func toggle(control: BaseButton) -> void:
	# Nested scroll/layout containers finish their deferred size changes first.
	await process_frame
	await process_frame
	if DisplayServer.get_name()=="headless": control.button_pressed=not control.button_pressed
	else: await click_control(control)
	await process_frame

func enter(actions: Array) -> void:
	await key(KEY_SHIFT,true)
	for event in E.inputs(game._active_profile(),actions): await tap(OS.find_keycode_from_string(event.key))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size=Vector2i(1160,850)
	var path:=fresh(); await process_frame
	var original: Dictionary=game._character_document().duplicate(true); var bytes:=FileAccess.get_file_as_bytes(path)
	check(game._set_current_developer_option("all_elements",true),"Use existing memory-only developer isolation")
	game.player_pos=game.Layout.LAB_DOOR; game._enter_laboratory(); game.laboratory_panel.arena.set_process(false); await process_frame
	var panel=game.laboratory_panel; var view=panel.numeric_view
	check(panel.numeric_observation.button_pressed and view.visible and view.frames.is_empty(),"Laboratory opens actual numeric observation UI, no phantom input")
	var mapping: Dictionary=game._active_profile().to_data(); var book: Dictionary=game.discovered.to_data()
	await enter(["ACCUMULATE"])
	check(view.frames.size()==1 and view.display_frame.operator=="ACCUMULATE", "One actual key creates one incomplete-prefix observation")
	check(cell(view,"mana_amount",2)=="%.3f" % game._inspect_chant(true).final_state.mana_amount and cell(view,"flow_strength",4)!="", "Tree shows real engine numbers and B before chant completion")
	for event in E.inputs(game._active_profile(),["SHAPE"]): await tap(OS.find_keycode_from_string(event.key))
	check(view.frames.size()==2 and view.step_picker.item_count==3,"Every input adds a selectable step")
	var before: Dictionary=Unit.signature(game._inspect_chant(true))
	var resources:=Vector2(game.player_mana,game.mana_debt); var research_before:Dictionary=game.research.to_data()
	await toggle(panel.numeric_observation)
	check(not view.visible and panel.live_orb.visible,"OFF restores original orb UI")
	check(Equal.equal(before,Unit.signature(game._inspect_chant(true))),"Observation OFF leaves complete inspection/spell/cost results identical")
	await toggle(panel.numeric_observation)
	check(view.visible and view.frames.size()==2 and Equal.equal(before,Unit.signature(game._inspect_chant(true))),"ON restores current read-only steps without a new simulation result")
	check(resources==Vector2(game.player_mana,game.mana_debt) and mapping==game._active_profile().to_data() and book==game.discovered.to_data() and research_before==game.research.to_data(),"Toggling never pays mana, changes keys, grants discoveries or changes research")
	for event in E.inputs(game._active_profile(),["DIRECT"]): await tap(OS.find_keycode_from_string(event.key))
	var live_frames: Array=view.frames.duplicate(true)
	check(live_frames.size()==3 and view.display_frame.after==O.numbers(game._inspect_chant(true).simulation.casting_steps.back().after),"Current readings exactly match the final existing step snapshot")
	check(view.plot.frames.size()==3 and cell(view,"cohesion",7)=="%.3f" % live_frames.back().raw.cohesion,"Plot and raw column receive the same snapshot data")
	check(not view.heading.text.contains("OH-") and not view.trend.text.contains("OH-") and not view.projection.text.contains("OH-"),"Numeric UI never reveals an undiscovered identity or recipe")
	if DisplayServer.get_name()!="headless": await capture("mana_observation_live")
	var next: int=game.journal.to_data().next_id
	await key(KEY_SHIFT,false)
	check(game.journal.to_data().next_id==next+1 and view.frames.is_empty(),"Existing Shift-up casts/records once and clears live observation session")
	var record: Dictionary=game.journal.records().back()
	var equal_frames:=true
	for i in live_frames.size(): equal_frames=equal_frames and record.steps[i].mana_observation==live_frames[i]
	check(equal_frames,"Journal keeps the exact live observation frames, not a different replay")
	await toggle(view.history_mode)
	view.record_step.value=1
	check(view.display_frame==O.from_record(record,0) and cell(view,"mana_amount",2)=="%.3f" % live_frames[0].after.mana_amount,"Historical step navigation renders saved numbers")
	view.record_step.value=3
	check(view.display_frame==live_frames.back(),"Historical last step reproduces live state exactly")
	if DisplayServer.get_name()!="headless": await capture("mana_observation_record")
	await toggle(view.history_mode)
	await enter(["DIRECT","SHAPE","ACCUMULATE"])
	var reversed: Dictionary=view.frames.back()
	check(reversed.multiset==live_frames.back().multiset and reversed.raw!=live_frames.back().raw,"Same multiset shows different actual order-dependent state")
	check(cell(view,"cohesion",8)=="%.3f" % (reversed.after.cohesion-live_frames.back().after.cohesion),"Current-versus-previous-record numeric delta is correct")
	var cancel_id: int=game.journal.to_data().next_id
	await tap(KEY_ESCAPE); await key(KEY_SHIFT,false)
	check(view.frames.is_empty() and game.journal.to_data().next_id==cancel_id+1 and game.journal.records().back().result.outcome=="cancelled","Esc clears live data and records cancellation without auto-release")
	check(game.journal.records().back().steps.size()==3 and game.journal.records().back().steps.back().has("mana_observation"),"Cancelled experiment remains available as research data")
	game._reset_combat_input(); game.exhaustion_seconds=0
	await enter(["COMPRESS","COMPRESS","COMPRESS","COMPRESS","COMPRESS"])
	check(view.frames.size()==5 and view.display_frame.multiset.COMPRESS==5 and view.display_frame.after.stability==0,"Repeated input retains exact count and collapse state")
	check(cell(view,"cohesion",3)=="0.000" and cell(view,"cohesion",9)=="28.000","UI separates a clipped zero delta from a real raw change")
	await key(KEY_SHIFT,false)
	check(view.frames.is_empty() and game.journal.records().back().result.outcome=="failed","Failed release clears transient observations but keeps the failed record")
	await toggle(view.history_mode)
	check(view.display_frame.get("after",{}).get("stability")==0 and cell(view,"stability",7)!="—", "Failed raw and clipped stability remain visible in history")
	await toggle(view.history_mode)
	game._reset_combat_input(); game.exhaustion_seconds=0
	await tap(KEY_SHIFT); await tap(KEY_SHIFT)
	check(game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST and game._movement_speed()==0,"Observation adds no 70-percent focus movement")
	game.player_mana=0; game.mana_debt=0; game._process(.1)
	check(is_equal_approx(game.player_mana,1.6),"Existing double focus regeneration is unchanged, no new buffs")
	game.player_mana=game._max_mana(); panel.show_trial(); await process_frame
	# Trial transition intentionally cancels the old input session.
	await tap(KEY_SHIFT); await tap(KEY_SHIFT)
	check(game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST,"Re-enter focus after the existing trial-screen safety reset")
	for event in E.inputs(game._active_profile(),["ACCUMULATE","SHAPE","DIRECT"]): await tap(OS.find_keycode_from_string(event.key))
	var focus_next: int=game.journal.to_data().next_id
	await click_control(panel.arena)
	check(game.journal.to_data().next_id==focus_next+1,"Focus LMB remains an explicit release with observation enabled")
	await tap(KEY_ESCAPE); panel.show_journal(); await process_frame
	var doc: Dictionary=game._character_document()
	var stored_path: String=DIR+"roundtrip_%d.json" % OS.get_process_id()
	check(game.CharacterSave.write_file(stored_path,doc)==OK,"Save optional observation metadata through v6 using isolated path")
	var loaded: Dictionary=game.CharacterSave.load_file(stored_path)
	check(loaded.state=="loaded" and Equal.equal(loaded.data.laboratory,doc.laboratory),"Reload retains all old/new experiment data without migration")
	check(game._end_developer_test() and Equal.equal(original,game._character_document()) and bytes==FileAccess.get_file_as_bytes(path),"F2 restoration preserves original journal, map, debt, character and disk bytes")
	check(view.frames.is_empty() and view.records.is_empty(),"Leaving lab/developer session clears temporary observation references")
	await finish("MANA OBSERVATION UI")
