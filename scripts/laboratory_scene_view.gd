extends Node2D
## The same foot-plane, tile scale and world VFX units as the outdoor world.
const Art=preload("res://scripts/world/world_art.gd")
var arena
var effects_only:=false
func _ready() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
var enemies:Array:
	get:return arena.enemies
var missiles:Array:
	get:return arena.missiles
func _draw() -> void:
	if effects_only:
		arena.combat.draw(self);return
	for y in range(0,960,64):
		for x in range(0,1600,64):draw_texture_rect(Art.COBBLE,Rect2(x,y,64,64),false)
	draw_rect(arena.AREA,Color("c6baa0"),false,6)
	for catalyst in arena.CATALYSTS:
		var p:Vector2=catalyst["pos"]
		draw_set_transform(p,0,Vector2(1,.45));draw_circle(Vector2.ZERO,29,Color(.12,.15,.13,.45));draw_set_transform(Vector2.ZERO)
		match catalyst.element:
			"WOOD":draw_texture_rect(Art.TREE,Rect2(p-Vector2(29,72),Vector2(58,76)),false)
			"FIRE":
				draw_texture_rect(Art.ROCK,Rect2(p-Vector2(24,20),Vector2(48,30)),false);preload("res://scripts/spell_vfx.gd").flame(self,p-Vector2(0,8),1.2,arena.combat.visual_time)
			"EARTH":
				for i in 3:draw_texture_rect(Art.ROCK,Rect2(p+Vector2(-22+i*8,-28-i*7),Vector2(38,28)),false)
			"METAL":
				draw_texture_rect(Art.ROCK,Rect2(p-Vector2(23,25),Vector2(46,35)),false)
				for i in 3:draw_colored_polygon(PackedVector2Array([p+Vector2(i*10-12,4),p+Vector2(i*10-9,-40+i*7),p+Vector2(i*10,3)]),Color("b4d6e3"))
			"WATER":
				draw_set_transform(p,0,Vector2(1,.5));draw_circle(Vector2.ZERO,30,Color("8e9b9d"));draw_circle(Vector2.ZERO,24,Color("4b91ac"));draw_arc(Vector2.ZERO,17,0,TAU,24,Color("a8e0ed"),2);draw_set_transform(Vector2.ZERO)
		draw_string(ThemeDB.fallback_font,p+Vector2(-30,30),catalyst["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,12)
		draw_string(ThemeDB.fallback_font,p+Vector2(-24,46),"[E] 관찰",HORIZONTAL_ALIGNMENT_LEFT,-1,11)
		var color:=Color(preload("res://scripts/research_lore.gd").DATA[catalyst.element].color)
		var active:bool=arena.catalyst_reaction==catalyst.element and arena.catalyst_seconds>0
		var strength:float=arena.catalyst_seconds/2.8 if active else .15
		for i in (10 if active else 3):
			var angle:float=i*TAU/10+arena.combat.visual_time*(1 if catalyst.element in ["WATER","FIRE"] else .2)
			var q:Vector2=p+Vector2.from_angle(angle)* (16+(1-strength)*30)
			if catalyst.element=="FIRE":preload("res://scripts/spell_vfx.gd").flame(self,q,.25+strength*.3,arena.combat.visual_time)
			elif catalyst.element=="METAL":draw_line(q,q+Vector2(0,-8*strength),color,2)
			elif catalyst.element=="EARTH":draw_rect(Rect2(q,Vector2(3,3+strength*7)),color)
			elif catalyst.element=="WOOD":draw_line(p,q+Vector2(0,-strength*12),color,1+strength)
			else:draw_arc(q,3+strength*5,angle,angle+PI,12,color,2)
