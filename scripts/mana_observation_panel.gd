extends VBoxContainer
## Laboratory-only readout. UI state is transient and has no simulation hooks.
const Observation = preload("res://scripts/mana_observation.gd")
var frames: Array=[]
var records: Array=[]
var step_picker: OptionButton
var record_picker: OptionButton
var record_step: SpinBox
var history_mode: CheckButton
var heading: Label
var trend: Label
var projection: Label
var matrix: Tree
var plot: Control
var _source: Dictionary={}
var _selected_record_id := -1
var display_frame: Dictionary={}
var visual_orbs: Array = []
var visual_labels: Array = []

func _init() -> void:
	add_theme_constant_override("separation",2)
	var row := HBoxContainer.new(); add_child(row)
	step_picker=OptionButton.new(); step_picker.focus_mode=Control.FOCUS_NONE
	step_picker.add_theme_font_size_override("font_size",11)
	step_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(step_picker)
	step_picker.item_selected.connect(func(_i): _render())
	history_mode=CheckButton.new(); history_mode.text="기록 단계 보기"; history_mode.focus_mode=Control.FOCUS_NONE
	history_mode.add_theme_font_size_override("font_size",11)
	history_mode.toggled.connect(func(_on): _render()); row.add_child(history_mode)
	var history := HBoxContainer.new(); add_child(history)
	record_picker=OptionButton.new(); record_picker.focus_mode=Control.FOCUS_NONE
	record_picker.add_theme_font_size_override("font_size",11)
	record_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL; history.add_child(record_picker)
	record_picker.item_selected.connect(func(_i): _selected_record_id=-1; _render())
	record_step=SpinBox.new(); record_step.min_value=1; record_step.max_value=1; record_step.step=1
	record_step.focus_mode=Control.FOCUS_NONE
	record_step.get_line_edit().editable=false; record_step.get_line_edit().focus_mode=Control.FOCUS_NONE
	record_step.value_changed.connect(func(_v): _render()); history.add_child(record_step)
	heading=Label.new(); heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; heading.add_theme_font_size_override("font_size",12); add_child(heading)
	var visual_row := HBoxContainer.new(); add_child(visual_row)
	for caption in ["선택 입력 전", "선택 입력 후", "비교 기록 · 입력 후"]:
		var column := VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; visual_row.add_child(column)
		var label := Label.new(); label.text=caption; label.add_theme_font_size_override("font_size",10); column.add_child(label); visual_labels.append(label)
		var orb := preload("res://scripts/mana_orb_view.gd").new(); orb.custom_minimum_size=Vector2(120,90); column.add_child(orb); visual_orbs.append(orb)
	matrix=Tree.new(); matrix.columns=10; matrix.hide_root=true; matrix.column_titles_visible=true
	matrix.focus_mode=Control.FOCUS_NONE; matrix.custom_minimum_size=Vector2(520,220); matrix.add_theme_font_size_override("font_size",11)
	matrix.add_theme_constant_override("v_separation",1)
	for i in 10:
		matrix.set_column_title(i,["물성","전","후","Δ","B","O","T","raw","기록Δ","rawΔ"][i])
		matrix.set_column_custom_minimum_width(i,55 if i==0 else 43)
	add_child(matrix)
	plot=preload("res://scripts/mana_observation_plot.gd").new(); plot.custom_minimum_size=Vector2(520,64)
	plot.tooltip_text="각 물성의 실제 관측 범위로 개별 축을 표시합니다. 녹색은 선택 입력 전, 주황색은 입력 후입니다. 점은 실제 입력 단계이며 미래 상태를 예측하지 않습니다."
	add_child(plot)
	move_child(plot,matrix.get_index())
	trend=Label.new(); trend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; trend.add_theme_font_size_override("font_size",11); add_child(trend)
	projection=Label.new(); projection.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; projection.add_theme_font_size_override("font_size",11); add_child(projection)
	clear_live()

func clear_live() -> void:
	frames=[]; _source={}; step_picker.clear(); step_picker.add_item("실시간 · 입력 대기")
	_render()

func reset() -> void:
	records=[]; _selected_record_id=-1; record_picker.clear(); record_picker.add_item("직전 실험 (자동)",-1)
	history_mode.set_pressed_no_signal(false); clear_live()

func set_live(simulation: Dictionary, active: bool) -> void:
	if not active:
		if not frames.is_empty(): clear_live()
		return
	var source := {"steps":simulation.get("casting_steps",[]),"actions":simulation.get("actions",[]),"context":simulation.get("simulation_context",{}),"property_version":simulation.get("property_version","")}
	if source==_source: return
	_source=source.duplicate(true)
	frames=Observation.capture(simulation)
	var selected := step_picker.selected
	step_picker.clear(); step_picker.add_item("실시간 · 마지막 입력")
	for frame in frames: step_picker.add_item("%d단계 · %s" % [frame.index,frame.key])
	step_picker.select(selected if selected>=0 and selected<=frames.size() else 0)
	_render()

func set_records(value: Array) -> void:
	var selected := record_picker.get_selected_id() if record_picker.item_count>0 and record_picker.selected>0 else -1
	records=value.duplicate(true); record_picker.clear(); record_picker.add_item("직전 실험 (자동)",-1)
	for i in range(records.size()-1,-1,-1):
		var record: Dictionary=records[i]
		var outcome: String={"failed":"실패","cancelled":"취소","released":"방출","blocked":"발현 공간 없음","insufficient_mana":"자원 부족"}.get(record.get("result",{}).get("outcome",""),"관측")
		record_picker.add_item("#%d · %s · %d단계" % [record.id,outcome,record.get("steps",[]).size()],int(record.id))
	var index := record_picker.get_item_index(selected) if selected>=0 else 0
	record_picker.select(maxi(0,index)); _render()

