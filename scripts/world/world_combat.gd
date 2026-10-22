extends "res://scripts/elemental_combat.gd"
## Trait adaptation for this boss only; ordinary targets keep the existing executor.
func hit_enemy(game, enemy: Dictionary, definition: Definition, direction: Vector2) -> void:
	if not enemy.get("boss", false): super.hit_enemy(game, enemy, definition, direction); return
	var traits: Dictionary = enemy["traits"]
	var adjusted: Definition = definition.duplicate()
	var materials: Array = traits["materials"]
	if enemy.get("guarded", false) and "steel_plate" in materials: adjusted.damage *= traits["piercing_guard_factor"] if definition.pierce_targets > 1 else traits["guard_damage_factor"]
	if enemy.get("guarded",false) and "steel_plate" in materials and (definition.formula_effect.get("prototype",false) or definition.formula_effect.get("water15",false)):
		var guard:float=traits["piercing_guard_factor"] if definition.pierce_targets>1 else traits["guard_damage_factor"]
		adjusted.damage=definition.damage*lerpf(guard,1.0,clampf(definition.formula_effect.get("armor_ignore",0.0),0,1))
	if enemy.get("exposed", false): adjusted.damage *= traits["exposed_damage_factor"]
	adjusted.knockback *= minf(1.0 / maxf(1, traits["mass_class"]), 1.0 - float(traits["knockback_resistance"]))
	if adjusted.status_effect in [&"root", &"crystal"]:
		# P01: provisional 0.75 reapplication curve, reset with the encounter only.
		# Original 2.4s ordinary root remains unchanged; the 1.5s boss cap is confirmed.
		var repeats := int(enemy.get("root_applications", 0))
		var rules: Dictionary = preload("res://scripts/m1_spell_catalog.gd").CONFIG["boss"]
		adjusted.duration = minf(rules["confirmed_root_cap"], adjusted.duration * (1.0 - float(traits["root_resistance"]))) * pow(rules["pending_root_reapply_multiplier"], repeats)
		enemy["root_applications"] = repeats + 1
	if adjusted.status_effect == &"stagger": adjusted.duration *= 1.0 - float(traits["stagger_resistance"])
	if adjusted.status_effect == &"burn":
		if not ("cloth_joints" in materials or "wood" in materials or "organic" in materials): adjusted.damage_per_second *= 0.35
		if enemy.get("wet_remaining", 0.0) > 0: adjusted.duration *= 0.75; enemy["wet_remaining"] = 0.0
	if definition.attribute == &"WATER":
		enemy["wet_remaining"] = 2.0
		enemy["burn_remaining"] = maxf(0, enemy.get("burn_remaining", 0.0) - 1.0)
	super.hit_enemy(game, enemy, adjusted, direction)
	game.guardian.metrics["hits_taken"] += 1
	# No unapproved poise, stagger or charge cancellation on formula proposals.
	if definition.formula_effect.get("prototype",false) or (definition.formula_effect.get("water15",false) and int(str(definition.spell_id).right(3))>=64):return
	var pressure := 8.0 + (18.0 if definition.knockback > 0 else 0.0) + (12.0 if definition.status_effect in [&"root", &"crystal"] else 0.0)
	if definition.attribute in [&"METAL", &"EARTH"]: pressure += preload("res://scripts/m1_spell_catalog.gd").CONFIG["boss"]["pending_metal_earth_poise_bonus"]
	game.guardian.add_poise(pressure)

func melee(game, enemy: Dictionary, damage: float) -> void:
	var factor := float(enemy["traits"]["guard_damage_factor"]) if enemy.get("guarded", false) else 1.0
	if enemy.get("exposed", false): factor *= float(enemy["traits"]["exposed_damage_factor"])
	enemy["hp"] -= damage * factor
	game.guardian.add_poise(12)
