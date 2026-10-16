extends CanvasLayer
## Hub-only debug UI. Only Confirm commits; browsing and clues are harmless.

signal commit_requested(element: String, ticket: int)
signal clue_requested(element: String)
const BaseElements = preload("res://scripts/base_elements.gd")
const CharacterResearch = preload("res://scripts/character_research.gd")
var research: CharacterResearch
var opener: Button
var panel: PanelContainer
var confirmation: ConfirmationDialog
var summary: Label
var feedback: Label
var rows: Dictionary = {}
var _element := ""
var _ticket := 0
var writable := true

func setup(model: CharacterResearch) -> void:
	research = model
	layer = 10
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 17
	var background := StyleBoxFlat.new()
	background.bg_color = Color("202938")
	background.border_color = Color("596176")
	background.set_border_width_all(2)
	theme.set_stylebox("panel", "PanelContainer", background)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("33425b") if state != "disabled" else Color("252d3d")
		if state == "hover": style.bg_color = Color("496080")
		if state == "pressed": style.bg_color = Color("202938")
		style.border_color = Color("ffe5ab") if state == "focus" else Color("596176")
		style.set_border_width_all(1)
		style.set_content_margin_all(7)
		theme.set_stylebox(state, "Button", style)
	theme.set_color("font_disabled_color", "Button", Color("94a2b7"))
	opener = Button.new()
	opener.text = "[B] 속성 연구 / 디버그"
	opener.position = Vector2(110, 476)
	opener.theme = theme
	opener.pressed.connect(open)
	add_child(opener)
	panel = PanelContainer.new()
	panel.position = Vector2(80, 112)
	panel.size = Vector2(1000, 500)
	panel.theme = theme
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	summary = Label.new()
	content.add_child(summary)
	var help := Label.new()
	help.text = "친화성과 연구 선택은 별개입니다. 열람·관찰·단서는 슬롯을 소모하지 않습니다.\n마력탄·일반 신체강화(속성 비의존 부여)는 無가 아니며 슬롯을 쓰지 않습니다."
	content.add_child(help)
	for element in BaseElements.DEFINITIONS:
		var definition = BaseElements.DEFINITIONS[element]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		content.add_child(row)
		var label := Label.new()
		label.custom_minimum_size.x = 520
		row.add_child(label)
		var clue := Button.new()
		clue.text = "열람 / 단서"
		clue.pressed.connect(func(): clue_requested.emit(element))
		row.add_child(clue)
		var start := Button.new()
		start.custom_minimum_size.x = 150
		start.pressed.connect(request.bind(element))
		row.add_child(start)
		rows[element] = {"label": label, "start": start, "clue": clue, "definition": definition}
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size = Vector2(930, 48)
	content.add_child(feedback)
	var close_button := Button.new()
	close_button.text = "닫기 [B / Esc]"
	close_button.pressed.connect(close)
	content.add_child(close_button)
	confirmation = ConfirmationDialog.new()
	confirmation.theme = theme
	confirmation.title = "영구 연구 선택 확인"
	confirmation.ok_button_text = "영구 확정"
	confirmation.cancel_button_text = "취소"
	confirmation.exclusive = true
	confirmation.confirmed.connect(_confirm)
	confirmation.canceled.connect(_cancel)
	confirmation.close_requested.connect(_cancel)
	add_child(confirmation)
	panel.hide()
	refresh()

func set_hub(is_hub: bool) -> void:
	opener.visible = is_hub
	if not is_hub: close()

func open() -> void:
	refresh()
	panel.show()

func close() -> void:
	_cancel()
	panel.hide()

func is_open() -> bool:
	return panel.visible

func refresh() -> void:
	var chosen := PackedStringArray()
	for element in research.researched_base_elements:
		chosen.append(BaseElements.DEFINITIONS[element].display_name)
	summary.text = "확정 연구 %d / 3   %s" % [chosen.size(), "없음" if chosen.is_empty() else " · ".join(chosen)]
	for element in rows:
		var row: Dictionary = rows[element]
		row["label"].text = "%s | %s | 친화성: 관찰 필요" % [row["definition"].display_name, row["definition"].domain]
		var state := research.eligibility(element)
		row["start"].text = {"available": "연구 선택…", "already_researched": "연구 확정됨", "slots_full": "3속성 잠금"}.get(state, state)
		row["start"].disabled = not writable or state != "available"
		row["clue"].disabled = not writable
	if not writable: feedback.text = "저장 파일 보호 모드: 연구 변경이 차단되었습니다. 원본을 확인하세요."

func request(element: String) -> void:
	if not panel.visible or not writable or confirmation.visible: return
	var result := research.request_research(element)
	if result["state"] != "confirmation_required":
		feedback.text = "연구 요청 거부: " + result["state"]
		refresh()
		return
	_element = element
	_ticket = result["ticket"]
	var count := research.researched_base_elements.size() + 1
	confirmation.dialog_text = "%s 연구를 영구 확정합니까?\n슬롯 %d / 3을 영구 점유하며 취소·교체할 수 없습니다.\n%s" % [BaseElements.DEFINITIONS[element].display_name, count,
		"마지막 슬롯입니다. 확정 후 다른 기본 속성의 연구를 시작할 수 없습니다." if count == 3 else "선천적 친화성과 관계없이 직접 선택하는 연구입니다."]
	confirmation.popup_centered(Vector2i(760, 210))
	# Accidental Enter must not confirm immediately when opening the dialog.
	confirmation.get_cancel_button().grab_focus()

func _confirm() -> void:
	if not panel.visible or not writable or _ticket == 0: return
	var element := _element
	var ticket := _ticket
	_element = ""
	_ticket = 0
	commit_requested.emit(element, ticket)
	refresh()

func _cancel() -> void:
	research.cancel_request()
	_element = ""
	_ticket = 0
	confirmation.hide()
