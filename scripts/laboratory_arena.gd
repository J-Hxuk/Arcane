extends Control
## Isolated safe actors, shared combat executor. Never owns a character or save.
const Combat = preload("res://scripts/elemental_combat.gd")
const Definition = preload("res://scripts/spell_definition.gd")
const AREA := Rect2(0, 0, 1600, 960)
const EXIT_POS := Vector2(-1000, -1000)
const CATALYSTS := [
	{"element":"WOOD", "pos":Vector2(630,100), "name":"성장 식물"},
	{"element":"FIRE", "pos":Vector2(720,100), "name":"마법 화로"},
	{"element":"EARTH", "pos":Vector2(810,100), "name":"토양 시료"},
	{"element":"METAL", "pos":Vector2(900,100), "name":"금속 결정"},
	{"element":"WATER", "pos":Vector2(990,100), "name":"수류 장치"},
]
var combat := Combat.new()
func _blink_position_blocked(point:Vector2,radius:float)->bool:return _is_blocked(point,radius)
var enemies: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var player_pos := Vector2(180, 210)
var player_hp := 100.0
var hit_feedback:
	get:return controller.hit_feedback if controller!=null else null
func _receive_player_damage(amount:float,strong:=false,direction:=Vector2.ZERO)->bool:
	if controller!=null:
		var applied:bool=controller._receive_player_damage(amount,strong,direction)
		player_hp=controller.player_hp
		return applied
	player_hp=maxf(0,player_hp-amount);return true
var game_state := "LAB"
var moving_targets := false
var controller
var navigation := preload("res://scripts/destination_movement.gd").new()
var dodge := preload("res://scripts/dodge_motion.gd").new()
var body: AnimatedSprite2D
const CombatInput=preload("res://scripts/combat_input.gd")
var fallback_input:=CombatInput.new()
var combat_input:
	get:return controller.combat_input if controller!=null else fallback_input
var player_attack_cooldown:float:
	get:return controller.player_attack_cooldown if controller!=null else 0.0
var focus_active:=false
var viewport:SubViewport
var viewport_host:TextureRect
var camera:Camera2D
var actors:Node2D
var player_view:Node2D
var scenery:Node2D
var catalyst_reaction:=""
var catalyst_seconds:=0.0
func observe_catalyst(element:String)->void:
	catalyst_reaction=element;catalyst_seconds=2.8;scenery.queue_redraw()
var effects:Node2D
var target_views:Array[Node2D]=[]
var solids:Array=[{"rect":Rect2(680,370,30,32)},{"rect":Rect2(850,420,60,38)}]

func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_targets()
	# Display the viewport texture without forwarding root-window input into a
	# second viewport. The controller owns all input in root screen coordinates.
	viewport_host=TextureRect.new();viewport_host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport_host.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;viewport_host.stretch_mode=TextureRect.STRETCH_SCALE
	add_child(viewport_host);viewport_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport=SubViewport.new();viewport.size=Vector2i(1090,400);viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport);viewport_host.texture=viewport.get_texture()
	resized.connect(func():viewport.size=Vector2i(size))
	scenery=preload("res://scripts/laboratory_scene_view.gd").new();scenery.arena=self;viewport.add_child(scenery)
	actors=Node2D.new();actors.y_sort_enabled=true;viewport.add_child(actors)
	var Prop=preload("res://scripts/world/world_prop.gd")
	for data in [{"kind":"tree","pos":Vector2(695,402)}, {"kind":"rock","pos":Vector2(880,458),"rect":Rect2(850,420,60,38)}]:
		var prop=Prop.new();prop.configure(data);actors.add_child(prop)
	player_view=preload("res://scripts/world/world_player_view.gd").new();player_view.game=self;actors.add_child(player_view)
	player_view.set_process(false) # advance() owns the single presentation update.
	body=player_view.body
	for enemy in enemies:
		var view=preload("res://scripts/laboratory_target_view.gd").new();view.enemy=enemy;actors.add_child(view);target_views.append(view)
	effects=preload("res://scripts/laboratory_scene_view.gd").new();effects.arena=self;effects.effects_only=true;viewport.add_child(effects)
	camera=Camera2D.new();camera.position_smoothing_enabled=true;camera.position_smoothing_speed=7
	camera.limit_left=0;camera.limit_top=0;camera.limit_right=1600;camera.limit_bottom=960
	camera.zoom=Vector2.ONE;camera.position=player_pos;viewport.add_child(camera);camera.reset_smoothing();camera.force_update_scroll()
	_update_views()

