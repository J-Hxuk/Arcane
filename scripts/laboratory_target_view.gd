extends Node2D
## Replaceable training actor, ground anchor and silhouette shared with world art.
var enemy:Dictionary
func _ready() -> void:
	var body:=AnimatedSprite2D.new();body.sprite_frames=preload("res://scripts/world/world_art.gd").frames(preload("res://scripts/world/world_art.gd").GUARDIAN)
	body.animation=&"down";body.position=Vector2(0,-30);body.scale=Vector2.ONE*1.5
	body.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(body)
func _draw() -> void:
	var maximum:=maxf(1,float(enemy.get("max_hp",200)))
	draw_rect(Rect2(-20,-65,40,4),Color("493d3d"))
	draw_rect(Rect2(-20,-65,40*clampf(float(enemy.get("hp",0))/maximum,0,1),4),Color("92d294"))
	draw_string(ThemeDB.fallback_font,Vector2(-20,23),"%d 피해"%roundi(maxf(0,maximum-float(enemy.get("hp",maximum)))),HORIZONTAL_ALIGNMENT_LEFT,-1,12)
