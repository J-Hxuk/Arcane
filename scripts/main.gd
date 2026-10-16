extends Node2D
## Arcane Legacy: minimal top-down action / research / death-loop prototype.
## Made with drawn primitives so no art assets are required.

const SAVE_PATH := "user://arcane_legacy_save.json"
const AREA := Rect2(96.0, 104.0, 800.0, 480.0)
const TILE := 40.0
const COLS := 20
const ROWS := 12
const START_POS := Vector2(196.0, 204.0)
const EXIT_POS := Vector2(796.0, 484.0)
const PLAYER_SPEED := 200.0
const ENEMY_SPEED := 85.0
const CombatInput = preload("res://scripts/combat_input.gd")
const SpellBook = preload("res://scripts/spell_book.gd")
const SpellDefinition = preload("res://scripts/spell_definition.gd")
const CharacterResearch = preload("res://scripts/character_research.gd")
const CharacterSave = preload("res://scripts/character_save.gd")
const ResearchPanel = preload("res://scripts/research_panel.gd")
const ChantProfile = preload("res://scripts/chant_profile.gd")
const ManaSimulator = preload("res://scripts/mana_simulator.gd")
const ExperimentJournal = preload("res://scripts/experiment_journal.gd")
const LaboratoryPanel = preload("res://scripts/laboratory_panel.gd")
const CombatSpellResolver = preload("res://scripts/combat_spell_resolver.gd")
const ElementalCombat = preload("res://scripts/elemental_combat.gd")
const SpellDiscoveries = preload("res://scripts/spell_discoveries.gd")
const SpellRecordHud = preload("res://scripts/spell_record_hud.gd")

@export_range(0.1, 0.6, 0.01) var shift_double_tap_window := 0.3
var combat_input := CombatInput.new()
var spell_book := SpellBook.new()
# Override before _ready() in tests to avoid touching the player's real save.
var save_path := SAVE_PATH
var research := CharacterResearch.new()
var research_panel: ResearchPanel
var save_writable := true
var save_error := ""
var _save_document: Dictionary = {}
var chant_profile := ChantProfile.new()
var journal := ExperimentJournal.new()
var laboratory_panel: LaboratoryPanel
var chant_inputs: Array = []
var chant_started_ms := 0
var exhaustion_seconds := 0.0
var last_laboratory_result: Dictionary = {}
var pending_awakening_offer: Dictionary = {}
var elemental_combat := ElementalCombat.new()
var discovered := SpellDiscoveries.new()
var spell_record_hud: SpellRecordHud

var rng := RandomNumberGenerator.new()
var dungeon_rng := RandomNumberGenerator.new()
var game_state := "HUB"
var dungeon_kind := "FIXED"
var fixed_seed := 0
var map_seed := 0
var walls: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var player_pos := START_POS
var player_hp := 100.0
var player_mana := 100.0
var focus := 100.0
var focus_active := false
var player_attack_cooldown := 0.0
var runes: Array[String] = []
var cast_feedback := "Hold Shift or double-tap Shift. Q > E > LMB: Mana Bolt."
var status_message := ""
var status_time := 0.0
var carried_gold := 0
var bank_gold := 100
var injury_stacks := 0
var armor_durability := 100
var magic_talent := 50
var body_talent := 50
var learned_spells: Array[String] = []
var corpse: Dictionary = {}
var corpse_pos := Vector2.ZERO

func _ready() -> void:
	combat_input.double_tap_window = shift_double_tap_window
	combat_input.mode_changed.connect(_on_combat_mode_changed)
	combat_input.command_entered.connect(_on_command_entered)
	combat_input.attack_requested.connect(_melee_attack)
	combat_input.cast_requested.connect(_cast_spell)
	combat_input.cancel_requested.connect(_cancel_spell)
	combat_input.interact_requested.connect(_interact)
	rng.randomize()
	_load_or_create_character()
	research_panel = ResearchPanel.new()
	add_child(research_panel)
	research_panel.setup(research)
	research_panel.writable = save_writable
	research_panel.commit_requested.connect(_confirm_element_research)
	research_panel.clue_requested.connect(_acquire_debug_clue)
	research_panel.laboratory_requested.connect(_enter_laboratory)
	research_panel.refresh()
	laboratory_panel = LaboratoryPanel.new()
	add_child(laboratory_panel)
	laboratory_panel.setup(journal, chant_profile)
	laboratory_panel.setup_awakening(research)
	laboratory_panel.awakening_panel.clue_requested.connect(_collect_research_clue)
	laboratory_panel.awakening_panel.ritual_requested.connect(_begin_awakening)
	laboratory_panel.awakening_panel.ritual_cancelled.connect(_cancel_awakening)
	laboratory_panel.awakening_panel.confirmation_requested.connect(_confirm_element_research)
	laboratory_panel.release_requested.connect(_cast_spell)
	laboratory_panel.exit_requested.connect(_leave_laboratory)
	laboratory_panel.recover_requested.connect(_laboratory_recover)
	laboratory_panel.note_requested.connect(_save_experiment_note)
	combat_input.command_released.connect(_on_command_released)
	spell_record_hud = SpellRecordHud.new()
	add_child(spell_record_hud)
	spell_record_hud.setup(discovered, research_panel.opener.theme)
	spell_record_hud.preference_changed.connect(_change_spell_preference)
	status_message = "Choose a dungeon: [1] Ruins (fixed)  [2] Flux Maze (shifting)" if save_error.is_empty() else save_error
	status_time = 6.0
	queue_redraw()

func _max_hp() -> float:
	return 100.0 * (1.0 - 0.12 * float(injury_stacks))

