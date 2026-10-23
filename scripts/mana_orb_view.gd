extends Control
## Identical state + visual time -> identical drawing, live or archived.
const Model = preload("res://scripts/mana_visual_model.gd")
var descriptor: Dictionary = Model.project({})
var snapshot: Dictionary = {}
var visual_time := 0.0
var animated := false
var observation_gain := 1.0
var transparent_view := false
var target_descriptor: Dictionary = {}
var _transition_from: Dictionary = {}
var _transition_elapsed := 0.18
const TRANSITION_SECONDS := 0.18
var _box: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(animated)

func show_snapshot(state: Dictionary, time := 0.0, animate := false, context: Dictionary = {}) -> void:
	var projected := Model.project(state, context)
	if projected != target_descriptor:
		_transition_from = descriptor.duplicate(true)
		target_descriptor = projected.duplicate(true)
		_transition_elapsed = 0.0 if animate and animated else TRANSITION_SECONDS
	if not animate: _transition_elapsed = TRANSITION_SECONDS
	if not animate or not animated: visual_time = maxf(0.0, time)
	snapshot = state.duplicate(true)
	descriptor = projected if _transition_elapsed >= TRANSITION_SECONDS else descriptor
	animated = animate
	set_process(animate)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	visual_time = fmod(visual_time + delta, 3600.0)
	if _transition_elapsed >= TRANSITION_SECONDS:
		queue_redraw()
		return
	_transition_elapsed = minf(TRANSITION_SECONDS, _transition_elapsed + delta)
	if _transition_elapsed >= TRANSITION_SECONDS:
		descriptor = target_descriptor.duplicate(true)
		queue_redraw()
		return
	var weight := smoothstep(0.0, TRANSITION_SECONDS, _transition_elapsed)
	descriptor = target_descriptor.duplicate(true)
	for field in target_descriptor:
		if target_descriptor[field] is float or target_descriptor[field] is Vector2:
			descriptor[field] = lerp(_transition_from.get(field, target_descriptor[field]), target_descriptor[field], weight)
	queue_redraw()

