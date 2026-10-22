extends SceneTree
## Presentation-only contracts; gameplay regression suites remain separate.
const Scene = preload("res://scenes/world_main.tscn")
const F = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const Art = preload("res://scripts/world/world_art.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS: ", title)
	else: failures += 1; push_error("FAIL: " + title)
func run() -> void:
	var path := "res://.task002_artifacts/visual_topdown/unit_fixture.json"
	A.write(path, F.fixture("WATER", 1787453028))
	var game = Scene.instantiate()
	game.save_path = path; root.add_child(game); game.set_process(false)
	await process_frame
	var document: Dictionary = game._character_document()
	var bytes := FileAccess.get_file_as_bytes(path)
	check(game.player_view.body is AnimatedSprite2D and game.guardian_view.body is AnimatedSprite2D, "Player and guardian use replaceable AnimatedSprite2D bodies")
	var frames: SpriteFrames = game.player_view.body.sprite_frames
	for direction in Art.DIRECTIONS:
		check(frames.has_animation(direction) and frames.get_frame_count(direction) == 4, "Four-direction walking frames: " + direction)
	var image: Image = Art.TRAVELLER.get_image()
	for row in range(1, 4):
		check(image.get_region(Rect2i(0, row * 40, 32, 40)).get_data() != image.get_region(Rect2i(0, 0, 32, 40)).get_data(), "Facing has distinct source pixels: " + Art.DIRECTIONS[row])
	check(game.player_view.body.position == Vector2(0, -30) and game.player_view.body.scale == Vector2.ONE * 1.5, "Actor feet align to the unchanged ground/physics anchor")
	for vector in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		game.player_view._last_position = game.player_pos - vector
		game.player_view.update_presentation(0.016)
		check(game.player_view.facing == Art.direction(vector), "Movement selects the correct facing for " + str(vector))
	var buildings := 0
	var walls := 0
	for prop in game.actors.get_children():
		if not prop.get("data") is Dictionary: continue
		var data: Dictionary = prop.data
		if data.get("kind") == "building":
			buildings += 1
			var sprite: Sprite2D = prop.get_child(0)
			var footprint: Rect2 = data["rect"]
			check(sprite.texture is Texture2D and prop.position.y == footprint.end.y and sprite.position.y < -footprint.size.y, "Building elevation and foot-plane sort: " + data["name"])
		elif data.get("kind") in ["wall", "ruin"]:
			walls += 1
			check(prop.y_sort_enabled and prop.get_child_count() > 1, "Long wall has independently sorted sections")
	check(buildings == 4 and walls == 10 and game.actors.y_sort_enabled, "All existing structures participate in depth sorting")
	for entry in game.layout.interactions:
		check(not game.layout.blocked(entry["pos"], 13), "Original interaction ground position remains reachable: " + entry["id"])
	check(game._character_document() == document and FileAccess.get_file_as_bytes(path) == bytes, "Visual updates never mutate character, journal, bindings, or save bytes")
	print("WORLD VISUAL UNIT: %d checks, %d failures" % [checks, failures])
	game.free(); quit(1 if failures else 0)
