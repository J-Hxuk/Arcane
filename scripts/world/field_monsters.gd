extends RefCounted
static var CONFIG:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/field_monsters.json"))
const Navigation=preload("res://scripts/world/world_navigation.gd")
var actors:Array[Dictionary]=[]
var routes:Dictionary={}
var suppressed:=false
var _save_clock:=0.0
var _pickup_retry:=0.0
var _respawn_retry:=0.0
static func defaults()->Dictionary:return {"version":2,"defeated":[],"drops":[],"claimed":[],"spawns":{}}
static func base_id(id:String)->String:return id.split("@")[0]
static func instance_id(base:String,generation:int)->String:return base if generation==0 else base+"@"+str(generation)
static func integer(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value)) and value>=0 and value==int(value)
static func normalize(value:Dictionary)->Dictionary:
	var result:=defaults();result.merge(value.duplicate(true),true)
	if value.get("version",1)==1:
		result["legacy_defeated"]=value.get("defeated",[]).duplicate();result["legacy_claimed"]=value.get("claimed",[]).duplicate()
	result.version=2
	for spawn in CONFIG.spawns:
		if not result.spawns.has(spawn.id):result.spawns[spawn.id]={"generation":0,"dead":spawn.id in result.defeated,"remaining":CONFIG.respawn.seconds if spawn.id in result.defeated else 0.0}
	for drop in result.drops:
		if not drop.has("spawn_id"):drop["spawn_id"]=base_id(drop.id);drop["generation"]=0
	return result
static func valid(value:Variant)->bool:
	if not value is Dictionary:return false
	if not integer(value.get("version",1)) or int(value.get("version",1)) not in [1,2] or not value.get("spawns",{}) is Dictionary:return false
	for key in value.get("spawns",{}):
		var spawn=value.spawns[key]
		if not spawn is Dictionary or not integer(spawn.get("generation")) or not spawn.get("dead") is bool:return false
		var time=spawn.get("remaining")
		if not (time is int or time is float) or not is_finite(float(time)) or time<0:return false
	for key in ["defeated","claimed"]:
		if not value.get(key,[]) is Array:return false
		var seen:Array=[]
		for id in value.get(key,[]):
			if not id is String or id in seen:return false
			seen.append(id)
	if not value.get("drops",[]) is Array:return false
	var seen:Array=[]
	for drop in value.get("drops",[]):
		if not drop is Dictionary or not drop.get("id") is String or drop.id in seen or drop.id in value.get("claimed",[]):return false
		var point=drop.get("position")
		if not point is Array or point.size()!=2:return false
		for number in point:
			if not (number is int or number is float) or not is_finite(float(number)):return false
		if not preload("res://scripts/world/world_layout.gd").BOUNDS.grow(-13).has_point(Vector2(point[0],point[1])):return false
		var amount=drop.get("gold",0)
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount<1 or amount!=int(amount):return false
		seen.append(drop.id)
		if drop.has("generation") and (not integer(drop.generation) or not drop.get("spawn_id") is String or drop.id!=instance_id(drop.spawn_id,int(drop.generation))):return false
	return true
func _actor(spawn:Dictionary,generation:int,dead:bool)->Dictionary:
	var row:Dictionary=CONFIG.types[spawn.type];var home=Vector2(spawn.position[0],spawn.position[1])
	return {"spawn_id":spawn.id,"generation":generation,"field_id":instance_id(spawn.id,generation),"type":spawn.type,"pos":home,"home":home,"hp":0.0 if dead else float(row.hp),"max_hp":float(row.hp),"hurt_height":28.0,"state":"DEAD" if dead else "IDLE","timer":0.0,"target":home,"repath":0.0}
func build(game)->void:
	actors.clear();routes.clear();suppressed=false
	game.world_progress.data.field=normalize(game.world_progress.data.get("field",{}))
	for spawn in CONFIG.spawns:
		var meta:Dictionary=game.world_progress.data.field.spawns[spawn.id]
		var actor:=_actor(spawn,int(meta.generation),meta.dead);actors.append(actor);routes[actor.field_id]=Navigation.new()
	game.enemies.assign(actors)
