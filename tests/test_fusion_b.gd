extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const F = preload("res://tests/test_elemental_combat.gd")
const A = preload("res://tests/test_awakening.gd")
const H = preload("res://tests/test_chant.gd")
const R = preload("res://scripts/character_research.gd")
const S = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Dev = preload("res://scripts/developer_test_data.gd")
const DIR := "res://.task002_artifacts/fusion/"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
static func ritual(profile, element: String) -> Array:
	return H.path_for(profile, ["ACCUMULATE", "COMPRESS", "COMPRESS", "STABILIZE", "RESONATE", "STABILIZE", "RESONATE", "STABILIZE", "RESONATE", "STABILIZE", "SHAPE", "STABILIZE", "DIRECT"], H.first_for(profile, element))
func run() -> void:
	var path := DIR + "auxiliary.json"
	A.write(path, F.fixture("WATER", 1787453028))
	var game = Scene.instantiate()
	game.save_path = path
	root.add_child(game)
	game.set_process(false)
	game._enter_laboratory()
	check(game.research.begin_ritual("METAL") == "clues_required" and game.research.start_element_research("METAL") == "confirmation_required", "Auxiliary cannot be acquired by old API or menu")
	for source in ["book", "mentor", "environment"]: game._collect_research_clue("METAL", source)
	check(game.research.researched_base_elements.size() == 1 and game.research.ritual_eligibility("METAL") == "stable_reproduction_required", "Three clue sources do not consume slots or bypass experiments")
	var keys := ritual(game.chant_profile, "METAL")
	for i in 2:
		A.enter_keys(game, keys)
		game._laboratory_recover()
		game._cast_spell()
	check(game.research.stable_count("METAL") == 2 and game.research.interference_count("METAL") == 2, "Real laboratory releases establish stable and main-interference evidence")
	check(game._begin_awakening("METAL") == "ritual_started", "First auxiliary ritual starts after genuine prerequisites")
	game._cancel_awakening()
	check(game.research.auxiliary_attributes.is_empty(), "Cancel and retry never consume auxiliary slots")
	game._begin_awakening("METAL")
	A.enter_keys(game, keys)
	game._laboratory_recover()
	game._cast_spell()
	check(game.pending_awakening_offer.get("state") == "confirmation_required" and game.research.auxiliary_attributes.is_empty(), "Successful direct ritual still requires explicit permanent confirmation")
	var ticket: int = game.pending_awakening_offer.get("ticket", 0)
	var original_path: String = game.save_path
	game.save_path = DIR + "missing_parent/denied.json"
	check(game._confirm_element_research("METAL", ticket) == "save_failed" and game.research.auxiliary_attributes.is_empty(), "Failed final save rolls back the permanent auxiliary choice")
	game.save_path = original_path
	game._begin_awakening("METAL")
	A.enter_keys(game, keys)
	game._laboratory_recover()
	game._cast_spell()
	ticket = game.pending_awakening_offer.get("ticket", 0)
	check(game._confirm_element_research("METAL", ticket) == "committed" and game.research.main_attribute == "WATER" and game.research.auxiliary_attributes == PackedStringArray(["METAL"]), "Confirmed auxiliary preserves the original main and commits one slot")
	check(game.research.start_element_research("METAL", ticket) == "already_researched" and game.research.ritual_eligibility("FIRE") == "slots_full", "Duplicate and new second auxiliary acquisition are blocked")
	var basic := S.simulate(game.chant_profile, Dev.inputs(game.chant_profile, "METAL", ["ACCUMULATE", "DIRECT"]), true, game.research.simulation_context())
	check(Resolver.resolve(basic, "WATER")["state"] == "locked", "Confirmed auxiliary cannot cast a standalone basic spell")
	var original_data: Dictionary = game._character_document()
	game.free()
	var again = Scene.instantiate()
	again.save_path = path
	root.add_child(again)
	again.set_process(false)
	check(again.save_writable and H.equal(again._character_document(), original_data) and again.research.validate_evidence(again.journal.records()).is_empty(), "Reload preserves main, auxiliary and historical evidence")
	again.free()
	var model := R.new()
	model.load_data({"main_attribute": "METAL", "auxiliary_attributes": ["FIRE"], "innate_affinity": {"FIRE": 85}, "research_clues": [], "resonance_discoveries": {}})
	var profile = preload("res://scripts/chant_profile.gd").new()
	profile.load_data(preload("res://scripts/chant_profile.gd").generate(1787453028))
	var context := model.simulation_context()
	for source in ["book", "mentor"]: context["knowledge"]["FIRE"][source] = true
	var temp := R.new()
	temp.load_data(Dev.character(profile.to_data(), "FIRE")["research"])
	var example: Dictionary = Dev.examples(profile, "FIRE", temp.simulation_context()).filter(func(item): return item["spell_id"] == "FIRE_LANCE")[0]
	check(Resolver.resolve(S.simulate(profile, example["inputs"], true, context), "METAL")["state"] == "locked", "Auxiliary-only intermediate fire cannot bypass its rank restriction")
	print("FUSION B: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
