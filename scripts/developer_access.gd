extends RefCounted
## editor_runtime includes the editor executable's game run (F5/F6/CLI).
## A release build always wins over flags or an injected developer preference.
static func allowed(debug_build: bool, editor_runtime: bool, explicit: bool, preference: Variant = null) -> bool:
	if not debug_build: return false
	if preference != null: return preference == true
	return editor_runtime or explicit
