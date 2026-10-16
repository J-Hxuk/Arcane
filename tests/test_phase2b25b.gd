extends SceneTree
const Profile = preload("res://scripts/chant_profile.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Research = preload("res://scripts/character_research.gd")
const Helper = preload("res://tests/test_chant.gd")
const Fixture = preload("res://tests/test_elemental_combat.gd")
const Awakening = preload("res://tests/test_awakening.gd")
const SCENE = preload("res://scenes/main.tscn")
const DIR := "res://.task002_artifacts/2b25b/"
const Book = preload("res://scripts/spell_discoveries.gd")
const Save = preload("res://scripts/character_save.gd")
const BASIC := ["ACCUMULATE", "COMPRESS", "SHAPE", "DIRECT"]
var checks := 0
var failures := 0
var serial := str(Time.get_ticks_usec())

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func game_at(element: Variant):
	var path := DIR + serial + "_" + ("none" if element == null else str(element)) + ".json"
	Awakening.write(path, Fixture.fixture(element))
	var game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	return game

static func keys(profile: Profile, element: String, actions: Array = BASIC) -> Array:
	return Helper.path_for(profile, actions, "C" if element.is_empty() else Helper.first_for(profile, element))

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_short_chants()
	_lab_trials()
	_spell_records()
	_fire_studies()
	_unsuccessful_attempts()
	print("PHASE 2B25B TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _short_chants() -> void:
	var all_short := true
	var all_equivalent := true
	var all_locked := true
	var evidence_protected := true
	for seed_value in [1, 7, 71, 8431, 98765, 65537]:
		var profile := Profile.new()
		profile.load_data(Profile.generate(seed_value))
		for element in Profile.ELEMENTS:
			var inputs := Helper.inputs(keys(profile, element))
			var raw := Sim.simulate(profile, inputs, true, {"innate_element": "WOOD"})
			var result := Resolver.resolve(raw, element)
			all_short = all_short and result["state"] == "ready" and inputs.size() == 5
			var alternative := Sim.simulate(profile, Helper.inputs(keys(profile, element, ["ACCUMULATE", "SHAPE", "COMPRESS", "DIRECT"])), true, {"innate_element": "WOOD"})
			all_equivalent = all_equivalent and raw["final_state"] == alternative["final_state"] and Resolver.resolve(alternative, element).get("spell") == result.get("spell")
			all_locked = all_locked and Resolver.resolve(raw, null)["state"] == "locked"
			var research := Research.new()
			evidence_protected = evidence_protected and not research.record_resonance(profile, inputs, 1) and research.stable_count(element) == 0
	check(all_short, "Six elements across six personal mappings reach basic combat in five inputs")
	check(all_equivalent, "Alternate manipulation orders reach the same final state and spell")
	check(all_locked, "Short structures still require the permanent awakened main")
	check(evidence_protected, "Short basic structures cannot replace stable resonance evidence or awakening")
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	var pure := Sim.simulate(profile, Helper.inputs(keys(profile, "", ["ACCUMULATE", "DIRECT"])))
	check(pure["state"] == "ready" and pure["kind"] == "mana_bolt", "Personal neutral bolt takes three state-based inputs")
	check(Sim.simulate(profile, Helper.inputs(["Q", "E"]), true)["mana_cost"] == 15.0, "Original two-key tutorial bolt is unchanged")
	check(Sim.simulate(profile, Helper.inputs([Helper.first_for(profile, "FIRE")]))["kind"] == "none", "First word still has no completed phenomenon")

func _lab_trials() -> void:
	for element in Profile.ELEMENTS:
		var game = game_at(element)
		game._enter_laboratory()
		var arena = game.laboratory_panel.arena
		var permanent: Dictionary = game.research.to_data()
		Awakening.enter_keys(game, keys(game.chant_profile, element))
		var expected: Dictionary = game._inspect_chant(true)
		var mana: float = game.player_mana
		game._cast_spell()
		check(game.laboratory_panel.trial_panel.visible and game.laboratory_panel.trial_banner.text.contains(expected["spell"].display_name), element + " has an immediate named manifestation banner and visible arena")
		check(game.player_mana == mana - expected["mana_cost"] and game.missiles.is_empty() and game.research.to_data() == permanent, element + " safe trial charges real mana and never mutates dungeon actors or permanent research")
		check(game.journal.records()[-1]["result"].get("manifestation", {}).get("spell_id") == str(expected["spell"].spell_id), element + " archived experiment distinguishes combat manifestation from resonance")
		arena.advance(0.8)
		var reacted: bool = not arena.combat.barriers.is_empty()
		for enemy in arena.enemies:
			if enemy["hp"] < 200.0: reacted = true
		check(reacted and arena.player_hp == 100.0 and game.player_hp == game._max_hp(), element + " actual shared effect reacts on safe targets without enemy attacks")
		game.free()
	var game = game_at(null)
	game._enter_laboratory()
	Awakening.enter_keys(game, Awakening.sequence(game.chant_profile, "FIRE"))
	game._cast_spell()
	check(game.research.stable_count("FIRE") == 1 and not game.laboratory_panel.trial_panel.visible and game.laboratory_panel.message.text.contains("공명 성공"), "Resonance alone remains evidence and is clearly not a combat manifestation")
	game.free()

static func fire_actions(kind: String, variant := false) -> Array:
	var actions: Array = ["ACCUMULATE", "ACCUMULATE"] if kind == "FIRE_LANCE" else ["ACCUMULATE", "ACCUMULATE", "ACCUMULATE"]
	for i in (3 if kind == "FIRE_LANCE" else 1): actions.append("COMPRESS")
	for i in 3: actions.append_array(["STABILIZE", "RESONATE"])
	if variant: actions.append("DIRECT")
	actions.append("SHAPE")
	if kind == "FIRE_BLAST": actions.append("SHAPE")
	actions.append("STABILIZE")
	if not variant: actions.append("DIRECT")
	return actions

func _fire_studies() -> void:
	var universal := true
	var equivalent := true
	var protected := true
	for seed_value in [1, 71, 8431]:
		var profile := Profile.new()
		profile.load_data(Profile.generate(seed_value))
		for innate in ["FIRE", "WATER", "WOOD", "VOID", ""]:
			for kind in ["FIRE_LANCE", "FIRE_BLAST"]:
				var sim := Sim.simulate(profile, Helper.inputs(keys(profile, "FIRE", fire_actions(kind))), false, {"innate_element": innate})
				var other := Sim.simulate(profile, Helper.inputs(keys(profile, "FIRE", fire_actions(kind, true))), false, {"innate_element": innate})
				var resolved := Resolver.resolve(sim, "FIRE")
				universal = universal and resolved.get("spell") != null and str(resolved["spell"].spell_id) == kind
				equivalent = equivalent and Helper.equal(sim["final_state"], other["final_state"]) and Resolver.resolve(other, "FIRE").get("spell") == resolved.get("spell")
				protected = protected and Resolver.resolve(sim, "WATER")["state"] == "locked" and Resolver.resolve(sim, null)["state"] == "locked"
	check(universal, "Both advanced FIRE forms work across personal mappings and all affinity relations")
	check(equivalent, "Fire spell choice follows final state even when direction and shaping order changes")
	check(protected, "Advanced FIRE never bypasses main-attribute permission")
	var game = game_at("FIRE")
	game._enter_laboratory()
	var permanent: Dictionary = game.research.to_data()
	for kind in ["FIRE_EMBER", "FIRE_LANCE", "FIRE_BLAST"]:
		game._laboratory_recover()
		var actions: Array = BASIC if kind == "FIRE_EMBER" else fire_actions(kind)
		Awakening.enter_keys(game, keys(game.chant_profile, "FIRE", actions))
		var result: Dictionary = game._inspect_chant(true)
		check(str(result["spell"].spell_id) == kind, kind + " has a distinct final mana structure")
		game._cast_spell()
		var arena = game.laboratory_panel.arena
		arena.advance(0.6)
		var hit := 0
		for enemy in arena.enemies:
			if enemy["hp"] < 200.0: hit += 1
		check(hit == {"FIRE_EMBER": 1, "FIRE_LANCE": 3, "FIRE_BLAST": 2}[kind], kind + " has actual one-target / three-pierce / radial multi-target behavior")
		check(game.laboratory_panel.trial_banner.text.contains(result["spell"].display_name) and game.journal.records()[-1]["result"]["manifestation"]["spell_id"] == kind, kind + " announces and archives its real discovery")
	var after: Dictionary = game.research.to_data()
	var same_permanent := true
	for field in ["main_attribute", "auxiliary_attributes", "legacy_committed_attributes", "innate_affinity"]:
		same_permanent = same_permanent and after[field] == permanent[field]
	check(game.discovered.entries().size() == 3 and same_permanent, "Three discovered fire forms enter the HUD without modifying permanent research")
	var inputs := Helper.inputs(keys(game.chant_profile, "FIRE", fire_actions("FIRE_LANCE")))
	var raw := Sim.simulate(game.chant_profile, inputs, false, {"innate_element": "WATER"})
	raw["final_state"]["resonance"]["FIRE"] = 50.0
	check(Resolver.resolve(raw, "FIRE")["spell"].spell_id == &"FIRE_EMBER", "Opposed affinity still demands additional resonance for advanced forms")
	var arena = game.laboratory_panel.arena
	arena.reset_targets()
	arena.combat.barriers.append({"pos": arena.player_pos + Vector2(80, 0), "radius": 22.0, "life": 5.0, "color": Color.WHITE})
	check(not arena.manifest(Resolver.FIRE_STUDIES[1]), "Fire explosion cannot be placed through a stone barrier")
	game.save_path = DIR + "restart_fire.json"
	game._change_spell_preference("FIRE_LANCE", true, 0)
	check(FileAccess.file_exists(game.save_path), "Fire discoveries and preferences create an isolated restart fixture")
	game._enter_dungeon("FIXED")
	for kind in ["FIRE_LANCE", "FIRE_BLAST"]:
		Fixture.reset_arena(game)
		var direction: Vector2 = (game.get_global_mouse_position() - game.player_pos).normalized()
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		game.enemies.append(Fixture.target(game.player_pos + direction * 160.0))
		Awakening.enter_keys(game, keys(game.chant_profile, "FIRE", fire_actions(kind)))
		game._cast_spell()
		game._update_missiles(0.6, 1.0)
		check(game.enemies[0]["hp"] < 100 and game.runes.is_empty() and game.player_mana < 100.0, kind + " also manifests through the ordinary dungeon cast path")
	game.free()

func _unsuccessful_attempts() -> void:
	var game = game_at("WATER")
	game._enter_laboratory()
	Awakening.enter_keys(game, [Helper.first_for(game.chant_profile, "WATER")])
	game._cast_spell()
	check(game.discovered.entries().is_empty(), "Unfinished experiments never disclose a successful recipe")
	game._reset_combat_input()
	game._laboratory_recover()
	Awakening.enter_keys(game, keys(game.chant_profile, "WATER"))
	game.player_mana = 0
	game._cast_spell()
	check(game.discovered.entries().is_empty() and game.laboratory_panel.trial_banner.text.contains("마나가 부족"), "Insufficient mana has explicit failure feedback and creates no discovery")
	game._laboratory_recover()
	game.exhaustion_seconds = 1
	game._cast_spell()
	check(game.discovered.entries().is_empty() and game.laboratory_panel.trial_banner.text.contains("탈진"), "Exhaustion cannot leave a stale success banner or create a discovery")
	game._laboratory_recover()
	game._cast_spell()
	check(game.laboratory_panel.trial_commands.text.contains("전투 발현 완료") and not game.laboratory_panel.trial_commands.text.contains("전투 발현과 별개"), "Completed combat display cannot contradict its own named success banner")
	game.free()

func _spell_records() -> void:
	var game = game_at("WATER")
	game._enter_laboratory()
	var original: Dictionary = game.chant_profile.to_data()
	Awakening.enter_keys(game, keys(game.chant_profile, "WATER"))
	game._cast_spell()
	var entries: Array = game.discovered.entries()
	check(entries.size() == 1 and entries[0]["spell_id"] == "WATER_PUSH" and entries[0]["recipes"][0]["inputs"].size() == 5, "Only a genuinely successful personal spell enters the chant book")
	var saved_inputs: Array = entries[0]["recipes"][0]["inputs"]
	check(saved_inputs == game.journal.records()[-1]["steps"].map(func(step): return step["input"]), "Discovery stores exact evaluated successful press/hold timings from the journal")
	game._laboratory_recover()
	Awakening.enter_keys(game, keys(game.chant_profile, "WATER", ["ACCUMULATE", "SHAPE", "COMPRESS", "DIRECT"]))
	game._cast_spell()
	check(game.discovered.entries()[0]["recipes"].size() == 2, "A different successful path to the same spell is retained as a second chant")
	game._change_spell_preference("WATER_PUSH", true, 1)
	var path: String = game.save_path
	var book: Dictionary = game.discovered.to_data()
	game.free()
	game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._enter_dungeon("FIXED")
	check(Helper.equal(game.discovered.to_data(), book) and Helper.equal(game.chant_profile.to_data(), original) and game.discovered.entries()[0]["favorite"], "Scene reload restores discovered variants, favorite, representative and unchanged key mapping")
	var hud = game.spell_record_hud
	hud.toggle()
	check(hud.recipe.text == Book.format_inputs(book["spells"]["WATER_PUSH"]["recipes"][1]["inputs"]) and hud.title.text.contains("밀물 탄"), "Dungeon HUD displays the selected actual successful chant rather than a shared recipe")
	Awakening.enter_keys(game, keys(game.chant_profile, "WATER"))
	var mana: float = game.player_mana
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = hud.panel.get_global_rect().get_center()
	event.pressed = true
	game._input(event)
	hud.favorite_button.pressed.emit()
	check(game.missiles.is_empty() and game.player_mana == mana and not game.runes.is_empty(), "Clicking the HUD with a ready chant never auto-casts or consumes mana")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_J
	key_event.pressed = true
	game._input(key_event)
	check(not hud.expanded and not game.runes.is_empty(), "J toggles the record HUD without modifying chant commands")
	var timing := [{"key": "C", "at_ms": 0, "hold_ms": 400}, {"key": "T", "at_ms": 200, "hold_ms": 750}]
	check(Book.format_inputs(timing).contains("+") and Book.format_inputs(timing).contains("0.75초"), "Chant reminder preserves overlapping input and meaningful hold durations")
	var model := Book.new()
	var journal: Array = game.journal.records()
	model.import_journal(journal)
	check(model.entries().size() == 1, "Manifestation metadata imports known journal spells without guessing undiscovered answers")
	var before := model.to_data()
	check(not model.load_data({"version": 1, "spells": {"BAD": {"name": "bad", "recipes": [{"inputs": []}]}}}).is_empty() and model.to_data() == before, "Invalid discovered-chant data is rejected without truncating valid discoveries")
	var optional := Book.new()
	check(optional.load_data({"version": 1, "spells": {"MANA_BOLT": {"name": "Mana Bolt", "recipes": [{"inputs": Helper.inputs(["Q", "E"])}]}}}).is_empty() and not optional.entries()[0]["favorite"], "Optional preferences load safely with defaults while retaining successful inputs")
	# Preference saving failure rolls back in memory as well as preserving disk.
	game.save_path = DIR + "missing_directory/blocked.json"
	before = game.discovered.to_data()
	game._change_spell_preference("WATER_PUSH", true, 0)
	check(game.discovered.to_data() == before, "Failed preference writes cannot invent a durable favorite/representative")
	game.free()
