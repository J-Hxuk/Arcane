extends CanvasLayer
## Public view renders sensory evidence only. Mapping debug requires a CLI flag.
signal release_requested
signal exit_requested
signal recover_requested
signal note_requested(id: int, value: String)
signal manage_records_requested
signal first_word_requested
signal prototype_requested
signal movement_research_requested
const Journal = preload("res://scripts/experiment_journal.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const AwakeningPanel = preload("res://scripts/awakening_panel.gd")
const OrbView = preload("res://scripts/mana_orb_view.gd")
const VisualModel = preload("res://scripts/mana_visual_model.gd")
const Arena = preload("res://scripts/laboratory_arena.gd")
var journal: Journal
var profile: Profile
var panel: PanelContainer
var live: Label
var message: Label
var selectors: Array[OptionButton] = []
var steppers: Array[SpinBox] = []
var views: Array[TextEdit] = []
var back_buttons: Array[Button] = []
var next_buttons: Array[Button] = []
var note: LineEdit
var release_button: Button
var exit_button: Button
var recover_button: Button
var save_note_button: Button
var debug_window: Window
var debug_view: TextEdit
var awakening_panel: AwakeningPanel
var research_button: Button
var live_orb: OrbView
var before_orbs: Array[OrbView] = []
var after_orbs: Array[OrbView] = []
var play_buttons: Array[Button] = []
var timelines: Array[HSlider] = []
var time_labels: Array[Label] = []
var playing := [false, false]
var playheads := [0.0, 0.0]
var selected_records: Array[Dictionary] = [{}, {}]
var _note_record_id := -1
var trial_panel: PanelContainer
var arena: Arena
var trial_banner: Label
var trial_commands: Label
var trial_button: Button
var journal_button: Button
var trial_release_button: Button
var observation_lens: CheckButton
var observation_hint: Label
var coach: VBoxContainer
var preview_label:Label
var detailed_observation:CheckButton
var discovery_notice:PanelContainer
var discovery_text:Label
var notice_seconds:=0.0
var formal_rules:=false
var archive_columns:Array[Control]=[]
var comparison_hint:Label
var observation_target:OptionButton
var equipment_pickers:Array=[]
var lens_readout:Label
var lens_trial_readout:Label
var lens_trial_toggle:CheckButton
var lens_caption:Label
var lens_trial_caption:Label
var _lens_keys:Array=[]
var _caption_seconds:=0.0
var numeric_observation: CheckButton
var numeric_view: VBoxContainer
var observation_heading: Label
var _observation_latest: Dictionary = {}
var _observation_active := false

func setup(model: Journal, mapping: Profile,formal:=false) -> void:
	formal_rules=formal
	journal = model
	profile = mapping
	layer = 20
	panel = PanelContainer.new()
	panel.position = Vector2(25, 100)
	panel.size = Vector2(1110, 586)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1110, 586)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var toolbar := HBoxContainer.new()
	content.add_child(toolbar)
	var title := Label.new()
	title.text = "연구실 · 직접 영창 / 자동 실험 기록"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	trial_button = _button(toolbar, "실험실 · 직접 조작", show_trial)
	_button(toolbar, "기록 관리", func(): manage_records_requested.emit())
	if not formal_rules:_button(toolbar,"영창 시제품 전환",func():prototype_requested.emit())
	research_button = _button(toolbar, "단서 / 개화", func(): awakening_panel.open())
	release_button = _button(toolbar, "방출 / 기록", func(): release_requested.emit())
	release_button.hide() # Compatibility API only; normal release is Shift-up / focus LMB.
	recover_button = _button(toolbar, "회복", func(): recover_requested.emit())
	exit_button = _button(toolbar, "나가기", func(): exit_requested.emit())
	var help := Label.new()
	help.text = "연구실: 관측·일지 비교 / 실험실: RMB 이동·독립 조준·Shift 해제 방출·초집중 LMB / Space 취소·해제"
	content.add_child(help)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	content.add_child(body)
	var live_column := VBoxContainer.new()
	live_column.custom_minimum_size.x = 280
	body.add_child(live_column)
	coach = preload("res://scripts/research_coach.gd").new(); live_column.add_child(coach)
	var live_title := Label.new()
	live_title.text = "실시간 마나 관측"
	live_column.add_child(live_title)
	live_orb = OrbView.new()
	live_orb.custom_minimum_size = Vector2(280, 90)
	live_column.add_child(live_orb)
	live = Label.new()
	live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live.max_lines_visible = 4
	live.custom_minimum_size = Vector2(280, 62)
	live_column.add_child(live)
	preview_label=Label.new();preview_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preview_label.custom_minimum_size=Vector2(280,90);preview_label.add_theme_font_size_override("font_size",12);live_column.add_child(preview_label)
	observation_lens = CheckButton.new()
	observation_lens.text = "관측 렌즈 · 흔적 강조"
	observation_lens.focus_mode = Control.FOCUS_NONE
	observation_lens.toggled.connect(_lens_changed)
	live_column.add_child(observation_lens)
	_button(live_column, "스승의 기초 교육 · 다음 설명", func(): first_word_requested.emit())
	detailed_observation=CheckButton.new();detailed_observation.text="발견 주문 상세 관측";detailed_observation.focus_mode=Control.FOCUS_NONE;live_column.add_child(detailed_observation)
	detailed_observation.toggled.connect(func(_enabled):_render())
	discovery_notice=PanelContainer.new();discovery_notice.position=Vector2(260,12);discovery_notice.size=Vector2(850,82);add_child(discovery_notice)
	discovery_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	discovery_text=Label.new();discovery_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;discovery_text.custom_minimum_size=Vector2(810,78);discovery_text.add_theme_font_size_override("font_size",23);discovery_text.add_theme_color_override("font_color",Color("fff4cc"));discovery_notice.add_child(discovery_text);discovery_notice.hide()
	observation_hint = Label.new()
	observation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	observation_hint.custom_minimum_size = Vector2(280, 18)
	live_column.add_child(observation_hint)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	for side in range(2):
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 390
		column.add_theme_constant_override("separation", 5)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var selector := OptionButton.new()
		selector.clip_text = true
		selector.item_selected.connect(_record_selected.bind(side))
		column.add_child(selector)
		selectors.append(selector)
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.text = "단계"
		row.add_child(label)
		var stepper := SpinBox.new()
		stepper.min_value = 1
		stepper.max_value = 1
		stepper.value = 1
		stepper.value_changed.connect(_step_selected.bind(side))
		row.add_child(stepper)
		steppers.append(stepper)
		back_buttons.append(_button(row, "이전", func(): stepper.value -= 1))
		next_buttons.append(_button(row, "다음", func(): stepper.value += 1))
		var transport := HBoxContainer.new()
		column.add_child(transport)
		play_buttons.append(_button(transport, "재생", _toggle_play.bind(side)))
		var timeline := HSlider.new()
		timeline.custom_minimum_size.x = 150
		timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		timeline.step = 1.0
		timeline.focus_mode = Control.FOCUS_NONE
		timeline.value_changed.connect(_seek.bind(side))
		transport.add_child(timeline)
		timelines.append(timeline)
		var time_label := Label.new()
		time_label.custom_minimum_size.x = 102
		transport.add_child(time_label)
		time_labels.append(time_label)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		column.add_child(pair)
		for moment in ["입력 전", "입력 후"]:
			var cell := VBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(cell)
			var caption := Label.new()
			caption.text = moment
			cell.add_child(caption)
			var orb := OrbView.new()
			orb.custom_minimum_size = Vector2(190, 136)
			cell.add_child(orb)
			if moment == "입력 전": before_orbs.append(orb)
			else: after_orbs.append(orb)
		var view := TextEdit.new()
		view.editable = false
		view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		view.custom_minimum_size = Vector2(390, 110)
		view.add_theme_font_size_override("font_size", 12)
		view.add_theme_color_override("font_readonly_color", Color("dbe5f2"))
		column.add_child(view)
		views.append(view)
	var notes := HBoxContainer.new()
	content.add_child(notes)
	note = LineEdit.new()
	note.placeholder_text = "왼쪽 실험에 대한 내 가설 / 메모 (최대 2000자)"
	note.max_length = 2000
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_child(note)
	# Main pauses casting while an editable control owns keyboard focus.
	note.focus_entered.connect(func(): get_viewport().set_input_as_handled())
	save_note_button = _button(notes, "메모 저장", _request_note)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 32
	message.text = "실험·실패·취소는 자동 기록됩니다. 재생과 비교는 마나·슬롯을 바꾸지 않습니다."
	content.add_child(message)
	_setup_trial()
	panel.hide()
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--chant-debug"):
		debug_window = Window.new()
		debug_window.visible = false
		debug_window.title = "DEVELOPER ONLY · Chant internals"
		debug_window.size = Vector2i(750, 500)
		debug_view = TextEdit.new()
		debug_view.editable = false
		debug_window.add_child(debug_view)
		debug_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		debug_window.close_requested.connect(debug_window.hide)
		add_child(debug_window)
	refresh()
	if formal_rules:_formal_layout()

