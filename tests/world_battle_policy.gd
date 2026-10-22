extends RefCounted
## Test-only pilot. It uses actor movement/actions, never edits boss HP or AI state.
var cast_cooldown := 0.0
var movement_cooldown := 0.0
var casts := 0
var swings := 0
var dodges := 0
var elapsed := 0.0
func decide(game, delta: float, element: String, cost: float) -> Dictionary:
	cast_cooldown = maxf(0, cast_cooldown - delta); movement_cooldown = maxf(0, movement_cooldown - delta); elapsed += delta
	var boss = game.guardian
	if not boss.active: return {}
	var point: Vector2 = game.player_pos
	var origin: Vector2 = boss.actor["pos"]
	var offset := point - origin
	var away := offset.normalized() if not offset.is_zero_approx() else Vector2.LEFT
	var danger := false
	var goal := point
	var warning: bool = boss.state in ["WINDUP", "ACTIVE"]
	if warning:
		var side: Vector2 = boss.aim.orthogonal()
		if (point + side * 150).y < 570 or (point + side * 150).y > 1250: side = -side
		match boss.pattern:
			"SWEEP":
				danger = offset.length() < 168 and boss.aim.dot(away) > 0.05
				if danger: goal = origin + away * 205
			"CHARGE":
				danger = absf(offset.dot(boss.aim.orthogonal())) < 90 and offset.dot(boss.aim) > -20
				if danger: goal = origin + boss.aim * maxf(70, offset.dot(boss.aim)) + side * 145
			"SLAM":
				danger = point.distance_to(boss.target) < 127
				var out: Vector2 = (point - Vector2(boss.target)).normalized() if point.distance_to(boss.target) > 5 else side
				if danger: goal = boss.target + out * 155
			"THROW":
				var along := offset.dot(boss.aim)
				var across := absf(offset.dot(boss.aim.orthogonal()))
				danger = along > 0 and across < 42 + (along * 0.3 if boss.phase == 2 else 0)
				if danger: goal = origin + boss.aim * along + side * (95 + along * 0.35)
	var result: Dictionary = {}
	if danger:
		goal = goal.clamp(game.layout.ARENA.position + Vector2.ONE * 45, game.layout.ARENA.end - Vector2.ONE * 45)
		if not game._is_blocked(goal) and movement_cooldown <= 0:
			result["move"] = goal; movement_cooldown = 0.12
		result["dodge"] = boss.state == "WINDUP" and boss.timer < 0.38 and game.dodge.cooldown <= 0 and not game.dodge.active
		return result
	if not game.dodge.active and cast_cooldown <= 0 and game.player_mana >= cost:
		if element != "EARTH" and offset.length() < 480:
			result["cast"] = true; cast_cooldown = 1.05; casts += 1
		elif element == "EARTH" and boss.pattern == "CHARGE" and boss.state == "WINDUP" and offset.length() > 160:
			result["cast"] = true; cast_cooldown = 2; casts += 1
	if not result.has("cast") and (element == "EARTH" or game.player_mana < cost):
		if offset.length() > 77 and not warning and movement_cooldown <= 0:
			goal = origin + away * 67
			if not game._is_blocked(goal): result["move"] = goal; movement_cooldown = 0.25
		elif offset.length() <= 85 and not game.dodge.active and game.player_attack_cooldown <= 0:
			result["sword"] = true; swings += 1
	return result
