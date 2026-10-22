extends RefCounted
## Ground navigation disks remain unchanged. Sprite bodies have explicit vertical
## hurt capsules, used only for projectile contact, never navigation or aiming.
static func enemy_distance(point:Vector2,enemy:Dictionary)->float:
	var foot:Vector2=enemy.pos
	var height:float=enemy.get("hurt_height",0.0)
	var closest:=Vector2(foot.x,clampf(point.y,foot.y-height,foot.y))
	return point.distance_to(closest)
static func projectile_radius(missile:Dictionary)->float:
	return float(missile.get("collision_radius",missile.get("hit_width",0.0)))
static func slow_multiplier(enemy:Dictionary)->float:
	return clampf(1-.35*float(enemy.get("slow_strength",1)),.5,1) if enemy.get("slow_remaining",0)>0 else 1.0
