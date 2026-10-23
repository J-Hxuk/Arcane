extends Node2D
## A foot-anchored four-direction actor; this class never changes simulation state.
const Art = preload("res://scripts/world/world_art.gd")
var game
var body: AnimatedSprite2D
var facing: StringName = &"down"
var _last_position := Vector2.ZERO
var mana_orb: Control
var mana_visuals_enabled := true
var _observed_inputs: Array = []
var _observed_mode := -1

func _ready() -> void:
	body = AnimatedSprite2D.new()
	body.name = "CharacterSprite"
	body.sprite_frames = Art.frames(Art.TRAVELLER)
	body.position = Vector2(0, -30)
	body.scale = Vector2.ONE * 1.5
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.animation = facing
	add_child(body)
	mana_orb = preload("res://scripts/mana_orb_view.gd").new()
	mana_orb.transparent_view = true
	mana_orb.position = Vector2(-32, -94)
	mana_orb.size = Vector2(64, 64)
	add_child(mana_orb)
	if game != null: _last_position = game.player_pos

func _process(delta: float) -> void: update_presentation(delta)

func update_presentation(_delta: float) -> void:
	if game == null or body == null: return
	var chant_source = game if game.has_method("_inspect_chant") else game.controller
	var casting: bool = game.combat_input.mode != game.CombatInput.Mode.NORMAL
	mana_orb.visible = mana_visuals_enabled and chant_source != null and casting and not chant_source.runes.is_empty() and chant_source.game_state in ["DUNGEON", "LAB"]
	if mana_orb.visible:
		mana_orb.observation_gain = 1.45 if game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST else 1.0
		if _observed_inputs != chant_source.chant_inputs or _observed_mode != game.combat_input.mode:
			_observed_inputs = chant_source.chant_inputs.duplicate(true)
			_observed_mode = game.combat_input.mode
			var simulation: Dictionary = chant_source._inspect_chant(true).simulation
			mana_orb.show_snapshot(simulation.get("final_state", {}), 0.0, true)
	else:
		_observed_inputs = []
		_observed_mode = -1
		if mana_orb.animated: mana_orb.show_snapshot({})
	var motion: Vector2 = game.player_pos - _last_position
	_last_position = game.player_pos
	var moving := motion.length() > 0.01 and motion.length() < 80
	var aiming: bool = game.combat_input.mode != game.CombatInput.Mode.NORMAL or game.player_attack_cooldown > 0.6
	if aiming:
		facing = Art.direction(game.aim_world_position() - game.player_pos)
	elif moving:
		facing = Art.direction(motion)
	body.animation = facing
	if moving: body.play()
	else: body.pause(); body.frame = 0
	var hit=game.hit_feedback
	if hit!=null and hit.remaining>0:
		body.modulate=Color(1.9,.45,.4) if hit.heavy else Color(1.8,.8,.7)
		body.position=Vector2(0,-30)+hit.offset()
	else:body.modulate=Color.WHITE;body.position=Vector2(0,-30)
	queue_redraw()

func _draw() -> void:
	if game == null: return
	# Ground shadow and aim stay in the original top-down physics plane.
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, 17, Color(0.06, 0.12, 0.14, 0.55))
	draw_set_transform(Vector2.ZERO)
	var aim: Vector2 = (game.aim_world_position() - game.player_pos).normalized()
	if aim.length_squared() > 0:
		draw_colored_polygon(PackedVector2Array([aim * 28, aim * 23 + aim.orthogonal() * 3, aim * 23 - aim.orthogonal() * 3]), Color("e4d1a2"))
	if game.combat_input.mode != game.CombatInput.Mode.NORMAL: draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color("b6adf0"), 2)
	if game.dodge.active: draw_arc(Vector2.ZERO, 19, 0, TAU, 24, Color("b0e5fc"), 3)
	if game.focus_active: draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color("85c5ef"), 2)
