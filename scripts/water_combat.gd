extends RefCounted
static var SETTINGS:Dictionary=preload("res://scripts/water_spell_catalog.gd").DATA.physics
## Shared laboratory/world transient physics. No save or chant interpretation.
static func amount(d)->float:return float(d.formula_effect.get("strength",0))
static func _state(c,data:Dictionary)->void:
	if c.water_states.size()>=int(SETTINGS.max_transients):c.water_states.pop_front()
	c.water_states.append(data)
static func move_enemy(c,g,e:Dictionary,motion:Vector2)->void:
	if e.get("boss",false):
		if e.get("charging",false):return
		var guardian=g.get("guardian")
		if guardian!=null and guardian.state=="ACTIVE" and guardian.pattern=="CHARGE":return
		var traits:Dictionary=e.get("traits",{})
		motion*=minf(1.0/maxf(1,float(traits.get("mass_class",1))),1-float(traits.get("knockback_resistance",0)))
	var count:=maxi(1,ceili(motion.length()/3))
	for i in count:
		var p:Vector2=e.pos+motion/count
		if g._is_blocked(p,float(e.get("collision_radius",15))):break
		e.pos=p
static func visual(c,p:Vector2,d,life:float,kind:="area",direction:=Vector2.RIGHT)->void:
	c._visual({"pos":p,"dir":direction,"radius":maxf(d.radius,35),"life":life,"total":life,"color":d.projectile_color,"attribute":str(d.spell_id),"water15":true,"kind":kind,"formula_effect":d.formula_effect.duplicate(true)})
static func cast(c,g,d,direction:Vector2,aim)->bool:
	var id:=str(d.spell_id);var a:=amount(d)
	if id in ["OH-066","OH-067"]:
		for i in range(c.water_states.size()-1,-1,-1):
			if c.water_states[i].kind=="shield" and c.water_states[i].id==id:c.water_states.remove_at(i)
		_state(c,{"kind":"shield","id":id,"pos":g.player_pos+direction*d.placement_distance,"dir":direction,"radius":d.radius,"life":d.duration,"definition":d,"deflected":false,"serial":c.visual_time})
		return true
	if d.effect==&"projectile":
		var count:=3 if id=="OH-069" else (7 if id=="OH-075" else 1)
		for i in count:
			var per=d.duplicate();per.formula_effect=d.formula_effect.duplicate(true)
			per.damage=d.damage/count
			var offset:=float(i)-(count-1)*.5
			var angle:float=offset*(float(SETTINGS.spread_base)+float(SETTINGS.spread_strength)*a) if count>1 else 0.0
			var dir:=direction.rotated(angle)
			var curve:float=float(SETTINGS.curve_amplitude)*a if id=="OH-070" else ((-offset*float(SETTINGS.hydra_curve_per_stream)*a) if id=="OH-075" else 0.0)
			if id=="OH-074":per.damage=d.damage*(1-float(SETTINGS.delayed_fraction)*a);per.formula_effect["delayed_damage"]=d.damage*float(SETTINGS.delayed_fraction)*a
			g.missiles.append({"pos":g.player_pos,"origin":g.player_pos,"dir":dir,"launch_dir":dir,"curve":curve,"age":0.0,"hostile":false,"life":per.lifetime,"total_life":per.lifetime,"dmg":per.damage,"speed":per.projectile_speed,"color":per.projectile_color,"spell_id":per.spell_id,"definition":per,"hit_width":per.projectile_width,"collision_radius":per.projectile_radius,"pierce_left":per.pierce_targets,"hit_ids":[],"trail_points":[]})
			if id=="OH-069":g.missiles.back()["launch_delay"]=i*d.duration/2.0
		return true
	var center:Vector2=g.player_pos if d.effect==&"cone" else g.player_pos+direction*d.placement_distance
	if aim is Vector2 and d.effect==&"point":center=g.player_pos+direction*minf(d.placement_distance,g.player_pos.distance_to(aim))
	if g._is_blocked(center,1) or not c._clear_line(g,g.player_pos,center,1):return false
	for enemy in g.enemies:
		if enemy.hp<=0:continue
		var offset:Vector2=enemy.pos-center
		if offset.length()>d.radius+float(enemy.get("hit_radius",18)):continue
		if d.effect==&"cone" and not offset.is_zero_approx() and offset.normalized().dot(direction)<.45:continue
		if not c._clear_line(g,center,enemy.pos):continue
		var hit=d.duplicate();hit.formula_effect=d.formula_effect.duplicate(true)
		var outward:Vector2=offset.normalized()
		if id in ["OH-068","OH-071"]:
			hit.knockback=0 # Pull is integrated below, with a fixed total budget.
		c.hit_enemy(g,enemy,hit,outward if not outward.is_zero_approx() else direction)
		if id=="OH-072" and a>0:
			_state(c,{"kind":"release","enemy_id":c._enemy_id(enemy),"life":maxf(.01,float(enemy.get("root_remaining",d.duration))),"definition":d,"pos":enemy.pos})
	if id in ["OH-068","OH-071","OH-073"]:
		var seconds:float=d.duration if id!="OH-071" else 1.0
		_state(c,{"kind":"field","id":id,"pos":center,"life":seconds,"total":seconds,"elapsed":0.0,"next_tick":float(SETTINGS.dot_interval),"definition":d})
	visual(c,center,d,maxf(.6,d.duration),"area",direction)
	return true