func _setup_trial() -> void:
	trial_panel = PanelContainer.new()
	trial_panel.position = panel.position
	trial_panel.size = panel.size
	add_child(trial_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
	trial_panel.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var bar := HBoxContainer.new()
	content.add_child(bar)
	journal_button = _button(bar, "관측 / 실험 일지", show_journal)
	if not formal_rules:_button(bar,"영창 시제품 전환",func():prototype_requested.emit())
	_button(bar, "단서 / 개화", func(): awakening_panel.open())
	trial_release_button = _button(bar, "직접 방출 / 기록", func(): release_requested.emit())
	trial_release_button.hide()
	if not formal_rules:_button(bar, "회복 / 표적 초기화", func(): recover_requested.emit())
	else:_button(bar,"표적 초기화",func():arena.reset_targets())
	_button(bar, "표적 이동 전환", func(): arena.moving_targets = not arena.moving_targets)
	_button(bar, "나가기", func(): exit_requested.emit())
	if formal_rules:
		lens_trial_toggle=CheckButton.new();lens_trial_toggle.text="관측렌즈";lens_trial_toggle.focus_mode=Control.FOCUS_NONE;bar.add_child(lens_trial_toggle);lens_trial_toggle.toggled.connect(_lens_changed)
		_add_equipment_row(content)
	trial_banner = Label.new()
	trial_banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	trial_banner.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	trial_banner.custom_minimum_size.y = 42
	trial_banner.add_theme_font_size_override("font_size", 23)
	trial_banner.text = "Shift로 영창하고 놓으면 자동으로 방출합니다."
	content.add_child(trial_banner)
	trial_commands = Label.new()
	trial_commands.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trial_commands.custom_minimum_size = Vector2(1090, 92)
	trial_commands.add_theme_font_size_override("font_size",12)
	trial_commands.max_lines_visible=6
	content.add_child(trial_commands)
	if formal_rules:
		lens_trial_readout=Label.new();lens_trial_readout.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lens_trial_readout.custom_minimum_size=Vector2(1000,0);lens_trial_readout.max_lines_visible=2;content.add_child(lens_trial_readout);lens_trial_readout.hide()
		lens_trial_caption=Label.new();lens_trial_caption.add_theme_font_size_override("font_size",20);content.add_child(lens_trial_caption);lens_trial_caption.hide()
	arena = Arena.new()
	arena.custom_minimum_size = Vector2(1090, 330)
	if formal_rules:arena.custom_minimum_size.y=300
	content.add_child(arena)
	var hint := Label.new()
	hint.text = "위쪽 촉매는 가까이서 E로 환경 단서를 얻습니다. 안정성·피해 보너스는 없습니다. 실제 발현 뒤 이름과 표적 반응을 확인하세요."
	if formal_rules:hint.text="안정된 공명을 만든 뒤 같은 촉매에 접촉하세요. 식물·불꽃·광석·물결이 실제 마나에 반응합니다."
	content.add_child(hint)
	trial_panel.hide()

func show_trial(cancel_inputs := true) -> void:
	if cancel_inputs and arena.controller != null: arena.controller._reset_combat_input()
	panel.hide()
	trial_panel.show()
	refresh_equipment()
	if arena.controller!=null and arena.controller.spell_record_hud!=null:
		arena.controller.spell_record_hud.layer=27
		arena.controller.spell_record_hud.show()
	get_viewport().gui_release_focus()

func show_journal() -> void:
	if arena.controller != null: arena.controller._reset_combat_input()
	if arena.controller!=null and arena.controller.spell_record_hud!=null:arena.controller.spell_record_hud.hide()
	trial_panel.hide()
	panel.show()
	get_viewport().gui_release_focus()

func show_manifestation(name: String, recorded := true) -> void:
	trial_banner.text = "발현 성공 · " + name + ("  /  발견 영창 기록" if recorded else "  /  기록 저장 실패")
	trial_banner.add_theme_color_override("font_color", Color("a5f2b1"))
	# Discovery never changes the current research/trial screen or replay selection.
	message.text=trial_banner.text
	if formal_rules:
		notice_seconds=0;discovery_notice.hide();return
	discovery_text.text="✦ "+name+" — 마법 발현\n"+preload("res://scripts/research_lore.gd").personality(name)
	discovery_text.modulate=preload("res://scripts/research_lore.gd").color_for_name(name)
	notice_seconds=7.0;discovery_notice.show()

func begin_attempt() -> void:
	trial_banner.text = "직접 영창 중 · Shift를 놓으면 방출·기록합니다."
	message.text = "직접 영창 중 · 관측 구체와 직전 단계를 비교하세요."
	trial_banner.add_theme_color_override("font_color", Color("dbe5f2"))

func show_attempt_result(text: String) -> void:
	trial_banner.text = text
	trial_banner.add_theme_color_override("font_color", Color("ffd18b"))
	message.text = text

func setup_awakening(research) -> void:
	awakening_panel = AwakeningPanel.new()
	add_child(awakening_panel)
	awakening_panel.setup(research)

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open(theme: Theme) -> void:
	if arena.controller!=null and arena.controller.spell_record_hud!=null:arena.controller.spell_record_hud.hide()
	message.text = "실험·실패·취소는 자동 기록됩니다. 관측 구체와 입력 전·후를 비교하세요."
	var lab_theme: Theme = theme.duplicate()
	lab_theme.default_font_size = 13
	panel.theme = lab_theme
	trial_panel.theme = lab_theme
	awakening_panel.theme = lab_theme
	panel.show()
	arena.set_process(true)
	refresh()
	if debug_window != null: debug_window.popup_centered()

func close() -> void:
	_observation_latest={}; _observation_active=false
	if numeric_view!=null: numeric_view.reset()
	notice_seconds=0
	if discovery_notice!=null:discovery_notice.hide()
	playing = [false, false]
	panel.hide()
	trial_panel.hide()
	arena.reset_targets()
	arena.set_process(false)
	awakening_panel.close()
	awakening_panel.cancel_confirmation()
	if debug_window != null: debug_window.hide()

func is_editing() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit or focused is SpinBox

func reset_record_selection() -> void:
	_observation_latest={}; _observation_active=false
	if numeric_view!=null: numeric_view.reset()
	# A temporary character may reuse ID 1. Never carry its note into a real record.
	_note_record_id = -2
	note.clear()
	playing = [false, false]
	playheads = [0.0, 0.0]
	selected_records = [{}, {}]
	for stepper in steppers: stepper.set_value_no_signal(1)

func refresh(latest := false,preserve_playback:=false) -> void:
	if not preserve_playback:playing = [false, false]
	var records := journal.records()
	if numeric_view!=null: numeric_view.set_records(records)
	for side in range(2):
		var selected := selectors[side].get_selected_id()
		selectors[side].clear()
		for record in records:
			selectors[side].add_item("#%d · %s" % [record["id"], Journal.title(record)], int(record["id"]))
		if not records.is_empty():
			var index := selectors[side].get_item_index(selected)
			if latest or index < 0: index = maxi(0, records.size() - 1 - side)
			selectors[side].select(index)
	_render()

func _render() -> void:
	var records := journal.records()
	for side in range(2):
		var id := selectors[side].get_selected_id()
		var record: Dictionary = {}
		for candidate in records:
			if candidate["id"] == id: record = candidate
		var previous_id: int = selected_records[side].get("id", -1)
		selected_records[side] = record
		steppers[side].set_block_signals(true)
		steppers[side].max_value = maxi(1, record.get("steps", []).size())
		steppers[side].set_block_signals(false)
		if formal_rules and previous_id!=id:steppers[side].set_value_no_signal(maxi(1,record.get("steps",[]).size()))
		var index := int(steppers[side].value) - 1
		var steps: Array = record.get("steps", [])
		if previous_id != id: playheads[side] = _step_end(steps[index]) if index < steps.size() else 0.0
		else: playheads[side] = minf(playheads[side], _duration(side))
		_display_side(side)
		if side == 0 and _note_record_id != id:
			_note_record_id = id
			note.text = str(record.get("note", ""))
	for column in archive_columns:column.visible=not records.is_empty() and not (numeric_observation!=null and numeric_observation.button_pressed)

func _record_selected(_index: int, side: int) -> void:
	playing[side] = false
	steppers[side].set_value_no_signal(1)
	playheads[side] = 0.0
	_render()

func _step_selected(_value: float, side: int) -> void:
	playing[side] = false
	var steps: Array = selected_records[side].get("steps", [])
	var index := int(steppers[side].value) - 1
	if index < steps.size(): playheads[side] = _step_end(steps[index])
	_display_side(side)

func _step_end(step: Dictionary) -> float:
	return float(step["input"].get("at_ms", 0)) + float(step["input"].get("hold_ms", 0))

func _duration(side: int) -> float:
	var duration := float(selected_records[side].get("result", {}).get("elapsed_ms", 0))
	for step in selected_records[side].get("steps", []): duration = maxf(duration, _step_end(step))
	return maxf(1.0, duration)

func _display_side(side: int) -> void:
	var record := selected_records[side]
	var steps: Array = record.get("steps", [])
	var index := int(steppers[side].value) - 1
	var has_step := index >= 0 and index < steps.size()
	if has_step:
		var step: Dictionary = steps[index]
		# Both cells share the same visual clock: differences come from stored state.
		before_orbs[side].show_snapshot(step["before"], playheads[side] / 1000.0, false, record.get("simulation_context", {}))
		after_orbs[side].show_snapshot(step["after"], playheads[side] / 1000.0, false, record.get("simulation_context", {}))
		views[side].text = _step_text(step, record)
	else:
		before_orbs[side].show_snapshot({})
		after_orbs[side].show_snapshot({})
		views[side].text = "기록된 실험이 없습니다."
	back_buttons[side].disabled = not has_step or index <= 0
	next_buttons[side].disabled = not has_step or index >= steps.size() - 1
	play_buttons[side].disabled = not has_step
	play_buttons[side].text = "일시정지" if playing[side] else "재생"
	timelines[side].set_block_signals(true)
	timelines[side].max_value = _duration(side)
	timelines[side].set_value_no_signal(playheads[side])
	timelines[side].set_block_signals(false)
	time_labels[side].text = "%.1f / %.1f초" % [playheads[side] / 1000.0, _duration(side) / 1000.0]

func _toggle_play(side: int) -> void:
	if selected_records[side].get("steps", []).is_empty(): return
	if playheads[side] >= _duration(side): playheads[side] = 0.0
	playing[side] = not playing[side]
	_update_playhead(side)

func _seek(value: float, side: int) -> void:
	playing[side] = false
	playheads[side] = value
	_update_playhead(side)

func _update_playhead(side: int) -> void:
	var steps: Array = selected_records[side].get("steps", [])
	var index := 0
	for i in steps.size():
		if float(steps[i]["input"].get("at_ms", 0)) <= playheads[side]: index = i
	steppers[side].set_value_no_signal(index + 1)
	_display_side(side)

func advance_playback(delta: float) -> void:
	if not panel.visible or (awakening_panel != null and awakening_panel.visible): return
	for side in 2:
		if not playing[side]: continue
		playheads[side] = minf(_duration(side), playheads[side] + maxf(0.0, delta) * 1000.0)
		if playheads[side] >= _duration(side): playing[side] = false
		_update_playhead(side)

func _process(delta: float) -> void:
	_caption_seconds=maxf(0,_caption_seconds-delta)
	if formal_rules and _caption_seconds==0:
		if lens_caption!=null:lens_caption.text=""
		if lens_trial_caption!=null:lens_trial_caption.text=""
	notice_seconds=maxf(0,notice_seconds-delta)
	if discovery_notice!=null:discovery_notice.visible=(panel.visible or trial_panel.visible) and notice_seconds>0
	advance_playback(delta)

func _step_text(step: Dictionary, record: Dictionary) -> String:
	var input: Dictionary = step["input"]
	var result: Dictionary = record["result"]
	var stage: String = {"ready": "안정 구조", "weak": "약한 징후", "partial": "부분 공명", "unstable": "불안정", "failed": "붕괴", "incomplete": "미완성"}.get(str(result.get("response_stage", "")), "이전 기록")
	if result.has("manifestation"): stage = "전투 발현 · " + preload("res://scripts/spell_names.gd").label(str(result["manifestation"].get("spell_id","")))
	var change := VisualModel.transition(step["before"], step["after"], record.get("simulation_context", {}))
	var version_label := "당시 관측을 보관한 기록입니다.\n" if int(record.get("rules_version", 1)) < 7 else ""
	var actual: Dictionary = result.get("manifestation", {})
	var variant := "\n당시 발현: 피해 %.1f · 지속 %.2f초 · 범위 %.0f · 소모 마나 %.1f" % [actual.get("damage", 0), actual.get("duration", 0), actual.get("range", 0),result.get("energy_spent",0)] if actual.has("damage") and not formal_rules and detailed_observation.button_pressed else ""
	return version_label + "입력: %s · 누른 시점 %d ms · 유지 %d ms\n눈으로 비교: %s\n당시 기록 전: %s\n당시 기록 후: %s\n전체 결과: %s / %s\n경과 %d ms · %s\n메모: %s" % [
		input.get("key", "?"), input.get("at_ms", 0), input.get("hold_ms", 0),
		change["text"],
		step.get("before_observation", "뚜렷한 변화가 관찰되지 않습니다."), step["observation"],
		_outcome_label(result.get("outcome", "")), stage,
		result.get("elapsed_ms", 0), VisualModel.failure_label(result), record.get("note", "")] + variant

func _outcome_label(value: String) -> String:
	return {"released": "현상 유지", "failed": "미완성 / 붕괴", "cancelled": "중단", "insufficient_mana": "마나·정신력 한도", "exhausted": "영창 안정화 중"}.get(value, "기록")

func _request_note() -> void:
	var id := selectors[0].get_selected_id()
	if id >= 0: note_requested.emit(id, note.text)
	get_viewport().gui_release_focus()

func show_live(keys: Array[String], observation: String, mana: float, fatigue: float, debug_state: Dictionary, mode_label := "") -> void:
	if formal_rules:refresh_equipment()
	if formal_rules and observation_target!=null and arena.controller!=null:
		var target:String=arena.controller.research.ritual_target if not arena.controller.research.ritual_target.is_empty() else arena.controller.lab_observation_target
		if arena.controller.movement_research_active:target="__MOVEMENT__"
		for index in observation_target.item_count:
			if observation_target.get_item_metadata(index)==target:observation_target.select(index);break
		observation_target.disabled=not arena.controller.research.ritual_target.is_empty() or arena.controller.movement_research_active or arena.controller._attribute_session_locked()
	coach.update_state(debug_state, keys.size(), debug_state.get("last_change", "아직 입력 없음"), debug_state.get("research_context", {}))
	live_orb.show_snapshot(debug_state, 0.0, true)
	observation_hint.text = VisualModel.observation_hint(debug_state)
	live.text = "%s · 입력: %s\n관찰: %s\n마나 %.1f점 · 영창 안정화 %.1f초" % [mode_label, " > ".join(keys) if not keys.is_empty() else "(없음)", observation, mana, fatigue]
	if formal_rules:
		live.text=("입력: "+" · ".join(keys) if not keys.is_empty() else "마나의 잔상을 관찰합니다.")+"\n"+observation
		var records:=journal.records();var previous:Dictionary={}
		var index:int=records.size()-(2 if keys.is_empty() else 1)
		if index>=0:previous=records[index].result.get("terminal_snapshot",{})
		comparison_hint.text=compare_observations(debug_state,previous)
		_update_lens(keys,debug_state)
	trial_commands.text = live.text
	if debug_state.has("spell_preview"):
		preview_label.text=str(debug_state["spell_preview"]["text"])
		trial_commands.text+="\n"+str(debug_state["spell_preview"]["text"])
	if debug_view != null:
		debug_view.text = JSON.stringify({"profile": profile.to_data(), "mana": debug_state}, "\t")

func _lens_changed(enabled: bool) -> void:
	if formal_rules:
		observation_lens.set_pressed_no_signal(enabled)
		if lens_trial_toggle!=null:lens_trial_toggle.set_pressed_no_signal(enabled)
		for label in [lens_readout,lens_trial_readout,lens_caption,lens_trial_caption]:
			if label!=null:label.visible=enabled
		if not enabled:_caption_seconds=0;_lens_keys=[]
		if arena.controller!=null:arena.controller._update_laboratory_live()
		return
	for orb in [live_orb] + before_orbs + after_orbs:
		orb.observation_gain = 1.45 if enabled else 1.0
		orb.queue_redraw()

func _update_lens(keys:Array,state:Dictionary)->void:
	if observation_lens==null or not observation_lens.button_pressed:return
	var result:=preload("res://scripts/observation_lens.gd").interpret(profile,keys,state,state.get("lens_before",{}))
	var line:String="입력한 조작: "+result.meanings+"\n"+result.reading if not keys.is_empty() else "관측렌즈 · 영창을 입력하면 조작의 뜻과 실제 변화를 읽습니다."
	for label in [lens_readout,lens_trial_readout]:
		if label!=null:label.text=line
	if keys!=_lens_keys:
		_lens_keys=keys.duplicate()
		if not keys.is_empty():
			_caption_seconds=1.4
			for label in [lens_caption,lens_trial_caption]:
				if label!=null:label.text=result.caption

static func compare_observations(current:Dictionary,previous:Dictionary)->String:
	if previous.is_empty():return "관측을 남기면 직전 실험과 응집·흐름·안정·형상을 비교합니다."
	var changes:PackedStringArray=[]
	for field in {"cohesion":["응집",3.0],"flow_strength":["흐름",.06],"stability":["안정",3.0],"form_integrity":["형상 유지",3.0],"energy_loss":["빛의 손실",.2]}:
		var labels:Dictionary={"cohesion":["응집",3.0],"flow_strength":["흐름",.06],"stability":["안정",3.0],"form_integrity":["형상 유지",3.0],"energy_loss":["빛의 손실",.2]}
		var difference:float=float(current.get(field,0))-float(previous.get(field,0))
		if absf(difference)>float(labels[field][1]):changes.append(str(labels[field][0])+(" 증가" if difference>0 else " 감소"))
	return "직전 관측과 비교 · "+(" / ".join(changes) if not changes.is_empty() else "뚜렷한 물성 차이가 작습니다.")

func _formal_layout()->void:
	var old:=panel.get_child(0)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1110,586);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var margin:=MarginContainer.new();margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
	var content:=VBoxContainer.new();margin.add_child(content)
	var toolbar:=HBoxContainer.new();content.add_child(toolbar)
	trial_button.reparent(toolbar);_button(toolbar,"연구 일지",func():manage_records_requested.emit());research_button.reparent(toolbar);exit_button.reparent(toolbar)
	_button(toolbar,"기초 이동술 연구",func():movement_research_requested.emit())
	observation_lens.reparent(toolbar);observation_lens.text="관측렌즈";observation_lens.set_pressed_no_signal(false)
	numeric_observation=CheckButton.new();numeric_observation.text="수치 관측";numeric_observation.focus_mode=Control.FOCUS_NONE;toolbar.add_child(numeric_observation)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",12);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(body)
	var center:=VBoxContainer.new();center.custom_minimum_size.x=560;center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in 2:
		var column:Control=selectors[side].get_parent();column.reparent(body);column.custom_minimum_size=Vector2(230,0);column.size_flags_horizontal=Control.SIZE_FILL;archive_columns.append(column)
		selectors[side].fit_to_longest_item=false;selectors[side].custom_minimum_size.x=210
		if side==0:body.add_child(center)
		views[side].custom_minimum_size=Vector2(220,115);timelines[side].custom_minimum_size.x=60;time_labels[side].custom_minimum_size.x=65;time_labels[side].add_theme_font_size_override("font_size",11)
		for orb in [before_orbs[side],after_orbs[side]]:orb.custom_minimum_size=Vector2(105,130);orb.observation_gain=1.45
	var heading:=Label.new();heading.text="실시간 마나 관측";heading.add_theme_font_size_override("font_size",22);center.add_child(heading)
	observation_heading=heading
	_add_equipment_row(center)
	observation_target=OptionButton.new()
	for element in Profile.OHAENG:observation_target.add_item({"WOOD":"木","FIRE":"火","EARTH":"土","METAL":"金","WATER":"水"}[element]+" · 공명 관측");observation_target.set_item_metadata(observation_target.item_count-1,element)
	observation_target.add_item("중립 · 기초 이동술 연구");observation_target.set_item_metadata(observation_target.item_count-1,"__MOVEMENT__");observation_target.set_item_disabled(observation_target.item_count-1,true)
	observation_target.item_selected.connect(func(i):
		if arena.controller!=null:arena.controller._select_lab_observation(str(observation_target.get_item_metadata(i))))
	center.add_child(observation_target)
	live_orb.reparent(center);live_orb.custom_minimum_size=Vector2(540,230);live_orb.size_flags_vertical=Control.SIZE_EXPAND_FILL;live_orb.observation_gain=1.45
	numeric_view=preload("res://scripts/mana_observation_panel.gd").new();center.add_child(numeric_view)
	live.reparent(center);live.custom_minimum_size=Vector2(500,36);live.max_lines_visible=2;preview_label.reparent(center);preview_label.custom_minimum_size=Vector2(500,32);preview_label.max_lines_visible=2
	lens_readout=Label.new();lens_readout.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lens_readout.custom_minimum_size.x=500;lens_readout.max_lines_visible=3;center.add_child(lens_readout);lens_readout.hide()
	lens_caption=Label.new();lens_caption.add_theme_font_size_override("font_size",20);center.add_child(lens_caption);lens_caption.hide()
	comparison_hint=Label.new();comparison_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;comparison_hint.max_lines_visible=2;comparison_hint.custom_minimum_size=Vector2(500,36);center.add_child(comparison_hint)
	var details_row:=HBoxContainer.new();content.add_child(details_row)
	_button(details_row,"연구 지도 펼치기 / 접기",func():coach.visible=not coach.visible)
	coach.reparent(content);coach.hide();coach.feedback.custom_minimum_size=Vector2(1000,45)
	observation_hint.reparent(content);observation_hint.hide()
	note.get_parent().reparent(content);message.reparent(content)
	detailed_observation.free();detailed_observation=null
	old.queue_free()
	numeric_observation.toggled.connect(_set_numeric_observation)
	numeric_observation.set_pressed_no_signal(true)
	numeric_view.set_records(journal.records());_set_numeric_observation(true)
	get_viewport().size_changed.connect(_resize_formal_layout);call_deferred("_resize_formal_layout")

