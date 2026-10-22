extends "res://tests/preview_world_phase1.gd"
const Nav = preload("res://scripts/world/world_navigation.gd")
const Dodge = preload("res://scripts/dodge_motion.gd")
class SmallLayout:
	const BOUNDS := Rect2(0, 0, 400, 300)
	const ARENA := BOUNDS
	var solids: Array = []
class SmallGame:
	extends RefCounted
	var world_enabled := true
	var layout := SmallLayout.new()
	var elemental_combat = preload("res://scripts/elemental_combat.gd").new()
	var player_pos := Vector2(80, 150)
	func arena_locked() -> bool: return false
	func _is_blocked(point: Vector2, radius := 13.0) -> bool:
		if not layout.BOUNDS.grow(-radius).has_point(point): return true
		for shape in layout.solids:
			if shape.has("rect"):
				var rect: Rect2 = shape["rect"]
				if point.distance_to(point.clamp(rect.position, rect.end)) <= radius: return true
			elif point.distance_to(shape["circle"]) <= radius + shape["radius"]: return true
		return elemental_combat.blocks(point, radius)
	func _try_move_player(motion: Vector2) -> void:
		if not _is_blocked(player_pos + motion): player_pos += motion
func walk(model, nav) -> bool:
	for i in 2000:
		if not nav.active: return not model._is_blocked(model.player_pos)
		nav.advance(model, 0.02, 200)
		if model._is_blocked(model.player_pos): return false
	return false
func run() -> void:
	var model := SmallGame.new()
	var nav := Nav.new()
	check(nav.request(model, Vector2(150, 150)) and not nav.corrected and nav.destination == Vector2(150, 150), "Normal floor preserves the exact clicked destination")
	check(walk(model, nav) and model.player_pos.distance_to(Vector2(150, 150)) < 1, "Normal movement uses the collision-checked path")
	model.player_pos = Vector2(80, 150)
	model.layout.solids = [{"circle": Vector2(200, 150), "radius": 17.0}]
	check(nav.request(model, Vector2(200, 150)) and nav.corrected and nav.clicked_destination == Vector2(200, 150), "Tree-center click keeps raw and corrected destinations separately")
	check(absf(nav.destination.distance_to(Vector2(200, 150)) - 30.0) < 0.3 and walk(model, nav), "Tree projection reaches the nearest radius-expanded trunk boundary")
	model.player_pos = Vector2(80, 150); model.layout.solids = [{"rect": Rect2(150, 70, 100, 160)}]
	check(nav.request(model, Vector2(200, 150)) and nav.destination.distance_to(Vector2(136.85, 150)) < 0.3 and walk(model, nav), "Building interior projects to its nearest reachable outside face")
	model.player_pos = Vector2(80, 150); model.layout.solids = [{"rect": Rect2(190, 0, 20, 300)}]
	check(nav.request(model, Vector2(330, 150)) and nav.destination.x < 178 and walk(model, nav), "Unreachable floor beyond a closed wall projects to this connected component")
	check(model.player_pos.x < 178, "Corrected movement never teleports through the wall")
	check(nav.request(model, Vector2(-900, 150)) and nav.destination.x >= 13 and walk(model, nav), "Outside-map click projects inside the reachable radius-safe map")
	model.player_pos = Vector2(80, 150)
	check(nav.request(model, Vector2(100, 220)) and nav.request(model, Vector2(120, 50)) and nav.clicked_destination == Vector2(120, 50) and walk(model, nav), "Repeated RMB requests replace the previous route")
	model.player_pos = Vector2(80, 150); model.layout.solids = [{"rect": Rect2(190, 0, 20, 140)}, {"rect": Rect2(190, 160, 20, 140)}]
	check(nav.request(model, Vector2(330, 150)) and nav.destination.x < 190 and walk(model, nav), "A 20-pixel gap cannot pass a 26-pixel actor")
	var rebuilds: int = nav.rebuild_count
	for i in 10: nav.request(model, Vector2(330, 150))
	check(nav.rebuild_count == rebuilds and nav.planner.visited_count <= 120, "Repeated correction reuses the cached bounded graph")
	var requests: int = nav.request_count
	walk(model, nav)
	for i in 30: nav.advance(model, 0.02, 200)
	check(not nav.active and nav.request_count == requests, "Arrival does not repeatedly replan into the obstacle")
	check(not nav.request(model, Vector2(NAN, 0)) and not nav.active, "Invalid request cancels cleanly without a search loop")
	model.layout.solids = []
	for vector in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
		model.player_pos = Vector2(200, 150)
		var dodge := Dodge.new()
		dodge.begin(model.player_pos, Dodge.cursor_heading(model.player_pos, model.player_pos + vector * 100))
		dodge.advance(model, 0.18)
		check(model.player_pos.distance_to(Vector2(200, 150) + vector * 108) < 0.01 and not dodge.active, "Cursor-directed evasion retains 108px distance: " + str(vector))
		check(is_equal_approx(dodge.cooldown, 0.72) and not dodge.begin(model.player_pos, -vector), "Original 0.9s cooldown remains")
	for shape in [{"rect": Rect2(190, 0, 2, 300)}, {"rect": Rect2(190, 70, 80, 160)}, {"circle": Vector2(200, 150), "radius": 17.0}]:
		model.layout.solids = [shape]; model.player_pos = Vector2(140, 150)
		var dodge := Dodge.new(); dodge.begin(model.player_pos, Vector2.RIGHT); dodge.advance(model, 0.5)
		check(model.player_pos.x < 178 and not model._is_blocked(model.player_pos) and not dodge.active, "Slow-frame dodge stops before a thin wall/building/tree without skipping to the far side")
	check(Dodge.cursor_heading(Vector2.ONE, Vector2.ONE) == Vector2.RIGHT, "Overlapping cursor keeps the existing rightward safe fallback")
	print("PHASE4 MOVEMENT: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
