extends RefCounted
## Transient combat only: no save, input routing, research or personal key knowledge.
const Definition = preload("res://scripts/spell_definition.gd")
const VFX = preload("res://scripts/spell_vfx.gd")
var visual_time := 0.0
var barriers: Array[Dictionary] = []
var visuals: Array[Dictionary] = []
var _next_enemy_id := 1

func clear() -> void:
	barriers.clear()
	visuals.clear()
	_next_enemy_id = 1
	visual_time = 0.0

func _visual(data: Dictionary) -> void:
	# Cost remains bounded even with repeated piercing impacts in a long fight.
	if visuals.size() >= 96: visuals.pop_front()
	visuals.append(data)

func blocks(point: Vector2, radius: float) -> bool:
	for barrier in barriers:
		if point.distance_to(barrier["pos"]) < radius + float(barrier["radius"]): return true
	return false

func _clear_line(game, from: Vector2, to: Vector2, radius := 4.0) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 4.0))
	for i in range(1, steps + 1):
		if game._is_blocked(from.lerp(to, float(i) / steps), radius): return false
	return true

func cast(game, definition: Definition, direction: Vector2) -> bool:
	match definition.effect:
		&"projectile":
			game.missiles.append({"pos": game.player_pos, "dir": direction, "hostile": false,
				"life": definition.lifetime, "dmg": definition.damage, "speed": definition.projectile_speed,
				"color": definition.projectile_color, "spell_id": definition.spell_id,
				"definition": definition, "pierce_left": definition.pierce_targets, "hit_ids": []})
		&"barrier":
			var position: Vector2 = game.player_pos + direction * definition.placement_distance
			if game._is_blocked(position, definition.radius) or not _clear_line(game, game.player_pos, position): return false
			if position.distance_to(game.player_pos) < definition.radius + 16.0 or position.distance_to(game.EXIT_POS) < definition.radius + 60.0: return false
			for enemy in game.enemies:
				if position.distance_to(enemy["pos"]) < definition.radius + 16.0: return false
			barriers.append({"pos": position, "radius": definition.radius, "life": definition.duration,
				"color": definition.projectile_color})
		&"blast":
			var center: Vector2 = game.player_pos + direction * definition.placement_distance
			if game._is_blocked(center, 4.0) or not _clear_line(game, game.player_pos, center): return false
			for enemy in game.enemies:
				if float(enemy["hp"]) > 0 and Vector2(enemy["pos"]).distance_to(center) <= definition.radius and _clear_line(game, center, enemy["pos"]):
					hit_enemy(game, enemy, definition, direction)
			_visual({"pos": center, "radius": definition.radius, "life": 0.8, "total": 0.8, "color": definition.projectile_color, "attribute": definition.attribute})
		&"shockwave":
			for enemy in game.enemies:
				if float(enemy["hp"]) <= 0.0: continue
				var offset: Vector2 = enemy["pos"] - game.player_pos
				if offset.length() <= definition.radius and _clear_line(game, game.player_pos, enemy["pos"]):
					hit_enemy(game, enemy, definition, direction if offset.is_zero_approx() else offset.normalized())
			_visual({"pos": game.player_pos, "radius": definition.radius, "life": 0.45, "total": 0.45, "color": definition.projectile_color, "attribute": definition.attribute})
		_:
			return false
	return true

func _enemy_id(enemy: Dictionary) -> int:
	if not enemy.has("combat_id"):
		enemy["combat_id"] = _next_enemy_id
		_next_enemy_id += 1
	return int(enemy["combat_id"])

