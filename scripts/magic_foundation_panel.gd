extends AcceptDialog
## F2-only, memory-only model inspector. Never equips the combat character.
const Schools = preload("res://scripts/magic_schools.gd")
const Model = preload("res://scripts/magic_attunement.gd")
const Catalog = preload("res://scripts/magic_design_catalog.gd")
var game
var model = Model.new()
var catalog: Dictionary = {}
var school_picker: OptionButton
var sequence: LineEdit
var details: TextEdit
var grant_button: Button
var select_button: Button
var all_button: Button
var reset_button: Button
var probe_button: Button
var _built := false

func open_for(owner_game) -> bool:
	if not OS.is_debug_build() or not owner_game.developer_tools_enabled: return false
	game = owner_game
	if not _built: _build()
	catalog = Catalog.load_file()
	model = Model.new()
	_show_school()
	popup_centered(Vector2i(940, 590))
	return true

func _build() -> void:
	_built = true
	title = "Phase 1 · 신규 20계열 데이터 시험"
	get_ok_button().text = "닫기 · 시험 선택 폐기"
	var column := VBoxContainer.new(); add_child(column)
	var notice := Label.new()
	notice.text = "메모리 전용 · 실제 개화/장착/저장 변경 없음 · 270종은 기획 데이터이며 발현하지 않습니다."
	column.add_child(notice)
	school_picker = OptionButton.new(); school_picker.focus_mode = Control.FOCUS_NONE
	for school in Schools.all():
		school_picker.add_item(school.name + " · " + school.id)
		school_picker.set_item_metadata(school_picker.item_count-1, school.id)
	school_picker.item_selected.connect(func(_i): _show_school())
	column.add_child(school_picker)
	var row := HBoxContainer.new(); column.add_child(row)
	grant_button = _button(row, "선택 계열 시험 해금", func(): _grant_selected(); _refresh())
	select_button = _button(row, "시험 활성 계열 선택", func(): model.select_school(selected_id()); _refresh())
	all_button = _button(row, "20계열 전체 시험 해금", func():
		for school in Schools.all(): model.grant_school(school.id)
		_refresh())
	reset_button = _button(row, "시험 선택 초기화", func(): model = Model.new(); _refresh())
	sequence = LineEdit.new(); sequence.placeholder_text = "조작어를 · 로 구분 (알파벳 키가 아님)"; column.add_child(sequence)
	probe_button = _button(column, "Multiset 기획 ID 검사 · 전투 방출 없음", _probe)
	details = TextEdit.new(); details.editable = false; details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.custom_minimum_size = Vector2(900, 365); details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(details)
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
			game._toggle_developer_menu(); set_input_as_handled())
	visibility_changed.connect(func():
		if not visible: model = Model.new())

func _button(parent: Control, label: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = label; button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback); parent.add_child(button); return button

func selected_id() -> String:
	return str(school_picker.get_item_metadata(school_picker.selected))

func _grant_selected() -> void:
	var school := Schools.find(selected_id())
	if school.world_system == "WEST":
		for element in school.elements: model.grant_school("WEST_" + str(element))
	model.grant_school(school.id)

func _show_school() -> void:
	sequence.text = ""
	for row in catalog.get("rows", []):
		if row.school_id == selected_id(): sequence.text = row.chant_multiset; break
	_refresh()

func _refresh() -> void:
	var school := Schools.find(selected_id())
	var lines := PackedStringArray(["계열 " + selected_id(), "원소 " + str(school.elements) + " · 기질 " + str(school.nature)])
	lines.append("카탈로그 검사: " + ("정상" if catalog.get("ok", false) else str(catalog.get("errors", []))))
	lines.append("시험 자격/오행별 음양 선택: " + JSON.stringify(model.to_data()))
	lines.append("기존 5오행 전투 경로 유지 · 신규 계열 계수/전투 정의 없음 · MP/피해는 시험 설계값")
	for row in catalog.get("rows", []):
		if row.school_id == selected_id(): lines.append(row.spell_id + " · " + row.name_en + " · " + row.chant_multiset + " · " + row.design_approval_status)
	details.text = "\n".join(lines)

func _probe() -> Dictionary:
	var result := Catalog.identify(catalog, selected_id(), Catalog.actions(sequence.text), model.context())
	_refresh(); details.text += "\n\n검사 결과: " + JSON.stringify(result)
	return result
