extends RefCounted
## Four timed physical attacks. No elemental identity, summons or random instant hits.
const HOME := Vector2(3380, 910)
const Navigation = preload("res://scripts/world/world_navigation.gd")
var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/ruin_guardian.json"))
var actor: Dictionary = {}
var active := false
var state := "DORMANT"
var pattern := "SWEEP"
var phase := 1
var timer := 0.0
var cursor := 0
var aim := Vector2.LEFT
var target := HOME
var _hit := false
var _executed := false
var metrics: Dictionary = {}
var navigation := Navigation.new()
var replan_remaining := 0.0

func start(game) -> void:
	actor = {"boss": true, "pos": HOME, "hp": definition["max_hp"], "max_hp": definition["max_hp"], "hit_radius": definition["traits"]["size"], "collision_radius": definition["traits"]["size"],
		"traits": definition["traits"].duplicate(true), "poise": 0.0, "guarded": false, "exposed": false, "wet_remaining": 0.0,"hurt_height":44.0}
	game.enemies.assign([actor]); game.missiles.clear(); game.elemental_combat.clear()
	active = true; phase = 1; cursor = 0; timer = 0.7; state = "RECOVERY"
	navigation.cancel(); navigation.actor_radius = float(actor["collision_radius"]); replan_remaining = 0
	metrics = {"attacks": {}, "hits_taken": 0, "barrier_stops": 0, "terrain_stops": 0, "poise_breaks": 0, "player_hits": 0}

func stop() -> void:
	active = false; state = "DORMANT"; actor = {}; navigation.cancel()

func attack_data() -> Dictionary: return definition["patterns"][pattern]
func duration(key: String) -> float:
	var value: float = attack_data()[key]
	if phase == 2 and key == "windup": return value * 0.85
	if phase == 2 and key == "recovery": return maxf(1.25, value * 0.9)
	return value

func _begin_pattern(game, id: String) -> void:
	pattern = id; state = "WINDUP"; timer = duration("windup"); _hit = false; _executed = false
	aim = (game.player_pos - Vector2(actor["pos"])).normalized()
	if aim.is_zero_approx(): aim = Vector2.LEFT
	target = game.player_pos
	actor["guarded"] = id == "CHARGE"; actor["exposed"] = false
	metrics["attacks"][id] = int(metrics["attacks"].get(id, 0)) + 1

func _recover(seconds: float) -> void:
	state = "RECOVERY"; timer = seconds; actor["guarded"] = false; actor["exposed"] = true

func add_poise(amount: float) -> void:
	if not active or actor.is_empty(): return
	actor["poise"] = float(actor["poise"]) + amount
	if actor["poise"] >= float(actor["traits"]["poise_max"]):
		actor["poise"] = 0.0; actor["stagger_remaining"] = maxf(actor.get("stagger_remaining", 0.0), 0.4)
		_recover(2.5); metrics["poise_breaks"] += 1

func _damage_player(game, amount: float) -> void:
	if _hit: return
	game._receive_player_damage(amount,pattern in ["SLAM","CHARGE"],game.player_pos-Vector2(actor["pos"]))
	_hit = true; metrics["player_hits"] += 1

func _move(game, motion: Vector2) -> bool:
	var steps := maxi(1, ceili(motion.length() / 5.0))
	var step := motion / steps
	for i in steps:
		var point: Vector2 = actor["pos"] + step
		if game._is_blocked(point, float(actor["traits"]["size"])): return false
		actor["pos"] = point
		if state == "ACTIVE" and pattern == "CHARGE" and point.distance_to(game.player_pos) < 42: _damage_player(game, attack_data()["damage"])
	return true

func _chase(game, delta: float) -> void:
	var origin: Vector2 = actor["pos"]
	var goal: Vector2 = game.player_pos + (origin - game.player_pos).normalized() * 60
	if game._is_blocked(goal, navigation.actor_radius):
		for i in 12:
			var candidate: Vector2 = game.player_pos + Vector2.from_angle(i * TAU / 12) * 65
			if not game._is_blocked(candidate, navigation.actor_radius): goal = candidate; break
	if navigation.clear_line(game, origin, goal):
		navigation.cancel(); _move(game, (goal - origin).normalized() * minf(112.0 * delta, origin.distance_to(goal))); return
	replan_remaining -= delta
	if replan_remaining <= 0 and (not navigation.active or navigation.destination.distance_to(goal) > 45 or not navigation.clear_line(game, origin, navigation.waypoints[0])):
		navigation.request_from(game, origin, goal); replan_remaining = 0.6
	if not navigation.active: return
	while not navigation.waypoints.is_empty() and origin.distance_to(navigation.waypoints[0]) < 4: navigation.waypoints.pop_front()
	if navigation.waypoints.is_empty(): navigation.cancel(); return
	var offset: Vector2 = navigation.waypoints[0] - origin
	_move(game, offset.normalized() * minf(112.0 * delta, offset.length()))

