extends SceneTree
## Phase 2B-2: no player saves. Covers model laws and the real persisted flow.
const Research = preload("res://scripts/character_research.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Save = preload("res://scripts/character_save.gd")
const Helper = preload("res://tests/test_chant.gd")
const SCENE = preload("res://scenes/main.tscn")
const DIR := "res://.task002_artifacts/phase2b2/"
const RESTART := DIR + "restart.json"
const STABLE_ACTIONS := ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE", "STABILIZE", "RESONATE", "STABILIZE", "RESONATE", "STABILIZE"]
const RITUAL_ACTIONS := STABLE_ACTIONS + ["SHAPE", "DIRECT", "STABILIZE"]
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

static func sequence(profile: Profile, element: String, ritual := false) -> Array:
	return Helper.path_for(profile, RITUAL_ACTIONS if ritual else STABLE_ACTIONS, Helper.first_for(profile, element))

static func seeded_fixture(legacy: Array = []) -> Dictionary:
	return {"schema_version": 2, "magic": 67, "body": 34, "bank": 193, "injury": 1, "armor": 73,
		"fixed_seed": 23456, "corpse": {"kind": "FIXED", "gold": 41, "x": 196, "y": 204}, "learned": ["EMBER", "MANA_BOLT"],
		"unknown": {"keep": [1, 2]}, "chant": Profile.generate(65537), "laboratory": {"version": 1, "next_id": 1, "records": []},
		"research": {"researched_base_elements": legacy, "innate_affinity": {"WOOD": 85, "FIRE": 25, "EARTH": 25, "METAL": 25, "WATER": 25, "VOID": 25},
			"research_clues": [], "old_field": "keep"}}

static func write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func game_at(path: String):
	var game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	return game

static func enter_keys(game, keys: Array) -> void:
	game._reset_combat_input()
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	game.combat_input.handle_event(event, 1.0)
	for index in range(keys.size()):
		event = InputEventKey.new()
		event.keycode = OS.find_keycode_from_string(keys[index])
		event.physical_keycode = event.keycode
		event.pressed = true
		game.combat_input.handle_event(event, 1.1 + index * 0.1)
		event.pressed = false
		game.combat_input.handle_event(event, 1.11 + index * 0.1)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	if OS.get_cmdline_user_args().has("--verify-restart"): _restart()
	else:
		_laws()
		_model_guards()
		_flow()
		_compatibility()
		_save_failure()
	print("AWAKENING TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _laws() -> void:
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	var all_reachable := true
	var all_single_hidden := true
	var deterministic := true
	var all_awakenable := true
	for innate in Profile.OHAENG:
		var model := Research.new()
		model.load_data({"innate_affinity": {innate: 85}})
		for element in Profile.OHAENG:
			for source in ["book", "mentor"]: model.acquire_clue(element, source, Rules.clue_id(element, source))
			var context := model.simulation_context()
			var events := Helper.inputs(sequence(profile, element, true))
			var result := Sim.simulate(profile, events, true, context)
			if result["state"] != "ready" or result["kind"] != element.to_lower() + "_resonance": all_reachable = false
			if result != Sim.simulate(profile, events, true, context): deterministic = false
			var candidate := Research.new()
			candidate.load_data(model.to_data())
			candidate.record_resonance(profile, events, 1)
			candidate.record_resonance(profile, events, 2)
			if candidate.begin_ritual(element) != "ritual_started": all_awakenable = false
			var proof := candidate.complete_ritual(profile, events)
			if proof["state"] != "confirmation_required" or candidate.start_element_research(element, proof.get("ticket", 0)) != "committed": all_awakenable = false
			var single := Sim.simulate(profile, Helper.inputs([Helper.first_for(profile, element)]), true, context)
			if single["kind"] != "none" or single["observation"] != "뚜렷한 변화가 관찰되지 않습니다.": all_single_hidden = false
	check(all_reachable, "All 25 elemental innate/target combinations have reachable ritual structures, including opposed pairs")
	check(deterministic, "Every elemental experiment is deterministic under identical character/knowledge conditions")
	check(all_awakenable, "All 25 elemental combinations can complete the full clue/evidence/ritual/confirmation model flow")
	check(all_single_hidden, "First word reveals neither element phenotype nor innate affinity in all 25 elemental combinations")
	for innate in Rules.CONTROLS:
		var controlled: String = Rules.CONTROLS[innate]
		check(Rules.relation(innate, controlled) == "opposed" and Rules.relation(controlled, innate) == "opposed", "Directed control edge penalizes either innate/target direction: " + innate)
	check(Rules.relation("VOID", "WOOD") == "neutral" and Rules.relation("FIRE", "VOID") == "neutral", "VOID is excluded from the five-phase interference ring")
	var easy := Rules.requirements("WOOD", {"innate_element": "WOOD"})
	var hard := Rules.requirements("EARTH", {"innate_element": "WOOD"})
	check(easy["gain"] > hard["gain"] and easy["interference"] < hard["interference"] and easy["stability"] < hard["stability"], "Affinity changes observable growth/control requirements, never a random success roll")
	var knowledge := {"EARTH": {"book": true, "mentor": true}}
	var informed := Rules.requirements("EARTH", {"innate_element": "WOOD", "knowledge": knowledge})
	check(informed["stability"] < hard["stability"] and informed["resonance"] < hard["resonance"], "Book and mentor knowledge lower different preparation/control requirements")
	var control_events := Helper.inputs(Helper.path_for(profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], Helper.first_for(profile, "FIRE")))
	check(Sim.simulate(profile, control_events)["state"] == "ready" and Sim.simulate(profile, control_events, false, {"control_penalty": 20.0})["state"] == "unstable", "An explicit common environmental control condition changes outcomes deterministically")
	var events := Helper.inputs(Helper.path_for(profile, ["RESONATE"], Helper.first_for(profile, "EARTH")))
	check(Sim.simulate(profile, events)["state"] == "weak", "Insufficient preparation yields a weak clue, not stable resonance")
	events = Helper.inputs(Helper.path_for(profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], Helper.first_for(profile, "EARTH")))
	check(Sim.simulate(profile, events, false, {"innate_element": "WOOD"})["state"] == "partial", "Opposed target gives partial response until further controlled resonance")
	check(Sim.simulate(profile, Helper.inputs(["Q", "E"]), true, {"innate_element": "WOOD", "knowledge": knowledge})["kind"] == "mana_bolt", "Pure tutorial bolt remains independent of all affinity and knowledge requirements")

