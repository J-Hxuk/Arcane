extends SceneTree
## Phase 2B-1 acceptance: pure laws + real Main save/lab/combat integration.
const Profile = preload("res://scripts/chant_profile.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Journal = preload("res://scripts/experiment_journal.gd")
const Game = preload("res://scripts/main.gd")
const Save = preload("res://scripts/character_save.gd")
const SCENE = preload("res://scenes/main.tscn")
const DIR := "res://.task002_artifacts/phase2b1/"
const RESTART := DIR + "restart_chant.json"
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

func equal(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fixture() -> Dictionary:
	return {"schema_version": 1, "magic": 62, "body": 39, "bank": 432, "injury": 1, "armor": 81,
		"fixed_seed": 8675309, "learned": ["EMBER", "MANA_BOLT"], "unknown": {"keep": [1, 2]},
		"corpse": {"kind": "FIXED", "gold": 41, "x": 196, "y": 204},
		"research": {"researched_base_elements": ["WOOD", "WATER", "VOID"],
			"innate_affinity": {"FIRE": 9, "WOOD": 83}, "research_clues": [{"book": "keep"}], "extra": true}}

func write(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func game_at(path: String) -> Game:
	var game: Game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	return game

static func key_for(profile: Profile, action: String) -> String:
	for key in Profile.MOBILE_KEYS:
		if profile.manipulation(key) == action: return key
	return "?"

static func first_for(profile: Profile, element: String) -> String:
	for key in Profile.ATTRIBUTE_KEYS:
		if profile.first_word(key) == element: return key
	return "?"

static func path_for(profile: Profile, actions: Array, first := "C") -> Array:
	var keys: Array = [first]
	for action in actions: keys.append(key_for(profile, action))
	return keys

static func inputs(keys: Array, hold_ms := 0) -> Array:
	var events: Array = []
	for index in range(keys.size()): events.append({"key": keys[index], "at_ms": index * 100, "hold_ms": hold_ms})
	return events

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	if OS.get_cmdline_user_args().has("--verify-restart"):
		_restart()
	else:
		_profile_and_simulator()
		_journal()
		_integration()
		_protection()
	print("CHANT TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _profile_and_simulator() -> void:
	var profile := Profile.new()
	var data := Profile.generate(12345)
	check(profile.load_data(data).is_empty(), "Generated two-table profile validates")
	check(data == Profile.generate(12345), "Same seed generates identical mappings")
	check(data != Profile.generate(98765), "Different seeds can produce different mappings")
	check(data["first_words"].size() == 6 and data["manipulations"].size() == 14 and profile.first_word("C").is_empty(), "Six attribute words, fourteen manipulations and reserved neutral C")
	var exported := profile.to_data()
	exported["first_words"]["Q"] = "LIGHTNING"
	check(profile.first_word("Q") != "LIGHTNING", "Mapping getter returns detached data")
	check(not profile.load_data(exported).is_empty() and profile.to_data() == data, "Invalid mapping cannot overwrite an established profile")
	var single := Sim.simulate(profile, inputs([first_for(profile, "FIRE")]))
	check(single["state"] == "incomplete" and single["kind"] == "none" and single["final_state"]["mana_amount"] == 0.0, "First attribute alone creates no completed phenomenon")
	var same_observation := true
	for first in Profile.ATTRIBUTE_KEYS + ["C"]:
		if Sim.simulate(profile, inputs([first]))["observation"] != single["observation"]: same_observation = false
	check(same_observation, "No first-key affinity or element signal is leaked")
	var path_a := path_for(profile, ["ACCUMULATE", "COMPRESS", "SHAPE", "DIRECT", "STABILIZE"])
	var path_b := path_for(profile, ["ACCUMULATE", "SHAPE", "COMPRESS", "DIRECT", "STABILIZE"])
	var a := Sim.simulate(profile, inputs(path_a))
	var b := Sim.simulate(profile, inputs(path_b))
	check(a["state"] == "ready" and a["kind"] == "mana_bolt" and a["final_state"]["base_attributes"].is_empty(), "Neutral structure makes a bolt without requiring VOID or a slot")
	check(a["final_state"] == b["final_state"] and a["kind"] == b["kind"] and path_a != path_b, "Different manipulation orders reach the same state and effect kind")
	check(a == Sim.simulate(profile, inputs(path_a)), "Identical profile and event sequence is deterministic")
	var longer := path_for(profile, ["ACCUMULATE", "ACCUMULATE", "DISSIPATE", "COMPRESS", "SHAPE", "DIRECT", "STABILIZE"])
	var expensive := Sim.simulate(profile, inputs(longer))
	check(expensive["kind"] == a["kind"] and expensive["mana_cost"] > a["mana_cost"], "Same effect may have a costlier path")
	var held := Sim.simulate(profile, inputs(path_a, 500))
	check(held["final_state"]["mana_amount"] > a["final_state"]["mana_amount"], "Recorded hold duration influences accumulation deterministically")
	var fire_word := first_for(profile, "FIRE")
	var fire := Sim.simulate(profile, inputs(path_for(profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], fire_word)))
	var unstable := Sim.simulate(profile, inputs(path_for(profile, ["ACCUMULATE", "COMPRESS", "RESONATE"], fire_word)))
	check(fire["state"] == "ready" and fire["kind"] == "fire_resonance", "Prototype FIRE resonance can be stabilized")
	check(unstable["state"] == "unstable" and unstable["kind"] == "unstable", "Unstable resonance gives distinct feedback")
	var failed := Sim.simulate(profile, inputs(path_for(profile, ["COMPRESS", "COMPRESS", "COMPRESS", "COMPRESS", "COMPRESS", "COMPRESS", "COMPRESS"], fire_word)))
	check(failed["state"] == "failed", "Excessive instability produces deterministic collapse")
	var other := Sim.simulate(profile, inputs(path_for(profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], first_for(profile, "WATER"))))
	check(other["state"] != "ready", "No six-element content expansion sneaks into the one-element prototype")
	var repeated := Sim.simulate(profile, inputs([fire_word, first_for(profile, "WATER")]))
	check(repeated["final_state"]["base_attributes"] == ["FIRE"], "Second attribute-shaped key is interpreted as a manipulation, not a new element")
	var legacy := Sim.simulate(profile, inputs(["Q", "E"]), true)
	check(legacy["kind"] == "mana_bolt" and legacy["mana_cost"] == 15.0, "Legacy QE adapter creates the neutral bolt structure at the old cost")
	check(Sim.simulate(profile, inputs(["W"]))["state"] == "failed", "Focus-only manipulation cannot be the first word")
	check(Sim.simulate(profile, inputs(["C", "LIGHTNING"]))["state"] == "failed", "Unknown token is rejected")
	var bad := inputs(path_a)
	bad[1]["at_ms"] = -1
	check(Sim.simulate(profile, bad)["state"] == "failed", "Invalid input time fails closed")
	bad = inputs(["Q", "E"])
	bad[1]["hold_ms"] = 60001
	check(Sim.simulate(profile, bad, true)["state"] == "failed", "Tutorial adapter cannot bypass malformed event validation")
	check(Sim.simulate(profile, ["bad event"])["state"] == "failed", "Malformed event is rejected without crashing")
	var many: Array = []
	for index in range(33): many.append({"key": "C", "at_ms": index, "hold_ms": 0})
	check(Sim.simulate(profile, many)["state"] == "failed", "Simulator enforces the input buffer limit outside UI")
	var forged: Dictionary = a["final_state"].duplicate(true)
	forged["base_attributes"] = ["WOOD", "FIRE", "WATER", "METAL"]
	check(Sim.classify(forged, 8)["state"] == "failed", "Final-state validator refuses a fourth constituent")
	forged["base_attributes"] = ["LIGHTNING"]
	check(Sim.classify(forged, 8)["state"] == "failed", "Derived concept cannot masquerade as a base element")
	var all_seeds := true
	for seed_value in range(1, 33):
		var p := Profile.new()
		if not p.load_data(Profile.generate(seed_value)).is_empty(): all_seeds = false
		var sequence := inputs(path_for(p, ["ACCUMULATE", "COMPRESS", "SHAPE", "DIRECT", "STABILIZE"]))
		if Sim.simulate(p, sequence)["kind"] != "mana_bolt" or Sim.simulate(p, sequence) != Sim.simulate(p, sequence): all_seeds = false
	check(all_seeds, "32 seeds retain complete mobile operations and deterministic bolt construction")

func _journal() -> void:
	var p := Profile.new()
	p.load_data(Profile.generate(71))
	var result := Sim.simulate(p, inputs(path_for(p, ["ACCUMULATE", "COMPRESS", "SHAPE", "DIRECT", "STABILIZE"])))
	var journal := Journal.new()
	var id_a := journal.append(result, "released", 16.0, 600, 1)
	var id_b := journal.append(result, "cancelled", 0.0, 600, 1)
	var before := journal.to_data()
	var replay := journal.replay(id_a, 1)
	var comparison := journal.compare(id_a, 1, id_b, 2)
	check(not replay.is_empty() and not comparison["right"].is_empty(), "Journal replays snapshots and compares two independently selected steps")
	check(journal.to_data() == before, "Replay and compare do not mutate stored state")
	replay["after"]["mana_amount"] = 999
	check(journal.to_data() == before, "Returned replay snapshots are detached")
	check(journal.replay(id_a, -1).is_empty() and journal.replay(999, 0).is_empty(), "Invalid replay selections are harmless")
	check(journal.records()[0]["result"]["terminal_snapshot"]["phase"] == "RELEASE" and journal.records()[1]["result"]["terminal_snapshot"]["phase"] == "CANCEL", "Release and cancel terminal states are recorded")
	check(journal.note(id_a, "내 가설") and not journal.note(id_a, "a".repeat(2001)), "Player notes are editable and length bounded")
	var restored := Journal.new()
	check(restored.load_data(JSON.parse_string(JSON.stringify(journal.to_data()))).is_empty() and equal(restored.to_data(), journal.to_data()), "Journal and notes survive JSON round-trip")
	var invalid := journal.to_data()
	invalid["records"][0]["steps"][0]["input"]["hold_ms"] = "bad"
	check(not restored.load_data(invalid).is_empty() and equal(restored.to_data(), journal.to_data()), "Malformed stored timing is rejected without replacing a valid journal")

func _integration() -> void:
	var path := DIR + "legacy_" + serial + ".json"
	var original := fixture()
	write(path, original)
	var bytes := FileAccess.get_file_as_bytes(path)
	var game := game_at(path)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var preserved := true
	for key in original:
		if key != "schema_version" and not equal(original[key], saved[key]): preserved = false
	check(preserved and saved["schema_version"] == 2 and FileAccess.get_file_as_bytes(path + ".v1.bak") == bytes, "Phase 2A migration preserves all prior values and original v1 bytes")
	var profile := game.chant_profile.to_data()
	check(not profile.is_empty() and game.journal.records().is_empty(), "Missing chant/journal fields are initialized once")
	var research := game.research.to_data()
	game._enter_laboratory()
	check(game.game_state == "LAB" and not game.research_panel.opener.visible and game.laboratory_panel.debug_window == null, "Lab opens separately; developer answers are absent by default")
	game.player_pos = game.EXIT_POS
	game.carried_gold = 17
	game._interact()
	game._melee_attack()
	check(game.game_state == "LAB" and game.carried_gold == 17 and game.player_attack_cooldown == 0.0, "Lab NORMAL F and LMB never trigger dungeon exit or sword side effects")
	var neutral := path_for(game.chant_profile, ["ACCUMULATE", "COMPRESS", "SHAPE", "DIRECT", "STABILIZE"])
	_enter_keys(game, neutral)
	var mana := game.player_mana
	game._cast_spell()
	check(game.player_mana == mana - 16.0 and game.journal.records().size() == 1 and game.missiles.size() == 1, "Lab personal bolt consumes actual mana, releases and auto-records")
	check(game.journal.records()[0]["steps"].size() == neutral.size() and game.journal.records()[0]["steps"][1]["input"]["hold_ms"] == 10, "Router captures real press ordering, elapsed time and release duration")
	var before := [game.player_mana, game.exhaustion_seconds, game.research.to_data(), game.missiles.duplicate(true), game.journal.to_data()]
	game.laboratory_panel.refresh()
	game.journal.replay(1, 2)
	game.journal.compare(1, 2, 1, 3)
	check(before == [game.player_mana, game.exhaustion_seconds, game.research.to_data(), game.missiles.duplicate(true), game.journal.to_data()], "Replay/UI comparison cannot consume mana, mutate research or fire projectiles")
	_enter_keys(game, ["C"])
	var live_before := [game.runes.duplicate(), game.chant_inputs.duplicate(true), game.journal.to_data(), game.player_mana]
	game.laboratory_panel.steppers[0].value = 2
	game.laboratory_panel.refresh()
	check(live_before == [game.runes.duplicate(), game.chant_inputs.duplicate(true), game.journal.to_data(), game.player_mana], "Replay while a new chant is in progress does not cancel or mutate it")
	game._clear_chant()
	game._save_experiment_note(1, "형상이 이어지는지 비교")
	check(game.journal.records()[0]["note"] == "형상이 이어지는지 비교", "Lab player note is saved")
	_enter_keys(game, [first_for(game.chant_profile, "FIRE")])
	check(not game.laboratory_panel.live.text.contains("FIRE") and game.journal.records().size() == 1, "Single word reveals no answer and does not prematurely finalize an experiment")
	game._cancel_spell()
	check(game.journal.records().size() == 2 and game.journal.records()[1]["result"]["outcome"] == "cancelled", "Cancel auto-records without committing an element")
	_enter_keys(game, ["C", key_for(game.chant_profile, "DISSIPATE")])
	mana = game.player_mana
	game._cast_spell()
	var lab_cost := mana - game.player_mana
	check(lab_cost == 2.0 and game.exhaustion_seconds == 1.0, "Failed lab experiment applies small cost and temporary exhaustion")
	game._cast_spell()
	check(game.player_mana == mana - lab_cost and game.journal.records()[-1]["result"]["outcome"] == "exhausted", "Exhaustion blocks repeated releases without repeated mana loss")
	game._laboratory_recover()
	check(game.player_mana == game._max_mana() and game.exhaustion_seconds == 0.0, "Lab gives explicit recovery access")
	game._cancel_spell()
	var fire := path_for(game.chant_profile, ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE"], first_for(game.chant_profile, "FIRE"))
	_enter_keys(game, fire)
	game._cast_spell()
	check(game.journal.records()[-1]["result"]["kind"] == "fire_resonance" and game.research.to_data() == research, "Even a successful unresearched FIRE experiment consumes no slot at the three-slot lock")
	game._leave_laboratory()
	game._enter_dungeon("FIXED")
	game.enemies.clear()
	_enter_keys(game, ["C", key_for(game.chant_profile, "DISSIPATE")])
	mana = game.player_mana
	game._cast_spell()
	check(mana - game.player_mana == lab_cost and game.exhaustion_seconds == 1.0, "Dungeon uses identical failure cost and exhaustion laws")
	game._reset_combat_input()
	game._process(1.0)
	_enter_keys(game, neutral)
	game._cast_spell()
	check(game.missiles.size() == 1 and game.research.to_data() == research, "Dungeon personal bolt uses the same final-state interpreter without changing slots")
	game._die()
	check(game.chant_profile.to_data() == profile and game.research.to_data() == research, "Death retains character mappings and permanent research")
	var lab_data := game.journal.to_data()
	game.free()
	game = game_at(path)
	check(equal(game.chant_profile.to_data(), profile) and equal(game.journal.to_data(), lab_data) and equal(game.research.to_data(), research), "New scene load retains mappings, records, notes and original research")
	var restart := fixture()
	restart["schema_version"] = 2
	restart["chant"] = profile
	restart["laboratory"] = lab_data
	write(RESTART, restart)
	write(DIR + "restart_expected.json", restart)
	game.free()
	var fresh := game_at(DIR + "new_" + serial + ".json")
	var highs := 0
	for score in fresh.research.innate_affinity.values():
		if score == 85: highs += 1
	check(highs == 1 and fresh.research.innate_affinity.size() == 6, "Only new characters get one hidden high affinity; old affinities were preserved")
	fresh.free()

func _enter_keys(game: Game, keys: Array) -> void:
	game._reset_combat_input()
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	game.combat_input.handle_event(shift, 1.0)
	for index in range(keys.size()):
		var event := InputEventKey.new()
		event.keycode = OS.find_keycode_from_string(keys[index])
		event.physical_keycode = event.keycode
		event.pressed = true
		game.combat_input.handle_event(event, 1.1 + index * 0.1)
		event.pressed = false
		game.combat_input.handle_event(event, 1.11 + index * 0.1)

func _protection() -> void:
	var bad_profile := Profile.generate(9)
	bad_profile["first_words"]["Q"] = "LIGHTNING"
	var cases := [{"chant": null}, {"chant": bad_profile}, {"chant": {"version": 99}},
		{"laboratory": {"version": 99}}, {"laboratory": {"records": [{"id": 1}]}},
		{"schema_version": 2}]
	for index in range(cases.size()):
		var data := fixture()
		data.merge(cases[index], true)
		var path := DIR + "protected_%s_%d.json" % [serial, index]
		write(path, data)
		var bytes := FileAccess.get_file_as_bytes(path)
		var game := game_at(path)
		check(not game.save_writable and not game._save_character() and bytes == FileAccess.get_file_as_bytes(path), "Invalid persisted mapping/journal is preserved without reroll: %d" % index)
		game.free()
	var path := DIR + "savefail_" + serial + ".json"
	write(path, fixture())
	var game := game_at(path)
	game._enter_laboratory()
	game.save_path = DIR + "missing_" + serial + "/character.json"
	_enter_keys(game, ["Q", "E"])
	game._cast_spell()
	check(game.journal.records().is_empty() and game.laboratory_panel.message.text.contains("실패"), "Journal save failure is visible and does not claim a durable record")
	game.free()

func _restart() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "restart_expected.json"))
	var game := game_at(RESTART)
	check(equal(game.chant_profile.to_data(), expected["chant"]), "Separate engine process preserves both stored mappings and seed/version")
	check(equal(game.journal.to_data(), expected["laboratory"]), "Separate engine process preserves every step and player note")
	check(equal(game.research.to_data(), expected["research"]) and game.magic_talent == 62 and game.body_talent == 39, "Separate engine process preserves Phase 2A talents and permanent slots")
	check(game._confirm_element_research("FIRE", 99) == "slots_full", "Three-slot rule remains enforced after v2 restart")
	var first := first_for(game.chant_profile, "FIRE")
	var result := Sim.simulate(game.chant_profile, inputs([first]))
	check(result["kind"] == "none" and result["observation"] == "뚜렷한 변화가 관찰되지 않습니다.", "First-word non-disclosure also holds after restart")
	game.free()
