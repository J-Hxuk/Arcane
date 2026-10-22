extends SceneTree
## Explicit isolated interactive harness. Never references user:// for saving.
const Fixture=preload("res://tests/formula_world_fixture.gd")
const P=preload("res://scripts/mana_formula_prototypes.gd")
const E=preload("res://scripts/chant_engine_v2.gd")
const R=preload("res://scripts/formal_spell_registry.gd")
var game
var panel:VBoxContainer
var label:Label
func _initialize()->void:call_deferred("run")
func run()->void:
	if not OS.is_debug_build():quit(1);return
	if "--raw-order-residual" in OS.get_cmdline_user_args():E.CONFIG.tuning["order_residual_mode"]="raw"
	root.size=Vector2i(1160,840)
	DirAccess.make_dir_recursive_absolute("res://.task002_artifacts/mana_formula_audit")
	var path:="res://.task002_artifacts/mana_formula_audit/interactive_%d.json"%Time.get_ticks_usec()
	var source:Dictionary=preload("res://tests/test_elemental_combat.gd").fixture("WATER",1787453028)
	if FileAccess.file_exists("res://.task002_artifacts/mana_formula_audit/user_before.json"):source=JSON.parse_string(FileAccess.get_file_as_string("res://.task002_artifacts/mana_formula_audit/user_before.json"))
	preload("res://tests/test_awakening.gd").write(path,source)
	game=Fixture.new();game.save_path=path;root.add_child(game)
	game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.show_trial()
	var layer:=CanvasLayer.new();layer.layer=50;root.add_child(layer)
	panel=VBoxContainer.new();panel.position=Vector2(16,720);panel.size=Vector2(1120,110);layer.add_child(panel)
	label=Label.new();label.text="수식 시험 전용 저장 복사본 · 정식 주문 아님 · 버튼은 영창 입력만 준비합니다. LMB로 방출 / Shift로 직접 입력 가능"
	panel.add_child(label)
	var buttons:=HBoxContainer.new();panel.add_child(buttons)
	for row in P.DATA.spells:
		for active in [false,true]:
			var button:=Button.new();button.text=row.source_id+(" 현상 ON" if active else " 현상 OFF");buttons.add_child(button)
			button.pressed.connect(func():prepare(row,active))
	var switch:=Button.new();switch.text="연구실 / 보스 시험장";buttons.add_child(switch);switch.pressed.connect(toggle_arena)
	if "--smoke" in OS.get_cmdline_user_args():
		prepare(P.DATA.spells[0],true);await process_frame
		var success:bool=game._inspect_chant(true).get("spell")!=null and game.save_path.begins_with("res://.task002_artifacts/")
		print("FORMULA PREVIEW: %d checks, %d failures"%[2,0 if success else 1]);game.queue_free();await process_frame;quit(0 if success else 1)
func prepare(row:Dictionary,active:bool)->void:
	var options:Array=[]
	for order in R.permutations(row.actions):
		var result:=E.resolve(game._active_profile(),E.inputs(game._active_profile(),order),game._prototype_context())
		if result.get("spell")!=null:options.append({"order":order,"strength":result.spell.formula_effect.strength})
	options.sort_custom(func(a,b):return a.strength<b.strength)
	if options.is_empty():return
	var choice:Dictionary=options.back() if active else options.front()
	game._reset_combat_input();game._clear_chant()
	game.chant_inputs=E.inputs(game._active_profile(),choice.order);game.runes.assign(game.chant_inputs.map(func(event):return event.key))
	for event in game.chant_inputs:event.released=true
	game.combat_input._set_mode(game.CombatInput.Mode.FOCUS_CAST)
	game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
	label.text=row.name+" / "+" → ".join(game.runes)+" / 준비만 완료 · 시험장에 조준하고 LMB 방출 · 실제 저장은 변경하지 않음"
	game._update_laboratory_live();root.gui_release_focus()
func toggle_arena()->void:
	game._reset_combat_input()
	if game.game_state=="LAB":
		game._leave_laboratory();game.player_pos=Vector2(3200,910);game._start_guardian()
	else:
		game.guardian.stop();game.game_state="HUB";game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.show_trial()