func _model_guards() -> void:
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	var model := Research.new()
	check(model.main_attribute == null and model.auxiliary_attributes.is_empty(), "New model has no main or auxiliary attribute")
	check(model.request_research("WOOD")["state"] == "awakening_required" and model.start_element_research("WOOD", 1) == "confirmation_required", "Old Phase 2A UI/API cannot bypass the awakening flow")
	check(model.begin_ritual("WOOD") == "clues_required", "Ritual cannot start without any clue")
	for source in ["book", "mentor"]: model.acquire_clue("WOOD", source, Rules.clue_id("WOOD", source))
	check(model.begin_ritual("WOOD") == "stable_reproduction_required" and model.researched_base_elements.is_empty(), "Clue acquisition alone never unlocks or occupies a slot")
	var events := Helper.inputs(sequence(profile, "WOOD"))
	model.record_resonance(profile, events, 1)
	model.record_resonance(profile, events, 1)
	check(model.stable_count("WOOD") == 1 and model.begin_ritual("WOOD") == "ritual_started", "Duplicate evidence stays one record; one stable experiment now allows a manual ritual")
	model.record_resonance(profile, events, 2)
	check(model.begin_ritual("WOOD") == "ritual_started", "Two separate stable records and both clue types allow a ritual attempt")
	check(model.complete_ritual(profile, events)["state"] == "ritual_structure_required", "Stable resonance alone cannot bypass ritual shape and direction")
	var proof := model.complete_ritual(profile, Helper.inputs(sequence(profile, "WOOD", true)))
	check(proof["state"] == "confirmation_required" and model.main_attribute == null and model.researched_base_elements.is_empty(), "Valid ritual creates only a pending confirmation, not a permanent choice")
	check(model.start_element_research("FIRE", proof["ticket"]) == "confirmation_required", "Ritual confirmation ticket is bound to its target")
	model.cancel_request()
	check(model.start_element_research("WOOD", proof["ticket"]) == "confirmation_required", "Cancelled ritual proof cannot commit later")
	model.begin_ritual("WOOD")
	var fresh := model.complete_ritual(profile, Helper.inputs(sequence(profile, "WOOD", true)))
	check(model.start_element_research("WOOD", proof["ticket"]) == "confirmation_required", "Reattempt invalidates the previous proof")
	check(model.start_element_research("WOOD", fresh["ticket"]) == "committed" and model.main_attribute == "WOOD" and model.researched_base_elements.size() == 1, "Exactly one main and slot are committed atomically in the model")
	check(model.start_element_research("WOOD", fresh["ticket"]) == "already_researched" and model.start_element_research("FIRE", 999) == "confirmation_required", "Duplicate is a no-op and a forged auxiliary confirmation is rejected")
	check(model.begin_ritual("FIRE") == "clues_required" and model.request_research("FIRE")["state"] == "auxiliary_awakening_required", "New auxiliary research needs its own evidence and ritual")
	check(not model.to_data().has("researched_base_elements") and model.to_data()["main_attribute"] == "WOOD", "Roles are the only persisted source of new permanent research")

