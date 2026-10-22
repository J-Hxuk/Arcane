extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const F = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const H = preload("res://tests/test_chant.gd")
const D = preload("res://scripts/developer_test_data.gd")
const R = preload("res://scripts/character_research.gd")
const P = preload("res://scripts/chant_profile.gd")
const S = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
func run() -> void:
	var expect := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expect="): expect = int(arg.trim_prefix("--expect="))
	check(Resolver.FUSION_SPELLS.size() == expect, "Sequential D checkpoint has exactly the intended number of combat resources")
	var path := "res://.task002_artifacts/fusion/developer_original.json"
	A.write(path, F.fixture("WATER", 1787453028))
	var game = Scene.instantiate()
	game.save_path = path
	game.developer_tools_enabled = true
	root.add_child(game)
	game.set_process(false)
	var bytes := FileAccess.get_file_as_bytes(path)
	var original: Dictionary = game._character_document()
	for option in ["WATER_METAL", "FIRE_WATER"]:
		for location in ["LAB", "DUNGEON"]:
			game._start_developer_test(option, location)
			if location == "LAB": game.laboratory_panel.arena.set_process(false)
			var examples := D.examples(game.chant_profile, option, game.research.simulation_context())
			for example in examples:
				var first: String = game.research.main_attribute
				var second: String = game.research.auxiliary_attributes[0]
				for reverse in [false, true]:
					if location == "LAB": game._laboratory_recover()
					else: F.reset_arena(game)
					if location == "LAB": game.laboratory_panel.arena.controller = null # Fixed-direction executor fixture; window tests use real cursor input.
					var events := D.fusion_inputs(game.chant_profile, second if reverse else first, first if reverse else second, example["spell_id"] == "ICE_CRYSTAL_BARRIER")
					var resolved := Resolver.resolve(S.simulate(game.chant_profile, events, true, game.research.simulation_context()), first)
					check(resolved["state"] == "ready" and str(resolved["spell"].spell_id) == example["spell_id"], location + " forward/reverse resolves " + example["spell_id"])
					A.enter_keys(game, events.map(func(event): return event["key"]))
					game._cast_spell()
					var arena = game.laboratory_panel.arena if location == "LAB" else game
					var runtime = game.laboratory_panel.arena.combat if location == "LAB" else game.elemental_combat
					if example["spell_id"] == "ICE_CRYSTAL_BARRIER":
						check(runtime.barriers.size() == 1 and runtime.blocks(runtime.barriers[0]["pos"], 5), location + " crystal barrier physically blocks actors")
						var center: Vector2 = runtime.barriers[0]["pos"]
						arena.missiles.append({"pos": center + Vector2(60, 0), "dir": Vector2.LEFT, "hostile": true, "life": 2.0, "dmg": 16.0})
						runtime.update_missiles(arena, 0.5, 1.0)
						check(arena.missiles.is_empty(), location + " crystal barrier intercepts real projectile")
						runtime.update(arena, 6.1)
						check(runtime.barriers.is_empty(), location + " crystal barrier expires")
					else:
						check(arena.missiles.size() == 1, location + " projectile is actually spawned")
						var missile: Dictionary = arena.missiles[0]
						arena.enemies.clear()
						arena.enemies.append(F.target(arena.player_pos + Vector2(missile["dir"]) * 80))
						var before: Vector2 = arena.enemies[0]["pos"]
						runtime.update_missiles(arena, 0.3, 1.0)
						var enemy: Dictionary = arena.enemies[0]
						check(enemy["hp"] == 100 - example["damage"] and (enemy.get("crystal_remaining", 0.0) > 0 if example["spell_id"] == "ICE_CRYSTAL_NEEDLE" else enemy["pos"].distance_to(before) > 100), location + " real damage and distinct crystal restraint / wind push")
						if example["spell_id"] == "ICE_CRYSTAL_NEEDLE":
							runtime.update(arena, 1.0)
							check(arena.enemies[0]["root_remaining"] == 0 and arena.enemies[0]["crystal_remaining"] == 0, location + " crystal restraint ends at its duration")
					check(game.developer_metrics.get("spell") == example["name"] and not game.discovered.entries().is_empty(), location + " successful direct input is recorded for J HUD")
					check(FileAccess.get_file_as_bytes(path) == bytes, "Temporary fusion release never touches the original save")
	check(game._end_developer_test() and H.equal(game._character_document(), original) and FileAccess.get_file_as_bytes(path) == bytes, "Ending all temporary pair tests restores original main/slots/keys/document")
	game.free()
	print("FUSION D%d: %d checks, %d failures" % [expect, checks, failures])
	quit(0 if failures == 0 else 1)
