extends SceneTree
const SCENE = preload("res://scenes/main.tscn")
const Fixture = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const Helper = preload("res://tests/test_chant.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const Research = preload("res://scripts/character_research.gd")
const Visual = preload("res://scripts/mana_visual_model.gd")
const DevData = preload("res://scripts/developer_test_data.gd")
const DIR := "res://.task002_artifacts/ux1/"
var checks := 0
var failures := 0
var game
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
func fresh(developer := false) -> void:
	if is_instance_valid(game): game.free()
	A.write(DIR + "character.json", Fixture.fixture("WATER"))
	game = SCENE.instantiate()
	game.developer_tools_enabled = developer
	game.save_path = DIR + "character.json"
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._enter_dungeon("FIXED")
	Fixture.reset_arena(game)
func key(code: Key, pressed: bool, time := 1.0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	game.combat_input.handle_event(event, time)
func click(point: Vector2, button := MOUSE_BUTTON_RIGHT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.pressed = true
	game._input(event)
	event.pressed = false
	game._input(event)
func walk(seconds := 4.0) -> void:
	for i in ceili(seconds / 0.025): game.navigation.advance(game, 0.025, game.PLAYER_SPEED)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	fresh()
	_movement()
	fresh()
	_dodge()
	_short_chants_and_talents()
	_observation()
	_developer_tests()
	_laboratory_note_return()
	game.free()
	print("UX1 TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _movement() -> void:
	var origin: Vector2 = game.player_pos
	key(KEY_W, true)
	game._process(0.05)
	check(game.player_pos == origin and game.runes.is_empty() and game.combat_input.movement_axis() == Vector2.ZERO, "Default NORMAL WASD neither moves nor chants")
	key(KEY_W, false)
	click(Vector2(600, 300))
	check(game.navigation.active and game.navigation.destination == Vector2(600, 300), "Single RMB press/release retains a fixed destination")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(140, 150)
	game._input(motion)
	game.navigation.advance(game, 0.1, game.PLAYER_SPEED)
	check(game.player_pos.x > origin.x and game.navigation.destination == Vector2(600, 300), "Aim/cursor motion never tracks or changes the destination")
	click(Vector2(500, 450))
	check(game.navigation.destination == Vector2(500, 450), "A second RMB replaces the destination")
	walk()
	check(not game.navigation.active and game.player_pos.distance_to(Vector2(500, 450)) < 0.6, "Arrival stops exactly without overshoot or infinite movement")
	game.player_pos = Vector2(300, 300)
	game.walls.append(Vector2i(7, 4))
	click(Vector2(600, 300))
	var valid := true
	for i in 160:
		game.navigation.advance(game, 0.025, game.PLAYER_SPEED)
		valid = valid and not game._is_blocked(game.player_pos)
	check(valid and game.player_pos.distance_to(Vector2(600, 300)) < 0.6, "Bounded path search routes around a wall using swept actor collision")
	game.player_pos = Vector2(300, 300)
	game.walls.clear()
	for row in game.ROWS: game.walls.append(Vector2i(8, row))
	click(Vector2(700, 300))
	check(game.navigation.corrected and game.navigation.destination.x < game._cell_rect(Vector2i(8, 0)).position.x and not game._is_blocked(game.navigation.destination), "Unreachable destination projects to the current reachable side")
	walk()
	check(not game.navigation.active, "Corrected arrival stops without repeated movement attempts")
	game.walls.clear()
	click(Vector2(900, 300))
	check(game.navigation.corrected and not game._is_blocked(game.navigation.destination), "Out-of-bounds destination projects into the reachable map")
	game.player_pos = Vector2(300, 300)
	click(Vector2(600, 300))
	game.elemental_combat.barriers.append({"pos": Vector2(440, 300), "radius": 22.0, "life": 5.0, "color": Color.WHITE})
	valid = true
	for i in 160:
		game.navigation.advance(game, 0.025, game.PLAYER_SPEED)
		valid = valid and not game._is_blocked(game.player_pos)
	check(valid and game.player_pos.distance_to(Vector2(600, 300)) < 0.6, "A newly created earth barrier replans safely without crossing it (end=%s, %s)" % [game.player_pos, game.navigation.feedback])
	game.elemental_combat.clear()
	game.player_pos = Vector2(300, 300)
	key(KEY_SHIFT, true, 2.0)
	key(KEY_Q, true, 2.01)
	key(KEY_Q, false, 2.02)
	click(Vector2(600, 300))
	check(game.runes == ["Q"] and game.combat_input.mode == game.CombatInput.Mode.MOBILE_CAST and game.navigation.active, "RMB mobile casting preserves the unfinished chant buffer")
	click(game.spell_record_hud.panel.get_global_rect().get_center())
	check(game.navigation.destination == Vector2(600, 300) and game.runes == ["Q"], "HUD RMB cannot issue movement or cancel a chant")
	var cross := InputEventMouseButton.new()
	cross.button_index = MOUSE_BUTTON_RIGHT
	cross.position = Vector2(550, 330)
	cross.pressed = true
	game._input(cross)
	cross.position = game.spell_record_hud.panel.get_global_rect().get_center()
	cross.pressed = false
	game._input(cross)
	click(Vector2(650, 350))
	check(game.navigation.destination == Vector2(650, 350), "Releasing RMB over a HUD clears held state so the next world click works")
	game._reset_combat_input()
	click(Vector2(600, 300))
	key(KEY_SHIFT, true, 3.0)
	key(KEY_SHIFT, false, 3.01)
	key(KEY_SHIFT, true, 3.1)
	key(KEY_SHIFT, false, 3.11)
	check(not game.navigation.active and game.combat_input.mode == game.CombatInput.Mode.FOCUS_CAST, "Focus entry cancels destination immediately")
	click(Vector2(650, 400))
	origin = game.player_pos
	key(KEY_W, true, 3.2)
	game._process(0.1)
	check(game.player_pos == origin and game.runes == ["W"] and not game.navigation.active, "Focus WASD chants and RMB cannot move")
	key(KEY_ESCAPE, true, 3.4)
	key(KEY_ESCAPE, false, 3.41)
	game._process(0.1)
	check(game.player_pos == origin and not game.navigation.active, "Focus exit requires a new movement order")
	click(Vector2(600, 300))
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.navigation.active, "Focus loss cancels destination and held inputs")
	game.player_hp = 0
	click(Vector2(600, 300))
	check(not game.navigation.active, "Dead/immobile actor cannot receive movement")
	game.player_hp = 100
	game.game_state = "HUB"
	game._enter_laboratory()
	click(Vector2(500, 300))
	check(not game.navigation.active and game.game_state == "LAB", "Laboratory UI never generates a world destination")

func _dodge() -> void:
	click(Vector2(300, 180))
	game.navigation.advance(game, 0.025, game.PLAYER_SPEED)
	var origin: Vector2 = game.player_pos
	var cursor_heading: Vector2 = game.dodge.cursor_heading(origin, game.get_global_mouse_position())
	key(KEY_SHIFT, true, 5.0)
	key(KEY_Q, true, 5.01)
	key(KEY_Q, false, 5.02)
	key(KEY_CTRL, true, 5.03)
	key(KEY_CTRL, false, 5.04)
	check(game.dodge.active and not game.navigation.active and game.runes.is_empty(), "Ctrl during mobile casting cancels destination and unfinished chant")
	game.dodge.advance(game, 0.18)
	check(game.player_pos.distance_to(origin + cursor_heading * 108) < 0.1, "Moving dodge follows the current cursor for a bounded 108 units")
	key(KEY_CTRL, true, 5.2)
	key(KEY_CTRL, false, 5.21)
	check(not game.dodge.active and game.dodge.cooldown > 0, "Cooldown prevents unlimited repeated dodges")
	game._reset_combat_input()
	game.dodge.reset()
	game.player_pos = Vector2(300, 300)
	var heading: Vector2 = (game.get_global_mouse_position() - game.player_pos).normalized()
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	key(KEY_CTRL, true, 6.0)
	key(KEY_CTRL, false, 6.01)
	game.dodge.advance(game, 0.18)
	check(game.player_pos.distance_to(Vector2(300, 300) + heading * 108) < 0.1, "Stationary dodge follows mouse aim without requiring a destination")
	game._reset_combat_input()
	game.dodge.reset()
	game.player_pos = Vector2(300, 300)
	game.elemental_combat.barriers.append({"pos": Vector2(360, 300), "radius": 22.0, "life": 5.0, "color": Color.WHITE})
	game.dodge.begin(game.player_pos, Vector2.RIGHT)
	game.dodge.advance(game, 0.18)
	check(game.player_pos.x <= 325.01 and not game._is_blocked(game.player_pos), "Fast dodge cannot tunnel through an earth barrier")
	game.elemental_combat.clear()
	game.dodge.reset()
	game.player_pos = Vector2(300, 300)
	game.walls.append(Vector2i(6, 4))
	game.dodge.begin(game.player_pos, Vector2.RIGHT)
	game.dodge.advance(game, 0.18)
	check(game.player_pos.x < 323 and not game._is_blocked(game.player_pos), "Fast dodge cannot tunnel through terrain")
	game.walls.clear()
	game.dodge.reset()
	key(KEY_SHIFT, true, 7.0)
	key(KEY_SHIFT, false, 7.01)
	key(KEY_SHIFT, true, 7.1)
	key(KEY_SHIFT, false, 7.11)
	key(KEY_CTRL, true, 7.2)
	key(KEY_CTRL, false, 7.21)
	check(not game.dodge.active and game.dodge.cooldown == 0, "Focus rejects Ctrl without consuming cooldown")
	game._reset_combat_input()
	game.player_pos = Vector2(300, 300)
	game.missiles.append({"pos": Vector2(250, 300), "dir": Vector2.RIGHT, "hostile": true, "life": 2.0, "dmg": 16.0})
	game._update_missiles(0.5, 1.0)
	check(game.player_hp == 84.0, "Control case: stationary actor is hit by the enemy projectile")
	game.player_hp = 100
	game.missiles.clear()
	game.player_pos = Vector2(300, 300)
	game.dodge.begin(game.player_pos, Vector2.UP)
	game.dodge.advance(game, 0.18)
	game.missiles.append({"pos": Vector2(250, 300), "dir": Vector2.RIGHT, "hostile": true, "life": 2.0, "dmg": 16.0})
	game._update_missiles(0.5, 1.0)
	check(game.player_hp == 100, "Physical displacement genuinely avoids the same enemy projectile")
	game.dodge.reset()
	game.dodge.begin(game.player_pos, Vector2.UP)
	game.dodge.advance(game, 0.03)
	game.missiles.append({"pos": game.player_pos - Vector2(40, 0), "dir": Vector2.RIGHT, "hostile": true, "life": 2.0, "dmg": 16.0})
	game._update_missiles(0.4, 1.0)
	check(game.dodge.active and game.player_hp == 84.0, "Dodge grants no hidden invulnerability; a correctly aimed shot still hits during the roll")

func _short_chants_and_talents() -> void:
	var short := true
	var equivalent := true
	var no_two := true
	var guarded := true
	var evidence := true
	for seed_value in [1, 7, 71, 8431, 98765, 65537]:
		var profile := Profile.new()
		profile.load_data(Profile.generate(seed_value))
		for element in Profile.ELEMENTS:
			var first := Helper.first_for(profile, element)
			var inputs := Helper.inputs(Helper.path_for(profile, DevData.basic_actions(element), first))
			var simulation := Sim.simulate(profile, inputs, true)
			var result := Resolver.resolve(simulation, element)
			short = short and result["state"] == "ready" and (str(result["spell"].attribute) == element if element != "VOID" else str(result["spell"].spell_id) == "VOID_WAVE") and inputs.size() <= 7
			var alternate_actions:Array=DevData.basic_actions(element)
			var swap_index:=1 if element=="FIRE" else 0
			var first_action=alternate_actions[swap_index];alternate_actions[swap_index]=alternate_actions[swap_index+1];alternate_actions[swap_index+1]=first_action
			var alternate := Sim.simulate(profile, Helper.inputs(Helper.path_for(profile, alternate_actions, first)), true)
			equivalent = equivalent and Helper.equal(simulation["final_state"], alternate["final_state"]) and Resolver.resolve(alternate, element).get("spell")!=null and result.get("spell")!=null and Resolver.resolve(alternate, element)["spell"].spell_id==result["spell"].spell_id
			guarded = guarded and Resolver.resolve(simulation, null)["state"] == "locked"
			var research := Research.new()
			evidence = evidence and not research.record_resonance(profile, inputs, 1)
			for action in Profile.ACTIONS:
				var two := Sim.simulate(profile, Helper.inputs(Helper.path_for(profile, [action], first)), true)
				no_two = no_two and Resolver.resolve(two, element)["state"] != "ready"
	check(short and no_two, "All six basic spells reach differentiated states within seven inputs; one operation cannot suffice")
	check(equivalent, "Reordered operations with equal final states produce the same basic spell")
	check(guarded and evidence, "Differentiated combat cannot bypass main permission, resonance evidence or awakening")
	fresh()
	A.enter_keys(game, Helper.path_for(game.chant_profile, DevData.basic_actions("WATER"), Helper.first_for(game.chant_profile, "WATER")))
	game.magic_talent = 15
	game.body_talent = 85
	var low: Dictionary = game._inspect_chant(true)
	var low_pool: float = game._max_mana()
	game.magic_talent = 85
	game.body_talent = 15
	var high: Dictionary = game._inspect_chant(true)
	check(Helper.equal(low["simulation"], high["simulation"]) and low["spell"].spell_id == high["spell"].spell_id and low["mana_cost"] == high["mana_cost"], "Controlled body/magic talent swap changes neither chant interpretation nor input count/resonance/cost")
	check(low_pool == 61.5 and game._max_mana() == 138.5, "Magic talent changes the existing mana pool (15 -> 61.5, 85 -> 138.5)")
	game.magic_talent = 15
	game.body_talent = 85
	game.player_mana = low_pool
	game._cast_spell()
	check(game.missiles.size() == 1 and game.player_mana == 52.5, "Low magic talent can actually cast the water spell for 9 mana")
	var profile: Profile = game.chant_profile
	var fire_inputs := Helper.inputs(Helper.path_for(profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], Helper.first_for(profile, "FIRE")))
	var affine := Sim.simulate(profile, fire_inputs, false, {"innate_element": "FIRE"})
	var opposed := Sim.simulate(profile, fire_inputs, false, {"innate_element": "WATER"})
	check(affine["state"] == "ready" and opposed["state"] != "ready" and affine["final_state"]["resonance"]["FIRE"] > opposed["final_state"]["resonance"]["FIRE"], "Same mapping/inputs: innate affinity succeeds while opposed resonance is weaker and harder")
	var research := Research.new()
	research.load_data({"main_attribute": "WATER", "innate_affinity": {"FIRE": 85}, "auxiliary_attributes": []})
	var context := research.simulation_context()
	check(research.eligibility("FIRE") == "auxiliary_awakening_required", "First auxiliary requires an independent awakening, no talent penalty")
	research.load_data({"main_attribute": "WATER", "innate_affinity": {"FIRE": 85}, "auxiliary_attributes": ["FIRE", "METAL"]})
	check(research.simulation_context()["control_penalty"] == context["control_penalty"] and context["control_penalty"] == 0.0, "Role permissions are explicit; no arbitrary talent/control multiplier")
	Fixture.reset_arena(game)
	game.enemies.append(Fixture.target(Vector2(380, 300)))
	game.enemies[0]["shot"] = 0.01
	game.elemental_combat.cast(game, Resolver.DEFINITIONS["WATER"], Vector2.RIGHT)
	game._update_missiles(0.25, 1.0)
	game._update_enemies(0.2)
	check(game.missiles.is_empty() and game.enemies[0]["shot"] == 0.01 and is_equal_approx(game.enemies[0]["pos"].x, 515.0), "Water's 135-unit peel and 0.45-second stagger interrupt an imminent enemy shot")
	game.elemental_combat.update(game, 0.46)
	game._update_enemies(0.05)
	check(not game.missiles.is_empty(), "Water interruption expires and the enemy can act again")

func _observation() -> void:
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	var neutral := Visual.project(Sim.initial_state())
	var concealed := true
	var progressive := true
	var colors: Array = []
	for element in Profile.OHAENG:
		var first := Helper.first_for(profile, element)
		var one := Sim.simulate(profile, Helper.inputs([first]))
		concealed = concealed and Visual.project(one["final_state"]) == neutral
		var invalid := Sim.simulate(profile, Helper.inputs(Helper.path_for(profile, ["ACCUMULATE", "RESONATE"], first)))
		concealed = concealed and Visual.evidence(invalid["final_state"])["stage"] == "none" and invalid["observation"].contains("아직 확인되지")
		var partial := Sim.simulate(profile, Helper.inputs(Helper.path_for(profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], first)), false, {"innate_element": "WATER" if element == "FIRE" else ""})
		var mature := Sim.simulate(profile, Helper.inputs(A.sequence(profile, element)), false)
		var trace := Visual.evidence(mature["final_state"])
		progressive = progressive and trace["element"] == element and trace["stage"] == "stable" and Visual.evidence(partial["final_state"], partial["simulation_context"])["strength"] <= trace["strength"]
		colors.append(Visual.COLORS[element])
	check(concealed, "No element colors for first words or invalid resonance attempts, no false progress signal")
	check(progressive and colors.size() == 5, "Five elements develop distinct visual evidence from actual resonance")
	var state: Dictionary = Sim.simulate(profile, Helper.inputs(A.sequence(profile, "FIRE")))["final_state"]
	state["stability"] = 40
	check(Visual.evidence(state)["stage"] == "unstable", "Strong resonance with insufficient control is visibly unstable, never marked stable")
	state["phase"] = "FAILED"
	check(Visual.evidence(state)["stage"] == "collapsed" and Visual.project(state)["collapsed"], "Collapse has distinct broken/scattered evidence")
	fresh()
	game.game_state = "HUB"
	game._enter_laboratory()
	A.enter_keys(game, A.sequence(game.chant_profile, "FIRE"))
	game._cast_spell()
	var ui = game.laboratory_panel
	var archived: Dictionary = game.journal.to_data()
	var record: Dictionary = game.journal.records()[-1]
	ui.steppers[0].value = record["steps"].size()
	ui._step_selected(ui.steppers[0].value, 0)
	var stored: Dictionary = record["steps"][-1]["after"]
	check(ui.after_orbs[0].descriptor == Visual.project(stored, record["simulation_context"]) and ui.after_orbs[0].descriptor == ui.live_orb.descriptor, "Live and archived reaction visuals agree using the experiment's saved context")
	ui.observation_lens.button_pressed = true
	check(ui.live_orb.observation_gain == 1.45 and game.journal.to_data() == archived and ui.after_orbs[0].snapshot == stored, "Observation lens only emphasizes existing evidence; saved states and success rules are unchanged")

func _developer_tests() -> void:
	fresh()
	check(game.developer_panel == null and not game._start_developer_test("FIRE", "LAB"), "Ordinary play has no developer mapping UI or direct-call unlock")
	fresh(true)
	game.carried_gold = 37
	game.enemies.append(Fixture.target(Vector2(600, 300)))
	game.enemies[0]["combat_id"] = 17
	game.elemental_combat._next_enemy_id = 18
	var world_rng_state: int = game.rng.state
	var document: Dictionary = game._character_document()
	var mapping: Dictionary = game.chant_profile.to_data()
	var actors: Array = game.enemies.duplicate(true)
	var position: Vector2 = game.player_pos
	var path: String = game.save_path
	var disk := FileAccess.get_file_as_bytes(path)
	var backup := FileAccess.get_file_as_bytes(path + ".bak") if FileAccess.file_exists(path + ".bak") else PackedByteArray()
	game._toggle_developer_menu()
	var mana: float = game.player_mana
	click(Vector2(600, 300))
	game._request_destination(Vector2(600, 300))
	game._request_dodge()
	game._process(1.0)
	check(game._developer_menu_visible() and game.player_pos == position and game.player_mana == mana and not game.navigation.active and not game.dodge.active, "Developer modal pauses the world and blocks direct/click movement and dodge")
	for location in ["LAB", "DUNGEON"]:
		for element in Profile.ELEMENTS:
			check(game._start_developer_test(element, location) and game.developer_mode and game.game_state == location and (game.research.main_attribute == element and game.research.researched_base_elements.size() == 1 if element != "VOID" else game.research.main_attribute == null and game.research.researched_base_elements.is_empty()) and Helper.equal(game.chant_profile.to_data(), mapping), "Temporary " + element + " character in " + location + " retains keys and correct elemental/neutral role")
			var examples: Array = DevData.examples(game.chant_profile, element, game.research.simulation_context())
			check(examples.size() == (5 if element == "FIRE" else (1 if element == "VOID" else 3)), element + " developer screen provides only simulator-verified examples")
			for example in examples:
				if location == "LAB": game._laboratory_recover()
				else:
					Fixture.reset_arena(game)
					var direction: Vector2 = (game.get_global_mouse_position() - game.player_pos).normalized()
					if direction.is_zero_approx(): direction = Vector2.RIGHT
					game.enemies.append(Fixture.target(game.player_pos + direction * (80 if element == "VOID" else 160)))
				A.enter_keys(game, example["inputs"].map(func(event): return event["key"]))
				var before: float = game.player_mana
				game._cast_spell()
				check(game.runes.is_empty() and game.player_mana < before and game.developer_metrics.get("spell") == example["name"] and not game.discovered.entries().is_empty(), location + " actual temporary release/discovery: " + example["name"])
			check(FileAccess.get_file_as_bytes(path) == disk, location + " " + element + " test records never touch the original save bytes")
	game._die()
	check(game.developer_mode and game.game_state == "HUB" and FileAccess.get_file_as_bytes(path) == disk, "Temporary character death and its save remain isolated")
	check(game._end_developer_test() and not game.developer_mode and game.game_state == "DUNGEON" and game.player_pos == position and game.enemies == actors and game.carried_gold == 37 and game.elemental_combat._next_enemy_id == 18 and game.rng.state == world_rng_state, "Ending developer mode restores the original dungeon actors/IDs/RNG, position and carried progress")
	check(Helper.equal(game._character_document(), document) and FileAccess.get_file_as_bytes(path) == disk and (not FileAccess.file_exists(path + ".bak") or FileAccess.get_file_as_bytes(path + ".bak") == backup), "Original main, talents, keys, slots, journal, discoveries, unknown fields and disk/backup bytes are preserved")
	game._toggle_developer_menu()
	game.developer_panel.elements.selected = 1
	game.developer_panel.refresh()
	check(game.developer_panel.text.text.contains("Brandlance") and not game.developer_panel.text.text.contains("화염창") and game.developer_panel.text.text.contains("ACCUMULATE"), "Internal meanings and named validated FIRE examples are confined to the developer screen")
	game._toggle_developer_menu()

func _laboratory_note_return() -> void:
	fresh(true)
	game.game_state = "HUB"
	game._enter_laboratory()
	A.enter_keys(game, Helper.path_for(game.chant_profile, DevData.basic_actions("WATER"), Helper.first_for(game.chant_profile, "WATER")))
	game._cast_spell()
	var ui = game.laboratory_panel
	ui.note.text = "원래 캐릭터의 가설"
	game._save_experiment_note(1, ui.note.text)
	var disk := FileAccess.get_file_as_bytes(game.save_path)
	game._start_developer_test("FIRE", "LAB")
	A.enter_keys(game, Helper.path_for(game.chant_profile, DevData.basic_actions("FIRE"), Helper.first_for(game.chant_profile, "FIRE")))
	game._cast_spell()
	ui.note.text = "임시 개발 가설"
	game._save_experiment_note(1, ui.note.text)
	check(game.journal.records()[0]["id"] == 1 and game.journal.records()[0]["note"] == "임시 개발 가설", "Temporary and normal lab records may legitimately reuse the same experiment ID")
	check(game._end_developer_test() and game.game_state == "LAB" and ui.note.text == "원래 캐릭터의 가설" and game.journal.records()[0]["note"] == ui.note.text and FileAccess.get_file_as_bytes(game.save_path) == disk, "Lab return rebinds the actual original note even when IDs collide; no temporary note leaks to normal UI/save")
