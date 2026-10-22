extends AcceptDialog
## Deletion is confirmed against a stable ID set; controller owns backup/rollback.
const Journal = preload("res://scripts/experiment_journal.gd")
var game
var filter: OptionButton
var sort: OptionButton
var search: LineEdit
var list: ItemList
var summary: Label
var failures: CheckButton
var confirm: ConfirmationDialog
var _pending: Array = []
var retention_confirm:ConfirmationDialog
var _retention_remove:Array=[]
const FILTERS := ["all", "success", "no_result", "failed", "protected"]
const LABELS := {"discovery":"주문 발견 성공", "reproduction":"알려진 주문 재현", "observation":"마나 상태 관찰", "no_result":"결과 없는 실험", "failed":"불안정·실패", "cancelled":"사용자 취소", "protected":"중요·보호 기록"}
func setup(owner_game) -> void:
	game = owner_game; title = "연구 일지 관리 · 발견 주문과 키표는 삭제되지 않습니다"
	var column := VBoxContainer.new(); add_child(column)
	var row := HBoxContainer.new(); column.add_child(row)
	filter = OptionButton.new()
	for label in ["전체", "성공만", "결과 없음", "실패·취소", "보호 기록"]: filter.add_item(label)
	row.add_child(filter); filter.item_selected.connect(func(_i): refresh())
	sort = OptionButton.new()
	for label in ["날짜 최신순", "날짜 오래된순", "속성순", "결과순"]: sort.add_item(label)
	row.add_child(sort); sort.item_selected.connect(func(_i): refresh())
	search = LineEdit.new(); search.placeholder_text = "날짜 · 속성 · 실험 결과 · 메모 검색"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(search)
	search.text_changed.connect(func(_text): refresh())
	list = ItemList.new(); list.select_mode = ItemList.SELECT_MULTI
	list.custom_minimum_size = Vector2(900, 330); column.add_child(list)
	var actions := HBoxContainer.new(); column.add_child(actions)
	_button(actions,"전체 선택 · 비보존",func():
		list.deselect_all()
		var eligible:Array=game.journal.eligible_ids(game.journal.records().map(func(r):return r.id),game._journal_evidence_ids())
		for i in list.item_count:
			if list.get_item_metadata(i) in eligible:list.select(i,false))
	_button(actions, "선택 기록 삭제", func(): request_delete(selected_ids()))
	_button(actions, "결과 없는 기록 일괄삭제", func():
		var ids: Array = []
		for record in game.journal.records():
			if Journal.category(record) == "no_result": ids.append(record["id"])
		request_delete(ids))
	_button(actions, "선택 보존", func(): game._protect_journal_records(selected_ids(), true); refresh())
	_button(actions, "보존 해제", func(): game._protect_journal_records(selected_ids(), false); refresh())
	_button(actions, "마지막 삭제 복구", func(): game._restore_journal_delete(); refresh())
	_button(column,"최근 10개 정책 · 정리 미리보기",func():
		var preview:Dictionary=game._preview_journal_retention()
		if preview.is_empty():summary.text="백업 실패 · 기록을 정리하지 않았습니다.";return
		_retention_remove=preview.remove.duplicate()
		retention_confirm.dialog_text="일반 최근 %d개 + 사용자 보존 %d개를 유지합니다.\n오래된 비보존 %d개 삭제 예정. 취소한 뒤 원하는 기록을 보존할 수 있습니다.\n영구 연구 증거는 별도로 보관하며 발견·학습·키표·연구 진행은 유지됩니다."%[preview.normal_kept,preview.keep.size()-preview.normal_kept,preview.remove.size()]
		retention_confirm.popup_centered())
	failures = CheckButton.new(); failures.text = "실패·취소 실험도 자동 저장 (해제해도 성공·주요 관찰은 보존)"
	failures.button_pressed = game.journal.auto_failures(); column.add_child(failures)
	failures.toggled.connect(func(enabled): game._set_journal_auto_failures(enabled))
	summary = Label.new(); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(summary)
	confirm = ConfirmationDialog.new(); confirm.title = "기록 삭제 확인"; add_child(confirm)
	retention_confirm=ConfirmationDialog.new();retention_confirm.title="일지 정책 전환 · 사용자 확인";add_child(retention_confirm)
	retention_confirm.confirmed.connect(func():
		var ok:bool=game._confirm_journal_retention(_retention_remove);refresh()
		summary.text="최근 10개 + 보존 기록 정책 적용 완료" if ok else "정리 실패 또는 기록 변경 · 원본 유지")
	confirm.confirmed.connect(func():
		var removed: int = game._delete_journal_records(_pending)
		refresh(); summary.text = "%d개 삭제 · 발견 주문·개인 키표 보존 · 실패 시 원복합니다." % removed)
	visibility_changed.connect(func():
		if visible:
			game._reset_combat_input()
			if game.journal.retention_pending():game._preview_journal_retention() # Backup before the first preservation selection.
			refresh();_center_after_layout())
