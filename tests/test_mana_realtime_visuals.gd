extends "res://tests/current_options_helpers.gd"
const Model = preload("res://scripts/mana_visual_model.gd")
const Orb = preload("res://scripts/mana_orb_view.gd")
const Signature = preload("res://tests/test_mana_observation.gd")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	fresh(); await process_frame
	check(game._set_current_developer_option("all_elements",true),"Memory-only test isolation")
	var profile_before: Dictionary=game._active_profile().to_data().duplicate(true)
	var view=game.player_view
	chant(["ACCUMULATE","SHAPE","DIRECT"])
	game.combat_input.mode=game.CombatInput.Mode.MOBILE_CAST
	view.update_presentation(0.016)
	var inspected: Dictionary=game._inspect_chant(true)
	var signature: Dictionary=Signature.signature(inspected)
	check(view.mana_orb.visible and view.mana_orb.transparent_view and view.mana_orb.size==Vector2(64,64),"Combat orb uses a bounded transparent local area")
	check(view.mana_orb.target_descriptor==Model.project(inspected.simulation.final_state),"Combat orb reads the actual final engine snapshot")
	view.mana_visuals_enabled=false; view.update_presentation(0.016)
	check(not view.mana_orb.visible and Equal.equal(signature,Signature.signature(game._inspect_chant(true))),"Visual OFF preserves complete chant result")
	view.mana_visuals_enabled=true; view.update_presentation(0.016)
	check(Equal.equal(signature,Signature.signature(game._inspect_chant(true))),"Visual ON preserves complete chant result")
	game.combat_input.mode=game.CombatInput.Mode.FOCUS_CAST; view.update_presentation(0.016)
	check(view.mana_orb.observation_gain>1.0 and game._movement_speed()==0,"Focus shows particle trails and keeps movement locked")
	var isolated:=Orb.new(); root.add_child(isolated)
	var first: Dictionary=inspected.simulation.casting_steps[0].after
	var last: Dictionary=inspected.simulation.final_state
	isolated.show_snapshot(first,0.0,true)
	var start: Dictionary=isolated.descriptor.duplicate(true)
	isolated.show_snapshot(last,0.0,true)
	check(isolated.descriptor==start and isolated.target_descriptor==Model.project(last),"Input change starts from current visual state")
	isolated._process(0.09)
	check(isolated.descriptor.radius!=start.radius and isolated.descriptor.radius!=isolated.target_descriptor.radius,"Mid-transition radius is continuous")
	isolated._process(0.10)
	check(isolated.descriptor==isolated.target_descriptor,"Visual reaches exact observed state without stabilization delay")
	isolated.show_snapshot(first,2.0,false)
	var points:=isolated.particle_points(2.0)
	isolated.show_snapshot(first,2.0,false)
	check(points==isolated.particle_points(2.0) and isolated.descriptor==Model.project(first),"Archived snapshots draw deterministically without interpolation")
	isolated.free()
	game._reset_combat_input(); game._clear_chant()
	game.player_pos=game.Layout.LAB_DOOR; game._enter_laboratory(); await process_frame
	var panel=game.laboratory_panel; var numeric=panel.numeric_view
	await enter_keys(["ACCUMULATE","SHAPE","DIRECT"])
	var steps: Array=game._inspect_chant(true).simulation.casting_steps.duplicate(true)
	check(numeric.visual_orbs[0].snapshot==steps.back().before and numeric.visual_orbs[1].snapshot==steps.back().after,"Live visual pair follows selected real input")
	check(numeric.plot.selected_index==3,"Graph highlights the same selected input")
	numeric.step_picker.select(1); numeric._render()
	check(numeric.visual_orbs[0].snapshot==steps[0].before and numeric.visual_orbs[1].snapshot==steps[0].after and numeric.plot.selected_index==1,"Step selection synchronizes graph and both orbs")
	numeric.step_picker.select(0); numeric._render()
	await tap(KEY_ESCAPE); await key(KEY_SHIFT,false)
	var cancelled: Dictionary=game.journal.records().back()
	check(cancelled.result.outcome=="cancelled","Cancel produces an actual cancelled record")
	check(not numeric.visual_orbs[0].animated and not numeric.visual_orbs[1].animated,"Cancellation stops transient visual animation processing")
	numeric.history_mode.button_pressed=true
	check(numeric.visual_orbs[1].snapshot==cancelled.steps.back().after,"Cancelled final visual state is replayed exactly")
	numeric.history_mode.button_pressed=false
	await enter_keys(["DIRECT","SHAPE","ACCUMULATE"])
	check(numeric.visual_orbs[2].snapshot==cancelled.steps.back().after,"Current chant can be compared with previous archived state")
	check(Model.project(numeric.visual_orbs[1].snapshot)!=Model.project(numeric.visual_orbs[2].snapshot),"Same multiset in a different order changes actual visual properties")
	if DisplayServer.get_name()!="headless":await capture("phase2b_live_compare")
	await tap(KEY_ESCAPE); await key(KEY_SHIFT,false)
	game._reset_combat_input(); game.exhaustion_seconds=0
	await enter_keys(["COMPRESS","COMPRESS","COMPRESS","COMPRESS","COMPRESS"])
	await key(KEY_SHIFT,false)
	numeric.history_mode.button_pressed=true
	var failed: Dictionary=game.journal.records().back()
	check(failed.result.outcome=="failed" and numeric.visual_orbs[1].snapshot==failed.steps.back().after and numeric.visual_orbs[1].descriptor.collapsed,"Failed final state remains available and collapsed")
	if DisplayServer.get_name()!="headless":await capture("phase2b_failed_record")
	var old: Dictionary=cancelled.duplicate(true);old.id=999;old.steps=[{"input":{"key":"?"},"before":{},"after":{}}]
	numeric.set_records([old]);numeric._render()
	check(numeric.visual_orbs[1].snapshot.is_empty() and numeric.visual_labels[1].text.contains("미기록"),"Absent historical state is marked unrecorded without reconstruction")
	var children: int=numeric.get_child_count();var nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var started:=Time.get_ticks_usec()
	for i in 500:
		numeric.set_records([cancelled,failed]);numeric.record_step.value=(i%3)+1;numeric._render()
	check(numeric.get_child_count()==children and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes,"500 record selections keep node count bounded")
	print("PHASE2B 500 replay selections usec: ",Time.get_ticks_usec()-started)
	check(profile_before==game._active_profile().to_data(),"Visual interactions preserve personal key map")
	await finish("MANA REALTIME VISUALS")
