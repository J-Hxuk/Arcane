extends SceneTree
## Isolated fixtures only. Run again with -- --verify-restart in a new process.

const Game = preload("res://scripts/main.gd")
const Research = preload("res://scripts/character_research.gd")
const Save = preload("res://scripts/character_save.gd")
const Elements = preload("res://scripts/base_elements.gd")
const Spell = preload("res://scripts/spell_definition.gd")
const Book = preload("res://scripts/spell_book.gd")
const SCENE = preload("res://scenes/main.tscn")
const DIR := "res://.task002_artifacts/phase2a/"
const RESTART := DIR + "restart.json"
var checks := 0
var failures := 0
var serial := str(Time.get_ticks_usec())

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _fixture() -> Dictionary:
	return {"magic": 67, "body": 34, "bank": 234, "injury": 2, "armor": 61,
		"fixed_seed": 456789, "learned": ["EMBER", "MEND", "custom_spell"],
		"corpse": {"kind": "FIXED", "x": 196, "y": 204, "gold": 70, "extra": "keep"},
		"unknown_future_field": {"nested": [1, 2, "retain"]}}

func _json_equal(left: Variant, right: Variant) -> bool:
	# Godot JSON numbers load as floats; normalize both sides for deep equality.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value if value is String else JSON.stringify(value, "\t"))
	file.close()