func _flow() -> void:
	var path := DIR + "flow_" + serial + ".json"
	write(path, seeded_fixture())
	var game = game_at(path)
	var mapping: Dictionary = game.chant_profile.to_data()
	var original_affinity: Dictionary = game.research.innate_affinity
	check(game.research.main_attribute == null and game.research.researched_base_elements.is_empty(), "Actual migrated character starts unawakened without a random main assignment")
	game._enter_laboratory()
	game._collect_research_clue("EARTH", "book")
	game._collect_research_clue("EARTH", "mentor")
	check(game.research.researched_base_elements.is_empty() and game.research.research_clues.any(func(clue):return clue.source=="mentor") and not game.laboratory_panel.awakening_panel.journal_view.visible, "Real mentor clues remain internal without slot use or duplicate clue-list UI")
	for repetition in range(2):
		enter_keys(game, sequence(game.chant_profile, "EARTH"))
		game._cast_spell()
	check(game.research.stable_count("EARTH") == 2 and game.research.main_attribute == null, "Two opposed-element experiments create durable stable evidence without awakening")
	var lab_result: Dictionary = game.journal.records()[-1]
	var field_result := Sim.simulate(game.chant_profile, Helper.inputs(sequence(game.chant_profile, "EARTH")), true, game.research.simulation_context())
	check(lab_result["result"]["kind"] == field_result["kind"] and lab_result["result"]["terminal_snapshot"]["stability"] == field_result["final_state"]["stability"], "The field and lab share identical six-element laws and thresholds")
	var before_replay: Array = [game.player_mana, game.research.to_data(), game.journal.to_data()]
	game.journal.replay(1, 2)
	game.journal.compare(1, 2, 2, 4)
	game.laboratory_panel.refresh()
	check(before_replay == [game.player_mana, game.research.to_data(), game.journal.to_data()], "Clue/discovery additions do not compromise read-only replay and comparison")
	check(game._begin_awakening("EARTH") == "ritual_started", "Player can attempt a main opposed to their innate element")
	enter_keys(game, sequence(game.chant_profile, "EARTH", true))
	game._cast_spell()
	var ui = game.laboratory_panel.awakening_panel
	check(ui.confirmation.visible and game.research.main_attribute == null and game.research.researched_base_elements.is_empty(), "Real ritual opens a permanent-choice dialog before any slot mutation")
	var stale: Dictionary = game.pending_awakening_offer.duplicate()
	ui.confirmation.canceled.emit()
	check(game.research.main_attribute == null and game.research.researched_base_elements.is_empty() and game.research.ritual_target.is_empty(), "Dialog cancellation clears ritual proof and leaves permanent data untouched")
	check(game._confirm_element_research("EARTH", stale["ticket"]) == "confirmation_required", "Main API rejects a cancelled confirmation even from the lab")
	game._begin_awakening("EARTH")
	enter_keys(game, sequence(game.chant_profile, "EARTH", true))
	game._cast_spell()
	ui.confirmation.hide()
	ui.confirmation.confirmed.emit()
	check(game.research.main_attribute == "EARTH" and game.research.researched_base_elements == PackedStringArray(["EARTH"]) and game.research.auxiliary_attributes.is_empty(), "Actual confirmation commits only the chosen main and one slot")
	check(game.chant_profile.to_data() == mapping and game.research.innate_affinity == original_affinity, "Awakening never rewrites personal key tables or innate talent")
	check(game._begin_awakening("FIRE") != "ritual_started" and game._confirm_element_research("FIRE", 999) == "confirmation_required" and game.research.main_attribute == "EARTH", "Auxiliary API cannot replace the main or bypass its ritual")
	var stored: Dictionary = Save.load_file(path)["data"]
	check(stored["research"]["main_attribute"] == "EARTH" and not stored["research"].has("researched_base_elements"), "One save transaction contains the role and derived-slot source with no duplicate list")
	write(RESTART, stored)
	write(DIR + "expected.json", stored)
	game.free()
	game = game_at(path)
	check(game.save_writable and game.research.main_attribute == "EARTH" and game.chant_profile.to_data() == mapping, "Reload preserves main/slots and exact personal mappings")
	game.free()

