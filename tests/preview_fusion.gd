extends SceneTree
## Real rendered window and Godot event dispatch, isolated temporary profiles only.
const Scene = preload("res://scenes/main.tscn")
const F = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const H = preload("res://tests/test_chant.gd")
const D = preload("res://scripts/developer_test_data.gd")
const V = preload("res://scripts/mana_visual_model.gd")
const DIR := "res://.task002_artifacts/fusion/"
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1160, 720)
	var path := DIR + "window_original.json"
	A.write(path, F.fixture("WATER", 1787453028))
	game = Scene.instantiate()
	game.save_path = path
	game.developer_tools_enabled = true
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.25).timeout
	var disk := FileAccess.get_file_as_bytes(path)
	var original: Dictionary = game._character_document()
	for option in ["WATER_METAL", "FIRE_WATER"]:
		for location in ["LAB", "DUNGEON"]:
			await tap(KEY_F2)
			check(game.developer_panel.panel.visible, "F2 opens the actual developer pair selector")
			await select(game.developer_panel.elements, D.OPTIONS.find(option))
			await select(game.developer_panel.location, 0 if location == "LAB" else 1)
			await click(game.developer_panel.start_button)
			check(game.developer_mode and game.research.auxiliary_attributes.size() == 1 and game.game_state == location, "GUI starts isolated " + option + " " + location)
			var examples := D.examples(game.chant_profile, option, game.research.simulation_context())
			for example in examples:
				var arena = game.laboratory_panel.arena if location == "LAB" else game
				var runtime = game.laboratory_panel.arena.combat if location == "LAB" else game.elemental_combat
				if location == "LAB":
					game.laboratory_panel.arena.set_process(false)
					game._laboratory_recover()
					if game.laboratory_panel.trial_panel.visible: await click(game.laboratory_panel.journal_button)
				else:
					F.reset_arena(game)
					game.enemies.append(F.target(Vector2(450, 300)))
				await motion(Vector2(700, 300))
				root.gui_release_focus()
				await key(KEY_SHIFT, true)
				for event in example["inputs"]: await tap(OS.find_keycode_from_string(event["key"]))
				if location == "LAB":
					check(game.laboratory_panel.live_orb.is_visible_in_tree() and game.laboratory_panel.live_orb.descriptor["reaction"]["element"] == "BINDING", "Visible live two-stream binding is represented before release")
					await capture("binding_" + option + "_" + example["spell_id"])
					await click(game.laboratory_panel.release_button if game.laboratory_panel.panel.visible else game.laboratory_panel.trial_release_button)
				else: await click_point(Vector2(700, 300))
				await key(KEY_SHIFT, false)
				check(game.developer_metrics.get("spell") == example["name"], location + " actual input releases " + example["name"])
				if example["spell_id"] == "ICE_CRYSTAL_BARRIER":
					check(runtime.barriers.size() == 1 and runtime.blocks(runtime.barriers[0]["pos"], 13), location + " physical crystalline barrier exists")
				else:
					check(arena.missiles.size() == 1, location + " combat projectile exists")
					runtime.update_missiles(arena, 0.12, 1.0)
					await capture(location.to_lower() + "_flight_" + example["spell_id"])
					runtime.update_missiles(arena, 0.25, 1.0)
					check(arena.enemies[0]["hp"] < (200 if location == "LAB" else 100), location + " rendered combat really damages target")
				await capture(location.to_lower() + "_effect_" + example["spell_id"])
				if location == "LAB":
					var ui = game.laboratory_panel
					if ui.trial_panel.visible: await click(ui.journal_button)
					var record: Dictionary = game.journal.records()[-1]
					ui.steppers[0].value = record["steps"].size()
					ui._step_selected(ui.steppers[0].value, 0)
					check(ui.after_orbs[0].is_visible_in_tree() and ui.after_orbs[0].descriptor == V.project(record["steps"][-1]["after"], record["simulation_context"]), "Visible archived fusion visualization uses the exact saved snapshot")
					game.discovered.set_favorite(example["spell_id"], true)
					game.spell_record_hud.refresh()
				else:
					await tap(KEY_J)
					check(game.spell_record_hud.expanded, "J opens discovered fusion input history")
					await capture("j_" + example["spell_id"])
					await tap(KEY_J)
	await tap(KEY_F2)
	await click(game.developer_panel.end_button)
	check(not game.developer_mode and H.equal(game._character_document(), original) and FileAccess.get_file_as_bytes(path) == disk, "Actual GUI return preserves original player main, slots, keys and exact save bytes")
	game.free()
	print("FUSION WINDOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func tap(code: Key) -> void: await key(code, true); await key(code, false)
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
func motion(point: Vector2) -> void:
	Input.warp_mouse(point)
	await process_frame
	var event := InputEventMouseMotion.new()
	event.position = point; event.global_position = point
	Input.parse_input_event(event)
	await process_frame
func click(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control); await process_frame; await process_frame
			break
		ancestor = ancestor.get_parent()
	# Historical tests now use the public Shift-up / focus LMB controls.
	if control == game.laboratory_panel.release_button or control == game.laboratory_panel.trial_release_button:
		var ui = game.laboratory_panel
		if game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST:
			ui.show_trial(false); await process_frame
		if ui.trial_panel.visible:
			var point: Vector2 = ui.arena.world_to_screen(ui.arena.player_pos+Vector2(160,0))
			Input.warp_mouse(point); await process_frame
			var motion := InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
			Input.parse_input_event(motion); await process_frame
		if game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST:
			var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT
			event.position=ui.arena.world_to_screen(ui.arena.player_pos+Vector2(160,0)); event.global_position=event.position; event.pressed=true
			Input.parse_input_event(event); await process_frame
			event.pressed=false; Input.parse_input_event(event); await process_frame
		else: await key(KEY_SHIFT,false)
		return
	await process_frame # Newly opened containers must finish their layout first.
	var point := control.get_global_rect().get_center()
	if control.get_window() != root: point += Vector2(control.get_window().position)
	await click_point(point)
func click_point(point: Vector2) -> void:
	await motion(point)
	var event := InputEventMouseButton.new()
	event.position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await process_frame
func select(control: OptionButton, index: int) -> void:
	await click(control)
	# Mouse hover can replace PopupMenu's initial focus after it opens. Move the
	# cursor outside, then establish a known keyboard focus without selecting.
	await motion(Vector2(root.size)-Vector2(12,12))
	control.get_popup().set_focused_item(0)
	await process_frame
	for i in range(index): await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	await process_frame
func capture(label: String) -> void:
	game.queue_redraw(); game.laboratory_panel.arena.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DIR + label + ".png") == OK, "Rendered screenshot " + label)