func _max_mana() -> float:
	return (45.0 + float(magic_talent) * 1.1) * (1.0 - 0.10 * float(injury_stacks))

func _load_or_create_character() -> void:
	var loaded := CharacterSave.load_file(save_path)
	if loaded["state"] == "error":
		_protect_save(loaded["message"])
		return
	if loaded["state"] == "loaded":
		var parsed: Dictionary = loaded["data"]
		_save_document = parsed.duplicate(true)
		# Validate before assigning gameplay fields; never reroll an existing file.
		for field in ["magic", "body", "bank", "injury", "armor", "fixed_seed"]:
			var value = parsed.get(field, 0)
			if not (value is int or value is float):
				_protect_save("Invalid character field: " + field)
				return
		if not parsed.get("corpse", {}) is Dictionary or not parsed.get("learned", []) is Array:
			_protect_save("Invalid character knowledge / corpse data.")
			return
		magic_talent = int(parsed.get("magic", 50))
		body_talent = int(parsed.get("body", 50))
		bank_gold = int(parsed.get("bank", 100))
		injury_stacks = clampi(int(parsed.get("injury", 0)), 0, 3)
		armor_durability = int(parsed.get("armor", 100))
		fixed_seed = int(parsed.get("fixed_seed", 12345))
		corpse = parsed.get("corpse", {}).duplicate(true)
		learned_spells.clear()
		for name in parsed.get("learned", []):
			learned_spells.append(str(name))
		player_hp = _max_hp()
		player_mana = _max_mana()
		var research_data = parsed.get("research", {})
		if not research_data is Dictionary or (loaded["version"] >= 1 and not parsed.has("research")):
			_protect_save("Invalid research save data. Original preserved.")
			return
		if loaded["version"] >= 1:
			var required := ["innate_affinity", "research_clues", "researched_base_elements"] if loaded["version"] < 3 else ["main_attribute", "auxiliary_attributes", "legacy_committed_attributes", "innate_affinity", "research_clues", "resonance_discoveries"]
			for field in required:
				if not research_data.has(field):
					_protect_save("Incomplete research save data. Original preserved.")
					return
		var error := research.load_data(research_data)
		if not error.is_empty():
			_protect_save(error)
			return
		if loaded["version"] >= 2 and (not parsed.has("chant") or not parsed.has("laboratory")):
			_protect_save("Incomplete chant / laboratory save. Original preserved.")
			return
		var chant_data = parsed["chant"] if parsed.has("chant") else ChantProfile.generate(rng.randi_range(1, 2147483647))
		var lab_data = parsed.get("laboratory", {})
		if not chant_data is Dictionary or not lab_data is Dictionary:
			_protect_save("Invalid chant / laboratory save. Original preserved.")
			return
		error = chant_profile.load_data(chant_data)
		if error.is_empty(): error = journal.load_data(lab_data)
		if error.is_empty(): error = research.validate_evidence(journal.records())
		var discovery_data = parsed.get("spell_discoveries", {})
		if error.is_empty():
			if not discovery_data is Dictionary: error = "Invalid spell discoveries."
			else: error = discovered.load_data(discovery_data)
		if not error.is_empty():
			_protect_save(error)
			return
		if not parsed.has("spell_discoveries"): discovered.import_journal(journal.records())
		if loaded["migrate"]:
			if CharacterSave.backup_legacy(save_path, loaded["version"]) != OK:
				_protect_save("Legacy backup failed. Original preserved.")
				return
			_save_character()
		return
	var total := rng.randi_range(95, 105)
	magic_talent = rng.randi_range(15, total - 15)
	body_talent = total - magic_talent
	fixed_seed = rng.randi_range(1000, 9999999)
	# Only genuinely new characters receive affinity. These are provisional scores,
	# independent of magic/body talent and with no gameplay multiplier in Phase 2A.
	var affinity: Dictionary = {}
	var high_element: String = ChantProfile.ELEMENTS[rng.randi_range(0, 5)]
	for element in CharacterResearch.BaseElements.DEFINITIONS:
		affinity[element] = 85 if element == high_element else 25
	research.load_data({"innate_affinity": affinity})
	chant_profile.load_data(ChantProfile.generate(rng.randi_range(1, 2147483647)))
	player_hp = _max_hp()
	player_mana = _max_mana()
	_save_character()

func _protect_save(reason: String) -> void:
	save_writable = false
	save_error = reason
	_message(reason)

func _save_character() -> bool:
	if not save_writable: return false
	var save := _save_document.duplicate(true)
	save.merge({
		"schema_version": CharacterSave.SCHEMA_VERSION,
		"magic": magic_talent,
		"body": body_talent,
		"bank": bank_gold,
		"injury": injury_stacks,
		"armor": armor_durability,
		"fixed_seed": fixed_seed,
		"corpse": corpse,
		"learned": learned_spells,
		"research": research.to_data(),
		"chant": chant_profile.to_data(),
		"laboratory": journal.to_data(),
		"spell_discoveries": discovered.to_data()
	}, true)
	var error := CharacterSave.write_file(save_path, save)
	if error != OK:
		save_error = "Save failed: " + error_string(error)
		_message(save_error)
		return false
	_save_document = save
	save_error = ""
	return true

