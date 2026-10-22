extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const A = preload("res://tests/test_awakening.gd")
const H = preload("res://tests/test_chant.gd")
const D = preload("res://scripts/developer_test_data.gd")
const S = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Save = preload("res://scripts/character_save.gd")
const PATH := "res://.task002_artifacts/fusion/auxiliary.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
func run() -> void:
	var game = Scene.instantiate()
	game.save_path = PATH
	root.add_child(game)
	game.set_process(false)
	check(game.save_writable and game.research.main_attribute == "WATER" and game.research.auxiliary_attributes == PackedStringArray(["METAL"]), "Normal isolated save reloads its genuinely awakened auxiliary")
	if OS.get_cmdline_user_args().has("--verify-restart"):
		var disk := FileAccess.get_file_as_bytes(PATH)
		check(game.discovered.to_data()["spells"].has("ICE_CRYSTAL_NEEDLE") and game.discovered.to_data()["spells"]["ICE_CRYSTAL_NEEDLE"]["favorite"], "New engine process retains successful fusion recipe and favorite")
		check(game.research.validate_evidence(game.journal.records()).is_empty() and game.research.to_data()["fusion_observations"].has("METAL+WATER"), "New process validates separate phenomenon and exact journal evidence")
		check(FileAccess.get_file_as_bytes(PATH) == disk, "Current v4 reload does not rewrite saved snapshots")
	else:
		check(game.research.study_binding("METAL") == "binding_studied" and game._save_character(), "Binding study unlocks only after real auxiliary interference evidence")
		game._enter_laboratory()
		var events := D.fusion_inputs(game.chant_profile, "WATER", "METAL")
		A.enter_keys(game, events.map(func(event): return event["key"]))
		game._cast_spell()
		game._change_spell_preference("ICE_CRYSTAL_NEEDLE", true, 0)
		check(game.discovered.to_data()["spells"]["ICE_CRYSTAL_NEEDLE"]["base_elements"] == ["METAL", "WATER"] and game.research.to_data()["fusion_observations"].has("METAL+WATER"), "Normal isolated release persists combat lineage separately from phenomenon research")
		var before: Dictionary = game._character_document()
		var snapshot: Dictionary = game.journal.records()[-1]
		game.save_path = "res://.task002_artifacts/fusion/missing_parent/failed_cast.json"
		game._laboratory_recover()
		A.enter_keys(game, events.map(func(event): return event["key"]))
		var mana: float = game.player_mana
		var journal: Dictionary = game.journal.to_data()
		game._cast_spell()
		check(game.player_mana == mana and game.laboratory_panel.arena.missiles.is_empty() and H.equal(game.journal.to_data(), journal), "Failed laboratory save refunds mana and rolls back combat effect/journal")
		game.save_path = PATH
		var single := S.simulate(game.chant_profile, D.inputs(game.chant_profile, "WATER", ["ACCUMULATE", "COMPRESS", "SHAPE", "SHAPE", "DIRECT"]), true, game.research.simulation_context())
		check(not str(Resolver.resolve(single, "WATER").get("kind", "")).contains("ice"), "Water-only shaped mana never becomes ice")
		var fake := S.simulate(game.chant_profile, events, true, game.research.simulation_context())
		var denied_context: Dictionary = game.research.simulation_context()
		denied_context["binding_pairs"] = []
		check(Resolver.resolve(fake, "WATER", denied_context)["state"] == "locked", "Even injected ready mana needs a studied binding at resolver boundary")
		var forged := before.duplicate(true)
		forged["research"]["main_attribute"] = "FIRE"
		forged["research"]["auxiliary_attributes"] = ["METAL", "WATER"]
		check(not Save.valid_fusion_access(forged), "Saving an existing fusion discovery under an unrelated main is rejected")
		check(H.equal(Save.load_file(PATH)["data"]["laboratory"]["records"][-1], snapshot), "A failed later experiment leaves previous successful snapshots intact")
	game.free()
	print("FUSION PERSISTENCE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
