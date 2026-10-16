extends SceneTree
const Model = preload("res://scripts/mana_visual_model.gd")
const Orb = preload("res://scripts/mana_orb_view.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Journal = preload("res://scripts/experiment_journal.gd")
const Helper = preload("res://tests/test_chant.gd")
const Fixture = preload("res://tests/test_elemental_combat.gd")
const SCENE = preload("res://scenes/main.tscn")
const DIR := "res://.task002_artifacts/mana_visuals/"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

static func base_state() -> Dictionary:
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	return Sim.simulate(profile, Helper.inputs(Helper.path_for(profile, ["ACCUMULATE", "COMPRESS", "STABILIZE"], Helper.first_for(profile, "FIRE"))))["final_state"]

static func states() -> Dictionary:
	var result := {"BASE": base_state()}
	for action in Profile.ACTIONS:
		var state := base_state()
		Sim._apply(state, action, 0, {})
		result[action] = state
	var unstable := base_state()
	unstable["stability"] = 38.0
	result["UNSTABLE"] = unstable
	var collapsed := unstable.duplicate(true)
	collapsed["phase"] = "FAILED"
	collapsed["stability"] = 20.0
	result["COLLAPSED"] = collapsed
	return result

static func archive() -> Dictionary:
	# Deliberately not reproducible from today's keys. Rendering must use these bytes.
	var initial := Sim.initial_state()
	var first := base_state()
	var mystery := first.duplicate(true)
	mystery.merge({"mana_amount": 37.0, "cohesion": 83.0, "form_integrity": 61.0, "flow_vector": [0.3, 0.2]}, true)
	var failed := mystery.duplicate(true)
	failed.merge({"phase": "FAILED", "stability": 20.0}, true)
	var steps: Array = []
	var before := initial
	for i in 3:
		var after: Dictionary = [first, mystery, failed][i]
		steps.append({"input": {"key": "ARCHIVED_UNKNOWN", "at_ms": [100, 800, 2400][i], "hold_ms": [100, 0, 800][i]},
			"before": before.duplicate(true), "after": after.duplicate(true),
			"before_observation": "당시 남긴 관찰", "observation": "이전 버전의 원문 관찰"})
		before = after
	var record := {"id": 1, "steps": steps, "rules_version": 1, "profile_version": 1, "note": "보존할 메모",
		"result": {"outcome": "failed", "kind": "legacy", "failure_step": 3, "energy_spent": 2.0,
			"elapsed_ms": 3200, "observation": "이전 버전 원문", "terminal_snapshot": failed}}
	var second := record.duplicate(true)
	second["id"] = 2
	second["steps"][1]["after"]["mana_amount"] = 15.0
	return {"version": 1, "next_id": 3, "records": [record, second]}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_projection()
	_failures()
	_replay()
	print("MANA VISUAL TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _projection() -> void:
	var samples := states()
	var projections: Array = []
	for action in Profile.ACTIONS:
		var projection := Model.project(samples[action])
		check(not projections.has(projection), "Distinct visible state for existing manipulation: " + action)
		projections.append(projection)
		check(Model.transition(samples["BASE"], samples[action])["visibility"] == "visible", "Perceptible change text agrees with actual projection: " + action)
	check(Model.project(samples["COMPRESS"])["radius"] < Model.project(samples["BASE"])["radius"] and Model.project(samples["COMPRESS"])["density"] > Model.project(samples["BASE"])["density"], "Compression decreases volume and increases particle density")
	check(Model.project(samples["STABILIZE"])["jitter"] < Model.project(samples["BASE"])["jitter"], "Stabilization visibly reduces vibration")
	check(Model.project(samples["UNSTABLE"])["lobes"] == 3 and Model.project(samples["COLLAPSED"])["collapsed"], "Unstable fragmentation and collapse have separate visual states")
	var orb := Orb.new()
	root.add_child(orb)
	orb.show_snapshot(samples["RESONATE"], 2.0)
	var points := orb.particle_points(2.0)
	check(points == orb.particle_points(2.0) and points != orb.particle_points(2.3), "Deterministic particles rotate and move without random rerolls")
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	var concealed := true
	for key in Profile.ATTRIBUTE_KEYS + ["C"]:
		var first := Sim.simulate(profile, Helper.inputs([key]))
		if Model.project(first["final_state"]) != Model.project(Sim.initial_state()): concealed = false
	check(concealed, "All six first words and pure C have identical neutral visuals, no element/affinity leak")
	var hidden := Sim.initial_state()
	Sim._apply(hidden, "COMPRESS", 0, {})
	check(Model.transition(Sim.initial_state(), hidden)["visibility"] == "subtle", "Invisible preparation is distinct internally from a true no-change")
	check(Model.transition(hidden, hidden)["visibility"] == "none", "Truly unchanged state is classified separately")
	check(not Sim.observe(hidden, 2).contains("좁아진"), "Observation never claims a visible compressed orb when no mana exists")
	var malformed := Model.project({"mana_amount": NAN, "cohesion": "bad", "resonance": null, "flow_vector": [INF, "bad"]})
	check(malformed["presence"] == 0.0 and malformed["flow"] == Vector2.ZERO, "Legacy/malformed optional visual fields fail safely without mutating saved data")
	orb.free()

func _failures() -> void:
	var profile := Profile.new()
	profile.load_data(Profile.generate(71))
	var invalid := Sim.simulate(profile, Helper.inputs(["?"]))
	check(invalid["failure_step"] == 1 and invalid["failure_kind"] == "input_error" and Model.failure_label(invalid).contains("1번째"), "First actual input error is one-based step 1")
	check(invalid["observation"].contains("무너지고"), "First input error is described as collapse instead of no observed change")
	var success := Sim.simulate(profile, Helper.inputs(["Q", "E"]), true)
	check(success["failure_step"] == 0 and Model.failure_label(success) == "실패 단계 없음", "Zero means no failure position, never the first input")
	var unfinished := Sim.simulate(profile, Helper.inputs(["C"]))
	check(Model.failure_label(unfinished).contains("미완성 판정"), "Incomplete ending is not mislabeled as a structural collapse")
	check(Model.failure_label({"failure_step": 3}).contains("당시 판정 위치"), "Legacy positive failure sentinel is reported without inventing a collapse cause")
	var journal := Journal.new()
	journal.append(unfinished, "cancelled", 0.0, 0, 1)
	check(Model.failure_label(journal.records()[0]["result"]) == "실패 단계 없음", "Cancellation keeps an explicit absence of failure")

func _replay() -> void:
	var path := DIR + "isolated.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(Fixture.fixture(null)))
	file.close()
	var game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._enter_laboratory()
	var ui = game.laboratory_panel
	var old := archive()
	check(game.journal.load_data(old).is_empty() and game.journal.to_data() == old, "Legacy snapshot journal loads byte-equivalent data without schema migration")
	ui.refresh()
	ui.selectors[0].select(0)
	ui._record_selected(0, 0)
	ui.selectors[1].select(1)
	ui._record_selected(1, 1)
	ui._seek(1600, 0)
	ui._seek(1600, 1)
	var step: Dictionary = old["records"][0]["steps"][1]
	check(ui.before_orbs[0].snapshot == step["before"] and ui.after_orbs[0].snapshot == step["after"], "Before/after cells use exact archived snapshots, including unknown old commands")
	check(ui.after_orbs[0].descriptor != ui.after_orbs[1].descriptor, "Two experiment selectors compare their own distinct archived structures")
	check(ui.views[0].text.contains("이전 버전의 원문 관찰"), "Historical observation text is retained alongside the visual comparison")
	var saved_state := [game.player_mana, game.research.to_data(), game.chant_profile.to_data(), game.journal.to_data(), game.missiles.duplicate(true), game.runes.duplicate(), FileAccess.get_sha256(path)]
	var empty_keys: Array[String] = []
	ui.show_live(empty_keys, "", game.player_mana, 0.0, step["after"])
	ui.live_orb.visual_time = 1.6
	check(ui.live_orb.descriptor == ui.after_orbs[0].descriptor and ui.live_orb.particle_points(1.6) == ui.after_orbs[0].particle_points(1.6), "Live and replay display identical state and particle geometry at the same visual time")
	ui.note.text = "아직 저장하지 않은 가설"
	ui._toggle_play(0)
	ui.advance_playback(0.9)
	check(ui.steppers[0].value == 3 and ui.after_orbs[0].snapshot == old["records"][0]["steps"][2]["after"], "Timeline respects uneven recorded timestamps rather than equal step intervals")
	check(ui.steppers[1].value == 2, "Independent right timeline stays on its selected step")
	check(ui.note.text == "아직 저장하지 않은 가설", "Playback preserves unsaved player notes")
	ui.advance_playback(10.0)
	check(not ui.playing[0] and ui.playheads[0] == 3200.0, "Playback stops at the saved duration including the last held input")
	ui.timelines[0].value = 200.0
	check(ui.steppers[0].value == 1 and not ui.playing[0], "Timeline scrubbing pauses and selects the stored step")
	check(saved_state == [game.player_mana, game.research.to_data(), game.chant_profile.to_data(), game.journal.to_data(), game.missiles.duplicate(true), game.runes.duplicate(), FileAccess.get_sha256(path)], "Play/pause/seek/compare do not cast, spend mana, alter research/journal/chant, or write a save")
	ui._seek(1600, 0)
	game.chant_profile.load_data(Profile.generate(98765))
	ui._render()
	ui._seek(1600, 0)
	check(ui.after_orbs[0].snapshot == step["after"], "Changing a test profile cannot reinterpret archived snapshot results")
	var description: String = ui.views[0].text
	check(not description.contains("cohesion") and not description.contains("ACCUMULATE") and not description.contains("innate") and not description.contains("37.0"), "Public replay text discloses neither numeric mana internals nor key semantics")
	ui._toggle_play(0)
	ui.close()
	check(not ui.playing[0] and not ui.playing[1], "Leaving the lab stops both visual replay transports")
	game.free()
