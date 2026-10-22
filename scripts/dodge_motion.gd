extends RefCounted
## Prototype physical evasion, no invulnerability or talent scaling.
const DURATION := 0.18
const SPEED := 600.0
const COOLDOWN := 0.9
var remaining := 0.0
var cooldown := 0.0
var direction := Vector2.RIGHT
var origin := Vector2.ZERO
var active: bool:
	get: return remaining > 0.0
func cancel() -> void: remaining = 0.0
func reset() -> void:
	cancel()
	cooldown = 0.0
static func cursor_heading(position: Vector2, cursor: Vector2) -> Vector2:
	var offset := cursor - position
	return offset.normalized() if offset.length_squared() >= 1.0 else Vector2.RIGHT
func begin(position: Vector2, heading: Vector2) -> bool:
	if active or cooldown > 0.0: return false
	origin = position
	direction = heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT
	remaining = DURATION
	cooldown = COOLDOWN
	return true
func advance(game, delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not active: return
	var step := minf(delta, remaining)
	var before: Vector2 = game.player_pos
	# Ordinary evasion is a sweep, never the endpoint/teleport query of a future blink.
	var distance := SPEED * step
	var count := maxi(1, ceili(distance / 2.0))
	for i in count:
		var next: Vector2 = game.player_pos + direction * distance / count
		if game._is_blocked(next, 13.0): cancel(); break
		var previous: Vector2 = game.player_pos
		game._try_move_player(next - previous)
		if not game.player_pos.is_equal_approx(next): cancel(); break
	remaining = maxf(0.0, remaining - step)
	if game.player_pos.distance_to(before) < SPEED * step * 0.2: cancel()
