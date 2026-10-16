extends RefCounted
## Bounded, shared immediate-mode art. Physics never reads these drawings.
## Replace this adapter with assets later without changing spell execution.

static func polygon(canvas: CanvasItem, points: Array[Vector2], color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points), color)

static func flame(canvas: CanvasItem, p: Vector2, scale: float, time: float) -> void:
	var sway := sin(time * 13.0 + p.x) * 4.0 * scale
	polygon(canvas, [p + Vector2(-9, 4) * scale, p + Vector2(-7, -10) * scale,
		p + Vector2(sway, -25 * scale), p + Vector2(7, -8) * scale, p + Vector2(10, 3) * scale], Color("ff652f"))
	polygon(canvas, [p + Vector2(-5, 4) * scale, p + Vector2(sway * 0.5, -14 * scale),
		p + Vector2(5, 4) * scale], Color("ffe68c"))
	for i in 3:
		var phase := fposmod(time * 1.8 + float(i) / 3.0, 1.0)
		canvas.draw_circle(p + Vector2(sin(i * 4.0 + time) * 12, -10 - phase * 30) * scale, (1.0 - phase) * 2.5 * scale, Color("ffbd62"))

static func projectile(canvas: CanvasItem, missile: Dictionary, time: float) -> void:
	var p: Vector2 = missile["pos"]
	var d: Vector2 = missile["dir"]
	var n := d.orthogonal()
	var definition = missile.get("definition")
	if definition == null:
		canvas.draw_line(p - d * 15, p, Color("b3d9ef"), 3.0)
		canvas.draw_circle(p, 5.0, Color("e9adff") if missile["hostile"] else Color("9eeaff"))
		return
	match str(definition.attribute):
		"FIRE":
			var length := 46.0 if definition.pierce_targets > 1 else 22.0
			polygon(canvas, [p + d * 13, p - d * length + n * (7 + sin(time * 20) * 2), p - d * (length - 8), p - d * length - n * 7], Color("ff6336"))
			polygon(canvas, [p + d * 10, p - d * length * 0.85 + n * 3, p - d * length * 0.85 - n * 3], Color("ffe799"))
			for i in 4: canvas.draw_circle(p - d * (length + i * 7) + n * sin(time * 17 + i) * 7, 2.0, Color("ed9c55"))
		"METAL":
			canvas.draw_line(p - d * 64, p, Color("71839e"), 2.0)
			polygon(canvas, [p + d * 18, p - d * 24 + n * 6, p - d * 18, p - d * 24 - n * 6], Color("cbd4df"))
			canvas.draw_line(p - d * 21, p + d * 15, Color.WHITE, 2.0)
		"WATER":
			for i in 6:
				var q := p - d * i * 7.0 + n * sin(time * 12 + i * 0.8) * i * 1.4
				canvas.draw_circle(q, 9.0 - i, Color("409fce"))
			canvas.draw_arc(p, 6.0, d.angle() - 1.4, d.angle() + 1.4, 12, Color("bcf5ff"), 2.0)
		"WOOD":
			canvas.draw_line(p - d * 30, p + d * 8, Color("8cbc64"), 4.0)
			for i in 4:
				var q := p - d * i * 7.0
				var side := n * (1 if i % 2 == 0 else -1)
				polygon(canvas, [q, q - d * 7 + side * 10, q - d * 12], Color("8ad279"))
		_: canvas.draw_circle(p, 6.0, definition.projectile_color)

static func barrier(canvas: CanvasItem, data: Dictionary) -> void:
	var p: Vector2 = data["pos"]
	var r: float = data["radius"]
	canvas.draw_circle(p + Vector2(3, 6), r + 6, Color("333333"))
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8)
		canvas.draw_line(p + d * (r + 1), p + d * (r + 12), Color("b19a76"), 2.0)
	polygon(canvas, [p + Vector2(-1, -1.15) * r, p + Vector2(-0.4, -1.4) * r,
		p + Vector2(0.5, -1.2) * r, p + Vector2(1, -0.4) * r, p + Vector2(0.8, 0.8) * r,
		p + Vector2(-0.5, 1) * r, p + Vector2(-1.1, 0.4) * r], Color("9c8c71"))
	polygon(canvas, [p + Vector2(-0.4, -1.4) * r, p + Vector2(0.5, -1.2) * r,
		p + Vector2(0.1, 0.3) * r, p + Vector2(-0.8, 0.5) * r], Color("c7b898"))
	canvas.draw_line(p + Vector2(-0.3, -0.9) * r, p + Vector2(0.1, 0.3) * r, Color("66594c"), 2.0)

static func statuses(canvas: CanvasItem, enemy: Dictionary, time: float) -> void:
	if enemy["hp"] <= 0.0: return
	var p: Vector2 = enemy["pos"]
	if enemy.get("burn_remaining", 0.0) > 0.0:
		for i in 3: flame(canvas, p + Vector2((i - 1) * 11, 9), 0.65, time + i)
	if enemy.get("root_remaining", 0.0) > 0.0:
		for side in [-1.0, 1.0]:
			var points := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				points.append(p + Vector2(side * (24 - t * 18) + sin(t * TAU * 1.8) * 11, 24 - t * 45))
			canvas.draw_polyline(points, Color("559657"), 4.0, true)
			polygon(canvas, [p + Vector2(side * 9, -7), p + Vector2(side * 29, -19), p + Vector2(side * 22, -3)], Color("9be17a"))
	if enemy.get("stagger_remaining", 0.0) > 0.0:
		canvas.draw_arc(p, 23.0, time * 5, time * 5 + 4.5, 24, Color("dec8ff"), 2.0)

static func impact(canvas: CanvasItem, data: Dictionary, time: float) -> void:
	var p: Vector2 = data["pos"]
	var t: float = 1.0 - data["life"] / data["total"]
	var r: float = lerpf(7, data["radius"], t)
	var color: Color = data["color"]
	color.a = 1.0 - t * 0.8
	match str(data.get("attribute", "VOID")):
		"WATER":
			if data.has("to"):
				var destination: Vector2 = data["to"]
				for i in 7:
					var fraction := i / 6.0
					canvas.draw_circle(p.lerp(destination, fraction), 2.5 * (1.0 - t), color)
			for i in 10:
				var d := Vector2.from_angle(i * TAU / 10)
				canvas.draw_line(p + d * r * 0.55, p + d * r, color, 3.0)
				canvas.draw_circle(p + d * r, 3.0 * (1.0 - t), Color("b5f0ff"))
			canvas.draw_arc(p, r * 0.7, 0, TAU, 32, color, 2.0)
		"FIRE":
			for i in 8: flame(canvas, p + Vector2.from_angle(i * TAU / 8) * r * 0.7, (1.0 - t) * 0.85 + 0.2, time + i)
			canvas.draw_arc(p, r, 0, TAU, 40, color, 4.0)
		"METAL":
			for i in 6:
				var d := Vector2.from_angle(i * TAU / 6)
				canvas.draw_line(p + d * r * 0.3, p + d * r, color, 2.0)
		"WOOD":
			canvas.draw_arc(p, r, 0, TAU, 24, color, 2.0)
		_:
			for ring in 3:
				var points := PackedVector2Array()
				for i in 49:
					var a := i * TAU / 48
					points.append(p + Vector2.from_angle(a) * maxf(2, r - ring * 9 + sin(a * 5 + time * 10) * 4))
				canvas.draw_polyline(points, color, 2.0, true)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8)
				canvas.draw_line(p + d * r * 0.75, p + d * r, color, 2.0)
