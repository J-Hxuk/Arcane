extends SceneTree
## Run: Godot --headless --path . --script tests/test_combat.gd
## Synthetic InputEvents traverse the real router, main scene and spell effects.

const Game = preload("res://scripts/main.gd")
const CombatInput = preload("res://scripts/combat_input.gd")
const SpellDefinition = preload("res://scripts/spell_definition.gd")
const SCENE = preload("res://scenes/main.tscn")
const TEST_SAVE := "res://.task002_artifacts/test_character.json"

var game: Game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.task002_artifacts")
	var fixture := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"magic": 50, "body": 50, "fixed_seed": 12345,
		"bank": 100, "injury": 0, "armor": 100, "corpse": {}, "learned": ["EMBER"]}))
	fixture.close()
	game = SCENE.instantiate()
	game.legacy_wasd_enabled = true # Explicit developer comparison, not default controls.
	game.save_path = TEST_SAVE
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	_check(game.game_state == "HUB" and game.learned_spells.has("EMBER"), "Legacy save loads and preserves discoveries")
	game._enter_dungeon("FIXED")
	game.enemies.clear()
	_test_modes()
	_test_shift_boundaries()
	_test_casting()
	_test_routing_and_reset()
	_test_effects()
	_test_existing_loop()
	game.free()
	print("COMBAT TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _key(code: Key, pressed: bool, now: float, echo := false, location := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	event.location = location
	game.combat_input.handle_event(event, now)

func _tap(code: Key, now: float) -> void:
	_key(code, true, now)
	_key(code, false, now + 0.01)

func _mouse(button: MouseButton, now: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	game.combat_input.handle_event(event, now)
	event.pressed = false
	game.combat_input.handle_event(event, now + 0.01)

func _focus(now: float) -> void:
	_tap(KEY_SHIFT, now)
	_tap(KEY_SHIFT, now + 0.1)

func _test_modes() -> void:
	game._reset_combat_input()
	var origin := game.player_pos
	_key(KEY_W, true, 0.0)
	game._process(0.05)
	_check(game.player_pos.y < origin.y and game.runes.is_empty(), "NORMAL: WASD moves without entering commands")
	_key(KEY_SHIFT, true, 1.0)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Shift press immediately enters MOBILE_CAST")
	origin = game.player_pos
	game._process(0.05)
	_check(game.player_pos.y < origin.y and game.runes.is_empty(), "MOBILE_CAST: held WASD still only moves")
	_key(KEY_W, false, 1.1)
	_tap(KEY_Q, 1.15)
	_key(KEY_SHIFT, false, 1.2)
	_check(game.combat_input.mode == CombatInput.Mode.NORMAL and game.runes.is_empty(), "Shift release returns to NORMAL and clears unfinished commands")
	_focus(2.0)
	_check(game.combat_input.mode == CombatInput.Mode.FOCUS_CAST, "Fast Shift double tap enters persistent FOCUS_CAST")
	origin = game.player_pos
	_key(KEY_W, true, 2.2)
	_key(KEY_A, true, 2.21)
	_key(KEY_S, true, 2.22)
	_key(KEY_D, true, 2.23)
	game._process(0.2)
	_check(game.player_pos == origin and game.combat_input.movement_axis() == Vector2.ZERO, "FOCUS_CAST: exact zero displacement and movement axis")
	_check(game.runes == ["W", "A", "S", "D"], "FOCUS_CAST: each WASD press becomes a command")
	_focus(3.0)
	_check(game.combat_input.mode == CombatInput.Mode.NORMAL and game.runes.is_empty(), "Another Shift double tap exits FOCUS_CAST")
	game._reset_combat_input()
	_key(KEY_D, true, 4.0)
	_focus(4.1)
	origin = game.player_pos
	game._process(0.1)
	_check(game.player_pos == origin and game.runes.is_empty(), "Entering focus while moving stops held movement without inventing a command")
	game._reset_combat_input()

func _test_shift_boundaries() -> void:
	_tap(KEY_SHIFT, 10.0)
	_key(KEY_SHIFT, true, 10.301)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Second press after 0.3 seconds remains a hold")
	game._reset_combat_input()
	_tap(KEY_SHIFT, 11.0)
	_key(KEY_SHIFT, true, 11.3)
	_check(game.combat_input.mode == CombatInput.Mode.FOCUS_CAST, "Second press at the configured window enters focus")
	game._reset_combat_input()
	_key(KEY_SHIFT, true, 12.0)
	_key(KEY_SHIFT, false, 13.0)
	_key(KEY_SHIFT, true, 13.05)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Long hold followed by a fast repress is not a double tap")
	game._reset_combat_input()
	_key(KEY_SHIFT, true, 14.0)
	_key(KEY_SHIFT, true, 14.1, true)
	_key(KEY_SHIFT, true, 14.15)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Echo and duplicate presses cannot trigger focus")
	_tap(KEY_Q, 14.16)
	_key(KEY_SHIFT, false, 14.18)
	_key(KEY_SHIFT, true, 14.2)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Explicit command input disarms a pending double tap")
	game._reset_combat_input()
	game.combat_input.double_tap_window = 0.1
	_tap(KEY_SHIFT, 15.0)
	_key(KEY_SHIFT, true, 15.15)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Double-tap timing can be adjusted without input code changes")
	game.combat_input.double_tap_window = 0.3
	game._reset_combat_input()
	_key(KEY_SHIFT, true, 16.0, false, 1)
	_key(KEY_SHIFT, true, 16.05, false, 2)
	_key(KEY_SHIFT, false, 16.1, false, 1)
	_check(game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Overlapping left/right Shift presses remain one hold")
	_key(KEY_SHIFT, false, 16.15, false, 2)
	_check(game.combat_input.mode == CombatInput.Mode.NORMAL, "Releasing the final held Shift ends mobile casting")
	game._reset_combat_input()

func _test_casting() -> void:
	game.missiles.clear()
	game.player_attack_cooldown = 0.0
	_tap(KEY_Q, 20.0)
	_tap(KEY_E, 20.02)
	_mouse(MOUSE_BUTTON_LEFT, 20.04)
	_check(game.runes.is_empty() and game.missiles.is_empty() and game.player_attack_cooldown > 0.0, "NORMAL: Q/E do not cast, LMB still attacks with sword")
	_key(KEY_SHIFT, true, 21.0)
	var mana_before := game.player_mana
	_mouse(MOUSE_BUTTON_LEFT, 21.01)
	_check(game.cast_feedback.contains("Enter commands first") and game.player_mana == mana_before, "Empty cast reports missing commands without mana cost")
	_tap(KEY_Q, 21.02)
	_mouse(MOUSE_BUTTON_LEFT, 21.04)
	_check(game.cast_feedback.contains("Incomplete") and game.runes == ["Q"], "Incomplete formula retains entered commands for completion")
	_key(KEY_E, true, 21.06)
	_key(KEY_E, true, 21.07, true)
	_key(KEY_E, true, 21.08)
	_check(game.runes == ["Q", "E"] and game.missiles.is_empty(), "Holding a command adds one token and never auto-casts")
	_key(KEY_E, false, 21.09)
	_mouse(MOUSE_BUTTON_LEFT, 21.1)
	_check(game.missiles.size() == 1 and game.player_mana == mana_before - 15.0 and game.runes.is_empty(), "MOBILE_CAST: Q > E > LMB releases one mana bolt and consumes cost")
	_check(game.spell_book.definitions[0].requires_elements.is_empty(), "Basic mana bolt has zero element requirements and is not VOID")
	_check(game.learned_spells.has("MANA_BOLT") and game.learned_spells.has("EMBER"), "New discovery saves alongside legacy knowledge")
	_mouse(MOUSE_BUTTON_LEFT, 21.12)
	_check(game.missiles.size() == 1, "Repeated LMB requires fresh direct command input")
	_tap(KEY_Q, 21.14)
	_tap(KEY_E, 21.16)
	var debt_floor:float=-game.ManaOverdraw.limit(game._max_mana())
	game.player_mana = 0;game.mana_debt=-debt_floor
	_mouse(MOUSE_BUTTON_LEFT, 21.18)
	_check(game.missiles.size() == 1 and game.player_mana == 0 and game.mana_debt == -debt_floor and game.runes == ["Q", "E"] and game.cast_feedback.contains("마나 부족"), "Exceeding the mental overdraw limit preserves the formula and spawns no projectile")
	_tap(KEY_ESCAPE, 21.2)
	_check(game.runes.is_empty() and game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Esc clears mobile commands while Shift remains held")
	_tap(KEY_Q, 21.22)
	_tap(KEY_R, 21.24)
	_mouse(MOUSE_BUTTON_LEFT, 21.26)
	_check(game.cast_feedback.contains("command 2 (R)") and game.missiles.size() == 1, "Invalid formula identifies its first mismatched command")
	game._reset_combat_input()
	_focus(22.0)
	game.player_mana = game._max_mana()
	_tap(KEY_Q, 22.2)
	_tap(KEY_E, 22.22)
	_mouse(MOUSE_BUTTON_LEFT, 22.24)
	_check(game.missiles.size() == 2 and game.combat_input.mode == CombatInput.Mode.FOCUS_CAST and game.runes.is_empty(), "FOCUS_CAST: Q > E > LMB casts and remains in focus")
	_tap(KEY_ESCAPE, 22.3)
	_check(game.combat_input.mode == CombatInput.Mode.NORMAL and game.runes.is_empty(), "Esc cancels and leaves focus")
	game._reset_combat_input()
	# Check the data contract for future spells without introducing new gameplay.
	var composite := SpellDefinition.new()
	composite.display_name = "Test requirement"
	composite.commands = PackedStringArray(["W", "A"])
	composite.requires_elements = PackedStringArray(["FIRE", "WATER", "WOOD"])
	game.spell_book.definitions.append(composite)
	var tokens: Array[String] = ["W", "A"]
	_check(game.spell_book.inspect(tokens, PackedStringArray(["FIRE", "WATER"]))["state"] == "invalid_data", "Fixed-key composite formula is invalid under the binding grammar")
	_check(game.spell_book.inspect(tokens, composite.requires_elements)["state"] == "invalid_data", "Even all slots cannot authorize a fixed-key composite bypass")
	composite.requires_elements.append("EARTH")
	_check(game.spell_book.inspect(tokens, composite.requires_elements)["state"] == "invalid_data", "Spell data cannot bypass the fixed three-base-element limit")
	composite.requires_elements = PackedStringArray(["LIGHTNING"])
	_check(game.spell_book.inspect(tokens, composite.requires_elements)["state"] == "invalid_data", "Derived phenomena cannot become a seventh base element")
	game.spell_book.definitions.pop_back()

func _test_routing_and_reset() -> void:
	game.player_pos = game.EXIT_POS
	_key(KEY_SHIFT, true, 30.0)
	_tap(KEY_F, 30.1)
	_check(game.game_state == "DUNGEON" and game.runes == ["F"], "F in casting mode enters a token instead of leaving the dungeon")
	for index in range(40):
		_tap(KEY_Q, 31.0 + float(index) * 0.02)
	_check(game.runes.size() == 32 and game.cast_feedback.contains("buffer full"), "Long command input is bounded with visible overflow feedback")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.combat_input.mode == CombatInput.Mode.NORMAL and game.runes.is_empty() and game.combat_input.movement_axis() == Vector2.ZERO, "Application focus loss clears held inputs, mode and command buffer")
	_tap(KEY_E, 33.0)
	_check(game.game_state == "HUB", "E in NORMAL returns through the gate")
	game._enter_dungeon("FIXED")
	game.enemies.clear()
	_key(KEY_SHIFT, true, 34.0)
	game._process(0.01)
	_check(not game.focus_active, "Shift casting does not activate swift sense")
	_key(KEY_ALT, true, 34.1)
	game._process(0.01)
	_check(game.focus_active and game.combat_input.mode == CombatInput.Mode.MOBILE_CAST, "Alt activates existing swift sense independently of casting")
	game._reset_combat_input()
	_focus(35.0)
	_mouse(MOUSE_BUTTON_RIGHT, 35.2)
	_check(game.combat_input.mode == CombatInput.Mode.FOCUS_CAST and not game.navigation.active, "RMB is ignored in focus; Esc is the cancel input")
	_tap(KEY_ESCAPE, 35.3)

func _test_effects() -> void:
	game.missiles.clear()
	game.enemies.clear()
	game.player_pos = game.START_POS
	game.missiles.append({"pos": game.player_pos, "dir": Vector2.RIGHT, "hostile": false, "life": 1.8, "dmg": 35.0, "speed": 460.0})
	game.enemies.append({"pos": game.player_pos + Vector2(23.0, 0.0), "hp": 42.0, "shot": 10.0})
	game._update_missiles(0.05, 1.0)
	_check(game.missiles.is_empty() and game.enemies[0]["hp"] == 7.0, "Mana bolt collision applies damage and removes the projectile")
	game.enemies.clear()
	var wall_center: Vector2 = game._cell_rect(Vector2i(0, 0)).get_center()
	game.missiles.append({"pos": wall_center, "dir": Vector2.ZERO, "hostile": false, "life": 1.8, "dmg": 35.0})
	game._update_missiles(0.01, 1.0)
	_check(game.missiles.is_empty(), "Projectile expires against dungeon walls")

func _test_existing_loop() -> void:
	var previous_walls := game.walls.duplicate()
	var previous_seed := game.map_seed
	var previous_magic := game.magic_talent
	var previous_body := game.body_talent
	game.player_pos = game.START_POS
	game.carried_gold = 100
	_focus(40.0)
	_tap(KEY_W, 40.2)
	game._die()
	_check(game.game_state == "HUB" and game.combat_input.mode == CombatInput.Mode.NORMAL and game.runes.is_empty(), "Death resets focus and pending commands")
	_check(game.corpse["gold"] == 70 and game.injury_stacks == 1 and game.armor_durability == 85, "Existing death penalties and recoverable gold are preserved")
	game._enter_dungeon("FIXED")
	_check(game.map_seed == previous_seed and game.walls == previous_walls and game.corpse_pos == game.START_POS, "Fixed dungeon retains map and corpse position")
	game._interact()
	_check(game.corpse.is_empty() and game.carried_gold == 70, "Existing corpse interaction recovers gold")
	game.player_pos = game.EXIT_POS
	game._interact()
	game._heal_injuries()
	_check(game.injury_stacks == 0 and game.bank_gold == 155, "Banking expedition gold and healing still work")
	game._enter_dungeon("SHIFTING")
	previous_seed = game.map_seed
	game.carried_gold = 10
	game._die()
	game._enter_dungeon("SHIFTING")
	_check(game.map_seed != previous_seed and game.corpse_pos != Vector2.ZERO and not game._is_blocked(game.corpse_pos), "Shifting dungeon reseeds and relocates the corpse to an open point")
	game._save_character()
	var restored: Game = SCENE.instantiate()
	restored.save_path = TEST_SAVE
	restored.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(restored)
	_check(restored.magic_talent == previous_magic and restored.body_talent == previous_body and restored.learned_spells.has("MANA_BOLT") and restored.learned_spells.has("EMBER") and not restored.corpse.is_empty(), "Reload preserves talents, discoveries and death recovery data")
	restored.free()
