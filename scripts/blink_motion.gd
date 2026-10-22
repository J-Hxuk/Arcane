extends RefCounted
static var CONFIG:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/movement_abilities.json"))
static func destination(game,cursor:Vector2)->Dictionary:
	var start:Vector2=game.player_pos
	var offset:=cursor-start
	var maximum:float=preload("res://scripts/dodge_motion.gd").SPEED*preload("res://scripts/dodge_motion.gd").DURATION*float(CONFIG.blink_distance_multiplier)
	if offset.length()<1:return {"allowed":false}
	var target:=start+offset.normalized()*minf(offset.length(),maximum)
	var endpoint:=start;var steps:=maxi(1,ceili(start.distance_to(target)/2.0))
	for index in range(1,steps+1):
		var point:=start.lerp(target,float(index)/steps)
		if game._blink_position_blocked(point,13.0):break
		endpoint=point
	return {"allowed":endpoint.distance_to(start)>=1,"position":endpoint,"maximum":maximum}
