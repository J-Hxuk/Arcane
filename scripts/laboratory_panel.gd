extends CanvasLayer
## Public view renders sensory evidence only. Mapping debug requires a CLI flag.
signal release_requested
signal exit_requested
signal recover_requested
signal note_requested(id: int, value: String)
const Journal = preload("res://scripts/experiment_journal.gd")
const Profile = preload("res://scripts/chant_profile.gd")
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

func setup(model: Journal, mapping: Profile) -> void:
	journal = model
	profile = mapping
	layer = 20
	panel = PanelContainer.new()
	panel.position = Vector2(60, 110)
	panel.size = Vector2(1040, 572)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var toolbar := HBoxContainer.new()
	content.add_child(toolbar)
	var title := Label.new()
	title.text = "연구실 · 직접 영창 / 자동 실험 기록"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	release_button = _button(toolbar, "방출 / 기록", func(): release_requested.emit())
	recover_button = _button(toolbar, "회복", func(): recover_requested.emit())
	exit_button = _button(toolbar, "거점으로", func(): exit_requested.emit())
	var help := Label.new()
	help.text = "Shift 유지 / 두 번 → 직접 키 입력 → 방출. WASD는 초집중에서만 영창. RMB / Esc는 취소.\nC: 속성 비의존 시작 · 기존 Q → E 유지 · 키 하나만으로 현상 완성 없음. 잔광·윤곽·떨림을 비교하세요."
	content.add_child(help)
	live = Label.new()
	live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live.custom_minimum_size.y = 54
	content.add_child(live)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	for side in range(2):
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 496
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var selector := OptionButton.new()
		selector.clip_text = true
		selector.item_selected.connect(func(_index): _render())
		column.add_child(selector)
		selectors.append(selector)
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.text = "읽기 전용 단계 재생"
		row.add_child(label)
		var stepper := SpinBox.new()
		stepper.min_value = 1
		stepper.max_value = 1
		stepper.value = 1
		stepper.value_changed.connect(func(_value): _render())
		row.add_child(stepper)
		steppers.append(stepper)
		back_buttons.append(_button(row, "이전", func(): stepper.value -= 1))
		next_buttons.append(_button(row, "다음", func(): stepper.value += 1))
		var view := TextEdit.new()
		view.editable = false
		view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		view.custom_minimum_size = Vector2(496, 230)
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

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open(theme: Theme) -> void:
	var lab_theme: Theme = theme.duplicate()
	lab_theme.default_font_size = 14
	panel.theme = lab_theme
	panel.show()
	refresh()
	if debug_window != null: debug_window.popup_centered()

func close() -> void:
	panel.hide()
	if debug_window != null: debug_window.hide()

func is_editing() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit or focused is SpinBox

func refresh(latest := false) -> void:
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
		steppers[side].set_block_signals(true)
		steppers[side].max_value = maxi(1, record.get("steps", []).size())
		steppers[side].set_block_signals(false)
		var index := int(steppers[side].value) - 1
		var step := journal.replay(id, index)
		views[side].text = "기록된 실험이 없습니다." if step.is_empty() else _step_text(step, record)
		if side == 0: note.text = str(record.get("note", ""))

func _step_text(step: Dictionary, record: Dictionary) -> String:
	var input: Dictionary = step["input"]
	var result: Dictionary = record["result"]
	return "입력: %s · 누른 시점 %d ms · 유지 %d ms\n전: %s\n후: %s\n\n전체 결과: %s\n소모 마나 %.1f · 경과 %d ms · 실패 위치 %d\n메모: %s" % [
		input.get("key", "?"), input.get("at_ms", 0), input.get("hold_ms", 0),
		step.get("before_observation", "뚜렷한 변화가 관찰되지 않습니다."), step["observation"],
		_outcome_label(result.get("outcome", "")), result.get("energy_spent", 0.0),
		result.get("elapsed_ms", 0), result.get("failure_step", 0), record.get("note", "")]

func _outcome_label(value: String) -> String:
	return {"released": "현상 유지", "failed": "미완성 / 붕괴", "cancelled": "중단", "insufficient_mana": "마나 부족", "exhausted": "탈진 중"}.get(value, "기록")

func _request_note() -> void:
	var id := selectors[0].get_selected_id()
	if id >= 0: note_requested.emit(id, note.text)
	get_viewport().gui_release_focus()

func show_live(keys: Array[String], observation: String, mana: float, fatigue: float, debug_state: Dictionary, mode_label := "") -> void:
	live.text = "%s · 입력: %s\n관찰: %s\n마나 %.1f · 탈진 %.1f초" % [mode_label, " > ".join(keys) if not keys.is_empty() else "(없음)", observation, mana, fatigue]
	if debug_view != null:
		debug_view.text = JSON.stringify({"profile": profile.to_data(), "mana": debug_state}, "\t")
