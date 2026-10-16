extends CanvasLayer
## Read-only chant reminder; controls can only browse/favorite/choose a recipe.
signal preference_changed(id: String, favorite: bool, representative: int)
const Book = preload("res://scripts/spell_discoveries.gd")
var book: Book
var panel: PanelContainer
var expand_button: Button
var favorite_button: Button
var variant_button: Button
var previous_button: Button
var next_button: Button
var title: Label
var recipe: Label
var current: Label
var details: VBoxContainer
var expanded := false
var page := 0
var _entries: Array = []

func setup(model: Book, theme: Theme) -> void:
	book = model
	layer = 8
	panel = PanelContainer.new()
	var small: Theme = theme.duplicate()
	small.default_font_size = 12
	panel.theme = small
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	expand_button = _button(bar, "[J] 마법 기록 펼치기", toggle)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	previous_button = _button(bar, "이전", func(): page -= 1; refresh())
	next_button = _button(bar, "다음", func(): page += 1; refresh())
	favorite_button = _button(bar, "☆", _favorite)
	variant_button = _button(bar, "대표 영창 변경", _variant)
	details = VBoxContainer.new()
	column.add_child(details)
	recipe = Label.new()
	recipe.clip_text = true
	recipe.custom_minimum_size.x = 1030
	details.add_child(recipe)
	current = Label.new()
	current.clip_text = true
	current.custom_minimum_size.x = 1030
	details.add_child(current)
	refresh()
	visible = false

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func toggle() -> void:
	expanded = not expanded
	refresh()

func refresh() -> void:
	var selected_id := ""
	if page >= 0 and page < _entries.size(): selected_id = _entries[page]["spell_id"]
	_entries = book.entries()
	for i in _entries.size():
		if _entries[i]["spell_id"] == selected_id: page = i; break
	page = clampi(page, 0, maxi(0, _entries.size() - 1))
	details.visible = expanded
	panel.position = Vector2(60, 594 if expanded else 684)
	panel.size = Vector2(1040, 94 if expanded else 32)
	expand_button.text = "[J] 접기 · 직접 영창 필요" if expanded else "[J] 발견한 마법 영창 보기"
	for button in [previous_button, next_button, favorite_button, variant_button]: button.visible = expanded
	if _entries.is_empty():
		title.text = "실제 발현에 성공하면 영창을 기록합니다."
		recipe.text = "아직 발견한 영창이 없습니다. 정답은 표시하지 않습니다."
		for button in [previous_button, next_button, favorite_button, variant_button]: button.disabled = true
		return
	var entry: Dictionary = _entries[page]
	var index := int(entry.get("representative", 0))
	title.text = "%s · %d/%d · 영창 %d/%d" % [entry["name"], page + 1, _entries.size(), index + 1, entry["recipes"].size()]
	recipe.text = Book.format_inputs(entry["recipes"][index]["inputs"])
	recipe.tooltip_text = recipe.text + "\n+는 입력 유지가 겹친 구간입니다. 클릭 자동 시전은 없습니다."
	favorite_button.text = "★ 즐겨찾기" if entry["favorite"] else "☆ 즐겨찾기"
	previous_button.disabled = page <= 0
	next_button.disabled = page >= _entries.size() - 1
	favorite_button.disabled = false
	variant_button.disabled = entry["recipes"].size() <= 1

func update_current(keys: Array[String], feedback: String) -> void:
	current.text = "현재 입력: " + ("(없음)" if keys.is_empty() else " → ".join(keys)) + "  |  " + feedback

func owns_pointer(position: Vector2) -> bool:
	return visible and panel.get_global_rect().has_point(position)

func _favorite() -> void:
	if _entries.is_empty(): return
	var entry: Dictionary = _entries[page]
	preference_changed.emit(entry["spell_id"], not entry["favorite"], int(entry["representative"]))
	refresh()

func _variant() -> void:
	if _entries.is_empty(): return
	var entry: Dictionary = _entries[page]
	preference_changed.emit(entry["spell_id"], entry["favorite"], (int(entry["representative"]) + 1) % entry["recipes"].size())
	refresh()
