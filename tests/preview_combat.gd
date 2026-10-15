extends SceneTree
## Run without --headless. Saves real viewport renders and exercises _input().

const Game = preload("res://scripts/main.gd")
const CombatInput = preload("res://scripts/combat_input.gd")
const SCENE = preload("res://scenes/main.tscn")
var game: Game
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run preview_combat.gd with a display driver, without --headless.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.task002_artifacts")
	root.size = Vector2i(1160, 720)
	game = SCENE.instantiate()
	game.save_path = "res://.task002_artifacts/preview_character.json"
	root.add_child(game)
	game.set_process(false)
	await _key(KEY_1, true)
	await _key(KEY_1, false)
	_check(game.game_state == "DUNGEON", "Engine dispatches hub input to the real main scene")
	await _capture("normal")
	await _key(KEY_SHIFT, true)
	await _key(KEY_Q, true)
	await _key(KEY_Q, false)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST and game.runes == ["Q"], "Engine dispatches Shift and command key events")
	await _capture("mobile")
	await _key(KEY_SHIFT, false)
	# Capturing a frame may exceed the tap window, so start a fresh gesture.
	game._reset_combat_input()
	await _key(KEY_SHIFT, true)
	await _key(KEY_SHIFT, false)
	await _key(KEY_SHIFT, true)
	await _key(KEY_SHIFT, false)
	await _key(KEY_W, true)
	await _key(KEY_W, false)
	await _key(KEY_A, true)
	await _key(KEY_A, false)
	_check(game.combat_input.mode == CombatInput.Mode.FOCUS_CAST and game.runes == ["W", "A"], "Engine dispatches double tap and focus WASD commands")
	await _capture("focus")
	await _key(KEY_ESCAPE, true)
	await _key(KEY_ESCAPE, false)
	await _key(KEY_SHIFT, true)
	await _key(KEY_Q, true)
	await _key(KEY_Q, false)
	await _key(KEY_E, true)
	await _key(KEY_E, false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	_check(game.missiles.size() == 1 and game.runes.is_empty(), "Engine dispatches LMB to direct spell release")
	await _capture("released")
	# Render the maximum visible buffer and its error feedback as well.
	for index in range(32):
		game._on_command_entered("Q")
	game._on_command_entered("Q")
	await _capture("full_buffer")
	game.free()
	print("RENDER / INPUT DISPATCH: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _capture(label: String) -> void:
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png("res://.task002_artifacts/" + label + ".png")
	_check(result == OK and image.get_size() == Vector2i(1160, 720), "Rendered " + label + " HUD at 1160 x 720")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
