extends RefCounted
## Transient combat only: no save, input routing, research or personal key knowledge.
const Definition = preload("res://scripts/spell_definition.gd")
const VFX = preload("res://scripts/spell_vfx.gd")
var visual_time := 0.0
var barriers: Array[Dictionary] = []
var visuals: Array[Dictionary] = []
var _next_enemy_id := 1
var water_states:Array[Dictionary]=[]
var water_metrics:Dictionary={"shield_contacts":0,"deflections":0,"flow_steps":0,"dot_hits":0,"release_rings":0,"delayed_hits":0}

func clear() -> void:
	barriers.clear()
	water_states.clear()
	for key in water_metrics:water_metrics[key]=0
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

func cast(game, definition: Definition, direction: Vector2, aim_point: Variant = null) -> bool:
	if definition.requires_elements.size()>2:return false
	var owner=game.get("controller") if game.get("controller")!=null else game
	var isolated_all:bool=owner.get("developer_mode")==true and owner.get("_prototype_all")==true
	if owner.get("research")!=null and not isolated_all:
		var research=owner.research
		var elements:Array=Array(definition.requires_elements)
		if elements.size()==1 and elements[0] in preload("res://scripts/base_elements.gd").OHAENG and elements[0]!=research.main_attribute:return false
		if elements.size()>1:
			var fusion=preload("res://scripts/fusion_rules.gd")
			var access:Dictionary=research.simulation_context()
			access["formal_rules"]=owner.get("formal_rules")==true
			if not fusion.cast_allowed(elements,access):return false
	if definition.formula_effect.get("water15",false) and int(str(definition.spell_id).right(3))>=64:
		return preload("res://scripts/water_combat.gd").cast(self,game,definition,direction,aim_point)
	match definition.effect:
		&"projectile":
			game.missiles.append({"pos": game.player_pos, "dir": direction, "hostile": false,
				"life": definition.lifetime, "dmg": definition.damage, "speed": definition.projectile_speed,
				"color": definition.projectile_color, "spell_id": definition.spell_id,
					"definition": definition, "hit_width": definition.projectile_width, "pierce_left": definition.pierce_targets, "hit_ids": []})
			game.missiles.back()["collision_radius"]=definition.projectile_radius
		&"cone", &"point":
			var center: Vector2 = game.player_pos + direction * definition.placement_distance if definition.effect == &"point" else game.player_pos
			if definition.effect == &"point" and aim_point is Vector2:
				center = game.player_pos + direction * minf(definition.placement_distance, game.player_pos.distance_to(aim_point))
			if game._is_blocked(center, 1) or not _clear_line(game, game.player_pos, center, 1): return false
			for enemy in game.enemies:
				var offset: Vector2 = enemy["pos"] - game.player_pos
				var radius: float = enemy.get("hit_radius", 18.0)
				var inside: bool = Vector2(enemy["pos"]).distance_to(center) <= definition.radius + radius if definition.effect == &"point" else offset.length() <= definition.radius + radius and (offset.is_zero_approx() or offset.normalized().dot(direction) >= 0.45)
				if enemy["hp"] > 0 and inside and _clear_line(game, game.player_pos, enemy["pos"]):
					var hit_direction:=direction
					if definition.formula_effect.get("axis")=="circulation":
						hit_direction=(Vector2(enemy.pos)-center).normalized()
						if hit_direction.is_zero_approx():hit_direction=Vector2.ZERO
						var inward=definition.duplicate()
						inward.knockback=-minf(absf(definition.knockback),Vector2(enemy.pos).distance_to(center))
						hit_enemy(game,enemy,inward,hit_direction)
					else:hit_enemy(game, enemy, definition, hit_direction)
			var visual_life:float=maxf(.6,definition.duration) if definition.formula_effect.get("prototype",false) else .6
			_visual({"pos": center, "dir": direction, "radius": definition.radius, "life": visual_life, "total": visual_life, "color": definition.projectile_color, "attribute": str(definition.visual_style),"formula_effect":definition.formula_effect.duplicate(true)})
		&"barrier":
			var position: Vector2 = game.player_pos + direction * definition.placement_distance
			if game._is_blocked(position, definition.radius) or not _clear_line(game, game.player_pos, position): return false
			if position.distance_to(game.player_pos) < definition.radius + 16.0 or position.distance_to(game.EXIT_POS) < definition.radius + 60.0: return false
			for enemy in game.enemies:
				if position.distance_to(enemy["pos"]) < definition.radius + 16.0: return false
			barriers.append({"pos": position, "radius": definition.radius, "life": definition.duration,
				"color": definition.projectile_color, "visual_style": str(definition.visual_style)})
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
			_visual({"pos": game.player_pos, "radius": definition.radius, "life": 0.45, "total": 0.45, "color": definition.projectile_color, "attribute": definition.attribute if definition.visual_style.is_empty() else definition.visual_style})
		_:
			return false
	return true

func _enemy_id(enemy: Dictionary) -> int:
	if not enemy.has("combat_id"):
		enemy["combat_id"] = _next_enemy_id
		_next_enemy_id += 1
	return int(enemy["combat_id"])

