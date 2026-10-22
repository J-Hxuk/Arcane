extends Node2D
const Art = preload("res://scripts/world/world_art.gd")
@export_enum("TOWN", "WILDS", "RUINS","NORTH") var region := "TOWN"
const ROAD := [Vector2(1620, 900), Vector2(1950, 900), Vector2(2050, 1120), Vector2(2310, 1020), Vector2(2670, 900), Vector2(3370, 900)]
func _ready() -> void: texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _on_path(point: Vector2) -> bool:
	if region=="NORTH":return absf(point.x-(790+sin(point.y/180)*80))<48
	if region == "TOWN":
		return Rect2(150, 700, 1470, 180).has_point(point) or Rect2(710, 0, 160, 1350).has_point(point) or point.distance_to(Vector2(790, 790)) < 110 or Rect2(500, 500, 80, 200).has_point(point) or Rect2(960, 480, 80, 220).has_point(point) or Rect2(390, 1140, 80, 210).has_point(point) or Rect2(1110, 1130, 80, 220).has_point(point)
	for i in range(ROAD.size() - 1):
		if Geometry2D.get_closest_point_to_segment(point, ROAD[i], ROAD[i + 1]).distance_to(point) < 55: return true
	return false
func _draw() -> void:
	var rect := Rect2(0, 0, 1620, 1920) if region == "TOWN" else Rect2(1620, 0, 1340, 1920) if region == "WILDS" else Rect2(2960, 0, 880, 1920)
	if region=="NORTH":rect=Rect2(0,-960,3840,960)
	draw_texture_rect(Art.GRASS, rect, true)
	for y in range(int(rect.position.y), int(rect.end.y), 32):
		for x in range(floori(rect.position.x / 32) * 32, ceili(rect.end.x), 32):
			var cell := Rect2(x, y, 32, 32).intersection(rect)
			if cell.size.x <= 0: continue
			var center := cell.get_center()
			var arena := region == "RUINS" and Rect2(3000, 500, 720, 820).has_point(center)
			if arena or _on_path(center):
				var tile: Texture2D = Art.RUIN if arena else Art.COBBLE if region == "TOWN" else Art.DIRT
				draw_texture_rect_region(tile, cell, Rect2(Vector2(posmod(x, 64), posmod(y, 64)), cell.size))
	if region == "RUINS":
		draw_arc(Vector2(3370, 910), 235, 0, TAU, 64, Color("849282"), 3)
