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
const SPELL_RECIPES := {
	"QE": "EMBER",       # ranged projectile
	"EQ": "MEND",        # self healing
	"RR": "PULSE"        # point-blank area attack
}

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
var casting := false
var runes: Array[String] = []
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
	rng.randomize()
	_load_or_create_character()
	status_message = "Choose a dungeon: [1] Ruins (fixed)  [2] Flux Maze (shifting)"
	status_time = 6.0
	queue_redraw()

func _max_hp() -> float:
	return 100.0 * (1.0 - 0.12 * float(injury_stacks))

func _max_mana() -> float:
	return (45.0 + float(magic_talent) * 1.1) * (1.0 - 0.10 * float(injury_stacks))

func _load_or_create_character() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				magic_talent = int(parsed.get("magic", 50))
				body_talent = int(parsed.get("body", 50))
				bank_gold = int(parsed.get("bank", 100))
				injury_stacks = clampi(int(parsed.get("injury", 0)), 0, 3)
				armor_durability = int(parsed.get("armor", 100))
				fixed_seed = int(parsed.get("fixed_seed", 12345))
				corpse = parsed.get("corpse", {})
				for name in parsed.get("learned", []):
					learned_spells.append(str(name))
				player_hp = _max_hp()
				player_mana = _max_mana()
				return
	var total := rng.randi_range(95, 105)
	magic_talent = rng.randi_range(15, total - 15)
	body_talent = total - magic_talent
	fixed_seed = rng.randi_range(1000, 9999999)
	player_hp = _max_hp()
	player_mana = _max_mana()
	_save_character()

