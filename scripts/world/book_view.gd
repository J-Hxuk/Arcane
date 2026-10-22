extends Control
## Original open-book diagram, using different geometry for each of the five elements.
var element := "WOOD"
var page := 0
static var FONT:Font=preload("res://scripts/ui_fonts.gd").BOOK
var text_label:Label
var heading:Label
var scroller:ScrollContainer
const TITLES := {"WOOD":"木 · 뿌리와 성장", "FIRE":"火 · 발열과 연소", "EARTH":"土 · 지반과 방벽", "METAL":"金 · 금속과 자력", "WATER":"水 · 수류와 압력"}
func _ready() -> void:
	custom_minimum_size = Vector2(640,310);size_flags_vertical=Control.SIZE_EXPAND_FILL;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_PASS
	var margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,28)
	var spread=HBoxContainer.new();spread.add_theme_constant_override("separation",28);margin.add_child(spread)
	var illustration=Control.new();illustration.size_flags_horizontal=Control.SIZE_EXPAND_FILL;illustration.size_flags_stretch_ratio=.8;spread.add_child(illustration)
	var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.size_flags_stretch_ratio=1.2;spread.add_child(content)
	heading=Label.new();heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.add_theme_font_override("font",FONT);heading.add_theme_font_size_override("font_size",20);heading.add_theme_color_override("font_color",Color("465346"));content.add_child(heading)
	scroller=ScrollContainer.new();scroller.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroller)
	text_label=Label.new();text_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text_label.add_theme_font_override("font",FONT);text_label.add_theme_font_size_override("font_size",19);text_label.add_theme_constant_override("line_spacing",7);text_label.add_theme_color_override("font_color",Color("3b493e"));scroller.add_child(text_label)
	resized.connect(queue_redraw)
func _draw() -> void:
	var split:=size.x*.4
	draw_rect(Rect2(10, 15, size.x-20, size.y-18), Color("493e33"))
	draw_rect(Rect2(20, 10, split-22, size.y-20), Color("d0c5a5"))
	draw_rect(Rect2(split+2, 10, size.x-split-22, size.y-20), Color("ded2b1"))
	draw_line(Vector2(split,15),Vector2(split,size.y-15),Color("8d826b"),4)
	draw_string(FONT, Vector2(35, 56), TITLES[element], HORIZONTAL_ALIGNMENT_LEFT, split-50, 20, Color("3b493e"))
	var p := Vector2(split*.5,size.y*.5)
	match element:
		"WOOD":
			draw_line(p+Vector2(0,65),p-Vector2(0,65),Color("5a6950"),7)
			for i in 5:
				var side := -1 if i%2 else 1
				var q := p+Vector2(0,i*22-50)
				draw_colored_polygon(PackedVector2Array([q,q+Vector2(side*65,-35),q+Vector2(side*45,8)]),Color("6f9161"))
				for j in 3: draw_line(p+Vector2(0,65),p+Vector2((j-1)*45,100),Color("83664b"),3)
		"FIRE":
			preload("res://scripts/spell_vfx.gd").flame(self,p+Vector2(0,40),3.0,page*0.6)
			for i in 4: draw_arc(p,85+i*7,-2.6,-0.6,30,Color("aa684c"),2)
		"EARTH":
			for i in 4:
				var q := p+Vector2((i-2)*40,35)
				draw_colored_polygon(PackedVector2Array([q+Vector2(-17,35),q+Vector2(-15,-55+i*10),q+Vector2(12,-65+i*10),q+Vector2(22,35)]),Color("8b8067"))
				draw_line(q+Vector2(-15,-55+i*10),q+Vector2(12,-65+i*10),Color("b8a47d"),4)
		"METAL":
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-80),p+Vector2(35,35),p+Vector2(0,65),p+Vector2(-35,35)]),Color("899a9d"))
			for i in 3: draw_arc(p,65+i*13,0.3,TAU-0.3,40,Color("78718e"),2)
		"WATER":
			for i in 5:
				var points := PackedVector2Array()
				for j in 30: points.append(p+Vector2(j*6-85,sin(j*0.3+page)*12+i*22-40))
				draw_polyline(points,Color("4b8b9a"),4)
	var labels := ["1. 개화의 옛 증언", "2. 결락된 술법의 기록"]
	if heading!=null:heading.text=labels[page]
	# Actual readable page text is a child Label. Decorative fake text lines
	# underneath it would cross out the research clues.
	draw_string(FONT,Vector2(split-65,size.y-24),"%d / 2" % (page+1),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("655f4d"))
