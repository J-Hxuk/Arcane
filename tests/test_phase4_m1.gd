extends "res://tests/preview_world_phase1.gd"
const Catalog = preload("res://scripts/m1_spell_catalog.gd")
const Sim = preload("res://scripts/mana_simulator.gd")
const Resolver = preload("res://scripts/combat_spell_resolver.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Combat = preload("res://scripts/elemental_combat.gd")
const Arena = preload("res://scripts/laboratory_arena.gd")
static func actions_for(id: String) -> Array:
	return Catalog.PROFILES["examples"][id].duplicate()
func run() -> void:
	var definitions := Catalog.definitions()
	check(definitions.size() == 15, "Catalog imports exactly fifteen v0.5 basics, no M2-M5 content")
	var ids: Array = []
	for source in Catalog.SOURCE["spells"]:
		var definition = Catalog.find(source["id"])
		ids.append(str(definition.catalog_id))
		check(definition.validate_requirements().is_empty() and definition.damage == source["damage"] and definition.mana_cost == source["mana_cost"] and definition.english_name == source["english_name"], source["id"] + " retains source ID/name/cost/direct damage")
	check(ids.size() == 15 and Catalog.LEGACY.size() == 5, "Five existing Resources reused and ten distinct basic effects added")
	for seed_value in [1, 8431, 1787453028]:
		var profile := Profile.new(); profile.load_data(Profile.generate(seed_value))
		for source in Catalog.SOURCE["spells"]:
			var inputs := D.inputs(profile, source["element"], actions_for(source["id"]))
			var result := Resolver.resolve(Sim.simulate(profile, inputs), source["element"])
			check(result.get("spell") != null and str(result["spell"].catalog_id) == source["id"], source["id"] + " is recognized from final mana state under personal mapping " + str(seed_value))
			check(Resolver.resolve(Sim.simulate(profile, inputs), null)["state"] == "locked", source["id"] + " rejects unauthorised non-UI requests")
	var profile := Profile.new(); profile.load_data(Profile.generate(1787453028))
	var ordinary := D.inputs(profile, "WATER", ["ACCUMULATE","ACCUMULATE", "DIRECT","DIRECT"])
	var reversed := D.inputs(profile, "WATER", ["DIRECT","DIRECT", "ACCUMULATE","ACCUMULATE"])
	check(Resolver.resolve(Sim.simulate(profile, ordinary), "WATER")["spell"].catalog_id == Resolver.resolve(Sim.simulate(profile, reversed), "WATER")["spell"].catalog_id, "Equal final states select the same spell regardless of order")
	var stronger := Resolver.resolve(Sim.simulate(profile, D.inputs(profile, "WATER", ["ACCUMULATE", "ACCUMULATE","ACCUMULATE", "DIRECT","DIRECT"])), "WATER")
	check(stronger["spell"].catalog_id == &"OH-061" and stronger["spell"].knockback > 135, "Additional real accumulation changes the valid Tidebolt variant")
	var wider := Resolver.resolve(Sim.simulate(profile,D.inputs(profile,"WOOD",["ACCUMULATE","DIRECT","SHAPE","SHAPE"])),"WOOD")
	check(wider["spell"].radius > 85 and wider["spell"].catalog_id == &"OH-002", "Shaping a Root Flick expands its real area instead of changing keys")
	var broad := Resolver.resolve(Sim.simulate(profile,D.inputs(profile,"WOOD",["ACCUMULATE","SHAPE","RESONATE","STABILIZE","SHAPE","DIRECT"])),"WOOD")
	check(broad.get("spell")!=null and broad["spell"].projectile_width>0 and broad["spell"].catalog_id==&"OH-001","Additional shape on a resonant vine changes actual projectile hit width")
	var previous_fire:=preload("res://tests/test_phase2b25b.gd").fire_actions("FIRE_LANCE")
	previous_fire.append("COMPRESS")
	var legacy_fire:=Resolver.resolve(Sim.simulate(profile,D.inputs(profile,"FIRE",previous_fire)),"FIRE")
	check(legacy_fire.get("spell")!=null and legacy_fire["spell"].spell_id==&"FIRE_LANCE","Already implemented fire lance keeps its valid compressed range beyond the M1 envelope")
	for path in [["ACCUMULATE", "DIRECT", "DISSIPATE"], ["ACCUMULATE", "DIRECT", "ACCUMULATE", "ACCUMULATE", "ACCUMULATE"], ["ACCUMULATE", "DIRECT", "COMPRESS", "COMPRESS", "COMPRESS", "COMPRESS"]]:
		check(Resolver.resolve(Sim.simulate(profile, D.inputs(profile, "WATER", path)), "WATER").get("spell") == null, "Loss/overload/overcompression cannot silently fall back to Tidebolt")
	var arena := Arena.new(); root.add_child(arena)
	for source in Catalog.SOURCE["spells"]:
		arena.reset_targets()
		var definition = Catalog.find(source["id"])
		var distance := 160.0 if definition.effect == &"point" else 65.0 if definition.effect in [&"cone", &"shockwave"] else 180.0
		arena.enemies = [{"pos": arena.player_pos + Vector2(distance, 0), "hp": 200.0, "shot": INF}]
		var enemy: Dictionary = arena.enemies[0]
		var origin: Vector2 = enemy["pos"]
		check(arena.combat.cast(arena, definition, Vector2.RIGHT), source["id"] + " executes in the existing lab arena")
		if definition.effect == &"barrier":
			check(arena.combat.barriers.size() == 1 and arena._is_blocked(arena.player_pos + Vector2(95, 0)), "Stoneward has real collision and remains independent of other chants")
		else:
			arena.advance(0.5)
			check(enemy["hp"] < 200, source["id"] + " deals actual direct/status damage")
			if source["id"] == "OH-048": check(enemy["pos"].x < origin.x, "Lodestone pulls instead of pushing")
			if source["id"] in ["OH-061", "OH-063"]: check(enemy["pos"].x > origin.x, source["id"] + " pushes")
			if source["id"] == "OH-002": check(enemy.get("slow_remaining", 0) > 0 and enemy.get("root_remaining", 0) == 0, "Root Flick slow remains distinct from root")
			if source["id"] == "OH-033":
				arena.reset_targets(); arena.combat.cast(arena, definition, Vector2.RIGHT)
				check(arena.combat.visuals.size() > 0, "Faultstep creates a temporary ground-ridge effect")
	arena.reset_targets(); arena.moving_targets=true
	var target:Dictionary=arena.enemies[0]; target["slow_remaining"]=1.0
	var start:Vector2=target["pos"]; arena.advance(0.2)
	check(is_equal_approx(Vector2(target["pos"]).distance_to(start),3.25),"Root Flick slow changes the real moving laboratory target speed")
	arena.free()
	print("PHASE4 M1: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
