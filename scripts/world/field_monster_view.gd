extends Node2D
var actor:Dictionary
func _process(_delta:float)->void:
	position=actor.pos;visible=actor.state!="DEAD" and not actor.get("debug_hidden",false);queue_redraw()
func _draw()->void:
	if actor.is_empty():return
	draw_set_transform(Vector2(0,2),0,Vector2(1,.35));draw_circle(Vector2.ZERO,21,Color(0,0,0,.3));draw_set_transform(Vector2.ZERO)
	var stone:bool=actor.type=="SHALE";var color:=Color("90938b") if stone else Color("689b74")
	if actor.get("hit_remaining",0)>0:color=color.lerp(Color("fff1cc"),.8)
	var bob:=sin(Time.get_ticks_msec()*.005)*2
	draw_rect(Rect2(-13,-9,8,10),color.darkened(.3));draw_rect(Rect2(5,-9,8,10),color.darkened(.3))
	var body:=PackedVector2Array([Vector2(-21,-18+bob),Vector2(-15,-38+bob),Vector2(1,-45+bob),Vector2(19,-34+bob),Vector2(22,-15+bob),Vector2(10,-7+bob),Vector2(-12,-8+bob)])
	draw_colored_polygon(body,color);draw_polyline(body, color.darkened(.35),2)
	draw_circle(Vector2(-7,-25+bob),3,Color("e7e5bc"));draw_circle(Vector2(8,-25+bob),3,Color("e7e5bc"))
	draw_circle(Vector2(-7,-25+bob),1.3,Color("253c42"));draw_circle(Vector2(8,-25+bob),1.3,Color("253c42"))
	if not stone:
		draw_line(Vector2(0,-42+bob),Vector2(6,-53+bob),Color("344f35"),3);draw_colored_polygon(PackedVector2Array([Vector2(5,-49+bob),Vector2(19,-53+bob),Vector2(12,-42+bob)]),Color("9fb56e"))
	else:draw_polyline(PackedVector2Array([Vector2(-14,-34+bob),Vector2(-2,-26+bob),Vector2(2,-12+bob)]),Color("59646a"),2)
	draw_rect(Rect2(-23,-63,46,5),Color("293b3b"));draw_rect(Rect2(-22,-62,44*clampf(actor.hp/actor.max_hp,0,1),3),Color("d3a87c"))
