extends Control
## Code-drawn catalyst motifs. Cosmetic animation never changes equipped state.
const ELEMENTS=["FIRE","WATER","WOOD","METAL","EARTH",null]
const NAMES=["火 화","水 수","木 목","金 금","土 토","없음"]
const COLORS=[Color("ff9961"),Color("72d5ff"),Color("9cdb79"),Color("dee8fa"),Color("d9bb81"),Color("a8b2bf")]
static var FONT:Font=preload("res://scripts/ui_fonts.gd").UI
var game
var opacity:=0.0
var animation_time:=0.0
func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func advance(delta:float)->void:
	var target:=1.0 if game!=null and game.attribute_selector_visible() else 0.0
	opacity=move_toward(opacity,target,delta*7)
	animation_time=fmod(animation_time+delta,1000)
	queue_redraw()
func _process(delta:float)->void:advance(delta)
func _draw()->void:
	if game==null or opacity<=0:return
	var origin:=Vector2(get_viewport_rect().size.x*.5-270,get_viewport_rect().size.y-137+(1-opacity)*12)
	draw_rect(Rect2(origin,Vector2(540,116)),Color(.045,.065,.09,.97*opacity))
	draw_rect(Rect2(origin,Vector2(540,116)),Color(.5,.75,.8,.7*opacity),false,1)
	var locked:bool=game._attribute_session_locked()
	var title:String=("주속성" if game.research.selected_attribute_slot=="main" else "보조속성")+" 선택 · Alt+1~6 · Tab 대상 전환"+(" · 영창 중 고정" if locked else "")
	draw_string(FONT,origin+Vector2(13,20),title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(.9,.92,.84,opacity))
	for i in 6:
		var p:=origin+Vector2(49+i*88,62)
		var enabled:bool=game.attribute_shortcut_allowed(ELEMENTS[i]) and not locked
		var equipped=game.research.main_attribute if game.research.selected_attribute_slot=="main" else (null if game.research.auxiliary_attributes.is_empty() else game.research.auxiliary_attributes[0])
		var selected:bool=ELEMENTS[i]==equipped
		var color:Color=COLORS[i];color.a=opacity*(1.0 if enabled else .25)
		if selected:draw_rect(Rect2(p-Vector2(37,29),Vector2(74,75)),Color(.25,.42,.47,.6*opacity))
		icon(i,p+Vector2(0,sin(animation_time*2+i)*1.6),color)
		draw_string(FONT,p+Vector2(-30,37),str(i+1)+" · "+NAMES[i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
func icon(index:int,p:Vector2,color:Color)->void:
	var t:=animation_time
	match index:
		0:
			draw_rect(Rect2(p+Vector2(-15,7),Vector2(30,6)),color.darkened(.5))
			var points:=PackedVector2Array([p+Vector2(-12,7),p+Vector2(-9,-7),p+Vector2(sin(t*6)*4,-24),p+Vector2(6,-5),p+Vector2(13,7)])
			draw_colored_polygon(points,color);draw_line(p+Vector2(0,7),p+Vector2(sin(t*7)*3,-10),color.lightened(.4),3)
		1:
			draw_arc(p+Vector2(0,7),19,0,TAU,36,color.darkened(.3),4)
			for ring in 3:draw_arc(p,7+ring*5,t*(1+ring*.3)+ring,t*(1+ring*.3)+ring+PI*1.4,24,color,1.6)
		2:
			draw_rect(Rect2(p+Vector2(-3,-8),Vector2(6,23)),color.darkened(.4))
			for i in 3:draw_circle(p+Vector2((i-1)*9+sin(t*2+i)*2,-9-abs(i-1)*4),11,color)
		3:
			for i in 3:
				var x:=float(i-1)*12;var top:float=-23.0+abs(i-1)*9+sin(t*2+i)*2
				draw_colored_polygon(PackedVector2Array([p+Vector2(x-6,11),p+Vector2(x-5,top+7),p+Vector2(x,top),p+Vector2(x+6,top+7),p+Vector2(x+6,11)]),color)
				draw_line(p+Vector2(x,top+2),p+Vector2(x,8),color.lightened(.5),1)
		4:
			for i in 3:
				var q:=p+Vector2((i-1)*12,7-9*(i%2))
				draw_colored_polygon(PackedVector2Array([q+Vector2(-11,6),q+Vector2(-8,-8),q+Vector2(4,-12),q+Vector2(11,4)]),color.darkened(i*.12))
			for i in 4:draw_circle(p+Vector2(sin(t+i)*21,cos(t*.8+i)*16),1.3,color.lightened(.3))
		5:
			draw_arc(p,18,t*.2,t*.2+TAU*.9,32,color,2)
			draw_line(p+Vector2(-10,10),p+Vector2(10,-10),color,2)
