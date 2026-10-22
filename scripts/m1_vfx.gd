extends RefCounted
## Original geometric silhouettes for the ten new M1 spells; no external assets.
static func projectile(canvas: CanvasItem, missile: Dictionary, time: float) -> bool:
	var definition = missile.get("definition")
	if definition == null: return false
	var style := str(definition.visual_style)
	if style not in ["SPLINTER", "FLINTSHOT", "SHARDSHOT", "LODESTONE", "DROPLET"]: return false
	var p: Vector2 = missile["pos"]; var d: Vector2 = missile["dir"]; var n := d.orthogonal()
	match style:
		"SPLINTER":
			canvas.draw_colored_polygon(PackedVector2Array([p+d*17, p-d*18+n*5, p-d*11, p-d*18-n*4]), Color("bca276"))
			canvas.draw_line(p-d*13, p+d*10, Color("67523c"), 2)
			for i in 3: canvas.draw_line(p-d*(22+i*9)+n*3, p-d*(26+i*9), Color("8a9d65"), 2)
		"FLINTSHOT":
			var points := PackedVector2Array()
			for i in 6: points.append(p + Vector2.from_angle(i*TAU/6+time*7)*10)
			canvas.draw_colored_polygon(points, Color("b4ad91"))
			canvas.draw_line(points[1], points[4], Color("68756e"), 3)
			for i in 4: canvas.draw_circle(p-d*(16+i*8)+n*sin(i+time)*5, 2, Color("81796a"))
		"SHARDSHOT":
			canvas.draw_colored_polygon(PackedVector2Array([p+d*10, p+n*4, p-d*8, p-n*4]), Color("e6ebda"))
			canvas.draw_line(p-d*40, p-d*10, Color("8999ac"), 1)
			canvas.draw_line(p+n*8, p-n*8, Color.WHITE, 1)
		"LODESTONE":
			canvas.draw_arc(p, 9, d.angle()+0.4, d.angle()+TAU-0.4, 24, Color("b9b5d7"), 4)
			for i in 3: canvas.draw_arc(p-d*(12+i*8), 7+i*3, d.angle()+1, d.angle()+5.3, 20, Color("a49bc1"), 1)
		"DROPLET":
			for i in 4:
				var q := p-d*i*11+n*sin(time*12+i)*2
				canvas.draw_circle(q, 5-i*0.7, Color("69c9e3")); canvas.draw_circle(q+Vector2(-1,-1), 1.5, Color("d8ffff"))
	return true

static func impact(canvas: CanvasItem, data: Dictionary) -> bool:
	var style := str(data.get("attribute", ""))
	if style not in ["ROOT_FLICK", "CINDER_SWEEP", "FLASHPOINT", "FAULTSTEP", "EBBPULSE"]: return false
	var p: Vector2 = data["pos"]; var d: Vector2 = data.get("dir", Vector2.RIGHT)
	var t: float = 1-float(data["life"])/data["total"]; var radius: float = data["radius"]
	var fade := 1.0-t
	match style:
		"ROOT_FLICK":
			for i in 5:
				var ray := d.rotated((i-2)*0.23)
				var points := PackedVector2Array([p, p+ray*radius*0.3+Vector2(0,-9), p+ray*radius*0.7, p+ray*radius+Vector2(0,-16*fade)])
				canvas.draw_polyline(points, Color(0.5,0.7,0.35,fade), 4)
		"CINDER_SWEEP":
			var points := PackedVector2Array([p])
			for i in 17: points.append(p+d.rotated(-1+float(i)/8)*radius*(0.5+t*0.5))
			canvas.draw_colored_polygon(points, Color(1,0.32,0.12,fade*0.65))
			for i in 9: canvas.draw_line(p+d.rotated((i-4)*0.23)*radius*0.4, p+d.rotated((i-4)*0.23)*radius, Color(1,0.8,0.35,fade), 3)
		"FLASHPOINT":
			canvas.draw_circle(p, radius*(1-t), Color(1,0.94,0.7,fade))
			for i in 4:
				var ray := Vector2.from_angle(i*PI/2)
				canvas.draw_line(p-ray*radius*(1+t), p+ray*radius*(1+t), Color(1,0.6,0.2,fade), 2)
		"FAULTSTEP":
			for i in 5:
				var q := p+d.rotated((i-2)*0.22)*radius*0.8
				canvas.draw_colored_polygon(PackedVector2Array([q+Vector2(-9,4),q+Vector2(-7,-18*fade),q+Vector2(6,-22*fade),q+Vector2(11,5)]), Color(0.6,0.54,0.4,fade))
				canvas.draw_line(p+d*12,q,Color(0.35,0.31,0.23,fade),2)
		"EBBPULSE":
			for i in 3: canvas.draw_arc(p,maxf(1,radius*t-i*12),0,TAU,48,Color(0.4,0.85,0.95,fade),3)
			for i in 12:
				var ray := Vector2.from_angle(i*TAU/12)
				canvas.draw_circle(p+ray*radius*t,3*fade,Color(0.8,0.98,1,fade))
	return true