func _set_numeric_observation(enabled: bool) -> void:
	if numeric_view==null:return
	numeric_view.visible=enabled
	if observation_heading!=null:observation_heading.visible=not enabled
	for control in [live_orb,live,preview_label,comparison_hint]:control.visible=not enabled
	if enabled:numeric_view.set_live(_observation_latest,_observation_active)
	else:numeric_view.clear_live()
	_render()

func observe_simulation(simulation: Dictionary, active: bool) -> void:
	if numeric_view==null:return
	# This is a view of the existing inspection, never another resolve/cast.
	_observation_latest=simulation;_observation_active=active
	if numeric_observation.button_pressed:numeric_view.set_live(simulation,active)

func _resize_formal_layout()->void:
	if not formal_rules:return
	var extent:=get_viewport().get_visible_rect().size
	panel.position=Vector2(25,100);panel.size=Vector2(maxf(1110,extent.x-50),maxf(586,extent.y-134))

func _add_equipment_row(parent:Control)->void:
	var row:=HBoxContainer.new();parent.add_child(row)
	for slot in ["main","auxiliary"]:
		var label:=Label.new();label.text="주속성" if slot=="main" else "보조속성";row.add_child(label)
		var picker:=OptionButton.new();picker.custom_minimum_size.x=150;picker.focus_mode=Control.FOCUS_NONE;row.add_child(picker);equipment_pickers.append({"slot":slot,"picker":picker})
		picker.item_selected.connect(func(index):
			if arena!=null and arena.controller!=null:arena.controller._select_lab_equipment(slot,picker.get_item_metadata(index))
			refresh_equipment())

func refresh_equipment()->void:
	if not formal_rules or arena==null or arena.controller==null:return
	var game=arena.controller;var model=game.research
	var symbols={"WOOD":"木 · 목","FIRE":"火 · 화","EARTH":"土 · 토","METAL":"金 · 금","WATER":"水 · 수"}
	for entry in equipment_pickers:
		var picker:OptionButton=entry.picker
		if picker.get_popup().visible:continue # Keep an open selection menu stable until the player chooses.
		picker.clear();var values:Array=model.slot_candidates(entry.slot)
		if values.is_empty():values=[null]
		var selected=model.main_attribute if entry.slot=="main" else (null if model.auxiliary_attributes.is_empty() else model.auxiliary_attributes[0])
		for value in values:
			picker.add_item(symbols.get(value,"없음" if entry.slot=="auxiliary" else "미개화"));picker.set_item_metadata(picker.item_count-1,value)
			if value==selected:picker.select(picker.item_count-1)
		picker.disabled=game._attribute_session_locked() or game.movement_research_active or not model.ritual_target.is_empty() or not game.save_writable or (entry.slot=="main" and model.awakened_attributes.is_empty())
