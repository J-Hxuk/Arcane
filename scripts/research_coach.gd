extends VBoxContainer
const Visibility=preload("res://scripts/research_visibility.gd")
var target:OptionButton
var feedback:Label
var meters:Array[ProgressBar]=[]
var _known:Array=[]
var advice_log:Dictionary={}
func _ready()->void:
	var title:=Label.new();title.text="관측 연구 / 스승의 조언";add_child(title)
	target=OptionButton.new();add_child(target)
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size=Vector2(280,85);feedback.add_theme_font_size_override("font_size",13);add_child(feedback)
func update_state(state:Dictionary,count:int,change:String,access:Dictionary)->void:
	if target==null:return
	var known:Array=access.get("discovered_entries",[])
	if known!=_known or target.item_count==0:
		_known=known.duplicate(true);target.clear();target.add_item("자유 관측 · 미발견 반응 탐구")
		for row in known:target.add_item(row["name"]);target.set_item_metadata(target.item_count-1,row["spell_id"])
	advice_log=preload("res://scripts/mentor_advice.gd").evaluate(state,str(access.get("main_attribute","")),access.get("resolution",{}))
	if OS.is_debug_build() and get_meta("last_advice","")!=str(advice_log):
		set_meta("last_advice",str(advice_log));print("MENTOR_STATE ",JSON.stringify(advice_log))
	feedback.text="입력 %d회 · %s\n%s"%[count,Visibility.observed(state),advice_log["text"]]
	feedback.tooltip_text="관측 상태를 설명합니다. 미발견 주문 목록이나 정답 조건은 제공하지 않습니다."