func advance(game, delta: float) -> void:
	if not active: return
	if actor["hp"] <= 0:
		active = false; state = "VICTORY"; actor["guarded"] = false
		game._guardian_victory(); return
	if phase == 1 and actor["hp"] <= definition["max_hp"] * 0.5:
		phase = 2; game._message("수호 기사의 자세가 바뀝니다. 칼날은 부채꼴로 날아오며 전조가 짧아집니다.")
	actor["wet_remaining"] = maxf(0, actor.get("wet_remaining", 0.0) - delta)
	actor["poise"] = maxf(0, float(actor["poise"]) - delta * 2.0)
	if actor.get("stagger_remaining", 0.0) > 0: return
	var root: bool = actor.get("root_remaining", 0.0) > 0
	var time_scale := 0.55 if root and state == "WINDUP" else 1.0
	if state == "APPROACH":
		var order: Array = ["SWEEP", "CHARGE", "SLAM", "THROW"] if phase == 1 else ["CHARGE", "THROW", "SWEEP", "SLAM"]
		var next: String = order[cursor % 4]
		var offset: Vector2 = game.player_pos - Vector2(actor["pos"])
		if offset.length() > (115.0 if next == "SWEEP" else 390.0) or not game.elemental_combat._clear_line(game, actor["pos"], game.player_pos):
			if not root: _chase(game, delta * preload("res://scripts/combat_geometry.gd").slow_multiplier(actor))
			return
		cursor += 1; _begin_pattern(game, next); return
	if state == "WINDUP":
		timer -= delta * time_scale
		if timer <= 0: state = "ACTIVE"; timer = duration("active")
		return
	if state == "ACTIVE":
		if pattern == "CHARGE":
			if not root and not _move(game, aim * float(attack_data()["speed"]) * delta):
				var next: Vector2 = actor["pos"] + aim * 6
				metrics["barrier_stops" if game.elemental_combat.blocks(next, float(actor["traits"]["size"])) else "terrain_stops"] += 1
				add_poise(45); _recover(2.6); return
		elif not _executed:
			_executed = true
			match pattern:
				"SWEEP":
					var offset: Vector2 = game.player_pos - Vector2(actor["pos"])
					if offset.length() < float(attack_data()["range"]) and (offset.is_zero_approx() or aim.dot(offset.normalized()) > 0.18) and game.elemental_combat._clear_line(game, actor["pos"], game.player_pos): _damage_player(game, attack_data()["damage"])
				"SLAM":
					if game.player_pos.distance_to(target) < float(attack_data()["radius"]) and game.elemental_combat._clear_line(game, actor["pos"], game.player_pos): _damage_player(game, attack_data()["damage"])
				"THROW":
					for angle in ([-0.24, 0.0, 0.24] if phase == 2 else [0.0]):
						game.missiles.append({"pos": Vector2(actor["pos"]) + aim * 32, "dir": aim.rotated(angle), "hostile": true, "life": 2.3, "dmg": attack_data()["damage"], "speed": attack_data()["speed"]})
		timer -= delta
		if timer <= 0: _recover(duration("recovery"))
		return
	if state == "RECOVERY":
		timer -= delta
		if timer <= 0: state = "APPROACH"; actor["exposed"] = false
	if game.player_hp <= 0: game._die()

func caption() -> String:
	if state == "VICTORY": return "격파 · 귀환 또는 재도전 가능"
	if state == "DORMANT": return "문 앞에서 E로 도전"
	if state == "RECOVERY": return "자세를 회복하는 중 · 반격 기회"
	if state == "APPROACH": return "거리를 좁히는 중"
	return attack_data()["name"] + (" · 전조" if state == "WINDUP" else " · 공격")

func snapshot() -> Dictionary:
	var data: Dictionary = {}
	for field in ["actor", "active", "state", "pattern", "phase", "timer", "cursor", "aim", "target", "_hit", "_executed", "metrics"]:
		var value = get(field)
		data[field] = value.duplicate(true) if value is Dictionary else value
	return data

func restore(data: Dictionary, enemies: Array) -> void:
	navigation.cancel(); replan_remaining = 0
	for field in data: set(field, data[field].duplicate(true) if data[field] is Dictionary else data[field])
	for enemy in enemies:
		if enemy.get("boss", false): actor = enemy; break
	if not actor.is_empty(): navigation.actor_radius = actor.get("collision_radius", 26)

func draw_telegraph(canvas: CanvasItem) -> void:
	if not active or state not in ["WINDUP", "ACTIVE"]: return
	var point: Vector2 = actor["pos"]
	var alpha := 0.3 if state == "WINDUP" else 0.65
	var color := Color(1, 0.43, 0.24, alpha)
	match pattern:
		"SWEEP":
			var polygon := PackedVector2Array([point])
			for i in 25: polygon.append(point + aim.rotated(lerpf(-1.38, 1.38, i / 24.0)) * float(attack_data()["range"]))
			canvas.draw_colored_polygon(polygon, color)
			canvas.draw_arc(point, attack_data()["range"], aim.angle() - 1.38, aim.angle() + 1.38, 32, Color("ffcc8e"), 3)
		"CHARGE":
			var end := point + aim * float(attack_data()["speed"]) * float(attack_data()["active"])
			canvas.draw_line(point, end, color, 68)
			canvas.draw_line(point, end, Color("ffdf9a"), 3)
		"SLAM":
			canvas.draw_circle(target, attack_data()["radius"], color)
			canvas.draw_arc(target, attack_data()["radius"], 0, TAU, 48, Color("ffce94"), 3)
			canvas.draw_line(target - Vector2(18, 0), target + Vector2(18, 0), Color.WHITE, 2)
			canvas.draw_line(target - Vector2(0, 18), target + Vector2(0, 18), Color.WHITE, 2)
		"THROW":
			for angle in ([-0.24, 0.0, 0.24] if phase == 2 else [0.0]):
				canvas.draw_line(point, point + aim.rotated(angle) * 500, color, 14)
				canvas.draw_line(point, point + aim.rotated(angle) * 500, Color("eed9af"), 2)
