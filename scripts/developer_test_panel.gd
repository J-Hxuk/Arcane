extends CanvasLayer
signal start_requested(element: String, location: String)
signal end_requested
signal close_requested
const Profile = preload("res://scripts/chant_profile.gd")
const Data = preload("res://scripts/developer_test_data.gd")
const Book = preload("res://scripts/spell_discoveries.gd")
var opener: Button
var panel: PanelContainer
var elements: OptionButton
var location: OptionButton
var start_button: Button
var end_button: Button
var close_button: Button
var text: TextEdit
var status: Label
var target_picker:OptionButton
var active_main_picker:OptionButton
var active_aux_picker:OptionButton
var current_option_buttons:Dictionary={}
var game
var water_picker:OptionButton
var water_status:Label

func setup(owner_game, ui_theme: Theme) -> void:
	game = owner_game
	if game.formal_rules:_setup_formal(ui_theme);return
	layer = 40
	opener = Button.new()
	opener.text = "개발 시험 [F2]"
	opener.position = Vector2(985, 38)
	opener.size = Vector2(140, 36)
	opener.focus_mode = Control.FOCUS_NONE
	opener.pressed.connect(func(): game._toggle_developer_menu())
	add_child(opener)
	panel = PanelContainer.new()
	panel.theme = ui_theme
	panel.position = Vector2(45, 105)
	panel.size = Vector2(1070, 570)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(1040, 44)
	column.add_child(status)
	var row := HBoxContainer.new()
	column.add_child(row)
	elements = OptionButton.new()
	for element in Data.OPTIONS: elements.add_item("중립 마나 (舊 無)" if element == "VOID" else element)
	elements.item_selected.connect(func(_index): refresh())
	row.add_child(elements)
	location = OptionButton.new()
	location.add_item("연구실")
	location.add_item("던전")
	row.add_child(location)
	start_button = _button(row, "선택 속성 임시 캐릭터 시작", func(): start_requested.emit(Data.OPTIONS[elements.selected], "LAB" if location.selected == 0 else "DUNGEON"))
	end_button = _button(row, "시험 종료 · 원래 플레이 복귀", func(): end_requested.emit())
	close_button = _button(row, "닫기 / F2", func(): close_requested.emit())
	_button(column,"전속성 동시 시험 · 새 영창 시제품",func():game._start_prototype_all("LAB" if location.selected==0 else ("WORLD" if game.get("world_enabled")!=null else "DUNGEON")))
	_button(column,"전속성 동시 시험 · 기존 영창 호환",func():game._start_prototype_all("LAB" if location.selected==0 else ("WORLD" if game.get("world_enabled")!=null else "DUNGEON"),false))
	target_picker=OptionButton.new();target_picker.add_item("자동 판정 · 구성 충돌 시 거부");target_picker.set_item_metadata(0,"")
	for definition in preload("res://scripts/chant_engine_v2.gd").CONFIG.spells:
		target_picker.add_item("디버그 재현 대상 · "+str(definition.id));target_picker.set_item_metadata(target_picker.item_count-1,definition.id)
	column.add_child(target_picker);target_picker.hide()
	target_picker.item_selected.connect(func(index):
		if game.developer_mode and game._prototype_all:game.prototype_target=str(target_picker.get_item_metadata(index)))
	text = TextEdit.new()
	text.editable = false
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size = Vector2(1040, 270)
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_readonly_color", Color("dbe5f2"))
	column.add_child(text)
	panel.hide()