func _save_character() -> void:
	var save := {
		"magic": magic_talent,
		"body": body_talent,
		"bank": bank_gold,
		"injury": injury_stacks,
		"armor": armor_durability,
		"fixed_seed": fixed_seed,
		"corpse": corpse,
		"learned": learned_spells
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save, "\t"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if game_state == "HUB":
			if event.keycode == KEY_1:
				_enter_dungeon("FIXED")
			elif event.keycode == KEY_2:
				_enter_dungeon("SHIFTING")
			elif event.keycode == KEY_H:
				_heal_injuries()
		elif game_state == "DUNGEON":
			if event.keycode == KEY_F:
				_interact()
			elif event.keycode == KEY_ESCAPE:
				casting = false
				runes.clear()
			elif casting and event.keycode in [KEY_Q, KEY_E, KEY_R]:
				if runes.size() < 3:
					match event.keycode:
						KEY_Q: runes.append("Q")
						KEY_E: runes.append("E")
						KEY_R: runes.append("R")
					_show_rune_feedback()
	if event is InputEventMouseButton and game_state == "DUNGEON":
		if event.button_index == MOUSE_BUTTON_RIGHT:
			casting = event.pressed
			if event.pressed:
				runes.clear()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if casting:
				_cast_spell()
			else:
				_melee_attack()

func _process(delta: float) -> void:
	if status_time > 0.0:
		status_time -= delta
	if game_state == "DUNGEON":
		var axis := Vector2.ZERO
		if Input.is_key_pressed(KEY_A): axis.x -= 1.0
		if Input.is_key_pressed(KEY_D): axis.x += 1.0
		if Input.is_key_pressed(KEY_W): axis.y -= 1.0
		if Input.is_key_pressed(KEY_S): axis.y += 1.0
		if axis != Vector2.ZERO:
			axis = axis.normalized()
			_try_move_player(axis * PLAYER_SPEED * delta)
		player_attack_cooldown = maxf(0.0, player_attack_cooldown - delta)
		player_mana = minf(_max_mana(), player_mana + 3.0 * delta)
		focus_active = Input.is_key_pressed(KEY_SHIFT) and focus > 0.0
		if focus_active:
			focus = maxf(0.0, focus - 32.0 * delta)
		else:
			focus = minf(100.0, focus + 14.0 * delta)
		var enemy_time := 0.35 if focus_active else 1.0
		_update_enemies(delta * enemy_time)
		_update_missiles(delta, enemy_time)
	queue_redraw()

func _message(s: String) -> void:
	status_message = s
	status_time = 3.5

func _enter_dungeon(kind: String) -> void:
	game_state = "DUNGEON"
	dungeon_kind = kind
	map_seed = fixed_seed if kind == "FIXED" else rng.randi_range(100, 999999999)
	_build_map(map_seed)
	player_pos = START_POS
	player_hp = _max_hp()
	player_mana = _max_mana()
	focus = 100.0
	carried_gold = 0
	missiles.clear()
	casting = false
	runes.clear()
	_spawn_enemies()
	corpse_pos = Vector2.ZERO
	if not corpse.is_empty() and str(corpse.get("kind", "")) == kind:
		if kind == "FIXED":
			corpse_pos = Vector2(float(corpse.get("x", 0.0)), float(corpse.get("y", 0.0)))
		else:
			corpse_pos = _random_open_point()
	_message("Explore, research spells, and return through the gold gate [F].")

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
	return false

func _try_move_player(motion: Vector2) -> void:
	var px := player_pos + Vector2(motion.x, 0.0)
	if not _is_blocked(px): player_pos.x = px.x
	var py := player_pos + Vector2(0.0, motion.y)
	if not _is_blocked(py): player_pos.y = py.y

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
		if offset.length() > 50.0:
			var movement := offset.normalized() * ENEMY_SPEED * scaled_delta
			var target_x := pos + Vector2(movement.x, 0.0)
			if not _is_blocked(target_x): pos.x = target_x.x
			var target_y := pos + Vector2(0.0, movement.y)
			if not _is_blocked(target_y): pos.y = target_y.y
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
	for i in range(missiles.size() - 1, -1, -1):
		var m := missiles[i]
		var hostile := bool(m["hostile"])
		var actor_delta := delta * enemy_time if hostile else delta
		var speed := 160.0 if hostile else 460.0
		m["pos"] = m["pos"] + m["dir"] * speed * actor_delta
		m["life"] = float(m["life"]) - actor_delta
		var pos: Vector2 = m["pos"]
		var expire := float(m["life"]) < 0.0 or _is_blocked(pos, 4.0)
		if not expire and hostile:
			if pos.distance_to(player_pos) < 16.0:
				player_hp -= float(m["dmg"])
				expire = true
		elif not expire:
			for j in range(enemies.size()):
				if pos.distance_to(enemies[j]["pos"]) < 18.0:
					enemies[j]["hp"] = float(enemies[j]["hp"]) - float(m["dmg"])
					expire = true
					break
		if expire: missiles.remove_at(i)
		else: missiles[i] = m
	if player_hp <= 0.0 and game_state == "DUNGEON":
		_die()

func _melee_attack() -> void:
	if player_attack_cooldown > 0.0: return
	player_attack_cooldown = 0.42
	var aim := get_global_mouse_position() - player_pos
	if aim.length() < 1.0: return
	for e in enemies:
		var offset: Vector2 = e["pos"] - player_pos
		if offset.length() < 78.0 and aim.normalized().dot(offset.normalized()) > 0.30:
			e["hp"] = float(e["hp"]) - (18.0 + float(body_talent) * 0.13)

func _rune_sequence() -> String:
	var result := ""
	for s in runes: result += s
	return result

func _show_rune_feedback() -> void:
	var seq := _rune_sequence()
	if SPELL_RECIPES.has(seq):
		_message("Runes resonate! Complete the cast with LEFT CLICK.")
		return
	for recipe in SPELL_RECIPES.keys():
		if str(recipe).begins_with(seq):
			_message("Faint resonance... explore the next rune.")
			return
	_message("The mana pattern collapses. Release RMB to restart.")

func _cast_spell() -> void:
	var recipe := _rune_sequence()
	var spell := str(SPELL_RECIPES.get(recipe, ""))
	if spell == "":
		_message("Failed cast: no stable formula.")
		return
	var cost := 15.0 if spell == "EMBER" else 24.0
	if player_mana < cost:
		_message("Insufficient mana.")
		return
	player_mana -= cost
	if not learned_spells.has(spell):
		learned_spells.append(spell)
		_save_character()
		_message("NEW DISCOVERY: " + spell + "! The formula is saved.")
	match spell:
		"EMBER":
			var dir := get_global_mouse_position() - player_pos
			if dir.length() < 1.0: dir = Vector2.RIGHT
			missiles.append({"pos": player_pos, "dir": dir.normalized(), "hostile": false, "life": 1.8, "dmg": 35.0})
		"MEND":
			player_hp = minf(_max_hp(), player_hp + 27.0)
		"PULSE":
			for e in enemies:
				if Vector2(e["pos"]).distance_to(player_pos) < 120.0:
					e["hp"] = float(e["hp"]) - 35.0
	runes.clear()

func _interact() -> void:
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
	casting = false
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
	else:
		_draw_dungeon()
	if status_time > 0.0:
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
	for m in missiles:
		draw_circle(Vector2(m["pos"]), 6.0, Color("ff8a54") if not bool(m["hostile"]) else Color("c993e9"))
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
	_label_at(Vector2(932.0, 369.0), "WASD: move", 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 392.0), "LMB: sword", 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 415.0), "SHIFT: swift sense", 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 438.0), "HOLD RMB: spell", 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 461.0), "Q/E/R: combine", 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 484.0), "RMB+LMB: cast", 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 507.0), "F: loot / exit", 15, Color("b9d4e2"))
	_label_at(Vector2(932.0, 550.0), "Runes: %s" % _rune_sequence(), 16, Color("ffe5ab"))
	if focus_active:
		_label_at(Vector2(180.0, 620.0), "SWIFT SENSE ACTIVE: enemies 35% speed / player 100%", 17, Color("a4e5ff"))
