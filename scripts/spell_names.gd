extends RefCounted
## Display-only ID lookup. Stored historical names/IDs/recipes are never rewritten.
static var SOURCE:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/spell_display_names.json"))
static func label(id:String,fallback:="") -> String:
	if id=="MANA_BOLT":return "Mana Bolt"
	var catalog:String=SOURCE["legacy_ids"].get(id,id)
	if SOURCE["by_catalog_id"].has(catalog):return SOURCE["by_catalog_id"][catalog]
	# No authoritative English name was found for these old resources. Use their
	# unchanged Latin internal IDs until a name is approved, not an invented title.
	if not id.is_empty():return id
	return fallback if fallback.is_valid_identifier() else "Legacy Spell"