func hit_enemy(game, enemy: Dictionary, definition: Definition, direction: Vector2) -> void:
	enemy["hp"] -= definition.damage
	_visual({"pos": enemy["pos"], "radius": 38.0, "life": 0.5, "total": 0.5, "color": definition.projectile_color, "attribute": definition.attribute})
	match definition.status_effect:
		&"burn":
			enemy["burn_remaining"] = maxf(enemy.get("burn_remaining", 0.0), definition.duration)
			enemy["burn_dps"] = maxf(enemy.get("burn_dps", 0.0), definition.damage_per_second)
		&"root": enemy["root_remaining"] = maxf(enemy.get("root_remaining", 0.0), definition.duration)
		&"stagger": enemy["stagger_remaining"] = maxf(enemy.get("stagger_remaining", 0.0), definition.duration)
	if definition.knockback > 0.0:
		var origin: Vector2 = enemy["pos"]
		var steps := maxi(1, ceili(definition.knockback / 4.0))
		var motion := direction * definition.knockback / steps
		for i in steps:
			var destination: Vector2 = enemy["pos"] + motion
			if game._is_blocked(destination, 15.0): break
			enemy["pos"] = destination
		_visual({"pos": origin, "to": enemy["pos"], "radius": 28.0,
			"life": 0.45, "total": 0.45, "color": definition.projectile_color, "attribute": definition.attribute})

func update(game, delta: float) -> void:
	visual_time += delta
	# Durations use real combat seconds; Alt still slows enemy movement/projectiles only.
	for enemy in game.enemies:
		var burning: float = enemy.get("burn_remaining", 0.0)
		if burning > 0.0:
			enemy["hp"] -= float(enemy.get("burn_dps", 0.0)) * minf(delta, burning)
		for status in ["burn_remaining", "root_remaining", "stagger_remaining"]:
			enemy[status] = maxf(0.0, float(enemy.get(status, 0.0)) - delta)
	for i in range(barriers.size() - 1, -1, -1):
		barriers[i]["life"] -= delta
		if barriers[i]["life"] <= 0.0: barriers.remove_at(i)
	for i in range(visuals.size() - 1, -1, -1):
		visuals[i]["life"] -= delta
		if visuals[i]["life"] <= 0.0: visuals.remove_at(i)

func update_missiles(game, delta: float, enemy_time: float) -> void:
	for i in range(game.missiles.size() - 1, -1, -1):
		var missile: Dictionary = game.missiles[i]
		var hostile := bool(missile["hostile"])
		var actor_delta := delta * enemy_time if hostile else delta
		var speed := float(missile.get("speed", 160.0 if hostile else 460.0))
		var travel := speed * minf(actor_delta, maxf(0.0, missile["life"]))
		var start: Vector2 = missile["pos"]
		var steps := maxi(1, ceili(travel / 4.0))
		var expire: bool = missile["life"] <= 0.0 or game._is_blocked(start, 4.0)
		for step in range(1, steps + 1):
			if expire: break
			var position: Vector2 = start + Vector2(missile["dir"]) * travel * float(step) / steps
			missile["pos"] = position
			if game._is_blocked(position, 4.0):
				expire = true
				break
			if hostile:
				if position.distance_to(game.player_pos) < 16.0:
					game.player_hp -= float(missile["dmg"])
					expire = true
			else:
				for enemy in game.enemies:
					if enemy["hp"] <= 0.0 or position.distance_to(enemy["pos"]) >= 18.0: continue
					var id := _enemy_id(enemy)
					var hit_ids: Array = missile.get("hit_ids", [])
					if id in hit_ids: continue
					hit_ids.append(id)
					missile["hit_ids"] = hit_ids
					var definition: Definition = missile.get("definition")
					if definition != null: hit_enemy(game, enemy, definition, missile["dir"])
					else: enemy["hp"] -= float(missile["dmg"])
					missile["pierce_left"] = int(missile.get("pierce_left", 1)) - 1
					if missile["pierce_left"] <= 0:
						expire = true
						break
		missile["life"] -= actor_delta
		if expire or missile["life"] <= 0.0: game.missiles.remove_at(i)
		else: game.missiles[i] = missile
	if game.player_hp <= 0.0 and game.game_state == "DUNGEON": game._die()

func draw(game) -> void:
	for barrier in barriers:
		VFX.barrier(game, barrier)
	for enemy in game.enemies:
		VFX.statuses(game, enemy, visual_time)
	for missile in game.missiles:
		VFX.projectile(game, missile, visual_time)
	for visual in visuals:
		VFX.impact(game, visual, visual_time)