static func on_hit(c,g,e:Dictionary,d)->void:
	if str(d.spell_id)=="OH-074" and d.formula_effect.get("delayed_damage",0)>0:
		var follow=d.duplicate();follow.formula_effect=d.formula_effect.duplicate(true);follow.damage=d.formula_effect.delayed_damage
		follow.formula_effect.erase("delayed_damage")
		_state(c,{"kind":"delayed","enemy_id":c._enemy_id(e),"life":float(SETTINGS.delayed_seconds),"pos":e.pos,"definition":follow})
	if str(d.spell_id)=="OH-072":
		e["water_prison_remaining"]=e.get("root_remaining",d.duration);e["water_prison_radius"]=d.radius;e["water_prison_strength"]=amount(d)
static func shield(c,g,m:Dictionary,p:Vector2)->void:
	for s in c.water_states:
		if s.kind!="shield":continue
		var key:String=str(s.id)+":"+str(s.serial)
		if key in m.get("water_shields",[]):continue
		var hit:bool=p.distance_to(s.pos)<=s.radius if s.id=="OH-066" else absf((p-s.pos).dot(s.dir))<=12 and absf((p-s.pos).dot(Vector2(s.dir).orthogonal()))<=s.radius
		if not hit:continue
		var ids:Array=m.get("water_shields",[]);ids.append(key);m.water_shields=ids
		m.dmg*=1-float(SETTINGS.ripple_reduction if s.id=="OH-066" else SETTINGS.eddy_reduction)
		c.water_metrics["shield_contacts"]+=1
		if s.id=="OH-067" and not s.deflected and amount(s.definition)>.001:
			m.dir=Vector2(m.dir).rotated(float(SETTINGS.deflection_angle)*amount(s.definition));s.deflected=true
			c.water_metrics["deflections"]+=1
			visual(c,p,s.definition,.45,"deflect")
static func advance(c,g,dt:float)->void:
	for i in range(c.water_states.size()-1,-1,-1):
		var s:Dictionary=c.water_states[i];var d=s.definition;var a:=amount(d)
		var step:=minf(dt,maxf(0,s.life));s.life-=dt
		if s.kind=="shield" and s.id=="OH-066":s.pos=g.player_pos
		if s.kind=="field":
			var old:float=s.elapsed;s.elapsed+=step
			for e in g.enemies:
				var offset:Vector2=e.pos-s.pos;var distance:=offset.length()
				if e.hp<=0 or distance>d.radius or not c._clear_line(g,s.pos,e.pos):continue
				var inward:Vector2=-offset.normalized();var motion:=Vector2.ZERO
				if s.id=="OH-068":motion=inward*(absf(d.knockback)/s.total)*step+inward.orthogonal()*float(SETTINGS.orbit_speed)*a*step
				if s.id=="OH-071":
					# Convex mix of continuous pull and two finite-width pulses.
					var pulse:=0.0
					for window in [Vector2(0,.2),Vector2(.55,.75)]:pulse+=maxf(0,minf(s.elapsed,window.y)-maxf(old,window.x))/.4
					motion=inward*absf(d.knockback)*((1-a)*step/s.total+a*pulse)
				if s.id=="OH-073":motion=inward.orthogonal()*float(SETTINGS.counterflow_speed)*a*step*(1 if distance>d.radius*.5 else -1)
				if motion.length()>distance and s.id!="OH-073":motion=motion.limit_length(distance)
				move_enemy(c,g,e,motion)
				if motion.length()>.001:c.water_metrics["flow_steps"]+=1
			if s.id=="OH-073":
				while s.elapsed+.00001>=s.next_tick and s.next_tick<=s.total+.00001:
					for e in g.enemies:
						if e.hp>0 and Vector2(e.pos).distance_to(s.pos)<=d.radius and c._clear_line(g,s.pos,e.pos):
							var tick=d.duplicate();tick.damage=d.damage_per_second*float(SETTINGS.dot_interval);tick.knockback=0;tick.duration=.3
							c.hit_enemy(g,e,tick,Vector2.ZERO);c.water_metrics["dot_hits"]+=1
					s.next_tick+=float(SETTINGS.dot_interval)
		if s.life>0:continue
		if s.kind=="field" and s.id=="OH-073":
			var interval:float=SETTINGS.dot_interval
			var tail:float=s.total-floor((s.total+.000001)/interval)*interval
			if tail>0.00001:
				for e in g.enemies:
					if e.hp>0 and Vector2(e.pos).distance_to(s.pos)<=d.radius and c._clear_line(g,s.pos,e.pos):
						var tick=d.duplicate();tick.damage=d.damage_per_second*tail;tick.duration=.01;tick.knockback=0
						c.hit_enemy(g,e,tick,Vector2.ZERO);c.water_metrics["dot_hits"]+=1
		if s.kind=="release":
			for e in g.enemies:
				if c._enemy_id(e)==s.enemy_id:s.pos=e.pos;break
			for e in g.enemies:
				var v:Vector2=e.pos-s.pos
				if e.hp>0 and v.length()<=d.radius+float(SETTINGS.ring_extra_radius)*a and c._clear_line(g,s.pos,e.pos):move_enemy(c,g,e,(v.normalized() if v.length()>1 else Vector2.RIGHT)*float(SETTINGS.ring_displacement)*a)
			visual(c,s.pos,d,.65,"release");c.water_metrics["release_rings"]+=1
		if s.kind=="delayed":
			for e in g.enemies:
				if e.hp>0 and c._enemy_id(e)==s.enemy_id and Vector2(e.pos).distance_to(s.pos)<=25+d.projectile_radius and c._clear_line(g,s.pos,e.pos):c.hit_enemy(g,e,d,Vector2.ZERO);c.water_metrics["delayed_hits"]+=1
			visual(c,s.pos,d,.45,"pressure")
		c.water_states.remove_at(i)
