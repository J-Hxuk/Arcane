extends RefCounted
## Isolated Phase 0–3 proposals. Never added to the production registry or saves.
static var DATA:Dictionary=preload("res://scripts/mana_effect_score.gd").DATA
static func config(base:Dictionary)->Dictionary:
	var result:=base.duplicate(true)
	for row in DATA.spells:
		# A debug-only alias replaces its official row rather than registering a
		# second identity with the same multiset. Production never enters here.
		for i in range(result.spells.size()-1,-1,-1):
			if result.spells[i].id==row.source_id:result.spells.remove_at(i)
		result.spells.append({"id":row.id,"element":"WATER","grade":3,"actions":row.actions.duplicate(),"formula_prototype":true})
	return result
static func definition(id:String):
	for row in DATA.spells:
		if row.id!=id:continue
		var spell=preload("res://scripts/spell_definition.gd").new()
		spell.spell_id=id;spell.catalog_id=id;spell.display_name=row.name
		spell.attribute=&"WATER";spell.requires_elements=PackedStringArray(["WATER"])
		spell.projectile_color=Color("55cfff");spell.visual_style=StringName(row.score_axis)
		for field in ["effect","damage","mana_cost","radius","placement_distance","duration","status_effect","knockback","projectile_speed","lifetime","projectile_radius"]:
			if row.has(field):spell.set(field,row[field])
		spell.formula_effect={"prototype":true,"source_id":row.source_id,"axis":row.score_axis,"armor_ignore":row.get("armor_ignore",0.0)}
		return spell
	return null
