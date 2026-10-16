extends Control
## Isolated safe actors, shared combat executor. Never owns a character or save.
const Combat = preload("res://scripts/elemental_combat.gd")
const Definition = preload("res://scripts/spell_definition.gd")
const AREA := Rect2(15, 30, 1060, 330)
const EXIT_POS := Vector2(-1000, -1000)
var combat := Combat.new()
var enemies: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var player_pos := Vector2(180, 210)
var player_hp := 100.0
var game_state := "LAB"
var moving_targets := false

func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_targets()

func reset_targets() -> void:
	combat.clear()
	missiles.clear()
	enemies.clear()
	for position in [Vector2(330, 210), Vector2(410, 210), Vector2(490, 210), Vector2(245, 155), Vector2(200, 295)]:
		enemies.append({"pos": position, "home": position, "hp": 200.0, "max_hp": 200.0, "shot": INF})
	queue_redraw()

func _is_blocked(point: Vector2, radius := 13.0) -> bool:
	return not AREA.grow(-radius).has_point(point) or combat.blocks(point, radius)

func manifest(definition: Definition) -> bool:
	# Repeatable horizontal test lane; control is ordinary direct chant + release.
	return combat.cast(self, definition, Vector2.RIGHT)

func advance(delta: float) -> void:
	combat.update(self, delta)
	combat.update_missiles(self, delta, 1.0)
	if moving_targets:
		for enemy in enemies:
			if enemy.get("root_remaining", 0.0) > 0.0 or enemy.get("stagger_remaining", 0.0) > 0.0: continue
			var direction: float = enemy.get("travel", 1.0)
			var destination: Vector2 = enemy["pos"] + Vector2(0, direction * 25.0 * delta)
			if absf(destination.y - Vector2(enemy["home"]).y) > 25.0: enemy["travel"] = -direction
			elif not _is_blocked(destination, 15.0): enemy["pos"] = destination
	queue_redraw()

func _process(delta: float) -> void:
	# Effects continue while the journal is open; replay never advances this arena.
	advance(delta)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101e2d"))
	draw_rect(AREA, Color("202e3c"))
	for x in range(30, 1070, 40): draw_line(Vector2(x, 30), Vector2(x, 360), Color("293c49"))
	for y in range(40, 360, 40): draw_line(Vector2(15, y), Vector2(1075, y), Color("293c49"))
	draw_line(player_pos, player_pos + Vector2(510, 0), Color("3c5361"), 1.0)
	draw_circle(player_pos, 13.0, Color("6ed8e9"))
	var font := get_theme_default_font()
	draw_string(font, Vector2(24, 22), "안전 시험장 · 표적은 공격하지 않습니다 · 오른쪽 사선으로 직접 방출", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		var position: Vector2 = enemy["pos"]
		draw_rect(Rect2(position - Vector2(12, 16), Vector2(24, 32)), Color("ad7980"))
		draw_rect(Rect2(position + Vector2(-19, -25), Vector2(38, 4)), Color("402e38"))
		draw_rect(Rect2(position + Vector2(-19, -25), Vector2(38 * maxf(0.0, enemy["hp"]) / 200.0, 4)), Color("9fd494"))
		var status := ""
		if enemy.get("burn_remaining", 0.0) > 0.0: status += " 연소"
		if enemy.get("root_remaining", 0.0) > 0.0: status += " 속박"
		if enemy.get("stagger_remaining", 0.0) > 0.0: status += " 경직"
		draw_string(font, position + Vector2(-30, 42), "%d 피해%s" % [roundi(200.0 - enemy["hp"]), status], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	combat.draw(self)