func _confirm_element_research(element: String, ticket: int = 0) -> String:
	if not save_writable: return "save_protected"
	if game_state != "LAB": return "ritual_location_required"
	var previous := research.to_data()
	var result := research.start_element_research(element, ticket)
	if result == "committed" and not _save_character():
		research.load_data(previous) # No permanent choice unless it reached disk.
		result = "save_failed"
	if research_panel != null:
		research_panel.feedback.text = "연구 영구 확정 완료: " + element if result == "committed" else "연구 요청: " + result
		research_panel.refresh()
	if laboratory_panel != null:
		laboratory_panel.message.text = "주속성 영구 확정 완료: " + CharacterResearch.BaseElements.DEFINITIONS[element].display_name if result == "committed" else laboratory_panel.awakening_panel.reason(result)
		laboratory_panel.awakening_panel.refresh()
	pending_awakening_offer = {}
	_reset_combat_input()
	return result

func _collect_research_clue(element: String, source: String) -> void:
	if game_state != "LAB" or not save_writable or source not in ["book", "mentor"]: return
	var previous := research.to_data()
	var result := research.acquire_clue(element, source, CharacterResearch.Rules.clue_id(element, source))
	if result == "recorded" and not _save_character():
		research.load_data(previous)
		laboratory_panel.message.text = "단서 저장 실패: " + save_error
	laboratory_panel.awakening_panel.refresh()
	_update_laboratory_live()

func _begin_awakening(element: String) -> String:
	if game_state != "LAB" or not save_writable: return "ritual_location_required"
	_reset_combat_input()
	pending_awakening_offer = {}
	var result := research.begin_ritual(element)
	laboratory_panel.message.text = "의식 진행: 직접 영창으로 목표의 안정 공명·형상·방향을 완성하세요." if result == "ritual_started" else laboratory_panel.awakening_panel.reason(result)
	if result == "ritual_started": laboratory_panel.awakening_panel.close()
	laboratory_panel.awakening_panel.refresh()
	_update_laboratory_live()
	return result

func _cancel_awakening() -> void:
	_reset_combat_input()
	research.cancel_request()
	pending_awakening_offer = {}
	laboratory_panel.awakening_panel.cancel_confirmation()
	laboratory_panel.awakening_panel.refresh()
	laboratory_panel.message.text = "의식/확인을 취소했습니다. 주속성과 영구 슬롯은 바뀌지 않았습니다. 다른 대상을 계속 탐구할 수 있습니다."
	_update_laboratory_live()

func _finish_awakening_offer() -> void:
	if pending_awakening_offer.is_empty() or research.awakening_state != "confirmation_pending": return
	laboratory_panel.awakening_panel.offer(pending_awakening_offer)

func _acquire_debug_clue(element: String) -> void:
	if not save_writable: return
	var previous := research.to_data()
	var result := research.acquire_clue(element, "book", "debug_book_" + element)
	if result == "recorded" and not _save_character():
		research.load_data(previous)
		result = "save_failed"
	research_panel.feedback.text = "열람 / 단서: %s · 슬롯 소모 없음 · 기록 %d개" % [result, research.research_clues.size()]
	research_panel.refresh()

