extends SceneTree
## Actual renderer + GUI input. Deterministic isolated character, never a player save.
const SCENE = preload("res://scenes/main.tscn")
const Flow = preload("res://tests/test_awakening.gd")
const Helper = preload("res://tests/test_chant.gd")
const DIR := "res://.task002_artifacts/phase2b2/"
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a display driver for awakening preview.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size = Vector2i(1160, 720)
	root.gui_embed_subwindows = true
	var path := DIR + "preview_awakening.json"
	Flow.write(path, Flow.seeded_fixture())
	game = SCENE.instantiate()
	game.save_path = path
	root.add_child(game)
	game.set_process(false)
	await _tap(KEY_L)
	var lab = game.laboratory_panel
	var study = lab.awakening_panel
	check(game.game_state == "LAB" and game.research.main_attribute == null, "L enters an unawakened lab with the existing personal mappings")
	await _click(lab.research_button)
	check(study.visible and study.ritual_button.disabled, "Book/mentor/awakening interface is accessible and gated")
	await _select(study.target, 2)
	check(study.selected_element() == "EARTH", "Actual target dropdown selects EARTH without revealing a personal key")
	await _click(study.book_button)
	await _click(study.mentor_button)
	check(game.research.has_clue("EARTH", "book") and game.research.has_clue("EARTH", "mentor") and game.research.researched_base_elements.is_empty(), "Both GUI clue sources save independently without occupying slots")
	check(study.journal_view.text.contains("중심") and study.journal_view.text.contains("서적") and study.journal_view.text.contains("스승"), "Collected clues are readable in the research journal")
	await _capture("awakening_clues")
	await _click(study.back_button)
	await _key(KEY_SHIFT, true)
	await _tap(OS.find_keycode_from_string(Helper.first_for(game.chant_profile, "EARTH")))
	check(lab.live.text.contains("뚜렷한 변화가 관찰되지") and game.research.main_attribute == null, "A single actual attribute word reveals no completed phenomenon or affinity")
	await _capture("awakening_first_word")
	await _key(KEY_SHIFT, false)
	for repetition in range(2):
		await _chant(Flow.sequence(game.chant_profile, "EARTH"))
		await _click(lab.release_button)
		await _key(KEY_SHIFT, false)
	check(game.research.stable_count("EARTH") == 2 and game.research.researched_base_elements.is_empty(), "Two direct opposed-element experiments establish stable evidence, still no slot")
	var mana: float = game.player_mana
	var record_count: int = game.journal.records().size()
	await _click(lab.next_buttons[0])
	check(game.player_mana == mana and game.journal.records().size() == record_count, "Actual replay control remains read-only after discoveries")
	await _click(lab.research_button)
	check(not study.ritual_button.disabled and study.progress.text.contains("2 / 2"), "GUI shows readiness only after clues and stable reproduction")
	await _click(study.ritual_button)
	check(not study.visible and game.research.ritual_target == "EARTH", "Ritual button only starts a session; it does not auto-cast")
	await _chant(Flow.sequence(game.chant_profile, "EARTH", true))
	await _click(lab.release_button)
	check(study.confirmation.visible and game.research.main_attribute == null and game.research.researched_base_elements.is_empty(), "Direct ritual completion opens a permanent confirmation before slot mutation")
	await _capture("awakening_confirmation")
	await _click(study.confirmation.get_cancel_button())
	check(game.research.main_attribute == null and game.research.researched_base_elements.is_empty() and game.research.ritual_target.is_empty(), "Real Cancel leaves the main and slots untouched")
	await _key(KEY_SHIFT, false)
	# Choose a different opposed target after cancelling, then commit it explicitly.
	await _click(lab.research_button)
	await _select(study.target, 3)
	check(study.selected_element() == "METAL", "Another target remains selectable after a successful-but-cancelled ritual")
	await _click(study.book_button)
	await _click(study.mentor_button)
	await _click(study.back_button)
	for repetition in range(2):
		await _chant(Flow.sequence(game.chant_profile, "METAL"))
		await _click(lab.release_button)
		await _key(KEY_SHIFT, false)
	await _click(lab.research_button)
	await _click(study.ritual_button)
	await _chant(Flow.sequence(game.chant_profile, "METAL", true))
	await _click(lab.release_button)
	check(study.confirmation.visible and study.confirmation.dialog_text.contains("주속성"), "Second freely chosen ritual also requires explicit permanent confirmation")
	await _click(study.confirmation.get_ok_button())
	await _key(KEY_SHIFT, false)
	check(game.research.main_attribute == "METAL" and game.research.researched_base_elements == PackedStringArray(["METAL"]) and game.research.auxiliary_attributes.is_empty(), "Real Confirm stores the chosen non-innate main in exactly one slot")
	await _click(lab.research_button)
	check(study.status.text.contains("金") and study.ritual_button.disabled, "Main role is visible and subsequent awakenings are blocked")
	await _capture("awakening_committed")
	var stored: Dictionary = game.CharacterSave.load_file(path)["data"]
	check(stored["research"]["main_attribute"] == "METAL" and stored["chant"]["character_seed"] == 65537, "GUI confirmation persists role and unchanged character chant seed")
	await _click(study.back_button)
	await _click(lab.exit_button)
	await _tap(KEY_B)
	check(game.research_panel.is_open() and game.research_panel.rows["FIRE"]["start"].disabled, "Old B interface cannot bypass the main/auxiliary acquisition rules")
	await _tap(KEY_B)
	await _tap(KEY_1)
	check(game.game_state == "DUNGEON", "Existing dungeon entry remains usable after awakening")
	await _capture("awakening_dungeon")
	game.free()
	print("AWAKENING RENDER / GUI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _select(control: OptionButton, index: int) -> void:
	await _click(control)
	await _tap(KEY_HOME)
	# Popup HOME clears hover selection; the first Down focuses item zero.
	for step in range(index + 1): await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await process_frame

func _chant(keys: Array) -> void:
	root.gui_release_focus()
	await _key(KEY_SHIFT, true)
	for token in keys: await _tap(OS.find_keycode_from_string(token))

func _tap(code: Key) -> void:
	await _key(code, true)
	await _key(code, false)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _click(control: Control) -> void:
	await process_frame
	var point := control.get_global_rect().get_center()
	if control.get_window() != root: point += Vector2(control.get_window().position)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await process_frame

func _capture(label: String) -> void:
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(DIR + label + ".png") == OK and screenshot.get_size() == Vector2i(1160, 720), "Rendered " + label + " at 1160 x 720")
