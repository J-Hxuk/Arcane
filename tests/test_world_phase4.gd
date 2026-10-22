extends "res://tests/test_world_phase1.gd"
const Policy = preload("res://tests/world_battle_policy.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
func run() -> void:
	var path := "res://.task002_artifacts/phase3a/p4_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, F.fixture("WATER", 1787453028)); game = Scene.instantiate(); game.save_path = path; game.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(game)
	var original: Dictionary = game._character_document(); var disk := FileAccess.get_file_as_bytes(path)
	for element in ["WOOD", "FIRE", "EARTH", "METAL", "WATER"]:
		game._start_developer_test(element, "WORLD")
		var inputs: Array = D.inputs(game.chant_profile, element, D.basic_actions(element))
		var result: Dictionary = Resolver.resolve(Sim.simulate(game.chant_profile, inputs, true, game.research.simulation_context()), element, game.research.simulation_context())
		check(result.get("state") == "ready", element + " personal keys resolve a legal basic spell for full combat")
		var pilot := Policy.new()
		for frame in 12000:
			if not game.guardian.active: break
			var action := pilot.decide(game, 0.02, element, result["mana_cost"])
			if action.has("move"): game.navigation.request(game, action["move"])
			if action.get("dodge", false):
				game.navigation.advance(game, 0.001, 200); game._request_dodge(); pilot.dodges += 1
			var direction: Vector2 = (Vector2(game.guardian.actor["pos"]) - game.player_pos).normalized()
			if action.get("cast", false):
				if game.elemental_combat.cast(game, result["spell"], direction): game.player_mana -= float(result["mana_cost"])
			if action.get("sword", false):
				game.player_attack_cooldown = game.CombatBalance.MELEE_INTERVAL; game.elemental_combat.melee(game, game.guardian.actor, game.CombatBalance.melee_damage(game.body_talent))
			game._process(0.02)
		var won: bool = game.guardian.state == "VICTORY" and "RUIN_GUARDIAN" in game.world_progress.data["bosses"]
		print("BATTLE_RESULT ", JSON.stringify({"element": element, "won": won, "hp": game.player_hp, "seconds": pilot.elapsed, "casts": pilot.casts, "swords": pilot.swings, "dodges": pilot.dodges, "patterns": game.guardian.metrics.get("attacks", {})}))
		check(won and pilot.casts > 0, element + " baseline spell + ordinary movement/sword clears unmodified boss AI without healing or forced HP")
		game._end_developer_test()
	check(game._character_document() == original and FileAccess.get_file_as_bytes(path) == disk, "All complete combat simulations preserve the original save/research/J state")
	game.player_pos = Vector2(2910, 910); game._interact(); game.guardian._begin_pattern(game, "CHARGE")
	var encounter: Dictionary = game.guardian.snapshot(); var profile: Dictionary = game._character_document()
	game._start_developer_test("FIRE_WATER", "LAB"); game._end_developer_test()
	check(game.guardian.snapshot() == encounter and game.guardian.actor == game.enemies[0] and game._character_document() == profile, "F2 trial from an active boss restores the exact attack state and live enemy reference")
	game._save_character(); game.free(); game = Scene.instantiate(); game.save_path = path; game.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(game)
	check(not game.guardian.active and game.player_pos == game.world_progress.safe_position() and game.world_progress.data["encounter"] == null, "Interrupted boss fight reloads at the safe checkpoint rather than an empty locked arena")
	print("WORLD PHASE4: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
