extends PanelContainer
## Books/mentor explain observable principles, never a personal key answer table.
signal clue_requested(element: String, source: String)
signal ritual_requested(element: String)
signal ritual_cancelled
signal confirmation_requested(element: String, ticket: int)
signal neutral_transition_requested
signal binding_study_requested(element: String)
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
var environment_button: Button
var binding_button: Button
var transition_button: Button
var ritual_button: Button
var cancel_button: Button
var back_button: Button
var confirmation: ConfirmationDialog
var _element := ""
var _ticket := 0

func setup(model: Research) -> void:
	research = model
	position = Vector2(60, 110)
	custom_minimum_size.x=1040
	size = Vector2(1040, 390)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := Label.new()
	title.text = "속성 개화 · 실마리 → 공명 관측 → 촉매 검증 → 의식 → 영구 확인"
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
	for element in Elements.OHAENG:
		target.add_item(Elements.DEFINITIONS[element].display_name)
		target.set_item_metadata(target.item_count - 1, element)
	target.item_selected.connect(func(_index): refresh())
	choices.add_child(target)
	book_button = _button(choices, "마법서적 열람", func(): clue_requested.emit(selected_element(), "book"))
	mentor_button = _button(choices, "스승에게 질문", func(): clue_requested.emit(selected_element(), "mentor"))
	environment_button = _button(choices, "환경 촉매 관찰", func(): clue_requested.emit(selected_element(), "environment"))
	environment_button.tooltip_text = "공명진에서 안정된 마나를 만든 뒤 같은 속성의 촉매와 접촉해 검증합니다. 열람이나 E 입력만으로 검증되지 않습니다."
	binding_button = _button(choices, "결속 원리 연구", func(): binding_study_requested.emit(selected_element()))
	progress = Label.new()
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress.custom_minimum_size.y = 68
	column.add_child(progress)
	journal_view = TextEdit.new()
	journal_view.editable = false
	journal_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	journal_view.custom_minimum_size = Vector2(990, 0)
	journal_view.add_theme_color_override("font_readonly_color", Color("dbe5f2"))
	column.add_child(journal_view)
	journal_view.hide() # Clue data remains internal; books, mentors and catalysts own its presentation.
	var actions := HBoxContainer.new()
	column.add_child(actions)
	ritual_button = _button(actions, "개화 의식 시작 (직접 영창)", func(): ritual_requested.emit(selected_element()))
	cancel_button = _button(actions, "의식 중단 / 확인 취소", func(): cancel_confirmation(); ritual_cancelled.emit())
	transition_button = _button(actions, "기존 중립 역할 전환 확인", func(): neutral_transition_requested.emit())
	transition_button.tooltip_text = "기존 無 술식 권한과 기록을 보존합니다. 오행 주속성은 자동 지정하지 않습니다."
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

signal opened
func open() -> void:
	opened.emit()
	refresh()
	show()

func close() -> void:
	hide()
	get_viewport().gui_release_focus()

func _process(_delta:float)->void:
	if visible and not is_equal_approx(size.y,get_combined_minimum_size().y):size=Vector2(1040,get_combined_minimum_size().y)

func refresh() -> void:
	var element := selected_element()
	var main = research.main_attribute
	transition_button.visible = research.to_data().get("neutral_mana", {}).get("transition_pending", false)
	environment_button.visible = main != null
	binding_button.visible = main != null
	binding_button.disabled = not research.auxiliary_attributes.has(element)
	status.text = "주속성: " + ("미개화" if main == null else Elements.DEFINITIONS[main].display_name) + " · 활성 속성 %d / 2 · 보조는 융합 전용\n" % research.active_elements.size()
	status.text += "서적 또는 스승의 실마리 → 안정 공명 → 같은 속성 촉매 검증 → 직접 의식 → 영구 확인. 보조는 간섭 안정화도 필요합니다."
	if research.free_attributes:status.text="영구 개화 %d / 5 · 활성 주속성: %s · 보조: %s\n개화는 영구 보존하며 장착은 자유롭게 바꿉니다. 추가 개화도 실마리·공명·촉매·간섭 안정화·직접 의식·수동 확인이 필요합니다."%[research.awakened_attributes.size(),str(main),str(research.auxiliary_attributes)]
	if research.to_data().get("neutral_mana", {}).get("transition_pending", false): status.text += "\n기존 無 역할이 중립으로 보존됐습니다. 중립 역할 전환 확인 후 오행을 자유롭게 연구하세요."
	if not research.legacy_committed_attributes.is_empty():
		status.text += "\n기존 확정 슬롯은 보존 중입니다. 주속성을 임의 배정하지 않았습니다. 가득 찼다면 기존 속성을 의식으로 지정하세요."
	var eligible := research.ritual_eligibility(element)
	progress.text = "선택 대상: %s · 서적 %s / 스승 %s · 안정 공명 현재 %d회 / 최소 1회\n%s" % [
		Elements.DEFINITIONS[element].display_name, "획득" if research.has_clue(element, "book") else "미획득",
		"획득" if research.has_clue(element, "mentor") else "미획득", research.stable_count(element), reason(eligible)]
	if main != null: progress.text += " · 환경 단서 %s / 간섭 안정 재현 %d회" % ["획득" if research.has_clue(element, "environment") else "미획득", research.interference_count(element)]
	if research.use_current_rules:progress.text+="\n촉매 검증: "+("완료" if research.catalyst_verified(element) else "공명을 관측한 뒤 실험실 촉매에 다가가 검증하세요.")
	ritual_button.disabled = eligible != "available"
	cancel_button.disabled = research.ritual_target.is_empty()
	journal_view.text=""
	journal_view.hide()
	set_deferred("size",Vector2(1040,1)) # Compact after wrapping updates; hidden history reserves no height.