func _record() -> Dictionary:
	if records.is_empty(): return {}
	var id := record_picker.get_selected_id()
	if record_picker.selected<=0: return records.back()
	for record in records:
		if record.id==id: return record
	return {}

func _text(value: Variant) -> String:
	if value==null: return "—"
	return "%.3f" % float(value)

func _render() -> void:
	if matrix==null: return
	var record := _record()
	var count: int=record.get("steps",[]).size()
	record_step.max_value=maxi(1,count)
	if int(record.get("id",-1))!=_selected_record_id:
		_selected_record_id=int(record.get("id",-1)); record_step.set_value_no_signal(maxi(1,count))
	var previous := Observation.from_record(record,int(record_step.value)-1)
	var index: int=frames.size()-1 if step_picker.selected<=0 else step_picker.selected-1
	var current: Dictionary=frames[index] if index>=0 and index<frames.size() else {}
	display_frame=previous.duplicate(true) if history_mode.button_pressed else current.duplicate(true)
	_render_visuals(record, index)
	matrix.clear(); var root_item := matrix.create_item()
	if display_frame.is_empty():
		heading.text="Shift 영창을 입력하면 단계별 실제 수치가 표시됩니다. 실패·취소 기록도 선택해 볼 수 있습니다."
		trend.text="입력한 조작만 표시 · 정답 영창/미발견 주문 ID는 표시하지 않습니다."
		projection.text=""; plot.set_frames([]); return
	var f := display_frame
	var operator: String=Observation.OPERATORS.get(f.get("operator",""),"당시 의미 미기록")
	var attributes: String=str(f.get("context",{}).get("attributes",[]))
	heading.text=("기록 #%d · " % record.get("id",0) if history_mode.button_pressed else "실시간 · ")+"%d단계 / 입력 %s · %s / 적용 %s · 기질 미지정\n누적 조작: %s" % [f.index,f.key,operator,attributes,str(f.multiset)]
	var compared := Observation.difference(previous.get("after",{}),f.after) if not previous.is_empty() else {}
	for field in Observation.FIELDS:
		var item := matrix.create_item(root_item)
		item.set_text(0,Observation.LABELS[field])
		var values := [f.before.get(field),f.after.get(field),f.delta.get(field),f.B.get(field),f.O.get(field),f.T.get(field),f.raw.get(field),compared.get(field),f.raw_delta.get(field)]
		for column in values.size():
			item.set_text(column+1,_text(values[column])); item.set_tooltip_text(column+1,str(values[column]) if values[column]!=null else "당시 제공/기록되지 않은 값")
		if f.delta.has(field) and absf(float(f.delta[field]))>0.00000001:
			item.set_custom_color(3,Color("7ad4ef") if f.delta[field]>0 else Color("efbc79"))
	var series: Array=frames
	if history_mode.button_pressed:
		series=[]
		for i in range(int(record_step.value)): series.append(Observation.from_record(record,i))
	plot.set_frames(series)
	plot.selected_index=int(f.index)
	plot.queue_redraw()
	trend.text=Observation.describe(f)+"\n"+Observation.band(f)+" · "+str(f.get("note",""))
	var p: Dictionary=f.get("projection",{})
	projection.text=("계산된 투영: 집중 %.3f / 운동 %.3f · 안정성 추가 보정 %.3f" % [p.focus,p.motion,f.get("adjustment",{}).get("stability",0)]) if not p.is_empty() else "투영 수치 미기록"
	matrix.tooltip_text="전/후/Δ는 경계 처리된 실제 상태입니다. B/O/T/raw는 경계 처리 전 증분이며 안정성의 초기값은 별도입니다. rawΔ는 직전 입력의 raw와 비교해 상·하한에 가려진 변화도 보여줍니다. 기록Δ는 선택 기록의 입력 후와 비교합니다. 색은 증가/감소이며 좋음/나쁨 판정이 아닙니다."

func _render_visuals(record: Dictionary, live_index: int) -> void:
	var historical := history_mode.button_pressed
	var steps: Array=record.get("steps",[]) if historical else _source.get("steps",[])
	var index := int(record_step.value)-1 if historical else live_index
	var step: Dictionary=steps[index] if index>=0 and index<steps.size() else {}
	var context: Dictionary=record.get("simulation_context",{}) if historical else _source.get("context",{})
	for side in 2:
		var state: Dictionary=step.get("before" if side==0 else "after",{})
		visual_orbs[side].show_snapshot(state, 0.0, not state.is_empty() and not historical and step_picker.selected<=0, context)
		visual_orbs[side].tooltip_text="실제 저장/관측 스냅샷" if not state.is_empty() else "당시 시각 상태 미기록"
		visual_labels[side].text=("선택 입력 전" if side==0 else "선택 입력 후")+(" · 미기록" if state.is_empty() else "")
	var comparison_steps: Array=record.get("steps",[])
	var comparison_index := int(record_step.value)-1
	var comparison: Dictionary=comparison_steps[comparison_index].get("after",{}) if comparison_index>=0 and comparison_index<comparison_steps.size() else {}
	visual_orbs[2].show_snapshot(comparison,0.0,false,record.get("simulation_context",{}))
	visual_labels[2].text="기록 #%d · %d단계" % [record.get("id",0),comparison_index+1] if not comparison.is_empty() else "비교 기록 · 미기록"
