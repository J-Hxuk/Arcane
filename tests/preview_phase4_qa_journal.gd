extends "res://tests/preview_phase4_qa_v2.gd"
const J=preload("res://scripts/experiment_journal.gd")
func screen(control:Control)->Vector2:
	return control.get_global_rect().get_center()+(Vector2(control.get_window().position) if control.get_window()!=root else Vector2.ZERO)
func click(control:Control)->void:
	await process_frame;var p:=screen(control);await point(p)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=p;event.global_position=p;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func button(parent:Node,label:String)->Button:
	for node in parent.find_children("*","Button",true,false):
		if node.text==label:return node
	return null
func run()->void:
	root.size=Vector2i(1160,720);root.gui_embed_subwindows=true
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"))
	var path:=OUT+"journal_window_%d.json"%Time.get_ticks_usec();A.write(path,data)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();await process_frame
	var permanent:Dictionary=game._character_document().duplicate(true)
	game.laboratory_panel.manage_records_requested.emit();await process_frame;await process_frame;await process_frame
	var ui=game.journal_manager
	var evidence:Array=game._journal_evidence_ids();var keep_id:Variant
	for i in range(ui.list.item_count-1,-1,-1):
		var candidate=ui.list.get_item_metadata(i)
		if not J.has_id(evidence,candidate):ui.list.select(i);keep_id=candidate;break
	await click(button(ui,"선택 보존"))
	check(not J.has_id(game.journal.eligible_ids([keep_id],evidence),keep_id),"Actual preservation button excludes the selected old observation from deletion")
	await click(button(ui,"전체 선택 · 비보존"))
	check(not J.has_id(ui.selected_ids(),keep_id) and not ui.selected_ids().is_empty(),"Actual Select All excludes user-preserved and research-evidence rows")
	var before:Dictionary=game.journal.to_data().duplicate(true)
	await click(button(ui,"선택 기록 삭제"));check(ui.confirm.visible,"Selected deletion opens a real confirmation dialog")
	await click(ui.confirm.get_cancel_button());check(game.journal.to_data()==before,"Cancelling deletion leaves every observation intact")
	await click(button(ui,"최근 10개 정책 · 정리 미리보기"))
	check(ui.retention_confirm.visible and FileAccess.file_exists(path+".journal_retention.bak"),"Real retention preview appears only after an original-file backup")
	await shot("journal_retention_preview")
	await click(ui.retention_confirm.get_cancel_button());check(game.journal.to_data()==before,"Cancelling retention allows further preservation selection with no pruning")
	await click(button(ui,"최근 10개 정책 · 정리 미리보기"));await click(ui.retention_confirm.get_ok_button())
	check(not game.journal.retention_pending() and game.journal.trim_preview(game._journal_evidence_ids()).remove.is_empty(),"Actual approval keeps ten ordinary records plus preserved evidence")
	for field in ["chant","research","learned","spell_discoveries"]:check(H.equal(game._character_document()[field],permanent[field]),"Real journal cleanup preserves "+field)
	await shot("journal_retained")
	ui.hide()
	game.laboratory_panel.prototype_requested.emit();await process_frame;check(game.prototype_confirmation.visible and not game.prototype_enabled,"Normal player sees an explicit, still-unapproved grammar transition")
	await click(game.prototype_confirmation.get_cancel_button());check(not game.prototype_enabled and game.chant_profile.to_data()==data.chant,"Cancel keeps the actual original personal chant mapping")
	game.laboratory_panel.prototype_requested.emit();await process_frame;await click(game.prototype_confirmation.get_ok_button())
	check(game.prototype_enabled and game._active_profile().version()==2 and game.chant_profile.to_data()==data.chant,"Actual confirmation uses a separate personal table; original mapping is never overwritten")
	game.laboratory_panel.arena.set_process(false);game.laboratory_panel.show_trial();game.player_mana=game._max_mana();game.mana_debt=0
	var events:=E.inputs(game.prototype_profile,E.CONFIG.spells[4].actions)
	await point(game.laboratory_panel.arena.world_to_screen(Vector2(490,210)));await key(KEY_SHIFT,true)
	for event in events:await tap(OS.find_keycode_from_string(event.key))
	await key(KEY_SHIFT,false)
	var known:Dictionary=game.discovered.to_data();var journal:Dictionary=game.journal.to_data();var mapping:Dictionary=game.chant_profile.to_data();game.free()
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and H.equal(known,game.discovered.to_data()) and H.equal(journal,game.journal.to_data()) and H.equal(mapping,game.chant_profile.to_data()),"Real scene restart loads mixed legacy/v8 discoveries, journal snapshots and unchanged original mapping")
	check(not game.prototype_enabled and not game._prototype_all,"Restart defaults to compatibility; test authority and opt-in are session-only")
	game.free();print("PHASE4 QA JOURNAL WINDOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
