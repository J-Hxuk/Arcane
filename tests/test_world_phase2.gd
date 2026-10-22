extends "res://tests/test_world_phase1.gd"
const Progress = preload("res://scripts/world/world_progress.gd")
const H = preload("res://tests/test_chant.gd")
var path := ""
func fresh(document: Dictionary) -> void:
	if is_instance_valid(game): game.free()
	path = "res://.task002_artifacts/phase3a/p2_" + str(Time.get_ticks_usec()) + ".json"
	A.write(path, document)
	game = Scene.instantiate(); game.save_path = path; game.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(game)
func run() -> void:
	var fixture: Dictionary = F.fixture("WATER", 1787453028)
	fixture["schema_version"] = 4; fixture["external_future_field"] = {"untouched": 75}
	fresh(fixture)
	var original_research: Dictionary = game.research.to_data(); var original_chant: Dictionary = game.chant_profile.to_data()
	check(game.save_writable and game.world_progress.data["safe"]["region"] == "TOWN", "Existing v4 without world extension gets safe defaults")
	game.player_pos = Vector2(1000, 530); tap(KEY_E)
	check(game.world_dialog.visible, "Library is a physical building with an interaction modal")
	game._read_world_book("WATER")
	check(game.research.has_clue("WATER", "book") and Array(game.research.researched_base_elements) == ["WATER"], "Library links existing book clue IDs without adding a research slot")
	var clues: int = game.research.research_clues.size(); game._read_world_book("WATER")
	check(game.research.research_clues.size() == clues, "Repeated book reading does not duplicate clue or permanent choice")
	game.world_dialog.hide(); root.gui_release_focus()
	game.player_pos = game.layout.CHECKPOINT; game.player_hp = 33; game.player_mana = 12; tap(KEY_E)
	check(game.world_progress.safe_position() == game.layout.CHECKPOINT and game.player_hp == game._max_hp(), "Exterior checkpoint is recorded and restores resources")
	game.player_pos = Vector2(2790, 950); game.player_mana = 36; game._save_character()
	var saved: Dictionary = game.CharacterSave.load_file(path)["data"]
	check(saved["schema_version"] == 5 and H.equal(saved["external_future_field"], fixture["external_future_field"]) and H.equal(saved["chant"], fixture["chant"]), "Optional world v1 stays inside v4 and preserves unknown fields and personal key mapping")
	fresh(saved)
	check(game.player_pos == Vector2(2790, 950) and is_equal_approx(game.player_mana, 36) and game.world_progress.safe_position() == game.layout.CHECKPOINT, "Reload restores exterior region, position, checkpoint and mana")
	var doc: Dictionary = game._character_document()
	game.player_hp = 0; game._die()
	check(game.player_pos == game.layout.CHECKPOINT and game.game_state == "DUNGEON" and game.world_progress.data["deaths"] == 1 and game.player_hp == game._max_hp(), "Death returns living character to safe checkpoint without permanent deletion")
	check(game.chant_profile.to_data() == original_chant and game.research.has_clue("WATER", "book") and game.research.main_attribute == original_research["main_attribute"], "Death preserves selected element, clues, innate affinity and chant mapping")
	game.player_pos = game.layout.LAB_DOOR; game.player_mana = 27; game._enter_laboratory(); game._leave_laboratory()
	check(game.player_pos == game.layout.LAB_DOOR and is_equal_approx(game.player_mana, 27) and game.research.has_clue("WATER", "book"), "Lab entry/exit preserves mana, world position and research")
	var disk := FileAccess.get_file_as_bytes(path); var world: Dictionary = game.world_progress.to_data(); doc = game._character_document()
	check(game._start_developer_test("FIRE_WATER", "DUNGEON") and game._save_character() and game._end_developer_test(), "Legacy F2 fusion trial can still run and end")
	check(game._character_document() == doc and game.world_progress.to_data() == world and FileAccess.get_file_as_bytes(path) == disk, "F2 trial does not write world progress, user journal or disk")
	game.save_path = "res://.task002_artifacts/phase3a/missing_directory/reject.json"
	var before: Dictionary = game.world_progress.to_data(); var hp: float = game.player_hp
	check(not game._set_checkpoint("TOWN", game.layout.SPAWN) and game.world_progress.to_data() == before and game.player_hp == hp, "Checkpoint save failure rolls back progress and resource changes")
	var invalid: Dictionary = fixture.duplicate(true); invalid["world"] = {"position": ["wrong", 1]}
	fresh(invalid); var raw := FileAccess.get_file_as_bytes(path)
	check(not game.save_writable and FileAccess.get_file_as_bytes(path) == raw, "Malformed optional world data protects the original save instead of overwriting")
	var model := Progress.new()
	check(not model.load_data({"version": 2}).is_empty() and not model.load_data({"safe": {"region": "RUINS", "position": [3330, 900]}}).is_empty(), "Unknown progress version and unsafe checkpoint are rejected")
	print("WORLD PHASE2: %d checks, %d failures" % [checks, failures]); game.free(); quit(1 if failures else 0)