func _input(event: InputEvent) -> void:
	if game_state == "DUNGEON" and spell_record_hud != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
			spell_record_hud.toggle()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and spell_record_hud.owns_pointer(event.position): return
	if game_state == "LAB":
		if laboratory_panel.awakening_panel.confirmation.visible: return
		if laboratory_panel.awakening_panel.visible:
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				laboratory_panel.awakening_panel.close()
			return
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_RIGHT: return
		if laboratory_panel.is_editing():
			# Text/replay controls must never synthesize a cast or cancel a live one.
			if event is InputEventKey and not event.pressed:
				combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)
			return
		# GUI buttons own LMB in the lab; no click-through cast while browsing logs.
		combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)
		return
	if game_state == "HUB" and research_panel != null:
		if research_panel.confirmation.visible: return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_B:
				if research_panel.is_open(): research_panel.close()
				else: research_panel.open()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ESCAPE and research_panel.is_open():
				research_panel.close()
				get_viewport().set_input_as_handled()
				return
		if research_panel.is_open(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if game_state == "HUB":
			if event.keycode == KEY_1:
				_enter_dungeon("FIXED")
			elif event.keycode == KEY_2:
				_enter_dungeon("SHIFTING")
			elif event.keycode == KEY_H:
				_heal_injuries()
			elif event.keycode == KEY_L:
				_enter_laboratory()
	if game_state == "DUNGEON":
		combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_reset_combat_input()

func _reset_combat_input() -> void:
	if game_state == "LAB" and not runes.is_empty(): _record_cancelled_experiment()
	combat_input.reset()
	_clear_chant()
	focus_active = false
	cast_feedback = "Q > E > LMB: Mana Bolt (no element research needed)."
	_update_laboratory_live()

func _on_combat_mode_changed(_previous: CombatInput.Mode, current: CombatInput.Mode) -> void:
	# A single Shift release discards its short mobile-casting attempt.
	# A switch between casting modes otherwise keeps the explicit command queue.
	if current == CombatInput.Mode.NORMAL:
		if game_state == "LAB" and not runes.is_empty(): _record_cancelled_experiment()
		_clear_chant()
		cast_feedback = "Q > E > LMB: Mana Bolt (hold Shift or double-tap Shift)."
	_update_laboratory_live()

func _on_command_entered(token: String) -> void:
	if runes.size() >= spell_book.max_commands:
		cast_feedback = "Command buffer full. RMB / Esc to clear."
		return
	runes.append(token)
	if game_state == "LAB" and runes.size() == 1: laboratory_panel.begin_attempt()
	var now_ms := roundi(combat_input.last_command_time * 1000.0)
	if chant_inputs.is_empty(): chant_started_ms = now_ms
	chant_inputs.append({"key": token, "at_ms": clampi(now_ms - chant_started_ms, 0, 60000), "hold_ms": 0,
		"started_ms": now_ms, "released": false})
	_show_rune_feedback()
	_update_laboratory_live()

func _on_command_released(token: String, held_ms: int) -> void:
	for index in range(chant_inputs.size() - 1, -1, -1):
		if chant_inputs[index]["key"] == token and not chant_inputs[index]["released"]:
			chant_inputs[index]["hold_ms"] = mini(held_ms, 60000)
			chant_inputs[index]["released"] = true
			_show_rune_feedback()
			_update_laboratory_live()
			return

func _clear_chant() -> void:
	runes.clear()
	chant_inputs.clear()

func _simulation_inputs(finalize_holds := false) -> Array:
	var inputs: Array = []
	for index in range(runes.size()):
		var event := {"key": runes[index], "at_ms": index * 100, "hold_ms": 0}
		if index < chant_inputs.size() and chant_inputs[index]["key"] == runes[index]:
			var stored: Dictionary = chant_inputs[index]
			event = {"key": stored["key"], "at_ms": stored["at_ms"], "hold_ms": stored["hold_ms"]}
			if finalize_holds and not stored["released"]:
				event["hold_ms"] = clampi(Time.get_ticks_msec() - stored["started_ms"], 0, 60000)
		inputs.append(event)
	return inputs

func _cancel_spell() -> void:
	if game_state == "LAB" and not runes.is_empty(): _record_cancelled_experiment()
	_clear_chant()
	if game_state == "LAB" and not research.ritual_target.is_empty():
		research.cancel_request()
		pending_awakening_offer = {}
	cast_feedback = "Cast cancelled. Enter Q > E again for Mana Bolt."
	_update_laboratory_live()

func _process(delta: float) -> void:
	if spell_record_hud != null:
		spell_record_hud.visible = game_state == "DUNGEON"
		spell_record_hud.update_current(runes, cast_feedback)
	exhaustion_seconds = maxf(0.0, exhaustion_seconds - delta)
	if status_time > 0.0:
		status_time -= delta
	if game_state == "LAB":
		player_mana = minf(_max_mana(), player_mana + 8.0 * delta)
		_update_laboratory_live()
	if game_state == "DUNGEON":
		var axis := combat_input.movement_axis()
		if axis != Vector2.ZERO:
			axis = axis.normalized()
			_try_move_player(axis * PLAYER_SPEED * delta)
		player_attack_cooldown = maxf(0.0, player_attack_cooldown - delta)
		player_mana = minf(_max_mana(), player_mana + 3.0 * delta)
		focus_active = combat_input.swift_sense_held and focus > 0.0
		if focus_active:
			focus = maxf(0.0, focus - 32.0 * delta)
		else:
			focus = minf(100.0, focus + 14.0 * delta)
		var enemy_time := 0.35 if focus_active else 1.0
		elemental_combat.update(self, delta)
		_update_enemies(delta * enemy_time)
		if game_state == "DUNGEON":
			_update_missiles(delta, enemy_time)
	queue_redraw()

func _message(s: String) -> void:
	status_message = s
	status_time = 3.5

func _enter_dungeon(kind: String) -> void:
	if game_state == "LAB": _leave_laboratory()
	if research_panel != null: research_panel.set_hub(false)
	game_state = "DUNGEON"
	if spell_record_hud != null:
		spell_record_hud.visible = true
		spell_record_hud.refresh()
	elemental_combat.clear()
	dungeon_kind = kind
	map_seed = fixed_seed if kind == "FIXED" else rng.randi_range(100, 999999999)
	_build_map(map_seed)
	player_pos = START_POS
	player_hp = _max_hp()
	player_mana = _max_mana()
	focus = 100.0
	carried_gold = 0
	missiles.clear()
	_reset_combat_input()
	_spawn_enemies()
	corpse_pos = Vector2.ZERO
	if not corpse.is_empty() and str(corpse.get("kind", "")) == kind:
		if kind == "FIXED":
			corpse_pos = Vector2(float(corpse.get("x", 0.0)), float(corpse.get("y", 0.0)))
		else:
			corpse_pos = _random_open_point()
	_message("Mana Bolt: hold Shift, type Q > E, then LMB. Double-tap Shift: stationary casting.")
	if research.main_attribute != null:
		_message("개화한 주속성의 짧은 구조를 시험하세요. 직접 영창 후 조준하여 LMB · 발견 영창은 J.")

func _build_map(seed_value: int) -> void:
	dungeon_rng.seed = seed_value
	walls.clear()
	for row in range(ROWS):
		for col in range(COLS):
			if row == 0 or row == ROWS - 1 or col == 0 or col == COLS - 1:
				walls.append(Vector2i(col, row))
			elif dungeon_rng.randf() < 0.13:
				# Preserve an always navigable route from spawn to the exit.
				if row == 2 or col == 17 or Vector2i(col, row).distance_to(Vector2i(2, 2)) < 2.5 or Vector2i(col, row).distance_to(Vector2i(17, 9)) < 2.5:
					continue
				walls.append(Vector2i(col, row))

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(AREA.position + Vector2(cell) * TILE, Vector2(TILE, TILE))

func _is_blocked(point: Vector2, radius: float = 13.0) -> bool:
	if not AREA.grow(-radius).has_point(point):
		return true
	for cell in walls:
		if _cell_rect(cell).grow(radius).has_point(point):
			return true
	return elemental_combat.blocks(point, radius)

func _try_move_player(motion: Vector2) -> void:
	player_pos = _move_actor(player_pos, motion)

func _move_actor(position: Vector2, motion: Vector2) -> Vector2:
	# Small swept steps prevent temporary barriers being skipped during a slow frame.
	var steps := maxi(1, ceili(motion.length() / 6.0))
	var step := motion / steps
	for i in steps:
		var px := position + Vector2(step.x, 0.0)
		if not _is_blocked(px): position.x = px.x
		var py := position + Vector2(0.0, step.y)
		if not _is_blocked(py): position.y = py.y
	return position

func _random_open_point() -> Vector2:
	for tries in range(150):
		var col := dungeon_rng.randi_range(2, COLS - 3)
		var row := dungeon_rng.randi_range(2, ROWS - 3)
		var candidate := AREA.position + (Vector2(float(col), float(row)) + Vector2(0.5, 0.5)) * TILE
		if not _is_blocked(candidate, 18.0) and candidate.distance_to(START_POS) > 140.0 and candidate.distance_to(EXIT_POS) > 80.0:
			return candidate
	return EXIT_POS - Vector2(80.0, 0.0)

func _spawn_enemies() -> void:
	enemies.clear()
	for i in range(5):
		enemies.append({"pos": _random_open_point(), "hp": 42.0, "shot": dungeon_rng.randf_range(1.0, 2.0)})

func _update_enemies(scaled_delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		if float(e["hp"]) <= 0.0:
			carried_gold += 10
			enemies.remove_at(i)
			continue
		var pos: Vector2 = e["pos"]
		var offset := player_pos - pos
		if e.get("stagger_remaining", 0.0) > 0.0: continue
		if offset.length() > 50.0 and e.get("root_remaining", 0.0) <= 0.0:
			var movement := offset.normalized() * ENEMY_SPEED * scaled_delta
			pos = _move_actor(pos, movement)
			e["pos"] = pos
		elif offset.length() < 25.0:
			player_hp -= 19.0 * scaled_delta
		e["shot"] = float(e["shot"]) - scaled_delta
		if float(e["shot"]) <= 0.0:
			e["shot"] = 2.7
			if offset.length() < 460.0:
				missiles.append({"pos": pos, "dir": offset.normalized(), "hostile": true, "life": 4.0, "dmg": 16.0})
		enemies[i] = e
	if player_hp <= 0.0:
		_die()

func _update_missiles(delta: float, enemy_time: float) -> void:
	elemental_combat.update_missiles(self, delta, enemy_time)

func _melee_attack() -> void:
	if game_state != "DUNGEON": return
	if player_attack_cooldown > 0.0: return
	player_attack_cooldown = 0.42
	var aim := get_global_mouse_position() - player_pos
	if aim.length() < 1.0: return
	for e in enemies:
		var offset: Vector2 = e["pos"] - player_pos
		if offset.length() < 78.0 and aim.normalized().dot(offset.normalized()) > 0.30:
			e["hp"] = float(e["hp"]) - (18.0 + float(body_talent) * 0.13)

func _show_rune_feedback() -> void:
	cast_feedback = str(_inspect_chant()["message"])

func _inspect_chant(finalize_holds := false) -> Dictionary:
	var simulation := ManaSimulator.simulate(chant_profile, _simulation_inputs(finalize_holds), true, research.simulation_context())
	var legacy := spell_book.inspect(runes, research.researched_base_elements)
	# Keep the taught QE formula and the existing Resource requirements contract.
	if legacy["state"] in ["ready", "locked", "invalid_data"] and not (legacy.get("spell") == spell_book.MANA_BOLT and simulation["state"] != "ready"):
		legacy["simulation"] = simulation
		return legacy
	var result := simulation.duplicate(true)
	if game_state in ["DUNGEON", "LAB"] and not simulation["final_state"]["base_attributes"].is_empty():
		var combat := CombatSpellResolver.resolve(simulation, research.main_attribute)
		# Unawakened/unfinished lab structures remain research phenomena. Only a
		# genuinely authorized complete combat structure enters the shared executor.
		if game_state == "DUNGEON" or combat.get("spell") != null: result = combat
	result["simulation"] = simulation
	if simulation["kind"] == "mana_bolt": result["spell"] = spell_book.MANA_BOLT
	if not runes.is_empty() and runes[0] == "Q" and legacy["state"] == "invalid" and result["state"] != "ready":
		result["message"] = legacy["message"] + " " + simulation["observation"]
	return result

func _cast_spell() -> void:
	if not save_writable:
		cast_feedback = "Save protected: casting unavailable."
		return
	var result := _inspect_chant(true)
	if exhaustion_seconds > 0.0:
		cast_feedback = "Exhausted: wait briefly before casting."
		_record_experiment(result["simulation"], "exhausted", 0.0)
		if game_state == "LAB": laboratory_panel.show_attempt_result("발현 보류 · 탈진이 가라앉은 뒤 다시 방출하세요.")
		return
	if result["state"] != "ready":
		cast_feedback = "Cast failed: " + str(result["message"])
		# A single Q is the existing tutorial's unfinished prefix; keep its behavior.
		var penalty := 0.0 if runes.is_empty() or runes == ["Q"] or result["state"] in ["locked", "invalid_data"] else minf(2.0, player_mana)
		player_mana -= penalty
		if penalty > 0.0: exhaustion_seconds = 1.0
		_record_experiment(result["simulation"], "failed", penalty)
		if game_state == "LAB": laboratory_panel.show_attempt_result("구조 미완성 · " + str(result["message"]))
		_update_laboratory_live()
		return
	var definition: SpellDefinition = result.get("spell")
	var cost: float = definition.mana_cost if definition != null else result["mana_cost"]
	if result.has("final_state") and definition != null: cost = result["mana_cost"]
	if player_mana < cost:
		cast_feedback = "Insufficient mana: need %d, have %d." % [ceili(cost), floori(player_mana)]
		_record_experiment(result["simulation"], "insufficient_mana", 0.0)
		if game_state == "LAB": laboratory_panel.show_attempt_result("발현 실패 · 마나가 부족합니다. 회복 후 다시 시험하세요.")
		return
	if definition == null:
		player_mana -= cost
		cast_feedback = result["message"]
		_record_experiment(result["simulation"], "released", cost)
		_clear_chant()
		_update_laboratory_live(result["simulation"])
		_finish_awakening_offer()
		return
	var dir := get_global_mouse_position() - player_pos
	if dir.length() < 1.0: dir = Vector2.RIGHT
	var executed := laboratory_panel.arena.manifest(definition) if game_state == "LAB" else elemental_combat.cast(self, definition, dir.normalized())
	if not executed:
		cast_feedback = "방출 불가: 장애물/대상과 겹치지 않는 열린 공간을 조준하세요."
		_record_experiment(result["simulation"], "blocked", 0.0)
		if game_state == "LAB": laboratory_panel.show_attempt_result(cast_feedback)
		return
	player_mana -= cost
	var spell := str(definition.spell_id)
	var previous_discoveries := discovered.to_data()
	var previous_learned := learned_spells.duplicate()
	var inputs: Array = []
	for step in result["simulation"]["casting_steps"]: inputs.append(step["input"].duplicate(true))
	var changed := discovered.record(spell, definition.display_name, inputs, int(result["simulation"]["rules_version"]), game_state)
	if not learned_spells.has(spell):
		learned_spells.append(spell)
		changed = true
	cast_feedback = "Released %s [%s]. Enter commands again to cast." % [definition.display_name, " > ".join(runes)]
	var recorded := _record_experiment(result["simulation"], "released", cost, {"spell_id": spell, "name": definition.display_name}) if game_state == "LAB" else (not changed or _save_character())
	if not recorded:
		discovered.load_data(previous_discoveries)
		learned_spells = previous_learned
	if game_state == "LAB": laboratory_panel.show_manifestation(definition.display_name, recorded)
	if spell_record_hud != null: spell_record_hud.refresh()
	_clear_chant()
	var displayed: Dictionary = result["simulation"].duplicate(true)
	displayed["manifestation"] = definition.display_name
	_update_laboratory_live(displayed)

func _enter_laboratory() -> void:
	if game_state != "HUB" or not save_writable: return
	research_panel.close()
	research_panel.set_hub(false)
	_reset_combat_input()
	game_state = "LAB"
	last_laboratory_result = {}
	laboratory_panel.open(research_panel.opener.theme)
	_update_laboratory_live()

func _leave_laboratory() -> void:
	if game_state != "LAB": return
	_reset_combat_input()
	research.cancel_request()
	pending_awakening_offer = {}
	game_state = "HUB"
	laboratory_panel.close()
	research_panel.set_hub(true)

func _laboratory_recover() -> void:
	if game_state != "LAB": return
	player_mana = _max_mana()
	exhaustion_seconds = 0.0
	laboratory_panel.arena.reset_targets()
	_update_laboratory_live()

func _record_experiment(simulation: Dictionary, outcome: String, spent: float, manifestation: Dictionary = {}) -> bool:
	if game_state != "LAB" or runes.is_empty(): return true
	var previous := journal.to_data()
	var previous_research := research.to_data()
	var inputs: Array = []
	for step in simulation["casting_steps"]: inputs.append(step["input"].duplicate(true))
	var elapsed := 0
	for event in inputs: elapsed = maxi(elapsed, event["at_ms"] + event["hold_ms"])
	var id := journal.append(simulation, outcome, spent, elapsed, ChantProfile.VERSION)
	if not manifestation.is_empty(): journal.mark_manifestation(id, manifestation)
	if outcome == "released": research.record_resonance(chant_profile, inputs, id)
	var written := _save_character()
	if not written:
		journal.load_data(previous)
		research.load_data(previous_research)
		pending_awakening_offer = {}
		laboratory_panel.message.text = "기록 저장 실패: " + save_error
	else:
		laboratory_panel.message.text = "실험 자동 기록 완료. 단계와 두 기록을 자유롭게 비교하세요."
		if not manifestation.is_empty(): laboratory_panel.message.text = "발현 성공 · " + str(manifestation.get("name", ""))
		elif outcome == "released": laboratory_panel.show_attempt_result("공명 성공 · 전투마법은 아직 발현되지 않았습니다.")
		if outcome == "released" and not research.ritual_target.is_empty():
			var proof := research.complete_ritual(chant_profile, inputs)
			if proof["state"] == "confirmation_required":
				pending_awakening_offer = proof
				laboratory_panel.message.text = "개화 의식 성공. 최종 영구 확정 확인을 기다립니다."
			else: laboratory_panel.message.text = laboratory_panel.awakening_panel.reason(proof["state"])
	laboratory_panel.refresh(true)
	laboratory_panel.awakening_panel.refresh()
	return written

func _change_spell_preference(id: String, favorite: bool, representative: int) -> void:
	if not save_writable: return
	var previous := discovered.to_data()
	discovered.set_favorite(id, favorite)
	discovered.choose_recipe(id, representative)
	if not _save_character(): discovered.load_data(previous)
	spell_record_hud.refresh()

func _record_cancelled_experiment() -> void:
	var simulation := ManaSimulator.simulate(chant_profile, _simulation_inputs(true), true, research.simulation_context())
	last_laboratory_result = simulation
	_record_experiment(simulation, "cancelled", 0.0)

func _save_experiment_note(id: int, value: String) -> void:
	if game_state != "LAB" or not save_writable: return
	var previous := journal.to_data()
	if not journal.note(id, value): return
	if not _save_character():
		journal.load_data(previous)
		laboratory_panel.message.text = "메모 저장 실패: " + save_error
	else: laboratory_panel.message.text = "메모를 저장했습니다."
	laboratory_panel.refresh()

func _update_laboratory_live(last_result: Dictionary = {}) -> void:
	if game_state != "LAB" or laboratory_panel == null: return
	if not last_result.is_empty(): last_laboratory_result = last_result
	var result := last_laboratory_result if runes.is_empty() and not last_laboratory_result.is_empty() else ManaSimulator.simulate(chant_profile, _simulation_inputs(true), true, research.simulation_context())
	var mode_label: String = CombatInput.Mode.keys()[combat_input.mode]
	if not research.ritual_target.is_empty(): mode_label += " · 의식: " + CharacterResearch.BaseElements.DEFINITIONS[research.ritual_target].display_name
	var debug_state: Dictionary = result["final_state"].duplicate(true)
	debug_state["research_context"] = research.simulation_context()
	if not research.ritual_target.is_empty(): debug_state["target_conditions"] = CharacterResearch.Rules.requirements(research.ritual_target, research.simulation_context())
	var stage: String = {"weak": "약한 징후", "partial": "부분 공명", "unstable": "불안정", "failed": "붕괴", "ready": "안정 구조"}.get(result["state"], "준비 / 관찰")
	if not result["final_state"]["base_attributes"].is_empty() and result["state"] == "ready": stage = "공명 성공 · 전투 발현과 별개"
	if result.has("manifestation"): stage = "전투 발현 완료 · " + str(result["manifestation"])
	laboratory_panel.show_live(runes, stage + " · " + result["observation"], player_mana, exhaustion_seconds, debug_state, mode_label)

func _interact() -> void:
	if game_state != "DUNGEON": return
	if corpse_pos != Vector2.ZERO and player_pos.distance_to(corpse_pos) < 49.0:
		carried_gold += int(corpse.get("gold", 0))
		corpse.clear()
		corpse_pos = Vector2.ZERO
		_save_character()
		_message("Recovered the belongings from your last death.")
		return
	if player_pos.distance_to(EXIT_POS) < 60.0:
		bank_gold += carried_gold
		carried_gold = 0
		game_state = "HUB"
		elemental_combat.clear()
		missiles.clear()
		if research_panel != null: research_panel.set_hub(true)
		_reset_combat_input()
		_save_character()
		_message("Returned safely. Your carried gold has been banked.")
		return
	_message("Nothing nearby to interact with.")

func _die() -> void:
	if game_state != "DUNGEON": return
	var retrievable := int(round(float(carried_gold) * 0.7))
	corpse = {"kind": dungeon_kind, "x": player_pos.x, "y": player_pos.y, "gold": retrievable}
	carried_gold = 0
	injury_stacks = mini(3, injury_stacks + 1)
	armor_durability = maxi(0, armor_durability - 15)
	player_hp = _max_hp()
	player_mana = _max_mana()
	game_state = "HUB"
	elemental_combat.clear()
	missiles.clear()
	if research_panel != null: research_panel.set_hub(true)
	_reset_combat_input()
	_save_character()
	_message("DEATH: +1 injury, -15 armor. Return to your dungeon to recover 70% of carried gold.")

func _heal_injuries() -> void:
	if injury_stacks <= 0:
		_message("No injuries to heal.")
		return
	var price := injury_stacks * 15
	if bank_gold < price:
		_message("Need %d banked gold to heal." % price)
		return
	bank_gold -= price
	injury_stacks = 0
	player_hp = _max_hp()
	player_mana = _max_mana()
	_save_character()
	_message("Injuries healed. Knowledge and talents remain unchanged.")

func _label_at(pos: Vector2, label: String, font_size: int = 16, color: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _spell_summary() -> String:
	var result := ""
	for name in learned_spells:
		if result != "": result += ", "
		result += name
	return result if result != "" else "none"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1160.0, 720.0)), Color("111522"))
	draw_rect(Rect2(25.0, 28.0, 1100.0, 65.0), Color("252d3d"))
	_label_at(Vector2(45.0, 55.0), "ARCANE LEGACY  /  PROTOTYPE", 23, Color("ffe5ab"))
	_label_at(Vector2(46.0, 80.0), "Single character  |  talent: magic %d / body %d  |  discoveries: %s" % [magic_talent, body_talent, _spell_summary()], 13, Color("b9d4e2"))
	if game_state == "HUB":
		_draw_hub()
	elif game_state == "DUNGEON":
		_draw_dungeon()
	if game_state != "DUNGEON": _label_at(Vector2(65.0, 707.0), "Research: %d/3  [%s]" % [research.researched_base_elements.size(), ", ".join(research.researched_base_elements)], 14, Color("b9d4e2"))
	if not save_writable:
		_label_at(Vector2(65.0, 601.0), "SAVE PROTECTED: " + save_error, 14, Color("ffcd91"))
	if game_state == "HUB" and status_time > 0.0 and not research_panel.is_open():
		draw_rect(Rect2(60.0, 634.0, 1040.0, 48.0), Color("33425b"))
		_label_at(Vector2(75.0, 665.0), status_message, 16, Color("ffffff"))