func _button(parent: Control, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func refresh() -> void:
	if game.formal_rules:
		if water_status!=null:water_status.text="물15 QA · 마나 1000 · 원본 저장 보호" if game.water_qa_active else "물15 QA는 임시 캐릭터로 실행합니다."
		status.text="현재 월드에 즉시 적용 중 · 원본 저장 보호 · 종료하면 시작 시점 진행 복구" if game.current_world_development else "별도 프리셋 시험 중 · 종료하면 원래 진행 복구" if game.developer_mode else "위 옵션을 켜면 지금 위치·캐릭터에 바로 적용합니다. 일반 저장은 보호됩니다."
		for option in current_option_buttons:current_option_buttons[option].set_pressed_no_signal(game.current_developer_options.get(option,false))
		end_button.text="개발 설정 종료 · 원래 진행 복구" if game.current_world_development else "시험 종료 · 원래 플레이 복귀"
		end_button.disabled=not game.developer_mode
		var lines:PackedStringArray=[JSON.stringify(game._active_profile().to_data().get("manipulations",{}))]
		lines.append("영구 개화: "+str(game.research.awakened_attributes))
		if game.water_qa_active:
			lines.append("물15 QA · 준비 후 화면에서 LMB / Esc 취소 · 마나회복은 HP·마나 회복 버튼")
			lines.append("실측 전투: "+JSON.stringify(game.laboratory_panel.arena.combat.water_metrics if game.game_state=="LAB" else game.elemental_combat.water_metrics))
			if not game.runes.is_empty():lines.append("준비 영창: "+" → ".join(game.runes))
		if active_main_picker!=null:
			active_main_picker.select(maxi(0,Data.Profile.OHAENG.find(game.research.main_attribute)))
			active_aux_picker.select(0 if game.research.auxiliary_attributes.is_empty() else Data.Profile.OHAENG.find(game.research.auxiliary_attributes[0])+1)
		if game.developer_metrics.has("loadout_combinations"):lines.append("모든 조합 검사: "+str(game.developer_metrics.loadout_combinations))
		lines.insert(0,"주속성 "+str(game.research.main_attribute)+" · 보조 "+str(game.research.auxiliary_attributes)+" · 점멸 "+("해금" if game.research.blink_unlocked() else "미해금"))
		for row in preload("res://scripts/formal_spell_registry.gd").config().spells:lines.append(str(row.id)+" · "+str(preload("res://scripts/chant_engine_v2.gd").inputs(game._active_profile(),row.actions).map(func(e):return e.key)))
		lines.append(JSON.stringify(game._inspect_chant(true).get("final_state",{})));text.text="\n".join(lines);return
	if target_picker!=null:target_picker.visible=game.developer_mode and game._prototype_all and game.prototype_enabled
	var element: String = Data.OPTIONS[elements.selected]
	status.text = "개발자 전용 · 월드 일시정지 · 임시 데이터는 메모리에만 저장합니다.\n" + ("시험 중: " + str(game.research.main_attribute) + " / 종료하면 원래 캐릭터와 진행 상태로 복귀합니다." if game.developer_mode else "선택 속성 하나를 주속성으로 가진 별도 시험 캐릭터를 만듭니다. 영구 개방 없음.")
	end_button.disabled = not game.developer_mode
	var profile = game.chant_profile
	var lines := PackedStringArray(["이 화면에서만 내부 의미와 검증된 시험 영창을 공개합니다. 연구실은 Shift 영창 후 해제로 자동 방출·기록합니다. 초집중/던전은 명시적으로 방출하세요.", "첫 속성어: " + JSON.stringify(profile.to_data().get("first_words", {})), "후속 조작: " + JSON.stringify(profile.to_data().get("manipulations", {})), "", "선택 속성 " + element + " · 성공 가능한 최종 상태 예시 (고정 레시피가 아닙니다):"])
	var temp = Data.character(profile.to_data(), element)
	var research = game.CharacterResearch.new()
	research.load_data(temp["research"])
	for example in Data.examples(profile, element, research.simulation_context()):
		lines.append("%s · %s\n입력 %d개 / 마나 %.1f / 피해 %.1f / 효과 %s / 지속 %.2f초 / 사거리·반경 %.0f\n100ms 간격 예시 %.1f초 (최소 시전시간 아님)" % [example["name"], Book.format_inputs(example["inputs"]), example["inputs"].size(), example["cost"], example["damage"], example["effect"], example["duration"], example["range"], example["sample_ms"] / 1000.0])
	if not game.developer_metrics.is_empty(): lines.append("\n최근 실제 방출: " + JSON.stringify(game.developer_metrics))
	lines.append("\nF2: 안전 정지/화면 전환 · Esc: 화면 닫기 · 일반 취소는 Esc, RMB는 목적지 이동입니다.")
	text.text = "\n".join(lines)
	if game.developer_mode and game._prototype_all and game.prototype_enabled:
		var prototype=preload("res://scripts/chant_engine_v2.gd")
		var catalog_lines:PackedStringArray= ["전속성 새 영창 시제품 · 이 디버그 카탈로그에서만 정의와 키 의미를 공개합니다.",JSON.stringify(game.prototype_profile.to_data()["manipulations"])]
		for row in prototype.CONFIG.spells:
			catalog_lines.append(str(row.id)+" · "+str(prototype.inputs(game.prototype_profile,row.actions).map(func(e):return e.key))+" · "+str(row.actions))
		text.text="\n".join(catalog_lines)
	elif game.developer_mode and game._prototype_all:
		var compatibility_lines:PackedStringArray=["전속성 기존 영창 호환 · 영구 속성 변경 없이 실행 경계에서만 개발 권한 적용"]
		for preset in Data.OPTIONS:
			var temporary=Data.character(game.chant_profile.to_data(),preset);var allowed=game.CharacterResearch.new();allowed.load_data(temporary.research)
			for example in Data.examples(game.chant_profile,preset,allowed.simulation_context()):compatibility_lines.append(example.name+" · "+Book.format_inputs(example.inputs))
		text.text="\n".join(compatibility_lines)
	if game.developer_mode and game._prototype_all:
		text.text+="\n\n설계 카탈로그 · 아래 이름은 실행 가능 여부나 새 조작 구성 확정을 의미하지 않습니다."
		for id in preload("res://scripts/spell_names.gd").SOURCE.by_catalog_id:text.text+="\n"+str(id)+" · "+str(preload("res://scripts/spell_names.gd").SOURCE.by_catalog_id[id])

func _setup_formal(ui_theme:Theme)->void:
	layer=40
	opener=Button.new();opener.text="개발자 [F2]";opener.position=Vector2(1000,38);opener.pressed.connect(func():game._toggle_developer_menu());add_child(opener)
	panel=PanelContainer.new();panel.position=Vector2(45,105);panel.size=Vector2(1070,570);panel.theme=ui_theme;add_child(panel)
	var column:=VBoxContainer.new();panel.add_child(column)
	status=Label.new();column.add_child(status)
	var current_row:=HBoxContainer.new();column.add_child(current_row)
	for option in {"all_elements":"오행 전체 개화","bindings":"결속 연구 이력 시험","blink":"점멸 강제 해금"}:
		var toggle:=CheckButton.new();toggle.text={"all_elements":"오행 전체 개화","bindings":"결속 연구 이력 시험","blink":"점멸 강제 해금"}[option];toggle.focus_mode=Control.FOCUS_NONE;current_row.add_child(toggle);current_option_buttons[option]=toggle
		toggle.toggled.connect(func(enabled):game._set_current_developer_option(option,enabled);refresh())
	var row:=HBoxContainer.new();column.add_child(row)
	elements=OptionButton.new()
	for choice in Data.OPTIONS:elements.add_item(choice)
	row.add_child(elements);location=OptionButton.new();location.add_item("연구실");location.add_item("월드");row.add_child(location)
	start_button=_button(row,"임시 캐릭터 시험",func():start_requested.emit(Data.OPTIONS[elements.selected],"LAB" if location.selected==0 else "WORLD"))
	_button(row,"등록 주문 권한 우회 시험",func():game._start_prototype_all("LAB" if location.selected==0 else "WORLD"))
	end_button=_button(row,"시험 종료 · 원래 플레이 복귀",func():end_requested.emit())
	close_button=_button(row,"닫기",func():close_requested.emit())
	target_picker=OptionButton.new();target_picker.add_item("자동 판정");target_picker.set_item_metadata(0,"")
	for definition in preload("res://scripts/formal_spell_registry.gd").config().spells:
		target_picker.add_item(str(definition.id));target_picker.set_item_metadata(target_picker.item_count-1,definition.id)
	target_picker.item_selected.connect(func(i):
		if game.developer_mode:game.prototype_target=str(target_picker.get_item_metadata(i)))
	column.add_child(target_picker)
	var actions:=GridContainer.new();actions.columns=5;column.add_child(actions)
	var labels={"resources":"HP·마나 회복","low_hp":"HP 15%","empty_mana":"마나 비우기","learn":"등록 주문 발견·학습","spawn":"적 소환","clear_enemies":"적 제거","gold":"100 골드","items":"물약 각 5개","reset":"시험 환경 초기화"}
	labels.merge({"research_primary":"주속성 초기화","research_auxiliary":"보조/결속 초기화","research_catalysts":"촉매 검증 초기화","research_blink":"점멸 초기화","blink_unlock":"점멸 강제 해금","research_all":"전체 연구 초기화","research_toggle":"선택 속성 개화 토글"})
	labels.merge({"research_all_elements":"오행 전체 개화","research_selections":"장착 선택 초기화","research_only":"선택 속성만 개화","loadout_check":"모든 주/보조 조합 검사"})
	for action in labels:_button(actions,labels[action],func():game._developer_current_action(action))
	var equipment:=HBoxContainer.new();column.add_child(equipment)
	var qa:=HBoxContainer.new();column.add_child(qa)
	_button(qa,"물15 QA 연구실",func():game._water_qa_start("LAB"))
	_button(qa,"일반 표적",func():game._water_qa_start("FIELD"))
	_button(qa,"물15 QA 수호기사",func():game._water_qa_start("WORLD"))
	water_picker=OptionButton.new();qa.add_child(water_picker)
	for water in preload("res://scripts/water_spell_catalog.gd").DATA.spells:water_picker.add_item(water.id+" "+water.name);water_picker.set_item_metadata(water_picker.item_count-1,water.id)
	_button(qa,"기본/약한 현상 준비",func():game._water_qa_prepare(str(water_picker.get_item_metadata(water_picker.selected)),"off");refresh())
	_button(qa,"강한 현상 준비",func():game._water_qa_prepare(str(water_picker.get_item_metadata(water_picker.selected)),"on");refresh())
	water_status=Label.new();column.add_child(water_status)
	active_main_picker=OptionButton.new();active_aux_picker=OptionButton.new();active_aux_picker.add_item("보조 없음")
	for element in Profile.OHAENG:active_main_picker.add_item("주 "+element);active_aux_picker.add_item("보조 "+element)
	equipment.add_child(active_main_picker);equipment.add_child(active_aux_picker);_button(equipment,"활성 슬롯 강제 지정",func():game._developer_current_force_loadout(Profile.OHAENG[active_main_picker.selected],null if active_aux_picker.selected==0 else Profile.OHAENG[active_aux_picker.selected-1]))
	text=TextEdit.new();text.editable=false;text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;text.custom_minimum_size=Vector2(1000,125);text.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(text);panel.hide()
