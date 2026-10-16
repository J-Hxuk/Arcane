extends Control
## Identical state + visual time -> identical drawing, live or archived.
const Model = preload("res://scripts/mana_visual_model.gd")
var descriptor: Dictionary = Model.project({})
var snapshot: Dictionary = {}
var visual_time := 0.0
var animated := false
var _box: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(animated)

func show_snapshot(state: Dictionary, time := 0.0, animate := false) -> void:
	var projected := Model.project(state)
	if not animate or not animated: visual_time = maxf(0.0, time)
	snapshot = state.duplicate(true)
	descriptor = projected
	animated = animate
	set_process(animate)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	visual_time = fmod(visual_time + delta, 3600.0)
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
		if collapse:
			point = point.normalized() * (0.25 + fposmod(time * 0.35 + float(i) / count, 1.0) * 0.65)
		points.append(point)
	return points

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var center := size * 0.5
	var scale_factor := minf(size.x * 0.36, size.y * 0.39)
	var ink := Color("88deed")
	draw_line(Vector2(12, center.y), Vector2(size.x - 12, center.y), Color("223747"), 1.0)
	draw_arc(center, scale_factor, 0.0, TAU, 64, Color("223747"), 1.0)
	if descriptor["presence"] <= 0.0 and not descriptor["collapsed"]:
		draw_circle(center, 2.0, Color("536b7d"))
		return
	var radius: float = descriptor["radius"] * scale_factor
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
	for i in points.size():
		var point := center + points[i] * scale_factor
		if descriptor["binding"] > 0.0 and i % 4 == 0 and not descriptor["collapsed"]:
			draw_line(point, center + points[(i + 8) % points.size()] * scale_factor, Color(ink, 0.18 + float(descriptor["binding"]) * 0.5), 1.0)
		if Vector2(descriptor["flow"]).length() > 0.0:
			draw_line(point - Vector2(descriptor["flow"]) * 7.0, point, Color(ink, 0.35), 1.3)
		draw_circle(point, 1.0 + brightness * 1.0 + float(descriptor["density"]) * 0.8, Color(ink, 0.3 + brightness * 0.65))
	if descriptor["collapsed"]:
		for i in 7:
			var direction := Vector2.from_angle(i * TAU / 7.0)
			draw_line(center + direction * scale_factor * 0.3, center + direction.rotated(0.12) * scale_factor * 0.85, Color(ink, 0.45), 1.5)

func _background() -> StyleBoxFlat:
	if _box != null: return _box
	var box := StyleBoxFlat.new()
	box.bg_color = Color("101e2d")
	box.border_color = Color("365064")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	_box = box
	return box
