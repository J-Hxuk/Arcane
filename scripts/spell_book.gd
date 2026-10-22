extends RefCounted
## Formula matching and diagnostics do not execute effects or alter research.

const SpellDefinition = preload("res://scripts/spell_definition.gd")
const MANA_BOLT = preload("res://data/spells/mana_bolt.tres")

var definitions: Array[SpellDefinition] = [MANA_BOLT]
var max_commands := 32 # Input buffer guard; not a final spell-length rule.

func inspect(tokens: Array[String], researched_elements: PackedStringArray = PackedStringArray()) -> Dictionary:
	if tokens.is_empty():
		return {"state": "empty", "message": "Enter commands first: Q > E, then LMB."}
	var prefix_found := false
	var best_prefix := 0
	for definition in definitions:
		var matched := 0
		for index in range(mini(tokens.size(), definition.commands.size())):
			if tokens[index] != definition.commands[index]:
				break
			matched += 1
		best_prefix = maxi(best_prefix, matched)
		if matched != tokens.size():
			continue
		if tokens.size() < definition.commands.size():
			prefix_found = true
			continue
		var data_error := definition.validate_requirements()
		if not data_error.is_empty():
			return {"state": "invalid_data", "message": data_error}
		for element in definition.requires_elements:
			if not researched_elements.has(element):
				return {"state": "locked", "message": "Research required: " + element}
		return {"state": "ready", "message": definition.display_name + " ready. LMB to release.", "spell": definition}
	if prefix_found:
		return {"state": "incomplete", "message": "Incomplete formula after command %d. Continue entering commands." % tokens.size()}
	return {"state": "invalid", "message": "No formula matches command %d (%s). Esc to clear." % [best_prefix + 1, tokens[best_prefix]]}