func _draw_hub() -> void:
	_label_at(Vector2(100.0, 167.0), "THE REFUGE  /  The same character survives every expedition", 22)
	_label_at(Vector2(110.0, 230.0), "[1] Enter the RUINS  -  fixed layout, corpse stays at the place of death", 18)
	_label_at(Vector2(110.0, 270.0), "[2] Enter the FLUX MAZE  -  layout reshuffles, corpse moves to a new room", 18)
	_label_at(Vector2(110.0, 330.0), "[H] Heal all injuries: 15 gold per stack", 18, Color("a8d6b5"))
	_label_at(Vector2(110.0, 388.0), "Banked gold: %d  |  injury stacks: %d/3  |  armor: %d/100" % [bank_gold, injury_stacks, armor_durability], 18)
	if not corpse.is_empty():
		_label_at(Vector2(110.0, 447.0), "Your belongings remain in: %s (recoverable gold: %d)" % [str(corpse.get("kind", "")), int(corpse.get("gold", 0))], 18, Color("ffcd91"))
	_label_at(Vector2(110.0, 545.0), "Save file: user://arcane_legacy_save.json", 14, Color("9caec4"))
	_label_at(Vector2(110.0, 580.0), "[L] Laboratory - chant, observe, replay and compare", 18, Color("a8d6b5"))