func particle_points(time: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var presence: float = descriptor["presence"]
	var radius: float = descriptor["radius"]
	var flow: Vector2 = descriptor["flow"]
	var count := 64 if presence > 0.0 else 0
	var collapse: bool = descriptor["collapsed"]
	for i in count:
		var angle := float(i) * 2.399963 + time * (0.12 + float(descriptor["orbit"]) * 1.1)
		var distance := sqrt(float(i + 1) / count) * radius
		var point := Vector2.from_angle(angle) * distance
		point *= 1.0 + float(descriptor["dispersion"]) * 0.4 * fposmod(time * 0.4 + float(i) / count, 1.0)
		var jitter: float = descriptor["jitter"]
		point += Vector2(sin(time * 13.0 + i * 4.3), cos(time * 17.0 + i * 2.7)) * jitter * 0.28
		if descriptor["lobes"] > 1:
			point *= 0.45
			point += Vector2.from_angle(TAU * (i % int(descriptor["lobes"])) / descriptor["lobes"]) * 0.48
		point += flow * (fposmod(time * 0.9 + float(i) / count, 1.0) - 0.5) * 0.7
		point.y*=1.0+float(descriptor.get("spread",0))*0.4
		point*=1.0-float(descriptor.get("anchoring",0))*0.2
		if collapse:
			point = point.normalized() * (0.25 + fposmod(time * 0.35 + float(i) / count, 1.0) * 0.65)
		points.append(point)
	return points

func _draw() -> void:
	if not transparent_view: draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var center := size * 0.5
	var scale_factor := minf(size.x * 0.36, size.y * 0.39)
	var ink := Color("88deed")
	var trace: Dictionary = descriptor["reaction"]
	if not str(trace["element"]).is_empty(): ink = ink.lerp(Model.COLORS.get(trace["element"], Color("a4d8f0")), minf(1, float(trace["strength"]) * observation_gain))
	if not transparent_view:
		draw_line(Vector2(12, center.y), Vector2(size.x - 12, center.y), Color("223747"), 1.0)
		draw_arc(center, scale_factor, 0.0, TAU, 64, Color("223747"), 1.0)
	if descriptor["presence"] <= 0.0 and not descriptor["collapsed"]:
		draw_circle(center, 2.0, Color("536b7d"))
		return
	var radius: float = descriptor["radius"] * scale_factor
	if snapshot.get("binding_window", false):
		for i in 4: draw_arc(center, maxf(12, radius * 1.6), visual_time + i * PI / 2, visual_time + i * PI / 2 + 0.8, 12, Color("e7d7ae"), 2.0)
	var brightness: float = descriptor["brightness"]
	if descriptor["collapsed"]: ink = Color("aa9fae")
	var offset: Vector2 = descriptor["flow"] * sin(visual_time * 0.8) * scale_factor * 0.12
	center += offset
	if not descriptor["collapsed"]:
		for layer in range(4, 0, -1):
			draw_circle(center, maxf(3.0, radius * (1.0 + layer * 0.14)), Color(ink, brightness * 0.025))
		if descriptor["form"] > 0.0:
			draw_arc(center, maxf(4.0, radius * 1.12), 0.0, TAU * float(descriptor["form"]), 48, Color(ink, 0.75), 1.5)
		if descriptor["orbit"] > 0.0:
			var angle := visual_time * (0.4 + float(descriptor["orbit"]))
			draw_arc(center, maxf(7.0, radius * 1.35), angle, angle + PI * 1.5, 40, Color(ink, 0.7), 2.0)
	var points := particle_points(visual_time)
	var previous_points := particle_points(visual_time - 0.08) if observation_gain > 1.0 else PackedVector2Array()
	if descriptor.get("persistence",0)>0:
		draw_arc(center,maxf(4,radius*1.22),0,TAU,48,Color(ink,minf(0.6,descriptor["persistence"]*0.3)),1.0)
	for i in points.size():
		var point := center + points[i] * scale_factor
		if descriptor["binding"] > 0.0 and i % 4 == 0 and not descriptor["collapsed"]:
			draw_line(point, center + points[(i + 8) % points.size()] * scale_factor, Color(ink, 0.18 + float(descriptor["binding"]) * 0.5), 1.0)
		if Vector2(descriptor["flow"]).length() > 0.0:
			draw_line(point - Vector2(descriptor["flow"]) * (7.0 * observation_gain), point, Color(ink, minf(0.65, 0.35 * observation_gain)), 1.3)
		if observation_gain > 1.0 and i % 4 == 0:
			var previous := center + previous_points[i] * scale_factor
			draw_line(previous, point, Color(ink, 0.45), 1.0)
		draw_circle(point, 1.0 + brightness * 1.0 + float(descriptor["density"]) * 0.8, Color(ink, 0.3 + brightness * 0.65))
	if descriptor["collapsed"]:
		for i in 7:
			var direction := Vector2.from_angle(i * TAU / 7.0)
			draw_line(center + direction * scale_factor * 0.3, center + direction.rotated(0.12) * scale_factor * 0.85, Color(ink, 0.45), 1.5)
	elif trace["stage"] != "none":
		_draw_reaction(center, radius, ink, trace)

func _draw_reaction(center: Vector2, radius: float, ink: Color, trace: Dictionary) -> void:
	var amount: float = trace["strength"]
	var count := 8 if trace["stage"] == "stable" else maxi(2, roundi(amount * 6))
	var reach := maxf(10, radius) * (0.5 + amount * 0.7)
	ink.a = minf(1, (0.25 + amount * 0.7) * observation_gain)
	for i in count:
		var angle := i * TAU / count + visual_time * 0.3
		var d := Vector2.from_angle(angle)
		var n := d.orthogonal()
		var p := center + d * reach
		match str(trace["element"]):
			"BINDING":
				var components: Array = trace.get("elements", [])
				var left: Color = Model.COLORS.get(components[0], Color.WHITE)
				var right: Color = Model.COLORS.get(components[1], Color.WHITE)
				var spread := 0.3 if trace["stage"] == "stable" else 0.65
				var a := center + d.rotated(spread) * reach
				var b := center + d.rotated(-spread) * reach
				draw_circle(a, 3.5, left)
				draw_circle(b, 3.5, right)
				draw_line(a, b, left.lerp(right, 0.5), 2.0 if trace["stage"] == "stable" else 1.0)
				draw_line(a, center - d * reach * 0.5, right, 1.2)
			"FIRE":
				var tip := p + Vector2(sin(visual_time * 9 + i) * 3, -8 - amount * 12)
				draw_colored_polygon(PackedVector2Array([p - Vector2(4, 0), tip, p + Vector2(4, 0)]), ink)
			"WATER":
				var wave := PackedVector2Array()
				for j in 13: wave.append(center + Vector2((j - 6) * reach / 6, sin(j * 0.8 + visual_time * 3 + i) * (3 + amount * 4) + (i - count / 2.0) * 6))
				draw_polyline(wave, ink, 1.5, true)
			"WOOD":
				draw_line(center + d * reach * 0.35, p + d * 8, ink, 1.8)
				draw_line(p, p + n * 7 - d * 6, ink, 2.0)
				draw_line(p - d * 6, p - n * 8 - d * 10, ink, 2.0)
			"EARTH":
				draw_colored_polygon(PackedVector2Array([p - d * 5 - n * 4, p + d * 5 - n * 3, p + d * 6 + n * 4, p - d * 4 + n * 5]), ink)
			"METAL":
				draw_line(p - d * 7, p + d * 7, ink, 2.0)
				draw_line(p - n * 4, p + n * 4, Color(1, 1, 1, ink.a), 1.2)
			"VOID":
				var ripple := PackedVector2Array()
				for j in 25:
					var a := j * TAU / 24
					ripple.append(center + Vector2.from_angle(a) * (reach + sin(a * 5 + visual_time * 4) * 3 + i * 3))
				draw_polyline(ripple, ink, 1.0, true)
	if trace["stage"] == "unstable": draw_arc(center, reach + 8, visual_time * 4, visual_time * 4 + 2, 16, Color("ffc58a"), 2.5)

func _background() -> StyleBoxFlat:
	if _box != null: return _box
	var box := StyleBoxFlat.new()
	box.bg_color = Color("101e2d")
	box.border_color = Color("365064")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	_box = box
	return box
