extends SceneTree
## Real rendering and GUI input dispatch; no player save is opened.

const SCENE = preload("res://scenes/main.tscn")
const DIR := "res://.task002_artifacts/phase2a/"
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a display driver to run preview_research.gd.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size = Vector2i(1160, 720)
	root.gui_embed_subwindows = true
	var path := DIR + "preview.json"
	var fixture := FileAccess.open(path, FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"magic": 67, "body": 34, "fixed_seed": 12345, "learned": ["EMBER"]}))
	fixture.close()
	game = SCENE.instantiate()
	game.save_path = path
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await _key(KEY_B)
	var ui = game.research_panel
	_check(ui.is_open() and ui.summary.text.contains("0 / 3"), "Engine B input opens zero-slot research UI")
	await _capture("research_zero")
	await _click(ui.rows["FIRE"]["clue"])
	_check(game.research.research_clues.size() == 1 and game.research.researched_base_elements.is_empty(), "GUI book click records a clue with zero slot use")
	await _click(ui.rows["FIRE"]["start"])
	_check(ui.confirmation.visible and game.research.researched_base_elements.is_empty(), "GUI research click opens confirmation without committing")
	await _capture("research_confirm")
	await _click(ui.confirmation.get_cancel_button())
	_check(not ui.confirmation.visible and game.research.researched_base_elements.is_empty(), "GUI Cancel leaves permanent choices empty")
	for element in ["WOOD", "WATER", "VOID"]:
		await _click(ui.rows[element]["start"])
		if element == "VOID":
			_check(ui.confirmation.dialog_text.contains("마지막 슬롯"), "Real third-slot dialog warns about permanent lock")
			await _capture("research_third_warning")
		await _click(ui.confirmation.get_ok_button())
		_check(game.research.researched_base_elements.has(element), "GUI Confirm commits: " + element)
	await _capture("research_three")
	await _click(ui.rows["FIRE"]["start"])
	_check(not ui.confirmation.visible and game.research.researched_base_elements.size() == 3, "Disabled fourth-element GUI button cannot open or commit")
	await _key(KEY_B)
	_check(not ui.is_open(), "B closes debug panel")
	await _key(KEY_1)
	_check(game.game_state == "DUNGEON" and not ui.opener.visible, "Existing dungeon key still works after research UI closes")
	await _capture("research_dungeon")
	game.free()
	print("RESEARCH RENDER / GUI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _click(button: Button) -> void:
	await process_frame
	var viewport := root
	var point := button.get_global_rect().get_center()
	if button.get_window() != root:
		point += Vector2(button.get_window().position)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	viewport.push_input(event, true)
	await process_frame
	event.pressed = false
	viewport.push_input(event, true)
	await process_frame
	await process_frame

func _capture(label: String) -> void:
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(DIR + label + ".png") == OK and screenshot.get_size() == Vector2i(1160, 720), "Rendered " + label + " at 1160 x 720")
