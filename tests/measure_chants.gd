extends SceneTree
## Breadth-first minimum for basic spells; dominated extra volume/cohesion is pruned.
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Helper = preload("res://tests/test_chant.gd")

static func minimum(element: String, context: Dictionary = {}) -> Dictionary:
	var initial := Sim.initial_state()
	if not element.is_empty(): initial["base_attributes"] = [element]
	var queue: Array = [[initial, []]]
	var seen: Dictionary = {}
	var cursor := 0
	while cursor < queue.size():
		var entry: Array = queue[cursor]
		cursor += 1
		var state: Dictionary = entry[0]
		var path: Array = entry[1]
		var outcome := Sim.classify(state, path.size() + 1, -1, context)
		var simulation := outcome.duplicate(true)
		simulation.merge({"final_state": state, "simulation_context": context, "casting_steps": []})
		var resolved := simulation if element.is_empty() else Resolver.resolve(simulation, element)
		if resolved["state"] == "ready": return {"inputs": path.size() + 1, "actions": path, "states_visited": cursor}
		if path.size() >= 10: continue
		for action in ["ACCUMULATE", "COMPRESS", "STABILIZE", "RESONATE", "SHAPE", "DIRECT"]:
			if action == "ACCUMULATE" and state["mana_amount"] >= 10: continue
			if action == "COMPRESS" and state["cohesion"] >= 25: continue
			if action == "SHAPE" and state["form_integrity"] >= 50: continue
			if action == "DIRECT" and state["flow_vector"] == [1.0, 0.0]: continue
			if action == "STABILIZE" and state["stability"] >= 100: continue
			if action == "RESONATE" and (element.is_empty() or state["mana_amount"] < 10 or state["cohesion"] < 25 or state["resonance"].get(element, 0) >= 100): continue
			var next := state.duplicate(true)
			Sim._apply(next, action, 0, context)
			if next["stability"] < 30: continue
			var signature := JSON.stringify(next)
			if seen.has(signature): continue
			seen[signature] = true
			queue.append([next, path + [action]])
	return {"inputs": -1}

func _initialize() -> void:
	var result := {"pure_personal": minimum("")}
	for element in Profile.ELEMENTS:
		result[element] = minimum(element, {"knowledge": {element: {"book": true, "mentor": true}}})
	print("CHANT_MINIMA ", JSON.stringify(result))
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	quit()