func _draw_dungeon() -> void:
	draw_rect(AREA, Color("202938"))
	for col in range(COLS + 1):
		var px := AREA.position.x + float(col) * TILE
		draw_line(Vector2(px, AREA.position.y), Vector2(px, AREA.end.y), Color("303744"), 1.0)
	for row in range(ROWS + 1):
		var py := AREA.position.y + float(row) * TILE
		draw_line(Vector2(AREA.position.x, py), Vector2(AREA.end.x, py), Color("303744"), 1.0)
	for cell in walls:
		draw_rect(_cell_rect(cell), Color("596176"))
	# Gold gate
	draw_circle(EXIT_POS, 19.0, Color("f2c777"))
	draw_circle(EXIT_POS, 12.0, Color("64501f"))
	if corpse_pos != Vector2.ZERO:
		draw_circle(corpse_pos, 17.0, Color("f59e69"))
		draw_circle(corpse_pos, 9.0, Color("80433a"))
	for e in enemies:
		draw_circle(Vector2(e["pos"]), 15.0, Color("dd6670"))
	elemental_combat.draw(self)
	if combat_input.mode == CombatInput.Mode.FOCUS_CAST:
		draw_arc(player_pos, 23.0, 0.0, TAU, 40, Color("ffe5ab"), 2.0)
	if focus_active:
		draw_circle(player_pos, 27.0, Color(0.3, 0.78, 1.0, 0.3))
		draw_circle(player_pos + Vector2(-19.0, 4.0), 11.0, Color(0.2, 0.6, 1.0, 0.2))
	draw_circle(player_pos, 13.0, Color("6ed8e9"))
	var direction := get_global_mouse_position() - player_pos
	if direction.length() > 0.1:
		draw_line(player_pos, player_pos + direction.normalized() * 30.0, Color("f5f7ff"), 2.5)
	draw_rect(Rect2(915.0, 105.0, 227.0, 485.0), Color("252d3d"))
	_label_at(Vector2(932.0, 130.0), "DUNGEON", 17, Color("ffe5ab"))
	_label_at(Vector2(932.0, 153.0), dungeon_kind, 15)
	_label_at(Vector2(932.0, 198.0), "HP: %d / %d" % [roundi(player_hp), roundi(_max_hp())], 17)
	_label_at(Vector2(932.0, 230.0), "Mana: %d / %d" % [roundi(player_mana), roundi(_max_mana())], 17)
	_label_at(Vector2(932.0, 262.0), "Focus: %d / 100" % roundi(focus), 17)
	_label_at(Vector2(932.0, 294.0), "Gold: %d" % carried_gold, 17)
	_label_at(Vector2(932.0, 326.0), "Enemies: %d" % enemies.size(), 17)
	var mode_name: String = CombatInput.Mode.keys()[combat_input.mode]
	_label_at(Vector2(932.0, 357.0), mode_name, 17, Color("ffe5ab"))
	_label_at(Vector2(932.0, 384.0), "WASD: " + ("commands" if combat_input.mode == CombatInput.Mode.FOCUS_CAST else "move"), 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 408.0), "Shift hold: mobile cast", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 432.0), "Shift x2: focus toggle", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 456.0), "LMB: sword / release", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 480.0), "RMB / Esc: cancel", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 504.0), "Alt hold: swift sense", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 528.0), "F: interact / command", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 566.0), "Mana Bolt: Q > E", 15, Color("ffe5ab"))
	_draw_cast_hud()

func _draw_cast_hud() -> void:
	if spell_record_hud != null and spell_record_hud.expanded: return
	# Two rows keep all 32 buffer tokens visible instead of overflowing the sidebar.
	draw_rect(Rect2(60.0, 594.0, 1040.0, 92.0), Color("33425b"))
	_label_at(Vector2(75.0, 615.0), "Commands: " + ("(empty)" if runes.is_empty() else " > ".join(runes.slice(0, 16))), 15, Color("ffe5ab"))
	if runes.size() > 16:
		_label_at(Vector2(165.0, 635.0), " > ".join(runes.slice(16)), 15, Color("ffe5ab"))
	_label_at(Vector2(75.0, 658.0), cast_feedback, 14)
	if status_time > 0.0:
		_label_at(Vector2(75.0, 680.0), status_message, 13, Color("b9d4e2"))
