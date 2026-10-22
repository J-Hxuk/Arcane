extends RefCounted
## Shared cached radius-aware planning for the legacy dungeon, lab and world.
## Uses the existing actor collision query, including temporary earth barriers.
var active := false
var destination := Vector2.ZERO
var waypoints: Array[Vector2] = []
var direction := Vector2.ZERO
var feedback := ""
var clicked_destination := Vector2.ZERO
var corrected := false
var request_count := 0
var planner := preload("res://scripts/reachable_navigation.gd").new()

func cancel() -> void:
	active = false
	waypoints.clear()
	direction = Vector2.ZERO

func clear_line(game, from: Vector2, to: Vector2) -> bool:
	var count := maxi(1, ceili(from.distance_to(to) / 5.0))
	for i in range(1, count + 1):
		if game._is_blocked(from.lerp(to, float(i) / count), 13.0): return false
	return true

func _center(game, cell: Vector2i) -> Vector2:
	return game.AREA.position + (Vector2(cell) + Vector2(0.5, 0.5)) * game.TILE

func _anchor(game, point: Vector2) -> Vector2i:
	var chosen := Vector2i(-1, -1)
	var best := INF
	for y in game.ROWS:
		for x in game.COLS:
			var cell := Vector2i(x, y)
			var center := _center(game, cell)
			var distance := point.distance_squared_to(center)
			if distance < best and not game._is_blocked(center) and clear_line(game, point, center):
				chosen = cell
				best = distance
	return chosen

func _navigation_bounds(game) -> Rect2: return game.AREA
func _navigation_cell_size() -> float: return 40.0
func _navigation_radius() -> float: return 13.0

func request(game, goal: Vector2) -> bool:
	return request_from(game, game.player_pos, goal)

func request_from(game, start: Vector2, goal: Vector2) -> bool:
	cancel()
	clicked_destination = goal
	destination = start
	request_count += 1
	var result := planner.plan(game, start, goal, _navigation_bounds(game), _navigation_cell_size(), _navigation_radius())
	if result.is_empty():
		feedback = "이동 불가 · 연결된 유효 위치가 없습니다"
		return false
	destination = result["destination"]
	corrected = not destination.is_equal_approx(clicked_destination)
	waypoints.assign(result["waypoints"])
	active = not waypoints.is_empty()
	feedback = "도달 가능한 가까운 위치로 보정" if corrected else "목적지로 이동"
	return true

func advance(game, delta: float, speed: float) -> void:
	if not active or delta <= 0.0: return
	# Replan only when the next segment changes (e.g. a newly raised barrier).
	if not clear_line(game, game.player_pos, waypoints[0]):
		if not request(game, clicked_destination): return
	var budget := speed * delta
	while active and budget > 0.0:
		var offset: Vector2 = waypoints[0] - game.player_pos
		var distance := offset.length()
		if distance <= 0.5:
			waypoints.pop_front()
			if waypoints.is_empty(): cancel(); return
			continue
		direction = offset.normalized()
		var step := minf(distance, budget)
		var before: Vector2 = game.player_pos
		game._try_move_player(direction * step)
		budget -= step
		if game.player_pos.distance_to(before) < step * 0.5:
			cancel()
			feedback = "이동 정지 · 경로가 막혔습니다"
			return
		if game.player_pos.distance_to(waypoints[0]) <= 0.5:
			waypoints.pop_front()
			if waypoints.is_empty(): cancel()
