extends PanelContainer
## Books/mentor explain observable principles, never a personal key answer table.
signal clue_requested(element: String, source: String)
signal ritual_requested(element: String)
signal ritual_cancelled
signal confirmation_requested(element: String, ticket: int)
const Research = preload("res://scripts/character_research.gd")
const Elements = preload("res://scripts/base_elements.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
var research: Research
var target: OptionButton
var status: Label
var progress: Label
var journal_view: TextEdit
var book_button: Button
var mentor_button: Button
var ritual_button: Button
var cancel_button: Button
var back_button: Button
var confirmation: ConfirmationDialog
var _element := ""
var _ticket := 0

func setup(model: Research) -> void:
	research = model
	position = Vector2(60, 110)
	size = Vector2(1040, 572)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := Label.new()
	title.text = "서고와 스승 · 단서 수집 / 최초 개화"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	back_button = _button(bar, "자유 실험으로", close)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 65
	column.add_child(status)
	var choices := HBoxContainer.new()
	column.add_child(choices)
	target = OptionButton.new()
	target.custom_minimum_size.x = 220
	for element in Elements.DEFINITIONS:
		target.add_item(Elements.DEFINITIONS[element].display_name)
		target.set_item_metadata(target.item_count - 1, element)
	target.item_selected.connect(func(_index): refresh())
	choices.add_child(target)
	book_button = _button(choices, "마법서적 열람", func(): clue_requested.emit(selected_element(), "book"))
	mentor_button = _button(choices, "스승에게 질문", func(): clue_requested.emit(selected_element(), "mentor"))
	progress = Label.new()
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress.custom_minimum_size.y = 68
	column.add_child(progress)
	journal_view = TextEdit.new()
	journal_view.editable = false
	journal_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	journal_view.custom_minimum_size = Vector2(990, 245)
	journal_view.add_theme_color_override("font_readonly_color", Color("dbe5f2"))
	column.add_child(journal_view)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	ritual_button = _button(actions, "개화 의식 시작 (직접 영창)", func(): ritual_requested.emit(selected_element()))
	cancel_button = _button(actions, "의식 중단 / 확인 취소", func(): cancel_confirmation(); ritual_cancelled.emit())
	confirmation = ConfirmationDialog.new()
	confirmation.title = "최초 주속성 · 영구 확정 확인"
	confirmation.ok_button_text = "주속성 영구 확정"
	confirmation.cancel_button_text = "취소하고 더 탐구"
	confirmation.exclusive = true
	confirmation.confirmed.connect(_confirm)
	confirmation.canceled.connect(_cancel)
	confirmation.close_requested.connect(_cancel)
	add_child(confirmation)
	hide()
	refresh()

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func selected_element() -> String:
	return str(target.get_item_metadata(target.selected))

func open() -> void:
	refresh()
	show()

func close() -> void:
	hide()
	get_viewport().gui_release_focus()

func refresh() -> void:
	var element := selected_element()
	var main = research.main_attribute
	status.text = "주속성: " + ("미개화" if main == null else Elements.DEFINITIONS[main].display_name) + " · 영구 연구 %d / 3\n" % research.researched_base_elements.size()
	status.text += "서적과 스승의 단서 → 같은 속성의 안정 공명 2회 재현 → 의식에서 형상과 방향까지 직접 완성 → 영구 확인."
	if not research.legacy_committed_attributes.is_empty():
		status.text += "\n기존 확정 슬롯은 보존 중입니다. 주속성을 임의 배정하지 않았습니다. 가득 찼다면 기존 속성을 의식으로 지정하세요."
	var eligible := research.ritual_eligibility(element)
	progress.text = "선택 대상: %s · 서적 %s / 스승 %s · 안정 재현 %d / 2\n%s" % [
		Elements.DEFINITIONS[element].display_name, "획득" if research.has_clue(element, "book") else "미획득",
		"획득" if research.has_clue(element, "mentor") else "미획득", research.stable_count(element), reason(eligible)]
	ritual_button.disabled = eligible != "available"
	cancel_button.disabled = research.ritual_target.is_empty()
	var text := "연구 일지 · 수집한 서적 / 스승 / 관찰 단서\n\n"
	for clue in research.research_clues:
		if not clue is Dictionary: continue
		var observed_element := str(clue.get("element", ""))
		var source := str(clue.get("source", ""))
		if not Elements.DEFINITIONS.has(observed_element): continue
		text += "%s · %s\n" % [Elements.DEFINITIONS[observed_element].display_name, {"book": "서적", "mentor": "스승", "observation": "관찰"}.get(source, "이전 기록")]
		text += (Rules.clue_text(observed_element, source) if source in ["book", "mentor"] else "직접 실험에서 얻은 관찰. 단계 기록과 비교해 다시 재현해 보세요.") + "\n\n"
		if source == "observation":
			var ids: Array = research.resonance_discoveries.get(observed_element, {}).get("stable_experiment_ids", [])
			text += "안정 공명 실험 번호: " + ", ".join(ids.map(func(id): return "#%d" % id)) + "\n\n"
	journal_view.text = text

static func reason(state: String) -> String:
	return {"available": "의식 준비 완료. 성공 뒤 확인하기 전에는 슬롯이 바뀌지 않습니다.",
		"clues_required": "선택 속성의 마법서적과 스승 단서를 모두 모으세요.",
		"stable_reproduction_required": "자유 실험에서 안정 공명을 2회 방출·기록하세요. 중단/불안정은 재현에 포함되지 않습니다.",
		"main_already_confirmed": "주속성은 이미 영구 확정되었습니다. 보조속성 획득은 다음 단계입니다.",
		"slots_full": "기존 영구 슬롯이 가득 찼습니다. 기존 확정 속성 중 하나를 선택하세요.",
		"ritual_structure_required": "공명은 맞지만 의식의 형상/방향이 부족합니다. 형상을 잇고 한 방향으로 흐르게 한 뒤 안정화하세요.",
		"target_resonance_required": "목표와 같은 안정 공명을 완성해야 합니다. 실험의 관찰과 준비 조건을 비교하세요.",
		"save_failed": "저장 실패로 확정하지 않았습니다. 저장 경로를 확인한 뒤 의식을 다시 수행하세요."}.get(state, state)

func offer(result: Dictionary) -> void:
	_element = result["element"]
	_ticket = result["ticket"]
	confirmation.theme = theme
	var promotion := research.legacy_committed_attributes.has(_element)
	confirmation.dialog_text = "%s 의식을 완성했습니다.\n이 속성을 주속성으로 영구 확정하겠습니까?\n취소·교체·두 번째 주속성 선택은 불가능합니다.\n%s\n취소하면 슬롯 변경 없이 다른 속성 탐구를 계속할 수 있습니다." % [
		Elements.DEFINITIONS[_element].display_name,
		"이미 점유한 기존 슬롯의 역할만 주속성으로 지정합니다. 다른 기존 슬롯도 보존합니다." if promotion else "기본 속성 슬롯 1개를 영구 점유합니다. 보조속성 획득은 후속 단계입니다."]
	confirmation.popup_centered(Vector2i(820, 255))
	confirmation.get_cancel_button().grab_focus()

func _confirm() -> void:
	if _ticket == 0: return
	var ticket := _ticket
	var element := _element
	_ticket = 0
	_element = ""
	confirmation_requested.emit(element, ticket)
	refresh()

func _cancel() -> void:
	cancel_confirmation()
	ritual_cancelled.emit()

func cancel_confirmation() -> void:
	_element = ""
	_ticket = 0
	confirmation.hide()
