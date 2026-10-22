extends Node2D
const Art = preload("res://scripts/world/world_art.gd")
var game
var body: AnimatedSprite2D
var _last_position := Vector2.ZERO
func _ready() -> void:
	body = AnimatedSprite2D.new()
	body.name = "GuardianSprite"
	body.sprite_frames = Art.frames(Art.GUARDIAN)
	body.position = Vector2(0, -44)
	body.scale = Vector2.ONE * 2.2
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body)
	_last_position = position
func _process(_delta: float) -> void:
	if game == null: return
	var boss = game.guardian
	body.animation = Art.direction(boss.aim)
	if position.distance_to(_last_position) > 0.1: body.play()
	else: body.pause(); body.frame = 0
	_last_position = position
	body.modulate = Color("889b91") if boss.state == "VICTORY" else Color.WHITE
	body.rotation = -PI * 0.5 if boss.state == "VICTORY" else 0.0
	body.position.y = -12 if boss.state == "VICTORY" else -44
	queue_redraw()
func _draw() -> void:
	if game == null: return
	var boss = game.guardian
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 31, Color(0.05, 0.08, 0.1, 0.6))
	draw_set_transform(Vector2.ZERO)
	if boss.state == "VICTORY": return
	if not boss.actor.is_empty() and boss.actor.get("exposed", false): draw_arc(Vector2.ZERO, 32, 0, TAU, 32, Color("a8d8a5"), 3)
	if not boss.actor.is_empty() and boss.actor.get("wet_remaining", 0.0) > 0: draw_arc(Vector2.ZERO, 35, 0.2, PI + 0.2, 32, Color("79c9e5"), 3)
	if boss.phase == 2: draw_arc(Vector2.ZERO, 29, 0, TAU, 32, Color("dba178"), 2)
