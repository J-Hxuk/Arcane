extends RefCounted
## Pure, idempotent schema adapter. File backup belongs to CharacterSave.
static func document(source:Dictionary,free_attributes:=true) -> Dictionary:
	var result:=source.duplicate(true)
	if free_attributes and not result.has("research"):result["research"]={}
	if result.get("research") is Dictionary:
		result["research"]=preload("res://scripts/ohaeng_migration.gd").research(result["research"])
		if free_attributes:result["research"]=preload("res://scripts/attribute_loadout.gd").upgrade(result["research"])
	var vitals=result.get("world",{}).get("vitals") if result.get("world",{}) is Dictionary else null
	if vitals is Dictionary:
		var mana=vitals.get("mana",0)
		var debt=vitals.get("mana_debt",0)
		if (mana is int or mana is float) and (debt is int or debt is float) and is_finite(float(mana)) and is_finite(float(debt)) and debt>=0:
			# A legacy negative balance already represents the debt. Never add it twice.
			if mana<0:
				vitals["mana_debt"]=maxf(-float(mana),float(debt));vitals["mana"]=0.0
			elif not vitals.has("mana_debt"):vitals["mana_debt"]=0.0
	return result
