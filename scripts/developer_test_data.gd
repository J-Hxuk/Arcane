extends RefCounted
## Developer-only temporary characters and verified examples; never normal unlocks.
const Profile = preload("res://scripts/chant_profile.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Rules = preload("res://scripts/resonance_rules.gd")
const OPTIONS := ["WOOD", "FIRE", "EARTH", "METAL", "WATER", "VOID", "WATER_METAL", "FIRE_WATER"]

static func character(mapping: Dictionary, element: String) -> Dictionary:
	var selected := element
	var auxiliary: Array = []
	if element in ["WATER_METAL", "FIRE_WATER"]:
		element = "WATER" if selected == "WATER_METAL" else "FIRE"
		auxiliary = ["METAL" if selected == "WATER_METAL" else "WATER"]
	var affinity := {}
	var clues: Array = []
	for candidate in Profile.ELEMENTS:
		affinity[candidate] = 85 if candidate == element else 25
		for source in ["book", "mentor", "environment"]: clues.append({"element": candidate, "source": source, "id": Rules.clue_id(candidate, source)})
	var studies: Array = []
	if not auxiliary.is_empty(): studies.append(preload("res://scripts/fusion_rules.gd").pair([element, auxiliary[0]]))
	return {"schema_version": 4, "magic": 50, "body": 50, "bank": 100, "injury": 0, "armor": 100, "fixed_seed": 12345,
		"corpse": {}, "learned": [], "chant": mapping.duplicate(true), "laboratory": {"version": 1, "next_id": 1, "records": []},
		"research": {"main_attribute": element, "auxiliary_attributes": auxiliary, "binding_studies": studies, "legacy_committed_attributes": [], "innate_affinity": affinity, "research_clues": clues, "resonance_discoveries": {}},
		"spell_discoveries": {"version": 1, "spells": {}}}

static func inputs(profile: Profile, element: String, actions: Array) -> Array:
	var keys: Array = []
	for key in Profile.ATTRIBUTE_KEYS:
		if profile.first_word(key) == element: keys.append(key); break
	for action in actions:
		for key in profile.mobile_keys():
			if profile.manipulation(key) == action: keys.append(key); break
	var events: Array = []
	for i in keys.size(): events.append({"key": keys[i], "at_ms": i * 100, "hold_ms": 0})
	return events

static func examples(profile: Profile, element: String, context: Dictionary) -> Array:
	if element in ["WATER_METAL", "FIRE_WATER"]:
		var first := "WATER" if element == "WATER_METAL" else "FIRE"
		var second := "METAL" if element == "WATER_METAL" else "WATER"
		var found: Array = []
		for wall in ([false, true] if element == "WATER_METAL" else [false]):
			var events := fusion_inputs(profile, first, second, wall)
			var resolved := Resolver.resolve(Sim.simulate(profile, events, true, context), context.get("main_attribute"), context)
			if resolved.get("state") != "ready" or resolved.get("spell") == null: continue
			var definition = resolved["spell"]
			found.append({"spell_id": str(definition.spell_id), "name": definition.display_name, "inputs": events, "cost": resolved["mana_cost"], "damage": definition.damage,
				"duration": definition.duration, "range": definition.radius if definition.radius > 0 else definition.projectile_speed * definition.lifetime, "effect": str(definition.effect), "sample_ms": (events.size() - 1) * 100})
		return found
	var paths: Array = [["ACCUMULATE", "DIRECT"]]
	if element in Profile.OHAENG:
		paths.clear()
		var catalog=preload("res://scripts/m1_spell_catalog.gd")
		for definition in catalog.definitions():
			if str(definition.attribute)==element:paths.append(catalog.PROFILES["examples"][str(definition.catalog_id)])
	if element == "FIRE":
		for concentrated in [true, false]:
			var actions: Array = ["ACCUMULATE", "ACCUMULATE"] if concentrated else ["ACCUMULATE", "ACCUMULATE", "ACCUMULATE"]
			for i in (3 if concentrated else 1): actions.append("COMPRESS")
			for i in 3: actions.append_array(["STABILIZE", "RESONATE"])
			actions.append("SHAPE")
			if not concentrated: actions.append("SHAPE")
			actions.append_array(["STABILIZE", "DIRECT"])
			paths.append(actions)
	var result: Array = []
	for path in paths:
		var events := inputs(profile, element, path)
		var simulation := Sim.simulate(profile, events, true, context)
		var resolved := Resolver.resolve(simulation, element)
		if resolved.get("state") != "ready" or resolved.get("spell") == null: continue
		var definition = resolved["spell"]
		result.append({"spell_id": str(definition.spell_id), "name": definition.display_name, "inputs": events,
			"cost": resolved["mana_cost"], "damage": definition.damage, "duration": definition.duration,
			"range": definition.radius if definition.radius > 0 else definition.projectile_speed * definition.lifetime,
			"effect": str(definition.effect), "sample_ms": (events.size() - 1) * 100})
	return result

static func basic_actions(element:String) -> Array:
	var catalog=preload("res://scripts/m1_spell_catalog.gd")
	for definition in catalog.definitions():
		if str(definition.attribute)==element:return catalog.PROFILES["examples"][str(definition.catalog_id)].duplicate()
	return ["ACCUMULATE","DIRECT"]

static func fusion_inputs(profile: Profile, first: String, second: String, wall := false) -> Array:
	var events := inputs(profile, first, ["ACCUMULATE", "STABILIZE"])
	if profile.version() == 2:
		var preparation := inputs(profile, first, ["BIND"])
		preparation[1]["at_ms"] = events.size() * 100
		events.append(preparation[1])
	var second_key := ""
	for key in Profile.ATTRIBUTE_KEYS:
		if profile.first_word(key) == second: second_key = key; break
	events.append({"key": second_key, "at_ms": events.size() * 100, "hold_ms": 0})
	for action in (["SHAPE", "SHAPE", "DIRECT"] if wall else ["DIRECT"]):
		for key in profile.mobile_keys():
			if profile.manipulation(key) == action:
				events.append({"key": key, "at_ms": events.size() * 100, "hold_ms": 0})
				break
	return events