func reset_targets() -> void:
	navigation.cancel(); dodge.reset()
	combat.clear()
	missiles.clear()
	enemies.clear()
	for position in [Vector2(330, 210), Vector2(410, 210), Vector2(490, 210), Vector2(245, 155), Vector2(200, 295)]:
		enemies.append({"pos": position, "home": position, "hp": 200.0, "max_hp": 200.0, "shot": INF, "hurt_height":30.0})
	queue_redraw()
	for i in target_views.size():target_views[i].enemy=enemies[i]
	_update_views()

func _is_blocked(point: Vector2, radius := 13.0) -> bool:
	if not AREA.grow(-radius).has_point(point) or combat.blocks(point, radius):return true
	for shape in solids:
		var rect:Rect2=shape["rect"]
		if point.distance_to(point.clamp(rect.position,rect.end))<radius:return true
	return false

func manifest(definition: Definition) -> bool:
	return combat.cast(self, definition, aim_direction(), aim_world_position() if is_controlled() else null)

func is_controlled() -> bool:
	return controller != null and controller.laboratory_panel.trial_panel.visible

func aim_direction() -> Vector2:
	if not is_controlled(): return Vector2.RIGHT
	return dodge.cursor_heading(player_pos, aim_world_position())

func screen_to_world(point:Vector2) -> Vector2:
	var local:=viewport_host.get_global_transform_with_canvas().affine_inverse()*point
	if viewport==null:return local
	var pixels:=local*Vector2(viewport.size)/viewport_host.size.max(Vector2.ONE)
	return viewport.get_canvas_transform().affine_inverse()*pixels
func world_to_screen(point:Vector2) -> Vector2:
	var local:Vector2=viewport.get_canvas_transform()*point if viewport!=null else point
	if viewport!=null:local=local*viewport_host.size/Vector2(viewport.size).max(Vector2.ONE)
	return viewport_host.get_global_transform_with_canvas()*local
func aim_world_position() -> Vector2:return screen_to_world(get_viewport().get_mouse_position())
func _update_views() -> void:
	if player_view==null:return
	while target_views.size()>enemies.size():target_views.pop_back().queue_free()
	while target_views.size()<enemies.size():
		var view=preload("res://scripts/laboratory_target_view.gd").new();view.enemy=enemies[target_views.size()];actors.add_child(view);target_views.append(view)
	player_view.position=player_pos;player_view.update_presentation(0)
	camera.position=player_pos
	if controller!=null:
		var display_scale:=viewport_host.size/Vector2(viewport.size).max(Vector2.ONE)
		camera.offset=controller.hit_feedback.camera_offset(controller.hit_screen.shake_scale,camera.zoom*display_scale)
	camera.force_update_scroll()
	for i in target_views.size():target_views[i].enemy=enemies[i];target_views[i].position=enemies[i]["pos"];target_views[i].queue_redraw()
	scenery.queue_redraw();effects.queue_redraw()

func _try_move_player(motion: Vector2) -> void:
	var count := maxi(1, ceili(motion.length()/2))
	for i in count:
		if _is_blocked(player_pos + motion/count): break
		player_pos += motion/count

func melee(damage: float) -> void:
	for enemy in enemies:
		var offset: Vector2 = enemy["pos"] - player_pos
		if enemy["hp"] > 0 and offset.length() <= 85 and (offset.is_zero_approx() or offset.normalized().dot(aim_direction()) > 0.3) and combat._clear_line(self, player_pos, enemy["pos"]): enemy["hp"] -= damage

func nearest_catalyst() -> String:
	for catalyst in CATALYSTS:
		if player_pos.distance_to(catalyst["pos"]) < 55: return catalyst["element"]
	return ""

func advance(delta: float) -> void:
	catalyst_seconds=maxf(0,catalyst_seconds-delta)
	if is_controlled():
		var was_dodging := dodge.active
		dodge.advance(self, delta)
		if controller.combat_input.mode == controller.CombatInput.Mode.FOCUS_CAST: navigation.cancel()
		elif not was_dodging: navigation.advance(self, delta, controller._movement_speed())
	combat.update(self, delta)
	combat.update_missiles(self, delta, 1.0)
	if moving_targets:
		for enemy in enemies:
			if enemy.get("root_remaining", 0.0) > 0.0 or enemy.get("stagger_remaining", 0.0) > 0.0: continue
			var direction: float = enemy.get("travel", 1.0)
			var destination: Vector2 = enemy["pos"] + Vector2(0, direction * 25.0 * delta * preload("res://scripts/combat_geometry.gd").slow_multiplier(enemy))
			if absf(destination.y - Vector2(enemy["home"]).y) > 25.0: enemy["travel"] = -direction
			elif not _is_blocked(destination, 15.0): enemy["pos"] = destination
	queue_redraw()
	_update_views()

func _process(delta: float) -> void:
	# Effects continue while the journal is open; replay never advances this arena.
	advance(delta)
