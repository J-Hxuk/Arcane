extends "res://tests/test_world_phase1.gd"
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
func battle(element := "WATER") -> void:
	if game.developer_mode: game._end_developer_test()
	game._start_developer_test(element, "WORLD")
func step(seconds: float) -> void:
	for i in ceili(seconds / 0.01): game._process(0.01)
func run() -> void:
	var path := "res://.task002_artifacts/phase3a/p3_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, F.fixture("WATER", 1787453028))
	game = Scene.instantiate(); game.save_path = path; game.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(game)
	var original: Dictionary = game._character_document(); var bytes := FileAccess.get_file_as_bytes(path)
	for id in ["SWEEP", "CHARGE", "SLAM", "THROW"]:
		battle(); var boss = game.guardian
		game.player_pos = boss.actor["pos"] + Vector2(-80 if id == "SWEEP" else -220, 0)
		boss._begin_pattern(game, id); var hp: float = game.player_hp
		check(boss.state == "WINDUP" and boss.timer >= 0.85 and game.player_hp == hp, id + " has a measurable damage-free visual warning")
		step(1.9)
		check(game.player_hp < hp, id + " performs real damage within the announced shape")
		check(boss.state == "RECOVERY" and boss.timer > 0.5, id + " leaves a real counter-casting recovery window")
		battle(); boss = game.guardian
		game.player_pos = boss.actor["pos"] + Vector2(-80 if id == "SWEEP" else -220, 0); boss._begin_pattern(game, id)
		game.player_pos += Vector2(0, 200); hp = game.player_hp; step(1.9)
		check(game.player_hp == hp, id + " is avoided by moving out of its locked telegraph")
	battle(); var boss = game.guardian
	boss.actor["hp"] = 125; boss._begin_pattern(game, "THROW"); step(1.1)
	check(boss.phase == 2 and game.missiles.size() == 3, "Half-health phase changes attack order/speed and throws a three-blade fan")
	battle("WOOD"); boss = game.guardian
	var wood = Resolver.DEFINITIONS["WOOD"]
	game.elemental_combat.hit_enemy(game, boss.actor, wood, Vector2.LEFT)
	check(is_equal_approx(boss.actor["root_remaining"], wood.duration * 0.35) and boss.actor["poise"] >= 20, "Heavy boss reduces root duration while keeping control and posture pressure")
	boss._begin_pattern(game, "SWEEP"); var time: float = boss.timer; boss.advance(game, 0.2)
	check(is_equal_approx(time - boss.timer, 0.11), "Root meaningfully delays a telegraphed attack rather than becoming immune")
	battle(); boss = game.guardian; var water = Resolver.DEFINITIONS["WATER"]; var position: Vector2 = boss.actor["pos"]
	game.elemental_combat.hit_enemy(game, boss.actor, water, Vector2.LEFT)
	check(is_equal_approx(boss.actor["pos"].distance_to(position), water.knockback * 0.2) and boss.actor["poise"] >= 26 and boss.actor["wet_remaining"] > 0, "Mass scales water displacement while preserving posture disruption and wet state")
	var small := F.target(Vector2(3400, 1100)); game.elemental_combat.hit_enemy(game, small, water, Vector2.LEFT)
	check(absf(Vector2(3400, 1100).distance_to(small["pos"]) - 135) < 0.02, "Ordinary targets keep their original displacement, not boss resistance")
	battle(); boss = game.guardian; boss.actor["pos"] = Vector2(3070, 858)
	for i in 8: game.elemental_combat.hit_enemy(game, boss.actor, water, Vector2.LEFT)
	check(not game._is_blocked(boss.actor["pos"], boss.actor["collision_radius"]) and boss.actor["pos"].x >= 3036, "Repeated water pushes respect the full boss body at arena edges")
	boss.actor["stagger_remaining"] = 0; boss.actor["poise"] = 0; boss.state = "APPROACH"; boss.cursor = 0
	game.player_pos = Vector2(3307, 576); var start: Vector2 = boss.actor["pos"]; step(5)
	check(Vector2(boss.actor["pos"]).distance_to(start) > 100 and not game._is_blocked(boss.actor["pos"], 26) and boss.navigation.rebuild_count <= 1, "Boss leaves the pushed edge and routes around a pillar with cached body-size navigation")
	battle(); boss = game.guardian; boss.actor["traits"]["mass_class"] = 10; start = boss.actor["pos"]
	game.elemental_combat.hit_enemy(game, boss.actor, water, Vector2.LEFT)
	check(absf(Vector2(boss.actor["pos"]).distance_to(start) - 13.5) < 0.02, "Changing mass class changes physical displacement independently of elemental identity")
	battle("FIRE"); boss = game.guardian; game.elemental_combat.hit_enemy(game, boss.actor, Resolver.DEFINITIONS["FIRE"], Vector2.LEFT)
	var hp: float = boss.actor["hp"]; game.elemental_combat.update(game, 1)
	check(boss.actor["hp"] < hp and boss.actor["burn_remaining"] > 0, "Fire burn remains a meaningful damage-over-time tool against actual layered materials")
	boss.actor["burn_remaining"] = 0; boss.actor["burn_dps"] = 0; boss.actor["traits"]["materials"] = ["stone"]
	game.elemental_combat.hit_enemy(game, boss.actor, Resolver.DEFINITIONS["FIRE"], Vector2.LEFT)
	check(is_equal_approx(boss.actor["burn_dps"], 2.45), "Combustible lining versus inert material changes burn behavior, not an element weakness table")
	game.elemental_combat.hit_enemy(game, boss.actor, water, Vector2.LEFT)
	check(is_equal_approx(boss.actor["burn_remaining"], 2) and boss.actor["wet_remaining"] > 0, "Existing water pressure dampens ongoing burn and leaves a visible wet state")
	battle("METAL"); boss = game.guardian; boss.actor["guarded"] = true; boss.actor["exposed"] = false
	var metal = Resolver.DEFINITIONS["METAL"]; hp = boss.actor["hp"]; game.elemental_combat.hit_enemy(game, boss.actor, metal, Vector2.LEFT)
	check(is_equal_approx(hp - boss.actor["hp"], metal.damage * 0.92), "Piercing mitigates a raised physical shield without an elemental weakness multiplier")
	battle("EARTH"); boss = game.guardian; game.player_pos = Vector2(3120, 910)
	check(game.elemental_combat.cast(game, Resolver.DEFINITIONS["EARTH"], Vector2.RIGHT), "Basic earth wall is placed in the real arena")
	boss._begin_pattern(game, "CHARGE"); step(1.65)
	check(boss.metrics["barrier_stops"] == 1 and boss.state == "RECOVERY" and boss.actor["exposed"] and game.player_hp == game._max_hp(), "Earth wall physically stops the charge and opens a counterattack opportunity")
	game.guardian.add_poise(100)
	check(boss.metrics["poise_breaks"] > 0 and boss.timer >= 2.4, "Accumulated pressure interrupts attacks with a readable stance break")
	battle(); boss = game.guardian; game.player_pos = boss.actor["pos"] + Vector2(-95, 0); boss._begin_pattern(game, "SWEEP")
	game.navigation.request(game, game.player_pos + Vector2(-180, 0)); game.navigation.advance(game, 0.01, 200); game._request_dodge(); step(1.15)
	check(game.player_hp == game._max_hp() and game.player_pos.distance_to(boss.actor["pos"]) > 135, "Existing Ctrl dodge physically escapes the sweep; no invulnerability hack")
	game._end_developer_test()
	check(game._character_document() == original and FileAccess.get_file_as_bytes(path) == bytes, "All five temporary profiles and boss trials preserve the original isolated player")
	game.player_pos = Vector2(2910, 910); game._interact(); boss = game.guardian
	check(game.guardian.active and game.arena_locked(), "Physical entrance starts encounter and arena boundary")
	boss.actor["hp"] = 0; boss.advance(game, 0.01)
	check("RUIN_GUARDIAN" in game.world_progress.data["bosses"] and game.bank_gold == 160 and not game.arena_locked(), "Victory persists boss flag, unlocks exit and grants one first-clear reward")
	game._start_guardian(); game.guardian.actor["hp"] = 0; game.guardian.advance(game, 0.01)
	check(game.bank_gold == 160 and game.world_progress.data["rewards"].size() == 1, "Rematch cannot duplicate the reward")
	game.free(); game = Scene.instantiate(); game.save_path = path; game.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(game)
	check("RUIN_GUARDIAN" in game.world_progress.data["bosses"] and game.bank_gold == 160, "Fresh process-style scene load restores the defeated boss and reward")
	game._start_guardian(); game.guardian.actor["hp"] = 0; game.guardian.state = "VICTORY"; game.guardian.active = false
	game.world_progress.data["bosses"].clear(); game.world_progress.data["rewards"].clear(); var before: int = game.bank_gold
	game.save_path = "res://.task002_artifacts/phase3a/no_directory/rejected.json"
	check(not game._guardian_victory() and game.bank_gold == before and game.world_progress.data["bosses"].is_empty() and game.victory_pending, "Victory save failure rolls back reward and leaves an explicit retry")
	print("WORLD PHASE3: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
