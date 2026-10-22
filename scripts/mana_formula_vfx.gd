extends RefCounted
## The same physical radius is the boundary. No unrelated elemental bonus VFX.
static func area(canvas:CanvasItem,data:Dictionary,time:float)->void:
	var p:Vector2=data.pos;var radius:float=data.radius
	var effect:Dictionary=data.formula_effect;var strength:float=effect.get("strength",0)
	var color:=Color(.3,.8,1,.6);var count:=int(4+strength*5)
	canvas.draw_circle(p,radius,Color(.1,.5,.9,.08))
	canvas.draw_arc(p,radius,0,TAU,64,Color(.5,.9,1,.7),1.5)
	for i in count:
		var r:=radius*(.25+.7*float(i+1)/count)
		var angle:=time*(2+strength*4)+i*.8
		if effect.axis=="circulation":
			canvas.draw_arc(p,r,angle,angle+PI*1.2,32,color,1.5+strength)
			canvas.draw_line(p+Vector2.from_angle(angle)*r,p+Vector2.from_angle(angle-.25)*r*.75,color,2)
		else:
			canvas.draw_arc(p,r,angle,angle+PI*1.6,32,color,1.5+strength)
			canvas.draw_line(p+Vector2(-r,-radius*.4),p+Vector2(r,radius*.4),Color(.4,.8,1,.2),1)
