extends SceneTree
## Isolated fixture characters only. Never reads/writes the real user:// save.
const SCENE = preload("res://scenes/main.tscn")
const Profile = preload("res://scripts/chant_profile.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Save = preload("res://scripts/character_save.gd")
const Helper = preload("res://tests/test_chant.gd")
const Awakening = preload("res://tests/test_awakening.gd")
const DIR := "res://.task002_artifacts/phase2b25/"
const ACTIONS := Awakening.RITUAL_ACTIONS
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

static func fixture(element: Variant, seed_value := 8431) -> Dictionary:
	return {"schema_version": 3, "magic": 65, "body": 35, "fixed_seed": 12345, "bank": 100,
		"injury": 0, "armor": 100, "corpse": {}, "learned": ["EMBER"], "unknown": {"preserve": true},
		"chant": Profile.generate(seed_value), "laboratory": {"version": 1, "next_id": 1, "records": []},
		"research": {"main_attribute": element, "auxiliary_attributes": [], "legacy_committed_attributes": [],
			"innate_affinity": {"FIRE": 85, "WOOD": 25}, "research_clues": [], "resonance_discoveries": {}}}

static func keys_for(game, element: String) -> Array:
	return Helper.path_for(game.chant_profile, ACTIONS, Helper.first_for(game.chant_profile, element))

func game_at(element: Variant):
	var path := DIR + serial + "_" + ("unawakened" if element == null else str(element)) + ".json"
	Awakening.write(path, fixture(element))
	var game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._enter_dungeon("FIXED")
	reset_arena(game)
	return game

static func reset_arena(game) -> void:
	game._reset_combat_input()
	game.elemental_combat.clear()
	game.missiles.clear()
	game.enemies.clear()
	game.walls.clear()
	game.player_pos = Vector2(300, 300)
	game.player_mana = 100.0
	game.player_hp = 100.0
	game.exhaustion_seconds = 0.0
	game.game_state = "DUNGEON"

static func target(position: Vector2, hp := 100.0) -> Dictionary:
	return {"pos": position, "hp": hp, "shot": 100.0}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_laws()
	_access_and_integration()
	_effects()
	_awakening_to_combat()
	print("ELEMENTAL COMBAT TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _laws() -> void:
	var mapping_independent := true
	var same_state := true
	var no_fixed_commands := true
	var guards := true
	for element in Profile.ELEMENTS:
		var definition = Resolver.DEFINITIONS[element]
		check(definition.validate_requirements().is_empty(), element + " combat resource validates")
		no_fixed_commands = no_fixed_commands and definition.commands.is_empty()
		for seed_value in [1, 7, 71, 8431, 98765, 65537]:
			var profile := Profile.new()
			profile.load_data(Profile.generate(seed_value))
			var first := Helper.first_for(profile, element)
			var sequence := Helper.path_for(profile, ACTIONS, first)
			var simulation := Sim.simulate(profile, Helper.inputs(sequence), true)
			var result := Resolver.resolve(simulation, element)
			mapping_independent = mapping_independent and result.get("spell") == definition and result["state"] == "ready"
			var alternate := ACTIONS.duplicate()
			alternate.erase("SHAPE")
			alternate.insert(2, "SHAPE")
			var other := Sim.simulate(profile, Helper.inputs(Helper.path_for(profile, alternate, first)), true)
			var other_result := Resolver.resolve(other, element)
			same_state = same_state and other["final_state"] == simulation["final_state"] and other_result.get("spell") == definition
			guards = guards and Resolver.resolve(simulation, null)["state"] == "locked"
			var weak := Sim.simulate(profile, Helper.inputs([first]), true)
			guards = guards and not Resolver.resolve(weak, element).has("spell")
	check(mapping_independent, "All six spells resolve across 36 attribute/personal-mapping combinations")
	check(same_state, "Different manipulation orders with identical final state yield identical spell")
	check(no_fixed_commands, "Six elemental resources have no fixed key recipe")
	check(guards, "No first-word or unawakened main-attribute bypass")
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	var pure := Sim.simulate(profile, Helper.inputs(["Q", "E"]), true)
	check(pure["kind"] == "mana_bolt" and pure["final_state"]["base_attributes"].is_empty(), "Pure mana and VOID remain distinct")
	var inputs := Helper.inputs(Helper.path_for(profile, ACTIONS, Helper.first_for(profile, "WATER")))
	var water := Sim.simulate(profile, inputs)
	check(Resolver.resolve(water, "FIRE")["state"] == "locked", "Other main attribute cannot authorize WATER")
	var costly_inputs := inputs.duplicate(true)
	costly_inputs.append({"key": Helper.key_for(profile, "COMPRESS"), "at_ms": 4000, "hold_ms": 0})
	var costly := Resolver.resolve(Sim.simulate(profile, costly_inputs), "WATER")
	check(costly.get("spell") == Resolver.DEFINITIONS["WATER"] and costly["mana_cost"] > Resolver.resolve(water, "WATER")["mana_cost"], "Actual manipulation loss adds to data-defined base mana cost")

func _access_and_integration() -> void:
	for element in Profile.ELEMENTS:
		var game = game_at(element)
		var permanent: Dictionary = game.research.to_data()
		var profile: Dictionary = game.chant_profile.to_data()
		Awakening.enter_keys(game, keys_for(game, element))
		var result: Dictionary = game._inspect_chant(true)
		check(result["state"] == "ready" and result.get("spell") == Resolver.DEFINITIONS[element], element + " real Main mobile chant resolves")
		# Barrier creation needs open forward space. All aim directions here are open.
		var mana: float = game.player_mana
		game._cast_spell()
		var spawned: bool = game.missiles.size() == 1 or game.elemental_combat.barriers.size() == 1 or game.elemental_combat.visuals.size() == 1
		check(spawned and game.runes.is_empty() and game.player_mana == mana - result["mana_cost"], element + " real release spawns effect and charges data cost")
		check(game.research.to_data() == permanent and game.chant_profile.to_data() == profile, element + " cast preserves permanent main/affinity/mapping")
		var saved := Save.load_file(game.save_path)
		check(Helper.equal(saved["data"]["research"], permanent) and Helper.equal(saved["data"]["chant"], profile) and saved["data"]["unknown"]["preserve"], element + " discovery save preserves character and unknown data")
		reset_arena(game)
		game.player_mana = 0.0
		Awakening.enter_keys(game, keys_for(game, element))
		game._cast_spell()
		check(game.missiles.is_empty() and game.elemental_combat.barriers.is_empty() and game.elemental_combat.visuals.is_empty() and not game.runes.is_empty(), element + " insufficient mana emits no effect")
		reset_arena(game)
		Awakening.enter_keys(game, keys_for(game, element))
		game.exhaustion_seconds = 1.0
		game._cast_spell()
		check(game.player_mana == 100.0 and game.missiles.is_empty() and game.elemental_combat.barriers.is_empty() and game.elemental_combat.visuals.is_empty(), element + " exhaustion blocks real release")
		game.free()
	var game = game_at(null)
	Awakening.enter_keys(game, keys_for(game, "FIRE"))
	game._cast_spell()
	check(game.player_mana == 100.0 and game.missiles.is_empty() and game._inspect_chant()["state"] == "locked", "Direct non-UI call cannot cast an unawakened attribute")
	game.game_state = "HUB"
	game._enter_laboratory()
	Awakening.enter_keys(game, keys_for(game, "FIRE"))
	game._cast_spell()
	check(game.research.stable_count("FIRE") == 1 and game.research.main_attribute == null and game.missiles.is_empty() and game.journal.records()[-1]["result"]["kind"] == "fire_resonance", "Laboratory keeps six-element experimentation and awakening evidence, without combat execution")
	game.free()
	game = game_at("EARTH")
	Awakening.enter_keys(game, keys_for(game, "EARTH"))
	# Aiming anywhere is blocked by surrounding terrain; no resource charge on failure.
	for row in game.ROWS:
		for column in game.COLS: game.walls.append(Vector2i(column, row))
	game._cast_spell()
	check(game.elemental_combat.barriers.is_empty() and game.player_mana == 100.0 and not game.runes.is_empty(), "Main rejects obstructed EARTH placement before mana charge and preserves chant")
	game.free()

func _awakening_to_combat() -> void:
	var game = game_at(null)
	game.game_state = "HUB"
	game._enter_laboratory()
	for source in ["book", "mentor"]: game._collect_research_clue("WATER", source)
	for i in 2:
		Awakening.enter_keys(game, Awakening.sequence(game.chant_profile, "WATER"))
		game._cast_spell()
	check(game._begin_awakening("WATER") == "ritual_started", "Real WATER flow can begin ritual after two experiments")
	Awakening.enter_keys(game, keys_for(game, "WATER"))
	game._cast_spell()
	check(game.research.awakening_state == "confirmation_pending", "New combat extension preserves the actual awakening confirmation")
	var ticket: int = game.pending_awakening_offer.get("ticket", 0)
	check(game._confirm_element_research("WATER", ticket) == "committed", "Real WATER awakening saves through the existing confirmation API")
	var path: String = game.save_path
	var profile: Dictionary = game.chant_profile.to_data()
	game.free()
	game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._enter_dungeon("FIXED")
	reset_arena(game)
	Awakening.enter_keys(game, keys_for(game, "WATER"))
	game._cast_spell()
	check(game.research.main_attribute == "WATER" and game.chant_profile.to_data() == profile and game.missiles.size() == 1 and game.missiles[0]["spell_id"] == &"WATER_PUSH", "Awakening -> save -> reload -> real dungeon WATER combat release")
	game.free()

func _effects() -> void:
	var game = game_at("FIRE")
	var runtime = game.elemental_combat
	game.enemies.append(target(Vector2(380, 300)))
	runtime.cast(game, Resolver.DEFINITIONS["FIRE"], Vector2.RIGHT)
	game._update_missiles(0.25, 1.0)
	var hp: float = game.enemies[0]["hp"]
	runtime.update(game, 1.0)
	check(hp == 82.0 and game.enemies[0]["hp"] == 75.0 and game.enemies[0]["burn_remaining"] == 2.0, "FIRE deals impact damage plus timed burn damage")
	runtime.update(game, 10.0)
	check(game.enemies[0]["hp"] == 61.0 and game.enemies[0]["burn_remaining"] == 0.0, "FIRE burn is capped to its remaining duration on a long frame")
	reset_arena(game)
	game.enemies.append(target(Vector2(380, 300)))
	runtime.cast(game, Resolver.DEFINITIONS["WOOD"], Vector2.RIGHT)
	game._update_missiles(0.25, 1.0)
	var position: Vector2 = game.enemies[0]["pos"]
	game._update_enemies(0.5)
	check(game.enemies[0]["hp"] == 88.0 and game.enemies[0]["pos"] == position and game.enemies[0]["root_remaining"] > 0.0, "WOOD stops enemy movement rather than applying burn")
	runtime.update(game, 2.5)
	game._update_enemies(0.1)
	check(game.enemies[0]["pos"] != position, "WOOD enemy movement resumes after root expiration")
	reset_arena(game)
	check(runtime.cast(game, Resolver.DEFINITIONS["EARTH"], Vector2.RIGHT), "EARTH creates an obstacle in open aimed space")
	var barrier: Vector2 = runtime.barriers[0]["pos"]
	game._try_move_player(Vector2(200, 0))
	check(game.player_pos.x < barrier.x - 22.0 and game._is_blocked(barrier), "EARTH blocks player movement, including a large movement step")
	game.enemies.append(target(barrier + Vector2(80, 0)))
	game._update_enemies(2.0)
	check(game.enemies[0]["pos"].x > barrier.x + 22.0, "EARTH also blocks enemy movement")
	game.missiles.append({"pos": barrier + Vector2(60, 0), "dir": Vector2.LEFT, "hostile": true, "life": 2.0, "dmg": 16.0})
	game._update_missiles(0.5, 1.0)
	check(game.missiles.is_empty() and game.player_hp == 100.0, "EARTH intercepts hostile projectiles")
	game.missiles.append({"pos": barrier - Vector2(60, 0), "dir": Vector2.RIGHT, "hostile": false, "life": 2.0, "dmg": 35.0})
	game._update_missiles(0.5, 1.0)
	check(game.missiles.is_empty(), "EARTH also blocks friendly projectiles")
	runtime.update(game, 5.1)
	check(runtime.barriers.is_empty() and not game._is_blocked(barrier), "EARTH expires and restores walkable space")
	reset_arena(game)
	game.enemies.append(target(Vector2(395, 300)))
	check(not runtime.cast(game, Resolver.DEFINITIONS["EARTH"], Vector2.RIGHT) and runtime.barriers.is_empty(), "EARTH refuses actor overlap")
	reset_arena(game)
	game.walls.append(Vector2i(7, 4)) # x376..416 y264..304, on the aimed path.
	check(not runtime.cast(game, Resolver.DEFINITIONS["EARTH"], Vector2.RIGHT), "EARTH refuses terrain overlap/placement through walls")
	reset_arena(game)
	for x in [365, 425, 485, 545]: game.enemies.append(target(Vector2(x, 300)))
	runtime.cast(game, Resolver.DEFINITIONS["METAL"], Vector2.RIGHT)
	game._update_missiles(0.5, 1.0)
	check(game.enemies[0]["hp"] == 76.0 and game.enemies[1]["hp"] == 76.0 and game.enemies[2]["hp"] == 76.0 and game.enemies[3]["hp"] == 100.0, "METAL pierces exactly three distinct enemies in one swept flight")
	reset_arena(game)
	game.enemies.append(target(Vector2(380, 300)))
	runtime.cast(game, Resolver.DEFINITIONS["METAL"], Vector2.RIGHT)
	game._update_missiles(0.1, 1.0)
	game._update_missiles(0.02, 1.0)
	game._update_missiles(0.02, 1.0)
	check(game.enemies[0]["hp"] == 76.0, "METAL never repeatedly damages the same enemy across flight frames")
	reset_arena(game)
	game.enemies.append(target(Vector2(380, 300)))
	runtime.cast(game, Resolver.DEFINITIONS["WATER"], Vector2.RIGHT)
	game._update_missiles(0.25, 1.0)
	check(game.enemies[0]["pos"].x == 480.0 and game.enemies[0]["hp"] == 90.0, "WATER moves its hit target 100 units with lower impact damage")
	reset_arena(game)
	game.enemies.append(target(Vector2(350, 300)))
	game.walls.append(Vector2i(7, 4))
	runtime.cast(game, Resolver.DEFINITIONS["WATER"], Vector2.RIGHT)
	game._update_missiles(0.2, 1.0)
	check(game.enemies[0]["pos"].x <= 361.0 and not game._is_blocked(game.enemies[0]["pos"], 15.0), "WATER knockback cannot pass through terrain")
	reset_arena(game)
	for position_value in [Vector2(360, 300), Vector2(300, 380), Vector2(500, 300)]: game.enemies.append(target(position_value))
	runtime.cast(game, Resolver.DEFINITIONS["VOID"], Vector2.RIGHT)
	check(game.enemies[0]["hp"] == 84.0 and game.enemies[1]["hp"] == 84.0 and game.enemies[2]["hp"] == 100.0 and game.missiles.is_empty(), "VOID hits multiple nearby directions but excludes enemies outside its radius")
	position = game.enemies[0]["pos"]
	game.enemies[0]["shot"] = 0.0
	game._update_enemies(0.1)
	check(game.enemies[0]["pos"] == position and game.missiles.is_empty(), "VOID stagger pauses both movement and shooting")
	runtime.update(game, 0.7)
	game._update_enemies(0.1)
	check(game.enemies[0]["pos"] != position and not game.missiles.is_empty(), "VOID stagger expires and enemy behavior resumes")
	reset_arena(game)
	game.walls.append(Vector2i(7, 4))
	game.enemies.append(target(Vector2(420, 300)))
	runtime.cast(game, Resolver.DEFINITIONS["VOID"], Vector2.RIGHT)
	check(game.enemies[0]["hp"] == 100.0, "VOID shockwave respects terrain occlusion")
	reset_arena(game)
	runtime.cast(game, Resolver.DEFINITIONS["EARTH"], Vector2.RIGHT)
	game.player_pos = game.EXIT_POS
	game._interact()
	check(runtime.barriers.is_empty() and runtime.visuals.is_empty(), "Dungeon exit clears temporary effects")
	game._enter_dungeon("FIXED")
	reset_arena(game)
	runtime.cast(game, Resolver.DEFINITIONS["EARTH"], Vector2.RIGHT)
	game._die()
	check(runtime.barriers.is_empty() and game.missiles.is_empty(), "Death clears temporary effects without changing main attribute")
	game.free()
