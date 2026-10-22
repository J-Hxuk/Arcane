extends SceneTree
const SCENE = preload("res://scenes/main.tscn")
const Fixture = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const Helper = preload("res://tests/test_chant.gd")
const Research = preload("res://scripts/character_research.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Save = preload("res://scripts/character_save.gd")
const Journal = preload("res://scripts/experiment_journal.gd")
const DIR := "res://.task002_artifacts/fusion/"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var migrated_paths: Array = []
	for element in Profile.ELEMENTS:
		var doc: Dictionary = Fixture.fixture(element, 1787453028)
		doc["unknown_root"] = {"preserved": [1, 2, 3]}
		doc["research"]["unknown_research"] = "retained"
		var profile_for_history := Profile.new()
		profile_for_history.load_data(doc["chant"])
		var old_sim := Sim.simulate(profile_for_history, Helper.inputs(["Q", "E"]), true)
		old_sim["rules_version"] = 2
		old_sim["casting_steps"][0]["before"]["old_unknown_field"] = {"base_attributes": ["VOID"], "kept": true}
		var old_journal := Journal.new()
		old_journal.append(old_sim, "released", 15.0, 100, 1)
		old_journal.note(1, "이전 규칙 스냅샷 보존")
		doc["laboratory"] = old_journal.to_data()
		var path: String = DIR + "migration_" + element + "_" + str(OS.get_process_id())+"_"+str(Time.get_ticks_usec()) + ".json"
		migrated_paths.append(path)
		A.write(path, doc)
		var original := FileAccess.get_file_as_bytes(path)
		var game = SCENE.instantiate()
		game.save_path = path
		root.add_child(game)
		game.set_process(false)
		check(game.save_writable and Save.load_file(path,false)["version"] == Save.SCHEMA_VERSION, element + " v3 migrates to the current save schema")
		check(FileAccess.get_file_as_bytes(path + ".v3.bak") == original, element + " exact original bytes backed up")
		var output: Dictionary = game._character_document()
		check(Helper.equal(output["chant"], doc["chant"]) and Helper.equal(output["laboratory"], doc["laboratory"]) and Helper.equal(output["unknown_root"], doc["unknown_root"]) and output["research"]["unknown_research"] == "retained", element + " personal keys, historical journal and unknown fields preserved")
		if element == "VOID":
			check(game.research.main_attribute == null and game.research.researched_base_elements.is_empty() and output["research"]["neutral_mana"]["transition_pending"], "VOID becomes explicit pending neutral transition, no automatic elemental main")
			var sim := Sim.simulate(game.chant_profile, Helper.inputs(Helper.path_for(game.chant_profile, ["ACCUMULATE", "DIRECT"], Helper.first_for(game.chant_profile, "VOID"))), true, game.research.simulation_context())
			check(sim["final_state"]["base_attributes"].is_empty() and Resolver.resolve(sim, null, game.research.simulation_context())["state"] == "ready", "Legacy VOID retains neutral wave entitlement without any elemental slot")
			check(game.research.ritual_eligibility("WATER") == "neutral_transition_required" and game.research.acknowledge_neutral_transition() and game.research.main_attribute == null, "Explicit acknowledgement never selects a replacement main")
		else: check(game.research.main_attribute == element, element + " permanent main unchanged")
		game.free()
		var again = SCENE.instantiate()
		again.save_path = path
		root.add_child(again)
		again.set_process(false)
		check(again.save_writable and again.research.researched_base_elements.size() <= 3, element + " v4 reload remains valid")
		again.free()
	var legacy := Research.new()
	check(legacy.load_data({"researched_base_elements": ["WATER", "METAL", "VOID"], "innate_affinity": {"VOID": 85}, "research_clues": []}).is_empty() and legacy.researched_base_elements == PackedStringArray(["WATER", "METAL"]) and legacy.innate_affinity == {"VOID": 85}, "Three-slot legacy retains elemental commitments and old innate VOID, freeing only the neutral slot")
	check(legacy.eligibility("VOID") == "invalid_element", "Neutral research cannot consume a slot")
	var profile := Profile.new()
	profile.load_data(Profile.generate(1787453028))
	check(Sim.simulate(profile, Helper.inputs(["Q", "E"]), true)["kind"] == "mana_bolt" and Sim.simulate(profile, Helper.inputs(["C", "T", "C"]), true)["kind"] == "mana_bolt", "Both taught QE and personal neutral mana bolt remain usable")
	for alias in ["void", "none", "無"]:
		var aliased := Research.new()
		check(aliased.load_data({"main_attribute": alias}).is_empty() and aliased.main_attribute == null and aliased.to_data()["neutral_mana"]["original_roles"]["main_attribute"] == alias, "Legacy neutral alias preserves original spelling and pending transition: " + alias)
	var old_auxiliary := Research.new()
	check(old_auxiliary.load_data({"main_attribute": "WATER", "auxiliary_attributes": ["METAL", "VOID"]}).is_empty() and old_auxiliary.main_attribute == "WATER" and old_auxiliary.auxiliary_attributes == PackedStringArray(["METAL"]), "Legacy neutral auxiliary frees only neutral slot, preserving both elemental roles")
	check(Research.BaseElements.DEFINITIONS.size() == 5 and Resolver.DEFINITIONS["VOID"].requires_elements.is_empty(), "Canonical element registry and neutral spell requirements contain no VOID slot")
	var protected := Research.new()
	check(not protected.load_data({"main_attribute": "WATER", "auxiliary_attributes": ["VOID"], "legacy_committed_attributes": [], "researched_base_elements": ["FIRE", "VOID"]}).is_empty(), "Conflicting old role and derived-list sources remain protected, never silently corrected")
	check(not protected.load_data({"main_attribute": "VOID", "auxiliary_attributes": "METAL"}).is_empty(), "Malformed VOID role arrays cannot be truncated by migration")
	protected.load_data({"innate_affinity": {"VOID": 85, "WATER": 25}})
	check(protected.innate_element().is_empty() and protected.innate_affinity["VOID"] == 85, "Dominant old VOID affinity is not reinterpreted as a weaker elemental affinity")
	A.write(DIR + "a_restart_paths.json", {"paths": migrated_paths})
	print("FUSION A: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