func _compatibility() -> void:
	var fixture := seeded_fixture(["WOOD", "FIRE", "EARTH"])
	var old_profile := Profile.new()
	old_profile.load_data(fixture["chant"])
	var old_log = preload("res://scripts/experiment_journal.gd").new()
	var old_result := Sim.simulate(old_profile, Helper.inputs(["Q", "E"]), true)
	old_log.append(old_result, "released", 15, 200, 1)
	fixture["laboratory"] = old_log.to_data()
	var path := DIR + "legacy_" + serial + ".json"
	write(path, fixture)
	var original := FileAccess.get_file_as_bytes(path)
	var game = game_at(path)
	check(game.save_writable and FileAccess.get_file_as_bytes(path + ".v2.bak") == original, "v2 original bytes are backed up before migration")
	check(game.research.main_attribute == null and game.research.legacy_committed_attributes == PackedStringArray(["WOOD", "FIRE", "EARTH"]), "Three existing elemental slots are preserved without guessed roles")
	var saved: Dictionary = Save.load_file(path)["data"]
	var preserved := true
	for key in fixture:
		if key not in ["schema_version", "research"] and not Helper.equal(saved[key], fixture[key]): preserved = false
	check(preserved and saved["research"]["old_field"] == "keep", "Migration preserves talents/seeds/maps/clues/journal/unknown values")
	game._enter_laboratory()
	check(game._begin_awakening("METAL") == "slots_full", "Legacy three-slot character cannot gain a fourth slot through awakening")
	for source in ["book", "mentor"]: game._collect_research_clue("FIRE", source)
	for repetition in range(2):
		enter_keys(game, sequence(game.chant_profile, "FIRE"))
		game._cast_spell()
	game._begin_awakening("FIRE")
	enter_keys(game, sequence(game.chant_profile, "FIRE", true))
	game._cast_spell()
	var ui = game.laboratory_panel.awakening_panel
	check(ui.confirmation.dialog_text.contains("이미 점유한 기존 슬롯"), "Legacy role designation is explicitly described before commitment")
	ui.confirmation.hide()
	ui.confirmation.confirmed.emit()
	check(game.research.main_attribute == "FIRE" and game.research.researched_base_elements.size() == 3 and game.research.researched_base_elements.has("WOOD") and game.research.researched_base_elements.has("EARTH"), "Explicit legacy promotion changes one role without freeing or duplicating any elemental slot")
	game.free()
	var corrupt := seeded_fixture()
	corrupt["schema_version"] = 3
	corrupt["research"] = {"main_attribute": "WOOD", "auxiliary_attributes": ["WOOD"], "legacy_committed_attributes": [], "innate_affinity": {}, "research_clues": [], "resonance_discoveries": {}}
	path = DIR + "invalid_" + serial + ".json"
	write(path, corrupt)
	original = FileAccess.get_file_as_bytes(path)
	game = game_at(path)
	check(not game.save_writable and FileAccess.get_file_as_bytes(path) == original, "Contradictory v3 roles are protected, never repaired by deleting choices")
	game.free()
	var orphan := seeded_fixture()
	orphan["schema_version"] = 3
	orphan["research"] = {"main_attribute": null, "auxiliary_attributes": [], "legacy_committed_attributes": [], "innate_affinity": {}, "research_clues": [], "resonance_discoveries": {"FIRE": {"stable_experiment_ids": [999]}}}
	path = DIR + "orphan_" + serial + ".json"
	write(path, orphan)
	original = FileAccess.get_file_as_bytes(path)
	game = game_at(path)
	check(not game.save_writable and FileAccess.get_file_as_bytes(path) == original, "Orphan stable evidence cannot unlock a ritual without a durable experiment record")
	game.free()