func _center_after_layout() -> void:
	await get_tree().process_frame
	if not visible: return
	# Wrapped text initially measures before the window has a width. Reapply the
	# intended size after containers settle instead of retaining that tall estimate.
	size = Vector2i(950,520)
	await get_tree().process_frame
	if visible: position = Vector2i((Vector2(get_tree().root.size)-Vector2(size))*0.5).max(Vector2i(8,30))
func _button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text = text; button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback); parent.add_child(button)
func selected_ids() -> Array:
	var ids: Array = []
	for index in list.get_selected_items(): ids.append(list.get_item_metadata(index))
	return ids
func request_delete(ids: Array) -> void:
	_pending = game.journal.eligible_ids(ids, game._journal_evidence_ids())
	confirm.dialog_text = "%d개 관측 기록을 삭제하시겠습니까?\n영구 발견·학습·개화 및 최소 연구 증거는 별도 보관됩니다.\n사용자 보존 기록은 보존 해제 후 삭제할 수 있습니다. 백업과 실패 시 원복을 제공합니다." % _pending.size()
	confirm.popup_centered()
func refresh() -> void:
	list.clear()
	var records: Array = game.journal.records()
	records.sort_custom(func(a, b):
		if sort.selected == 2:
			var left := str(a.get("result", {}).get("terminal_snapshot", {}).get("base_attributes", []))
			var right := str(b.get("result", {}).get("terminal_snapshot", {}).get("base_attributes", []))
			if left != right: return left < right
		if sort.selected == 3 and Journal.category(a) != Journal.category(b): return Journal.category(a) < Journal.category(b)
		return a["id"] < b["id"] if sort.selected == 1 else a["id"] > b["id"])
	var evidence: Array = game._journal_evidence_ids()
	for record in records:
		var category := Journal.category(record)
		var selection: String = FILTERS[filter.selected]
		if selection == "success" and category not in ["discovery", "reproduction"]: continue
		if selection == "no_result" and category != "no_result": continue
		if selection == "failed" and category not in ["failed", "cancelled"]: continue
		if selection == "protected" and not record.get("protected", false) and not Journal.has_id(evidence,record.id): continue
		var time := Time.get_datetime_string_from_unix_time(int(record["created_at"])) if record.has("created_at") else "이전 기록"
		var elements := str(record["result"].get("terminal_snapshot", {}).get("base_attributes", []))
		var line := "#%d · %s · %s · %s · %s%s" % [record["id"], time, elements, Journal.title(record), record.get("note", ""), " ★ 사용자 보존" if record.get("protected",false) else ""]
		if not search.text.is_empty() and not line.to_lower().contains(search.text.to_lower()): continue
		list.add_item(line); list.set_item_metadata(list.item_count - 1, record["id"])
	summary.text = "표시 %d건 / 전체 %d건 · ★ 사용자 보존만 자동 삭제에서 제외 · 영구 연구 증거는 별도 보관. %s" % [list.item_count, records.size(),"기존 기록 삭제 확인 대기 · 미리보기 취소 가능" if game.journal.retention_pending() else "일반 최근 10개 정책"]