static func reason(state: String) -> String:
	if state=="catalyst_required":return "속성 촉매에서 공명을 검증해야 합니다."
	if state=="catalyst_rejected":return "촉매와 같은 속성의 안정된 공명을 확인하지 못했습니다."
	return {"available": "의식 준비 완료. 성공 뒤 확인하기 전에는 슬롯이 바뀌지 않습니다.",
		"binding_studied": "결속 원리 연구를 기록했습니다.",
		"confirmed_auxiliary_required": "영구 개화한 보조속성을 선택하세요.",
		"already_researched": "이미 영구 확정한 속성입니다.",
		"second_auxiliary_deferred": "주속성 하나와 보조속성 하나만 사용할 수 있습니다.",
		"environment_required": "안전 시험장의 환경 촉매를 관찰하세요. 단서만으로 슬롯은 소비되지 않습니다.",
		"interference_research_required": "다른 속성의 압력 속에서도 응집과 형상을 충분히 유지한 안정 공명을 기록하세요.",
		"neutral_transition_required": "기존 중립 역할 전환을 확인하세요. 새로운 주속성을 자동 배정하지 않습니다.",
		"clues_required": "서적 또는 스승에게서 먼저 실마리를 얻으세요. 촉매 접촉만으로 준비가 끝나지 않습니다.",
		"stable_reproduction_required": "자유 실험에서 안정 공명을 1회 방출·기록하세요. 중단/불안정은 재현에 포함되지 않습니다.",
		"main_already_confirmed": "주속성은 이미 영구 확정되었습니다. 보조속성 획득은 다음 단계입니다.",
		"slots_full": "기존 영구 슬롯이 가득 찼습니다. 기존 확정 속성 중 하나를 선택하세요.",
		"ritual_structure_required": "공명은 맞지만 의식의 형상/방향이 부족합니다. 형상을 잇고 한 방향으로 흐르게 한 뒤 안정화하세요.",
		"target_resonance_required": "목표와 같은 안정 공명을 완성해야 합니다. 실험의 관찰과 준비 조건을 비교하세요.",
		"save_failed": "저장 실패로 확정하지 않았습니다. 저장 경로를 확인한 뒤 의식을 다시 수행하세요."}.get(state, state)

func offer(result: Dictionary) -> void:
	_element = result["element"]
	_ticket = result["ticket"]
	confirmation.theme = theme
	if research.free_attributes:
		confirmation.title="속성 영구 개화 확인";confirmation.ok_button_text="속성 개화 확정"
		confirmation.dialog_text="%s 개화 의식을 완성했습니다.\n개화 기록은 영구 보존됩니다. 활성 주속성·보조속성 장착은 이후 자유롭게 변경할 수 있습니다.\n다른 속성의 개화를 막거나 영구 장착 슬롯을 점유하지 않습니다.\n개화를 확정하시겠습니까?"%Elements.DEFINITIONS[_element].display_name
		confirmation.popup_centered(Vector2i(820,255));confirmation.get_cancel_button().grab_focus();return
	if research.main_attribute != null:
		confirmation.title = "첫 보조속성 · 영구 확정 확인"
		confirmation.ok_button_text = "보조속성 영구 확정"
		confirmation.dialog_text = "%s 보조 개화 의식을 완성했습니다.\n보조 슬롯을 영구 점유하며 교체할 수 없습니다.\n보조는 공명·결속·융합 연구에 사용하며 단독 전투마법은 사용할 수 없습니다.\n취소하면 슬롯은 바뀌지 않습니다." % Elements.DEFINITIONS[_element].display_name
		confirmation.popup_centered(Vector2i(820, 255))
		confirmation.get_cancel_button().grab_focus()
		return
	confirmation.title = "최초 주속성 · 영구 확정 확인"
	confirmation.ok_button_text = "주속성 영구 확정"
	var promotion := research.legacy_committed_attributes.has(_element)
	confirmation.dialog_text = "%s 의식을 완성했습니다.\n이 속성을 주속성으로 영구 확정하겠습니까?\n취소·교체·두 번째 주속성 선택은 불가능합니다.\n%s\n취소하면 슬롯 변경 없이 다른 속성 탐구를 계속할 수 있습니다." % [
		Elements.DEFINITIONS[_element].display_name,
		"이미 점유한 기존 슬롯의 역할만 주속성으로 지정합니다. 다른 기존 슬롯도 보존합니다." if promotion else "기본 속성 슬롯 1개를 영구 점유합니다. 첫 보조속성은 별도의 연구와 직접 의식이 필요합니다."]
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
