extends Node2D
const Art = preload("res://scripts/world/world_art.gd")
var element := "WOOD"
func _ready() -> void:
	var texture := AtlasTexture.new(); texture.atlas = Art.TRAVELLER; texture.region = Rect2(0,0,32,40)
	var body := Art.sprite(texture, Vector2(-24,-60), Vector2(48,60)); add_child(body)
	body.modulate = {"WOOD":Color("a5cf8e"),"FIRE":Color("f3ad83"),"EARTH":Color("dbc696"),"METAL":Color("c0c7e7"),"WATER":Color("8ed9eb")}[element]
func _draw() -> void:
	var p := Vector2(0,-69)
	match element:
		"WOOD": draw_colored_polygon(PackedVector2Array([p+Vector2(-12,6),p+Vector2(3,-12),p+Vector2(11,6)]),Color("9cc07c"))
		"FIRE": preload("res://scripts/spell_vfx.gd").flame(self,p+Vector2(0,7),0.55,0)
		"EARTH": draw_rect(Rect2(p-Vector2(13,6),Vector2(26,14)),Color("b9a784"))
		"METAL": draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(8,0),p+Vector2(0,10),p-Vector2(8,0)]),Color("d5deed"))
		"WATER": draw_circle(p,7,Color("82cde5")); draw_arc(p,11,0.3,2.8,20,Color("beddeb"),2)
