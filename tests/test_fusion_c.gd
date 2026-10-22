extends SceneTree
const P = preload("res://scripts/chant_profile.gd")
const R = preload("res://scripts/character_research.gd")
const S = preload("res://scripts/mana_simulator.gd")
const D = preload("res://scripts/developer_test_data.gd")
const H = preload("res://tests/test_chant.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Fusion = preload("res://scripts/fusion_rules.gd")
const Visual = preload("res://scripts/mana_visual_model.gd")
const Save = preload("res://scripts/character_save.gd")
const Journal = preload("res://scripts/experiment_journal.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else: failures += 1; push_error("FAIL: " + label)
static func sequence(profile, first: String, second: String, wall := false) -> Array:
	var keys := H.path_for(profile, ["ACCUMULATE", "STABILIZE"], H.first_for(profile, first))
	keys.append(H.first_for(profile, second))
	if wall: keys.append_array([H.key_for(profile, "SHAPE"), H.key_for(profile, "SHAPE")])
	keys.append(H.key_for(profile, "DIRECT"))
	return H.inputs(keys)
func run() -> void:
	for seed_value in [71, 8431, 65537, 1787453028]:
		var profile := P.new()
		profile.load_data(P.generate(seed_value))
		for option in ["WATER_METAL", "FIRE_WATER"]:
			var model := R.new()
			model.load_data(D.character(profile.to_data(), option)["research"])
			var first: String = model.main_attribute
			var second: String = model.auxiliary_attributes[0]
			var forward := S.simulate(profile, sequence(profile, first, second), true, model.simulation_context())
			var reverse := S.simulate(profile, sequence(profile, second, first), true, model.simulation_context())
			check(forward["state"] == "ready" and H.equal(forward["final_state"], reverse["final_state"]), "%s seed%d symmetric declarations converge on identical complete mana state" % [option, seed_value])
			check(Visual.project(forward["final_state"], model.simulation_context()) == Visual.project(reverse["final_state"], model.simulation_context()), "Live/reversed binding visuals use identical state projection")
			var adjacent := S.simulate(profile, H.inputs([H.first_for(profile, first), H.first_for(profile, second)]), true, model.simulation_context())
			check(adjacent["final_state"]["base_attributes"].size() != 2, "Adjacent attribute keys never auto-bind")
			var without := model.simulation_context()
			without["binding_pairs"] = []
			check(S.simulate(profile, sequence(profile, first, second), true, without)["final_state"]["base_attributes"].size() != 2, "Unstudied binding cannot redeclare an element")
			var journal := Journal.new()
			journal.append(forward, "released", 8, 400, 1)
			var saved: Dictionary = journal.replay(1, 3)["after"]
			check(Visual.project(saved, model.simulation_context()) == Visual.project(forward["casting_steps"][3]["after"], model.simulation_context()), "Stored binding snapshot projects exactly; replay does not resimulate")
			model.record_resonance(profile, sequence(profile, first, second), 1)
			check(model.to_data().get("fusion_observations", {}).size() == 1, "Phenomenon evidence is recorded independently of any combat discovery")
			var poorer := model.simulation_context()
			poorer["knowledge"] = {}
			poorer["innate_element"] = "FIRE" if option == "WATER_METAL" else "METAL"
			var difficult := S.simulate(profile, sequence(profile, first, second), true, poorer)
			check(difficult["final_state"]["interference"] > forward["final_state"]["interference"], "Innate opposition and missing knowledge increase binding interference deterministically")
			var partial_events := sequence(profile, first, second)
			for i in 4: partial_events.append({"key": H.key_for(profile, "COMPRESS"), "at_ms": partial_events.size() * 100, "hold_ms": 0})
			var partial := S.simulate(profile, partial_events, true, model.simulation_context())
			for i in 6: partial_events.append({"key": H.key_for(profile, "COMPRESS"), "at_ms": partial_events.size() * 100, "hold_ms": 0})
			var collapsed := S.simulate(profile, partial_events, true, model.simulation_context())
			check(Visual.evidence(partial["final_state"])["stage"] == "unstable" and Visual.evidence(collapsed["final_state"])["stage"] == "collapsed", "Partial and collapsed bindings are observably different from a stable join")
	var fake := {"state": "ready", "final_state": {"phase": "READY", "mana_amount": 10.0, "base_attributes": ["METAL", "WATER"]}, "simulation_context": {"auxiliary_attributes": ["METAL", "WATER"]}}
	check(Resolver.resolve(fake, "FIRE")["state"] == "locked", "Resolver blocks two auxiliaries without main even for an injected ready state")
	check(not Fusion.authorized(["VOID", "WATER"], "WATER", ["VOID"]), "Neutral can never participate in elemental binding")
	var bad := D.character(P.generate(71), "FIRE_WATER")
	bad["research"]["auxiliary_attributes"] = ["METAL", "WATER"]
	bad["spell_discoveries"]["spells"] = {"fake_fusion": {"base_elements": ["METAL", "WATER"]}}
	check(Save.write_file("res://.task002_artifacts/fusion/forbidden.json", bad) == ERR_INVALID_DATA, "Final persistence boundary independently rejects auxiliary-only fusion lineage")
	check(Fusion.PHENOMENA.size() == 10 and Fusion.PHENOMENA["FIRE+WOOD"] == "metabolic_overdrive", "Ten phenomena retain their approved definitions without adding combat spells")
	print("FUSION C: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