func advance(game,delta:float)->void:
	if suppressed:return
	_pickup_retry=maxf(0,_pickup_retry-delta)
	_respawn_retry=maxf(0,_respawn_retry-delta)
	for meta in game.world_progress.data.field.spawns.values():
		if meta.dead:meta.remaining=maxf(0,meta.remaining-delta)
	for actor in actors:
		if actor not in game.enemies:game.enemies.append(actor)
	for actor in actors:
		actor["hit_remaining"]=maxf(0,actor.get("hit_remaining",0)-delta)
		if actor.hp<actor.get("last_hp",actor.max_hp):actor.hit_remaining=.16
		actor["last_hp"]=actor.hp
		if actor.hp<=0:
			actor["save_retry"]=maxf(0,actor.get("save_retry",0)-delta)
			if actor.state!="DEAD" and actor.save_retry==0:_death(game,actor)
			continue
		var row:Dictionary=CONFIG.types[actor.type];var distance:float=actor.pos.distance_to(game.player_pos)
		if actor.get("stagger_remaining",0.0)>0:continue
		if actor.state=="WINDUP":
			actor.timer-=delta
			if actor.timer<=0:
				if game.player_pos.distance_to(actor.target)<=row.range and game.elemental_combat._clear_line(game,actor.pos,game.player_pos):game._receive_player_damage(row.damage,false,(game.player_pos-actor.pos).normalized())
				actor.state="RECOVERY";actor.timer=row.recovery
			continue
		if actor.state=="RECOVERY":
			actor.timer-=delta
			if actor.timer<=0:actor.state="CHASE"
			continue
		if actor.state=="IDLE" and distance>row.aggro:continue
		if game.player_pos.distance_to(actor.home)>row.leash or actor.pos.distance_to(actor.home)>row.leash:actor.state="RETURN"
		elif actor.state!="RETURN":actor.state="CHASE"
		var goal:Vector2=actor.home if actor.state=="RETURN" else game.player_pos
		if actor.state=="RETURN" and actor.pos.distance_to(actor.home)<12:actor.state="IDLE";continue
		if actor.state=="CHASE" and distance<=row.range and game.elemental_combat._clear_line(game,actor.pos,game.player_pos):
			actor.state="WINDUP";actor.timer=row.windup;actor.target=game.player_pos;continue
		if actor.get("root_remaining",0.0)>0 or actor.get("crystal_remaining",0.0)>0:continue
		actor.repath-=delta
		var route=routes[actor.field_id]
		var heading:Vector2=goal-actor.pos
		if not route.clear_line(game,actor.pos,goal):
			if actor.repath<=0:route.request_from(game,actor.pos,goal);actor.repath=.75
			while not route.waypoints.is_empty() and actor.pos.distance_to(route.waypoints[0])<6:route.waypoints.pop_front()
			if route.waypoints.is_empty():continue
			heading=route.waypoints[0]-actor.pos
		var movement:Vector2=heading.normalized()*minf(heading.length(),row.speed*delta*preload("res://scripts/combat_geometry.gd").slow_multiplier(actor))
		var steps:=maxi(1,ceili(movement.length()/3))
		for step in steps:
			var next:Vector2=actor.pos+movement/steps
			if game._is_blocked(next,14):break
			actor.pos=next
	_collect(game)
	_respawn(game)
	_save_clock+=delta
	if _save_clock>=float(CONFIG.respawn.save_interval):
		_save_clock=0
		for meta in game.world_progress.data.field.spawns.values():
			if meta.dead:game._save_character();break
	if game.player_hp<=0:game._die()
func _death(game,actor:Dictionary)->void:
	var field:Dictionary=game.world_progress.data.field;var before=field.duplicate(true)
	if actor.field_id not in field.defeated:
		_latest(field.defeated,actor.field_id)
		field.spawns[actor.spawn_id]={"generation":actor.generation,"dead":true,"remaining":CONFIG.respawn.seconds}
		field.drops.append({"id":actor.field_id,"spawn_id":actor.spawn_id,"generation":actor.generation,"position":[actor.pos.x,actor.pos.y],"gold":CONFIG.types[actor.type].gold})
	if not game._save_character():game.world_progress.data.field=before;actor["save_retry"]=1.0;return
	actor.state="DEAD"
func _collect(game)->void:
	if _pickup_retry>0:return
	var field:Dictionary=game.world_progress.data.field
	for i in range(field.drops.size()-1,-1,-1):
		var drop:Dictionary=field.drops[i];var point=Vector2(drop.position[0],drop.position[1])
		if game.player_pos.distance_to(point)>30:continue
		var before=field.duplicate(true);var gold:int=game.bank_gold
		_latest(field.claimed,drop.id);field.drops.remove_at(i);game.bank_gold+=int(drop.gold)
		if not game._save_character():game.world_progress.data.field=before;game.bank_gold=gold;_pickup_retry=1.0;return
		game._message("골드 +%d"%drop.gold)
		# Saving replaces the progress document; continue against that authoritative copy.
		field=game.world_progress.data.field

static func _latest(history:Array,id:String)->void:
	for index in range(history.size()-1,-1,-1):
		if base_id(history[index])==base_id(id):history.remove_at(index)
	history.append(id)

func _respawn(game)->void:
	if _respawn_retry>0:return
	for index in actors.size():
		var old:Dictionary=actors[index]
		if old.state!="DEAD":continue
		var field:Dictionary=game.world_progress.data.field;var meta:Dictionary=field.spawns[old.spawn_id]
		if meta.remaining>0 or old.home.distance_to(game.player_pos)<float(CONFIG.respawn.minimum_player_distance) or game._field_spawn_visible(old.home):continue
		var outstanding:=0
		for drop in field.drops:
			if drop.spawn_id==old.spawn_id:outstanding+=1
		if outstanding>=int(CONFIG.respawn.max_outstanding_drops_per_spawn) or game._is_blocked(old.home,14):continue
		var crowded:=false
		for enemy in game.enemies:
			if enemy.hp>0 and enemy.pos.distance_to(old.home)<40:crowded=true;break
		if crowded:continue
		var before=field.duplicate(true);meta.generation+=1;meta.dead=false;meta.remaining=0.0
		if not game._save_character():game.world_progress.data.field=before;_respawn_retry=1.0;continue
		var spawn:Dictionary={}
		for candidate in CONFIG.spawns:
			if candidate.id==old.spawn_id:spawn=candidate;break
		var next:=_actor(spawn,int(meta.generation),false)
		actors[index]=next;game.enemies.erase(old);game.enemies.append(next);routes.erase(old.field_id);routes[next.field_id]=Navigation.new()
		game._replace_field_view(old,next)
