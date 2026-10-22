extends Node2D
## World effects must render after opaque chunk floors, in world coordinates.
const VFX = preload("res://scripts/spell_vfx.gd")
var game
func _draw() -> void:
	if game == null: return
	for entry in game.layout.interactions:
		var point: Vector2 = entry["pos"]
		draw_arc(point, 12, 0, TAU, 24, Color("c4bb83"), 2)
		if entry["id"] in ["laboratory", "library", "rest", "smith", "checkpoint", "arena"] or str(entry["id"]).begins_with("mentor_"):
			draw_string(ThemeDB.fallback_font, point + Vector2(-35, 32), entry["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e3d8ad"))
	if game.navigation.active: draw_arc(game.navigation.destination, 10, 0, TAU, 24, Color("f0da94"), 2)
	if game.developer_mode and game.navigation.corrected:
		draw_arc(game.navigation.clicked_destination, 7, 0, TAU, 16, Color("e78776"), 2)
		draw_line(game.navigation.clicked_destination, game.navigation.destination, Color("a0b5ac"), 1)
	if game.guardian.active:
		game.guardian.draw_telegraph(self)
		draw_line(Vector2(3010, 820), Vector2(3010, 1000), Color("b7c7d9"), 7)
	var combat = game.elemental_combat
	preload("res://scripts/water_vfx.gd").states(self,combat.water_states,combat.visual_time)
	for enemy in game.field_system.actors:
		if enemy.state=="WINDUP":
			var radius:float=game.field_system.CONFIG.types[enemy.type].range
			draw_circle(enemy.target,radius,Color(.85,.42,.22,.2));draw_arc(enemy.target,radius,0,TAU,32,Color("e6a879"),2)
	for drop in game.world_progress.data.get("field",{}).get("drops",[]):
		var point=Vector2(drop.position[0],drop.position[1]);draw_set_transform(point,0,Vector2(1,.55));draw_circle(Vector2.ZERO,9,Color("6d4e25"));draw_circle(Vector2(0,-3),7,Color("edce76"));draw_arc(Vector2(0,-3),5,0,TAU,16,Color("a88142"),1);draw_set_transform(Vector2.ZERO)
	for barrier in combat.barriers: VFX.barrier(self, barrier)
	for enemy in game.enemies: VFX.statuses(self, enemy, combat.visual_time)
	for missile in game.missiles: VFX.projectile(self, missile, combat.visual_time)
	for visual in combat.visuals: VFX.impact(self, visual, combat.visual_time)
