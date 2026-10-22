extends RefCounted
## Cached radius-aware grid plus exact obstacle-boundary projection. No teleportation.
var grid := AStarGrid2D.new()
var rebuild_count := 0
var visited_count := 0
var _signature := ""
var _adjacency: Dictionary = {}
var radius := 13.0
var bounds := Rect2()
var shapes: Array = []
const EPSILON := 0.15

func clear_line(game, from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 4.0))
	for i in range(steps + 1):
		if game._is_blocked(from.lerp(to, float(i) / steps), radius): return false
	return true

func _prepare(game, area: Rect2, cell_size: float) -> void:
	shapes = []
	if game.get("world_enabled") == true:
		shapes = game.layout.solids.duplicate(true)
	elif game.get("walls") is Array:
		for cell in game.walls: shapes.append({"rect": game._cell_rect(cell)})
	elif game.get("solids") is Array:shapes=game.solids.duplicate(true)
	var combat = game.get("elemental_combat")
	if combat == null: combat = game.get("combat")
	if combat != null:
		for barrier in combat.barriers: shapes.append({"circle": barrier["pos"], "radius": barrier["radius"]})
	var signature := str(area) + str(cell_size) + str(radius) + str(shapes)
	if signature == _signature: return
	_signature = signature; bounds = area; _adjacency.clear()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceil(area.size.x / cell_size), ceil(area.size.y / cell_size)))
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = area.position + Vector2.ONE * cell_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			grid.set_point_solid(cell, game._is_blocked(grid.get_point_position(cell), radius))
	rebuild_count += 1

func _anchor(game, point: Vector2) -> Vector2i:
	var center := Vector2i((point - bounds.position) / grid.cell_size)
	var best := INF
	var result := Vector2i(-1, -1)
	for y in range(center.y - 2, center.y + 3):
		for x in range(center.x - 2, center.x + 3):
			var cell := Vector2i(x, y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell): continue
			var p := grid.get_point_position(cell)
			if point.distance_squared_to(p) < best and clear_line(game, point, p):
				best = point.distance_squared_to(p); result = cell
	return result

func _neighbors(game, cell: Vector2i) -> Array:
	if _adjacency.has(cell): return _adjacency[cell]
	var result: Array[Vector2i] = []
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next: Vector2i = cell + offset
		if grid.region.has_point(next) and not grid.is_point_solid(next) and clear_line(game, grid.get_point_position(cell), grid.get_point_position(next)):
			result.append(next)
	_adjacency[cell] = result
	return result

func _candidates(goal: Vector2, start: Vector2) -> Array[Vector2]:
	var safe := bounds.grow(-radius - EPSILON)
	var result: Array[Vector2] = [goal.clamp(safe.position, safe.end), start]
	for shape in shapes:
		if shape.has("rect"):
			var rect: Rect2 = shape["rect"]
			var expanded := rect.grow(radius + EPSILON)
			var p := goal.clamp(expanded.position, expanded.end)
			result.append(Vector2(expanded.position.x, p.y)); result.append(Vector2(expanded.end.x, p.y))
			result.append(Vector2(p.x, expanded.position.y)); result.append(Vector2(p.x, expanded.end.y))
			for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
				var direction: Vector2 = goal - corner
				if not direction.is_zero_approx(): result.append(corner + direction.normalized() * (radius + EPSILON))
		else:
			var center: Vector2 = shape["circle"]
			var direction := goal - center
			if direction.is_zero_approx(): direction = start - center
			if direction.is_zero_approx(): direction = Vector2.RIGHT
			result.append(center + direction.normalized() * (float(shape["radius"]) + radius + EPSILON))
	return result

func plan(game, start: Vector2, goal: Vector2, area: Rect2, cell_size: float, actor_radius := 13.0) -> Dictionary:
	radius = actor_radius
	visited_count = 0
	if not start.is_finite() or not goal.is_finite() or game._is_blocked(start, radius): return {}
	if clear_line(game, start, goal): return {"destination": goal, "waypoints": [goal] if start.distance_to(goal) > 0.5 else []}
	_prepare(game, area, cell_size)
	var origin := _anchor(game, start)
	if origin.x < 0: return {}
	# Normal reachable goals keep the existing fast AStarGrid2D path. Full
	# connected-region projection is needed only for blocked/unreachable clicks.
	if not game._is_blocked(goal, radius):
		var goal_cell := _anchor(game, goal)
		if goal_cell.x >= 0:
			var path := grid.get_point_path(origin, goal_cell)
			path.append(goal)
			var valid := path.size() > 1
			var previous := start
			for point in path:
				if not clear_line(game, previous, point): valid = false; break
				previous = point
			if valid:
				var route: Array[Vector2] = []
				previous = start
				var cursor := 0
				while cursor < path.size():
					var chosen := cursor
					for i in range(path.size()-1, cursor-1, -1):
						if clear_line(game, previous, path[i]): chosen = i; break
					previous = path[chosen]; route.append(previous); cursor = chosen+1
				return {"destination": goal, "waypoints": route}
	# Bounded flood on an input request, never every frame. Its parents also give
	# a collision-checked route to every reachable candidate, including disconnected maps.
	var parents: Dictionary = {origin: origin}
	var pending: Array[Vector2i] = [origin]
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]; cursor += 1
		for next in _neighbors(game, cell):
			if parents.has(next): continue
			parents[next] = cell; pending.append(next)
	visited_count = pending.size()
	var candidates := _candidates(goal, start)
	var closest := start
	var distance := start.distance_squared_to(goal)
	var end := origin
	# Grid points provide a fallback even when every exact boundary is occluded.
	for cell in pending:
		var point := grid.get_point_position(cell)
		if point.distance_squared_to(goal) < distance:
			closest = point; distance = point.distance_squared_to(goal); end = cell
	for point in candidates:
		var d := point.distance_squared_to(goal)
		if d > distance + 0.0001 or game._is_blocked(point, radius): continue
		var cell := _anchor(game, point)
		if not parents.has(cell): continue
		closest = point; distance = d; end = cell
	# Refine the fallback along a swept reachable segment, without crossing walls.
	var ray := closest.direction_to(goal)
	var last := closest
	for i in range(1, ceili(closest.distance_to(goal) / 2.0) + 1):
		var point := closest + ray * minf(i * 2.0, closest.distance_to(goal))
		if game._is_blocked(point, radius): break
		last = point
	if clear_line(game, closest, last): closest = last
	if start.distance_to(closest) <= 0.5: return {"destination": closest, "waypoints": []}
	var route: Array[Vector2] = [closest]
	var cell := end
	while cell != origin:
		route.push_front(grid.get_point_position(cell)); cell = parents[cell]
	route.push_front(grid.get_point_position(origin))
	var smoothed: Array[Vector2] = []
	var point := start
	while not route.is_empty():
		var chosen := -1
		for i in range(route.size() - 1, -1, -1):
			if clear_line(game, point, route[i]): chosen = i; break
		if chosen < 0: return {}
		point = route[chosen]; smoothed.append(point); route = route.slice(chosen + 1)
	return {"destination": closest, "waypoints": smoothed}
