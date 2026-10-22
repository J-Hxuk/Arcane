extends RefCounted
## Single-pass bounded 2D geometry. Core radius is the actual collision radius.
static func projectile(c,m:Dictionary,t:float)->bool:
	var d=m.get("definition")
	if d==null or not d.formula_effect.get("water15",false):return false
	if m.get("launch_delay",0)>0:return true
	var p:Vector2=m.pos;var v:Vector2=m.dir;var n:=v.orthogonal();var r:float=d.projectile_radius
	var id:=str(d.spell_id);var a:float=d.formula_effect.get("strength",0)
	var trail:PackedVector2Array=PackedVector2Array(m.get("trail_points",[]))
	if trail.size()>1:c.draw_polyline(trail,Color(.2,.65,.85,.45),maxf(1,r*.65),true)
	var length:float={"OH-061":24,"OH-062":42,"OH-064":70,"OH-069":36,"OH-070":95,"OH-074":125,"OH-075":55}.get(id,35)
	# Glow and spray are decorative; only the solid head is a damaging core.
	c.draw_line(p-v*length,p,Color(.12,.38,.65,.4),r*2.5)
	c.draw_line(p-v*length*.8,p,Color(.38,.88,1,.75),maxf(1,r*.55))
	c.draw_circle(p,r,Color("73e4fa"));c.draw_arc(p,r,-PI,PI,18,Color("defcff"),1.2)
	for i in mini(12,int(5*d.visual_density)):
		var fraction:=float(i+1)/12
		var q:=p-v*length*fraction+n*sin(t*13+i*2)*r*(1+fraction)
		c.draw_circle(q,1.1+fraction,Color(.65,.94,1,.6))
	if id in ["OH-070","OH-074"]:
		c.draw_line(p-v*length*.6,p+v*r,Color.WHITE,1.3)
		for side in [-1,1]:c.draw_line(p-v*length*.4+n*(r+3)*side,p-v*length+n*(r+7)*side,Color(.5,.85,1,.5),1)
	if id=="OH-074":
		for i in 3:c.draw_arc(p-v*(i+1)*25,r+5+i*3,v.angle()-1.4,v.angle()+1.4,18,Color(.65,.95,1,.8),1.5)
	if a>.001:c.draw_arc(p,r+4,t*6,t*6+PI*a,20,Color(.9,1,1,.7),1)
	return true
static func area(c,data:Dictionary,t:float)->void:
	var p:Vector2=data.pos;var r:float=maxf(1,data.radius);var id:String=data.get("attribute","")
	var effect:Dictionary=data.get("formula_effect",{});var a:float=effect.get("strength",0)
	var phase:float=1-float(data.life)/maxf(.001,float(data.total))
	var opacity:=clampf(1-phase,0,1)
	if data.get("kind","") in ["release","pressure","deflect"]:opacity*=a
	var ink:=Color(.3,.8,.96,.7*opacity);var white:=Color(.8,1,1,.9*opacity)
	if data.get("kind")=="release":
		var extra_radius:float=preload("res://scripts/water_spell_catalog.gd").DATA.physics.ring_extra_radius
		for i in 3:c.draw_arc(p,maxf(1,(r+extra_radius*a)*minf(1,phase*1.5)-i*4),0,TAU,56,white,2)
		return
	match id:
		"OH-065":
			var points:=PackedVector2Array()
			var dir:Vector2=data.get("dir",Vector2.RIGHT)
			for i in 25:
				var f:=i/24.0;points.append(p+dir*r*f+dir.orthogonal()*sin(f*PI*1.5+phase*2)*r*.22)
			c.draw_polyline(points,ink,10*(1-phase)+1,true);c.draw_polyline(points,white,2,true)
		"OH-068","OH-071","OH-073":
			c.draw_circle(p,r,Color(.03,.18,.35,.13*opacity))
			var arms:int=8 if id=="OH-073" else (5 if id=="OH-071" else 3)
			for arm in arms:
				var points:=PackedVector2Array()
				for i in 25:
					var f:=i/24.0;var angle:float=arm*TAU/arms+f*PI*(1.1+a)+t*(1 if arm%2==0 or id!="OH-073" else -1)
					points.append(p+Vector2.from_angle(angle)*r*(.1+.9*f))
				c.draw_polyline(points,ink,3,true)
				c.draw_circle(points[-1],2.5,white)
			c.draw_arc(p,r,0,TAU,64,ink,1)
		"OH-072":
			c.draw_circle(p,r,Color(.1,.4,.65,.16*opacity))
			for i in 5:
				var points:=PackedVector2Array()
				for j in 33:
					var angle:=j*TAU/32;points.append(p+Vector2(cos(angle)*r,sin(angle)*r*(.2+i*.16)))
				c.draw_polyline(points,white if i==4 else ink,1.3,true)
		_:
			for i in 12:
				var v:=Vector2.from_angle(i*TAU/12+phase*.3)
				c.draw_line(p+v*r*phase*.6,p+v*r*phase,ink,2)
				c.draw_circle(p+v*r*phase,2,white)
			c.draw_arc(p,r*phase,0,TAU,40,ink,2)
static func states(c,list:Array,t:float)->void:
	for s in list:
		var d=s.definition
		if s.kind!="shield":continue
		if s.id=="OH-066":
			for layer in 3:
				c.draw_arc(s.pos,s.radius-layer*4,t*(layer+1)*.8,t*(layer+1)*.8+PI*1.65,48,Color(.35,.8,1,.55-layer*.1),2)
			for i in 8:c.draw_circle(s.pos+Vector2.from_angle(t+i*TAU/8)*s.radius,2,Color("dcffff"))
		else:
			var n:Vector2=Vector2(s.dir).orthogonal()
			for layer in 4:
				var points:=PackedVector2Array()
				for i in 25:
					var f:=i/24.0;points.append(s.pos+n*(f*2-1)*s.radius+Vector2(s.dir)*(sin(f*TAU+t*4+layer)*4+layer*3-6))
				c.draw_polyline(points,Color(.35,.8,1,.55),2,true)
			c.draw_arc(s.pos,14,t*3,t*3+TAU*.8,24,Color("b4f9ff"),2)