func hit_enemy(game, enemy: Dictionary, definition: Definition, direction: Vector2) -> void:
	var damage:=definition.damage
	# Formula harness targets may carry an explicit guard. No armor is invented
	# for normal enemies; the world boss adapter owns its established traits.
	if not enemy.get("boss",false) and enemy.has("formula_guard") and definition.formula_effect.get("prototype",false):
		damage*=lerpf(float(enemy.formula_guard),1.0,clampf(definition.formula_effect.get("armor_ignore",0.0),0,1))
	enemy["hp"] -= damage
	if definition.formula_effect.get("axis")=="confinement":
		enemy["water_prison_remaining"]=maxf(enemy.get("water_prison_remaining",0),definition.duration)
		enemy["water_prison_radius"]=definition.radius;enemy["water_prison_strength"]=definition.formula_effect.get("strength",0)
	_visual({"pos": enemy["pos"], "radius": 38.0, "life": 0.5, "total": 0.5, "color": definition.projectile_color, "attribute": definition.attribute if definition.visual_style.is_empty() else definition.visual_style})
	match definition.status_effect:
		&"burn":
			enemy["burn_remaining"] = maxf(enemy.get("burn_remaining", 0.0), definition.duration)
			enemy["burn_dps"] = maxf(enemy.get("burn_dps", 0.0), definition.damage_per_second)
		&"root": enemy["root_remaining"] = maxf(enemy.get("root_remaining", 0.0), definition.duration)
		&"crystal":
			enemy["root_remaining"] = maxf(enemy.get("root_remaining", 0.0), definition.duration)
			enemy["crystal_remaining"] = maxf(enemy.get("crystal_remaining", 0.0), definition.duration)
		&"stagger": enemy["stagger_remaining"] = maxf(enemy.get("stagger_remaining", 0.0), definition.duration)
		&"slow":
			enemy["slow_strength"]=maxf(float(enemy.get("slow_strength",0)) if enemy.get("slow_remaining",0)>0 else 0,definition.status_strength)
			enemy["slow_remaining"] = maxf(enemy.get("slow_remaining", 0.0), definition.duration)
	if definition.knockback != 0.0:
		var origin: Vector2 = enemy["pos"]
		var steps := maxi(1, ceili(absf(definition.knockback) / 4.0))
		var motion := direction * definition.knockback / steps
		for i in steps:
			var destination: Vector2 = enemy["pos"] + motion
			if game._is_blocked(destination, float(enemy.get("collision_radius", 15.0))): break
			enemy["pos"] = destination
		_visual({"pos": origin, "to": enemy["pos"], "radius": 28.0,
			"life": 0.45, "total": 0.45, "color": definition.projectile_color, "attribute": definition.attribute if definition.visual_style.is_empty() else definition.visual_style})
	if definition.formula_effect.get("water15",false):preload("res://scripts/water_combat.gd").on_hit(self,game,enemy,definition)

func update(game, delta: float) -> void:
	visual_time += delta
	preload("res://scripts/water_combat.gd").advance(self,game,delta)
	# Durations use real combat seconds; Alt still slows enemy movement/projectiles only.
	for enemy in game.enemies:
		var burning: float = enemy.get("burn_remaining", 0.0)
		if burning > 0.0:
			enemy["hp"] -= float(enemy.get("burn_dps", 0.0)) * minf(delta, burning)
		for status in ["burn_remaining", "root_remaining", "stagger_remaining", "crystal_remaining", "slow_remaining", "water_prison_remaining"]:
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
		if missile.get("launch_delay",0)>0:
			var waiting:float=minf(actor_delta,missile.launch_delay)
			missile.launch_delay-=waiting;actor_delta-=waiting
			if actor_delta<=0:continue
		var speed := float(missile.get("speed", 160.0 if hostile else 460.0))
		var travel := speed * minf(actor_delta, maxf(0.0, missile["life"]))
		var start: Vector2 = missile["pos"]
		var old_age:float=missile.get("age",0)
		missile["age"]=old_age+minf(actor_delta,maxf(0,missile.life))
		var steps := maxi(1, ceili(travel / 4.0))
		var expire: bool = missile["life"] <= 0.0 or game._is_blocked(start, 4.0)
		for step in range(1, steps + 1):
			if expire: break
			var position: Vector2 = Vector2(missile.pos) + Vector2(missile["dir"]) * travel / steps
			if missile.has("curve"):
				var age:float=lerpf(old_age,missile.age,float(step)/steps)
				var launch:Vector2=missile.launch_dir
				position=missile.origin+launch*speed*age+launch.orthogonal()*float(missile.curve)*sin(PI*age/maxf(.001,missile.total_life))
				missile.dir=(position-Vector2(missile.pos)).normalized()
			missile["pos"] = position
			if game._is_blocked(position, maxf(4.0,preload("res://scripts/combat_geometry.gd").projectile_radius(missile)) + float(missile.get("hit_width", 0))):
				expire = true
				break
			if hostile:
				preload("res://scripts/water_combat.gd").shield(self,game,missile,position)
				if position.distance_to(game.player_pos) < 16.0:
					if game.has_method("_receive_player_damage"):game._receive_player_damage(float(missile["dmg"]),false,missile["dir"])
					else:game.player_hp-=float(missile["dmg"])
					expire = true
			else:
				for enemy in game.enemies:
					if enemy["hp"] <= 0.0 or preload("res://scripts/combat_geometry.gd").enemy_distance(position,enemy) >= float(enemy.get("hit_radius", 18.0)) + preload("res://scripts/combat_geometry.gd").projectile_radius(missile) + float(missile.get("hit_width", 0)): continue
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
		if missile.has("trail_points"):
			missile.trail_points.append(missile.pos)
			if missile.trail_points.size()>18:missile.trail_points.pop_front()
		if expire or missile["life"] <= 0.0: game.missiles.remove_at(i)
		else: game.missiles[i] = missile
	if game.player_hp <= 0.0 and game.game_state == "DUNGEON": game._die()

func draw(game) -> void:
	preload("res://scripts/water_vfx.gd").states(game,water_states,visual_time)
	for barrier in barriers:
		VFX.barrier(game, barrier)
	for enemy in game.enemies:
		VFX.statuses(game, enemy, visual_time)
	for missile in game.missiles:
		VFX.projectile(game, missile, visual_time)
	for visual in visuals:
		VFX.impact(game, visual, visual_time)