func _game(path: String) -> Game:
	var game: Game = SCENE.instantiate()
	game.save_path = path
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	return game

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	if OS.get_cmdline_user_args().has("--verify-restart"):
		_verify_restart()
	else:
		_test_model()
		_test_requirements()
		_test_migration_and_ui()
		_test_new_character()
		_test_protection()
	print("RESEARCH TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_model() -> void:
	var model := Research.new()
	_check(Elements.DEFINITIONS.size() == 6, "Exactly six independent base resources")
	for element in Elements.DEFINITIONS:
		_check(str(Elements.DEFINITIONS[element].element_id) == element, "Stable resource ID: " + element)
	_check(model.main_attribute == null and model.researched_base_elements.is_empty(), "New research starts unawakened with zero slots")
	_check(model.load_data({"innate_affinity": {"FIRE": 91, "VOID": 12}}).is_empty() and model.researched_base_elements.is_empty(), "Innate affinity never consumes slots")
	var exposed := model.innate_affinity
	exposed["FIRE"] = 0
	_check(model.innate_affinity["FIRE"] == 91, "Affinity getter is detached")
	for source in ["book", "observation", "hint", "mentor"]:
		_check(model.acquire_clue("FIRE", source, source) == "recorded", "Independent clue source: " + source)
	_check(model.researched_base_elements.is_empty(), "Knowledge sources never occupy slots")
	_check(model.request_research("FIRE")["state"] == "awakening_required" and model.start_element_research("FIRE", 99) == "confirmation_required", "Old request cannot bypass the ritual")
	_check(model.start_element_research("LIGHTNING", 42) == "invalid_element", "Derived concept is not a base slot")
	_check(model.load_data({"researched_base_elements": ["WOOD", "WATER", "VOID"], "innate_affinity": model.innate_affinity}).is_empty(), "Three legacy choices load losslessly")
	_check(model.main_attribute == null and model.researched_base_elements.size() == 3, "Legacy roles are not guessed")
	var exposed_elements := model.researched_base_elements
	exposed_elements.append("FIRE")
	_check(model.researched_base_elements.size() == 3, "Research getter cannot bypass slot constraints")
	_check(model.request_research("FIRE")["state"] == "slots_full" and model.start_element_research("FIRE", 999) == "slots_full", "Fourth element rejected outside UI")
	_check(model.acquire_clue("FIRE", "observation", "after_lock") == "recorded" and model.researched_base_elements.size() == 3, "Knowledge remains available at the three-slot lock")
	var restored := Research.new()
	_check(restored.load_data(model.to_data()).is_empty() and restored.to_data() == model.to_data(), "Roles, affinity and clues round-trip")
	var before := model.to_data()
	_check(not model.load_data({"researched_base_elements": ["WOOD", "FIRE", "EARTH", "METAL"]}).is_empty() and model.to_data() == before, "Invalid load never truncates existing research")

func _test_requirements() -> void:
	var book := Book.new()
	var tokens: Array[String] = ["Q", "E"]
	_check(book.inspect(tokens)["state"] == "ready" and book.definitions[0].requires_elements.is_empty(), "Mana bolt works at zero research without VOID")
	var enhancement := Spell.new()
	enhancement.commands = PackedStringArray(["W"])
	enhancement.effect = &"enhancement" # Contract only; no gameplay effect introduced.
	book.definitions.append(enhancement)
	tokens = ["W"]
	_check(book.inspect(tokens)["state"] == "ready" and enhancement.requires_elements.is_empty(), "Attribute-independent enhancement needs no slot or VOID")
	enhancement.requires_elements = PackedStringArray(["WOOD", "WATER"])
	_check(book.inspect(tokens, PackedStringArray(["WOOD"]))["state"] == "locked", "Composite requires every constituent base element")
	_check(book.inspect(tokens, PackedStringArray(["WOOD", "WATER"]))["state"] == "ready", "Derived/composite access uses existing base slots")

func _test_migration_and_ui() -> void:
	var path := DIR + "legacy_" + serial + ".json"
	var original := _fixture()
	original["research"] = {"researched_base_elements": ["WOOD", "WATER", "VOID"], "innate_affinity": {}, "research_clues": [{"element": "FIRE", "source": "book", "id": "legacy_book"}], "extra": "keep"}
	_write(path, original)
	var original_bytes := FileAccess.get_file_as_bytes(path)
	var game := _game(path)
	_check(game.save_writable and game.magic_talent == 67 and game.body_talent == 34, "Legacy talents preserved without reroll")
	_check(game.research.innate_affinity.is_empty() and game.research.main_attribute == null and game.research.researched_base_elements.size() == 3, "Legacy affinity stays unrecorded and locked choices get no guessed main")
	_check(FileAccess.get_file_as_bytes(path + ".v0.bak") == original_bytes, "Migration backup preserves original bytes")
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var all_preserved := true
	for key in original:
		if key != "research" and not _json_equal(migrated[key], original[key]): all_preserved = false
	_check(all_preserved and migrated["research"]["extra"] == "keep" and migrated["schema_version"] == Save.SCHEMA_VERSION, "Existing values and unknown fields preserved in current schema")
	_check(game._confirm_element_research("FIRE") == "ritual_location_required", "Hub API cannot commit a research choice")
	var ui = game.research_panel
	ui.open()
	ui.request("FIRE")
	_check(not ui.confirmation.visible and ui.rows["FIRE"]["start"].disabled, "Old selection UI cannot bypass awakening")
	var chosen := game.research.to_data()
	ui.close()
	game._enter_dungeon("FIXED")
	_check(not ui.opener.visible and not ui.is_open(), "Research status UI does not overlay combat")
	game._die()
	_check(game.research.to_data() == chosen and ui.opener.visible, "Death retains permanent research and returns hub controls")
	game.free()
	game = _game(path)
	_check(game.research.to_data() == chosen and game.magic_talent == 67 and game.learned_spells.has("custom_spell"), "Reload preserves research, talents and discoveries")
	_test_researched_combat(game)
	var chant := game.chant_profile.to_data()
	game.free()
	var restart_data := original.duplicate(true)
	restart_data["schema_version"] = Save.SCHEMA_VERSION
	restart_data["research"] = chosen
	restart_data["research"]["innate_affinity"] = {"WOOD": 23, "VOID": 87, "legacy_note": "retain"}
	restart_data["research"]["unknown_research_field"] = {"keep": true}
	restart_data["chant"] = chant
	restart_data["laboratory"] = {"version": 1, "next_id": 1, "records": []}
	_write(RESTART, restart_data)
	game = _game(RESTART)
	_check(game._save_character(), "Restart fixture is written through the real save system")
	game.save_path = DIR + "nonexistent_" + serial + "/save.json"
	_check(not game._save_character() and game.research.main_attribute == null, "Save failure cannot invent a main attribute")
	game.free()

func _event(game: Game, code: Key, pressed: bool, now: float) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	game.combat_input.handle_event(event, now)

func _test_researched_combat(game: Game) -> void:
	var before := game.research.to_data()
	game._enter_dungeon("FIXED")
	game.enemies.clear()
	_event(game, KEY_SHIFT, true, 1.0)
	_event(game, KEY_D, true, 1.01)
	var origin := game.player_pos
	game._process(0.05)
	_check(game.player_pos.x > origin.x and game.runes.is_empty(), "Three researched slots: mobile WASD still moves only")
	_event(game, KEY_D, false, 1.02)
	_event(game, KEY_Q, true, 1.03)
	_event(game, KEY_Q, false, 1.04)
	_event(game, KEY_E, true, 1.05)
	_event(game, KEY_E, false, 1.06)
	game._cast_spell()
	_check(game.missiles.size() == 1 and game.runes.is_empty(), "Three researched slots: mobile mana bolt still releases")
	game._reset_combat_input()
	_event(game, KEY_SHIFT, true, 2.0)
	_event(game, KEY_SHIFT, false, 2.01)
	_event(game, KEY_SHIFT, true, 2.1)
	_event(game, KEY_SHIFT, false, 2.11)
	origin = game.player_pos
	_event(game, KEY_W, true, 2.12)
	_event(game, KEY_W, false, 2.13)
	game._process(0.05)
	_check(game.player_pos == origin and game.runes == ["W"], "Three researched slots: focus WASD is a command with zero movement")
	game._cancel_spell()
	_event(game, KEY_Q, true, 2.14)
	_event(game, KEY_Q, false, 2.15)
	_event(game, KEY_E, true, 2.16)
	_event(game, KEY_E, false, 2.17)
	game._cast_spell()
	_check(game.missiles.size() == 2, "Three researched slots: focus mana bolt still releases")
	_event(game, KEY_ALT, true, 2.18)
	game._process(0.01)
	_check(game.focus_active, "Three researched slots: Alt sense still activates independently")
	_event(game, KEY_ESCAPE, true, 2.19)
	_check(game.combat_input.mode == game.CombatInput.Mode.NORMAL, "Three researched slots: Esc still leaves focus")
	_check(game.research.to_data() == before, "Combat and attribute-independent casting never consume or alter research")
	# Test the real Main -> SpellBook requirements connection with a fixture only.
	var spell := Spell.new()
	spell.commands = PackedStringArray(["W"])
	spell.requires_elements = PackedStringArray(["WOOD", "WATER"])
	game.spell_book.definitions.append(spell)
	game.runes = ["W"]
	game._show_rune_feedback()
	_check(game.cast_feedback.contains("ready"), "Main passes committed elements to composite requirement evaluation")
	spell.requires_elements = PackedStringArray(["FIRE"])
	var count := game.missiles.size()
	game._cast_spell()
	_check(game.missiles.size() == count and game.cast_feedback.contains("Research required"), "Main rejects an unresearched spell even with direct non-UI cast request")
	game.spell_book.definitions.pop_back()

func _test_new_character() -> void:
	var path := DIR + "new_" + serial + ".json"
	var game := _game(path)
	var before := game.research.to_data()
	var magic := game.magic_talent
	var body := game.body_talent
	_check(game.research.innate_affinity.size() == 6 and game.research.researched_base_elements.is_empty(), "Only a new character gets six provisional innate scores and zero research")
	game.free()
	game = _game(path)
	_check(_json_equal(game.research.to_data(), before) and game.magic_talent == magic and game.body_talent == body, "Reload never regenerates new character talents or affinity")
	game.free()

func _test_protection() -> void:
	var cases: Array = ["{broken JSON", {"schema_version": 999}, {"research": null},
		{"research": {"researched_base_elements": ["FIRE", "FIRE"]}},
		{"research": {"researched_base_elements": ["WOOD", "FIRE", "EARTH", "METAL"]}},
		{"research": {"researched_base_elements": ["LIGHTNING"]}},
		{"schema_version": 1, "research": {}}, {"magic": "bad"}, {"schema_version": "bad"}]
	for index in range(cases.size()):
		var path := DIR + "protected_%s_%d.json" % [serial, index]
		_write(path, cases[index])
		var bytes := FileAccess.get_file_as_bytes(path)
		var game := _game(path)
		_check(not game.save_writable and not game._save_character() and game._confirm_element_research("FIRE") == "save_protected" and FileAccess.get_file_as_bytes(path) == bytes, "Invalid/future save stays byte-identical and read-only: %d" % index)
		game.free()
	var interrupted := DIR + "interrupted_" + serial + ".json"
	_write(interrupted + ".bak", _fixture())
	_check(Save.load_file(interrupted)["state"] == "error", "Interrupted save backup never triggers a fresh character reroll")

func _verify_restart() -> void:
	var game := _game(RESTART)
	_check(game.research.researched_base_elements == PackedStringArray(["WOOD", "WATER", "VOID"]), "Separate process restores all three permanent slots")
	_check(_json_equal(game.research.innate_affinity, {"WOOD": 23, "VOID": 87, "legacy_note": "retain"}), "Separate process restores affinity verbatim without reroll")
	_check(game.research.research_clues.size() == 1 and game.research.to_data()["unknown_research_field"] == {"keep": true}, "Separate process restores clues and unknown research fields")
	_check(game.magic_talent == 67 and game.body_talent == 34 and game.bank_gold == 234 and _json_equal(game.corpse, _fixture()["corpse"]) and game.learned_spells.has("EMBER"), "Separate process preserves original character and corpse")
	_check(game.research.start_element_research("FIRE", 123) == "slots_full" and game._save_character(), "Permanent lock remains enforced and saveable after restart")
	game.free()
