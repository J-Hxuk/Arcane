extends Control
var game
var drawing_rect:=Rect2()
static var FONT:Font=preload("res://scripts/ui_fonts.gd").UI
func _ready()->void:custom_minimum_size=Vector2(760,440);mouse_filter=Control.MOUSE_FILTER_IGNORE
func map_point(point:Vector2)->Vector2:
	return drawing_rect.position+(point-game.Layout.BOUNDS.position)/game.Layout.BOUNDS.size*drawing_rect.size
func _process(_delta:float)->void:queue_redraw()
func _draw()->void:
	if game==null:return
	drawing_rect=Rect2(Vector2(28,35),size-Vector2(56,70))
	draw_style_box(_paper(),Rect2(Vector2.ZERO,size))
	var bounds:Rect2=game.Layout.BOUNDS
	for region in [{"rect":Rect2(0,-960,3840,1040),"color":Color("526d55")},{"rect":Rect2(0,80,1620,1840),"color":Color("75836b")},{"rect":Rect2(1620,80,1340,1840),"color":Color("6c7559")},{"rect":Rect2(2960,80,880,1840),"color":Color("6a6b65")}]:
		var r:Rect2=region.rect;draw_rect(Rect2(map_point(r.position),r.size/bounds.size*drawing_rect.size),region.color)
	for solid in game.layout.solids:
		if solid.has("rect"):
			var r:Rect2=solid.rect;draw_rect(Rect2(map_point(r.position),r.size/bounds.size*drawing_rect.size),Color("374c4b"))
		else:draw_circle(map_point(solid.circle),2,Color("314f3b"))
	for mark in [{"name":"연구실","pos":game.Layout.LAB_DOOR},{"name":"대장간","pos":Vector2(1150,1180)},{"name":"마을","pos":Vector2(790,760)},{"name":"북쪽 들판","pos":Vector2(790,-550)},{"name":"수호 기사의 폐허","pos":Vector2(3350,900)}]:
		var point:=map_point(mark.pos);draw_circle(point,4,Color("e1c78f"))
		var width:=FONT.get_string_size(mark.name,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		var label:=Vector2(clampf(point.x+7,drawing_rect.position.x,drawing_rect.end.x-width-4),point.y-8)
		draw_string(FONT,label,mark.name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f1dfb8"))
	var player:=map_point(game.player_pos);draw_circle(player,8,Color("243c47"));draw_circle(player,5,Color("a9eeeb"));draw_arc(player,10,0,TAU,24,Color("e8f5d1"),1)
	draw_string(FONT,Vector2(30,size.y-13),"◆ 현재 위치    ·    북쪽 ↑    ·    M으로 닫기",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ead8b0"))
func _paper()->StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=Color("263b40");style.border_color=Color("b09b69");style.set_border_width_all(3);style.set_corner_radius_all(8);return style
