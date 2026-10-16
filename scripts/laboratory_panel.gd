extends CanvasLayer
## Public view renders sensory evidence only. Mapping debug requires a CLI flag.
signal release_requested
signal exit_requested
signal recover_requested
signal note_requested(id: int, value: String)
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

func setup(model: Journal, mapping: Profile) -> void:
	journal = model
	profile = mapping
	layer = 20
	panel = PanelContainer.new()
	panel.position = Vector2(25, 100)
	panel.size = Vector2(1110, 586)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var toolbar := HBoxContainer.new()
	content.add_child(toolbar)
	var title := Label.new()
	title.text = "연구실 · 직접 영창 / 자동 실험 기록"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	trial_button = _button(toolbar, "시험장", show_trial)
	research_button = _button(toolbar, "단서 / 개화", func(): awakening_panel.open())
	release_button = _button(toolbar, "방출 / 기록", func(): release_requested.emit())
	recover_button = _button(toolbar, "회복", func(): recover_requested.emit())
	exit_button = _button(toolbar, "거점으로", func(): exit_requested.emit())
	var help := Label.new()
	help.text = "Shift 유지 / 두 번 → 직접 영창 → 방출 · 첫 선언만으로는 정답이 드러나지 않습니다. 입력 전·후의 크기와 움직임을 비교하세요."
	content.add_child(help)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	content.add_child(body)
	var live_column := VBoxContainer.new()
	live_column.custom_minimum_size.x = 280
	body.add_child(live_column)
	var live_title := Label.new()
	live_title.text = "실시간 마나 관측"
	live_column.add_child(live_title)
	live_orb = OrbView.new()
	live_orb.custom_minimum_size = Vector2(280, 220)
	live_column.add_child(live_orb)
	live = Label.new()
	live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live.max_lines_visible = 7
	live.custom_minimum_size = Vector2(280, 104)
	live_column.add_child(live)
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
	_button(bar, "단서 / 개화", func(): awakening_panel.open())
	trial_release_button = _button(bar, "직접 방출 / 기록", func(): release_requested.emit())
	_button(bar, "회복 / 표적 초기화", func(): recover_requested.emit())
	_button(bar, "표적 이동 전환", func(): arena.moving_targets = not arena.moving_targets)
	_button(bar, "거점으로", func(): exit_requested.emit())
	trial_banner = Label.new()
	trial_banner.custom_minimum_size.y = 42
	trial_banner.add_theme_font_size_override("font_size", 23)
	trial_banner.text = "직접 영창으로 마법을 완성하고 방출하세요."
	content.add_child(trial_banner)
	trial_commands = Label.new()
	trial_commands.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trial_commands.custom_minimum_size = Vector2(1090, 55)
	content.add_child(trial_commands)
	arena = Arena.new()
	arena.custom_minimum_size = Vector2(1090, 365)
	content.add_child(arena)
	var hint := Label.new()
	hint.text = "완전 발현은 이름과 실제 표적 반응으로 확인합니다. 공명만 성공한 경우에는 관측 구체와 기록을 확인하세요."
	content.add_child(hint)
	trial_panel.hide()

func show_trial() -> void:
	panel.hide()
	trial_panel.show()
	get_viewport().gui_release_focus()

func show_journal() -> void:
	trial_panel.hide()
	panel.show()
	get_viewport().gui_release_focus()

func show_manifestation(name: String, recorded := true) -> void:
	trial_banner.text = "발현 성공 · " + name + ("  /  발견 영창 기록" if recorded else "  /  기록 저장 실패")
	trial_banner.add_theme_color_override("font_color", Color("a5f2b1"))
	show_trial()

func begin_attempt() -> void:
	trial_banner.text = "직접 영창 중 · 최종 구조를 완성한 뒤 방출하세요."
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

func refresh(latest := false) -> void:
	playing = [false, false]
	var records := journal.records()
	for side in range(2):
		var selected := selectors[side].get_selected_id()
		selectors[side].clear()
		for record in records:
			selectors[side].add_item("실험 #%d · %s" % [record["id"], _outcome_label(record["result"].get("outcome", ""))], int(record["id"]))
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
		var index := int(steppers[side].value) - 1
		var steps: Array = record.get("steps", [])
		if previous_id != id: playheads[side] = _step_end(steps[index]) if index < steps.size() else 0.0
		else: playheads[side] = minf(playheads[side], _duration(side))
		_display_side(side)
		if side == 0 and _note_record_id != id:
			_note_record_id = id
			note.text = str(record.get("note", ""))

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
		before_orbs[side].show_snapshot(step["before"], playheads[side] / 1000.0)
		after_orbs[side].show_snapshot(step["after"], playheads[side] / 1000.0)
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
	advance_playback(delta)

func _step_text(step: Dictionary, record: Dictionary) -> String:
	var input: Dictionary = step["input"]
	var result: Dictionary = record["result"]
	var stage: String = {"ready": "안정 구조", "weak": "약한 징후", "partial": "부분 공명", "unstable": "불안정", "failed": "붕괴", "incomplete": "미완성"}.get(str(result.get("response_stage", "")), "이전 기록")
	if result.has("manifestation"): stage = "전투 발현 · " + str(result["manifestation"].get("name", ""))
	var change := VisualModel.transition(step["before"], step["after"])
	return "입력: %s · 누른 시점 %d ms · 유지 %d ms\n눈으로 비교: %s\n당시 기록 전: %s\n당시 기록 후: %s\n전체 결과: %s / %s\n소모 마나 %.1f · 경과 %d ms · %s\n메모: %s" % [
		input.get("key", "?"), input.get("at_ms", 0), input.get("hold_ms", 0),
		change["text"],
		step.get("before_observation", "뚜렷한 변화가 관찰되지 않습니다."), step["observation"],
		_outcome_label(result.get("outcome", "")), stage, result.get("energy_spent", 0.0),
		result.get("elapsed_ms", 0), VisualModel.failure_label(result), record.get("note", "")]

func _outcome_label(value: String) -> String:
	return {"released": "현상 유지", "failed": "미완성 / 붕괴", "cancelled": "중단", "insufficient_mana": "마나 부족", "exhausted": "탈진 중"}.get(value, "기록")

func _request_note() -> void:
	var id := selectors[0].get_selected_id()
	if id >= 0: note_requested.emit(id, note.text)
	get_viewport().gui_release_focus()

func show_live(keys: Array[String], observation: String, mana: float, fatigue: float, debug_state: Dictionary, mode_label := "") -> void:
	live_orb.show_snapshot(debug_state, 0.0, true)
	live.text = "%s · 입력: %s\n관찰: %s\n마나 %.1f · 탈진 %.1f초" % [mode_label, " > ".join(keys) if not keys.is_empty() else "(없음)", observation, mana, fatigue]
	trial_commands.text = live.text
	if debug_view != null:
		debug_view.text = JSON.stringify({"profile": profile.to_data(), "mana": debug_state}, "\t")