func _save_failure() -> void:
	var path := DIR + "failure_" + serial + ".json"
	write(path, seeded_fixture())
	var game = game_at(path)
	game._enter_laboratory()
	for source in ["book", "mentor"]: game._collect_research_clue("WATER", source)
	for repetition in range(2):
		enter_keys(game, sequence(game.chant_profile, "WATER"))
		game._cast_spell()
	game._begin_awakening("WATER")
	enter_keys(game, sequence(game.chant_profile, "WATER", true))
	game._cast_spell()
	var ticket: int = game.pending_awakening_offer["ticket"]
	var disk_before := FileAccess.get_file_as_bytes(path)
	game.save_path = DIR + "missing_" + serial + "/save.json"
	check(game._confirm_element_research("WATER", ticket) == "save_failed" and game.research.main_attribute == null and game.research.researched_base_elements.is_empty(), "Failed final write rolls back both main and slot, with no reusable ritual proof")
	check(FileAccess.get_file_as_bytes(path) == disk_before and game.research.awakening_state == "unawakened", "Write failure leaves previous durable character untouched")
	game.free()

func _restart() -> void:
	var expected: Dictionary = Save.load_file(DIR + "expected.json")["data"]
	var game = game_at(RESTART)
	check(game.research.main_attribute == "EARTH" and game.research.researched_base_elements == PackedStringArray(["EARTH"]), "Separate process restores chosen non-innate main and exactly one slot")
	check(Helper.equal(game.chant_profile.to_data(), expected["chant"]) and Helper.equal(game.journal.to_data(), expected["laboratory"]), "Separate process preserves exact old key tables and full experiment journal")
	check(Helper.equal(game.research.innate_affinity, expected["research"]["innate_affinity"]) and game.magic_talent == 67 and game.body_talent == 34, "Separate process retains original innate and magic/body talents")
	game._enter_laboratory()
	check(game._begin_awakening("FIRE") != "ritual_started" and game.research.main_attribute == "EARTH", "Main remains unchanged and auxiliary prerequisites persist after restart")
	check(game.research.stable_count("EARTH") >= 2 and game.research.has_clue("EARTH", "book") and game.research.has_clue("EARTH", "mentor"), "Stable evidence and both clue sources persist across restart")
	game.free()
