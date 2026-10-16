extends RefCounted
## Event-based routing. Bindings live in Project Settings > Input Map.
## A second press within the window wins over hold; a long hold cannot be a tap.

enum Mode { NORMAL, MOBILE_CAST, FOCUS_CAST }

signal mode_changed(previous: Mode, current: Mode)
signal command_entered(token: String)
signal command_released(token: String, held_ms: int)
signal attack_requested
signal cast_requested
signal cancel_requested
signal interact_requested

const COMMAND_TOKENS := ["Q", "E", "R", "F", "Z", "X", "C", "V", "T", "G", "W", "A", "S", "D"]
const MOVEMENT_ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down"]
const TIMING_EPSILON := 0.000001 # Covers float subtraction at the exact millisecond boundary.

var mode: Mode = Mode.NORMAL
var double_tap_window := 0.3 # Temporary playtest value, in seconds.
var swift_sense_held := false
var _pressed_sources: Dictionary = {}
var _action_sources: Dictionary = {}
var _tap_started_at := -INF
var _tap_released := false
var last_command_time := 0.0
var _command_holds: Dictionary = {}

func handle_event(event: InputEvent, now: float) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if event is InputEventKey and event.echo:
		return
	var source := _source_id(event)
	if event.is_pressed():
		if _pressed_sources.has(source):
			return
		_pressed_sources[source] = true
	else:
		_pressed_sources.erase(source)
		if _command_holds.has(source):
			var held: Dictionary = _command_holds[source]
			_command_holds.erase(source)
			command_released.emit(held["token"], maxi(0, roundi((now - held["time"]) * 1000.0)))
	for action in MOVEMENT_ACTIONS:
		_update_action(action, event, source)
	_update_action(&"swift_sense", event, source)
	swift_sense_held = _is_held(&"swift_sense")
	if _update_action(&"cast_modifier", event, source):
		if _is_held(&"cast_modifier"):
			_shift_pressed(now)
		else:
			_shift_released(now)
		return
	if not event.is_pressed():
		return
	if event.is_action(&"cancel_cast"):
		_invalidate_tap()
		if mode == Mode.FOCUS_CAST:
			_set_mode(Mode.NORMAL)
		cancel_requested.emit()
		return
	if event.is_action(&"primary_attack"):
		_invalidate_tap()
		if mode == Mode.NORMAL:
			attack_requested.emit()
		else:
			cast_requested.emit()
		return
	if mode == Mode.NORMAL:
		if event.is_action(&"interact"):
			_invalidate_tap()
			interact_requested.emit()
		return
	for index in range(COMMAND_TOKENS.size()):
		# The last four tokens share bindings with movement, only in focus mode.
		if index >= 10 and mode != Mode.FOCUS_CAST:
			continue
		var token: String = COMMAND_TOKENS[index]
		if event.is_action(StringName("rune_" + token.to_lower())):
			_invalidate_tap()
			last_command_time = now
			_command_holds[source] = {"token": token, "time": now}
			command_entered.emit(token)
			return

func movement_axis() -> Vector2:
	if mode == Mode.FOCUS_CAST:
		return Vector2.ZERO
	return Vector2(
		float(_is_held(&"move_right")) - float(_is_held(&"move_left")),
		float(_is_held(&"move_down")) - float(_is_held(&"move_up"))
	).normalized()

func reset() -> void:
	_pressed_sources.clear()
	_action_sources.clear()
	_command_holds.clear()
	swift_sense_held = false
	_invalidate_tap()
	_set_mode(Mode.NORMAL)

func _source_id(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return "key:%d:%d" % [code, event.location]
	return "mouse:%d" % event.button_index

func _update_action(action: StringName, event: InputEvent, source: String) -> bool:
	if not event.is_action(action):
		return false
	var was_held := _is_held(action)
	var sources: Dictionary = _action_sources.get(action, {})
	if event.is_pressed():
		sources[source] = true
	else:
		sources.erase(source)
	_action_sources[action] = sources
	return was_held != _is_held(action)

func _is_held(action: StringName) -> bool:
	return not _action_sources.get(action, {}).is_empty()

func _shift_pressed(now: float) -> void:
	if _tap_released and now >= _tap_started_at and now - _tap_started_at <= double_tap_window + TIMING_EPSILON:
		_invalidate_tap()
		_set_mode(Mode.NORMAL if mode == Mode.FOCUS_CAST else Mode.FOCUS_CAST)
		return
	_tap_started_at = now
	_tap_released = false
	if mode != Mode.FOCUS_CAST:
		_set_mode(Mode.MOBILE_CAST)

func _shift_released(now: float) -> void:
	if now >= _tap_started_at and now - _tap_started_at <= double_tap_window + TIMING_EPSILON:
		_tap_released = true
	else:
		_invalidate_tap()
	if mode == Mode.MOBILE_CAST:
		_set_mode(Mode.NORMAL)

func _invalidate_tap() -> void:
	_tap_started_at = -INF
	_tap_released = false

func _set_mode(next: Mode) -> void:
	if next == mode:
		return
	var previous := mode
	mode = next
	mode_changed.emit(previous, mode)
