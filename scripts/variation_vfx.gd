extends RefCounted
## The filled core uses exactly the collision radius. Halo and wake are translucent.
static func draw(canvas:CanvasItem,missile:Dictionary,time:float)->void:
	var spell=missile.definition;var p:Vector2=missile.pos;var d:Vector2=missile.dir;var n:=d.orthogonal()
	var r:float=spell.projectile_radius;var color:Color=spell.projectile_color
	var halo:=color;halo.a=.12*spell.visual_glow;canvas.draw_circle(p,r*1.65,halo)
	var density:int=clampi(roundi(6*spell.visual_density),2,10)
	for i in density:
		var tail:Vector2=p-d*(r+float(i)*7*spell.visual_trail)+n*sin(time*12+i)*r*.20
		var fade:=color;fade.a=.45*(1-float(i)/density)
		canvas.draw_circle(tail,maxf(1,r*(.65-float(i)/density*.5)),fade)
	canvas.draw_circle(p,r,color)
	var bright:=color.lightened(.55);canvas.draw_arc(p,r*.67,d.angle()-1.4,d.angle()+1.4,18,bright,1.5)
	if spell.formula_effect.get("axis")=="pressure":
		var strength:float=spell.formula_effect.get("strength",0)
		canvas.draw_line(p-d*(25+strength*50),p+d*r,Color(.7,.95,1,.6),1+strength)
	if spell.visual_style==&"ICE_CRYSTAL" or spell.attribute==&"METAL":
		canvas.draw_colored_polygon(PackedVector2Array([p+d*r,p+n*r*.65,p-d*r,p-n*r*.65]),bright)
	elif spell.attribute==&"WOOD":
		canvas.draw_line(p-d*r,p+d*r,bright,2);canvas.draw_line(p-n*r*.7,p+n*r*.7,bright,2)
	elif spell.attribute==&"FIRE":
		canvas.draw_colored_polygon(PackedVector2Array([p+d*r*.8,p-d*r*.9+n*r*.6,p-d*r*.3,p-d*r*.9-n*r*.6]),bright)
