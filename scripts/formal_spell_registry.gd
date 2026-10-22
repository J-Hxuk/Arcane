extends RefCounted
## Port only existing, <=5-operation compositions. Never shorten or invent recipes.
static var cached:Dictionary={}
static var BALANCE:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/formal_spell_balance.json"))
static func config()->Dictionary:
	if not cached.is_empty():return cached
	cached=preload("res://scripts/chant_config.gd").DATA.duplicate(true)
	var existing=preload("res://scripts/m1_spell_catalog.gd")
	for definition in existing.definitions():
		var id:=str(definition.catalog_id);var present:=false
		for row in cached.spells:
			if row.id==id:present=true
		if present:continue
		var actions:Array=existing.PROFILES.examples[id]
		if actions.size()>5:continue
		if not can_survive(actions,str(definition.attribute),cached):continue
		cached.spells.append({"id":id,"element":str(definition.attribute),"grade":1 if actions.size()<=3 else 2 if actions.size()==4 else 3,"actions":actions.duplicate(),"ported_from":"m1_state_profiles"})
	cached.spells.append({"id":"MANA_BOLT","neutral":true,"element":"","grade":1,"actions":["ACCUMULATE","DIRECT"],"ported_from":"neutral_manipulation"})
	cached.spells.append({"id":"WIND_PRESSURE_BOLT","elements":["FIRE","WATER"],"grade":2,"actions":["ACCUMULATE","STABILIZE","BIND","DIRECT"],"ported_from":"fusion_inputs"})
	var water=preload("res://scripts/water_spell_catalog.gd")
	for item in water.DATA.spells:
		var present:=false
		for entry in cached.spells:
			if entry.id==item.id:present=true
		if not present:cached.spells.append({"id":item.id,"element":"WATER","grade":item.tier+1,"actions":item.actions.duplicate(),"ported_from":"water15"})
	return cached
static func can_survive(actions:Array,element:String,settings:Dictionary)->bool:
	for order in permutations(actions):
		if preload("res://scripts/mana_variation.gd").state(order,element,settings).stability>=float(settings.thresholds.collapse_below):return true
	return false
static func permutations(actions:Array)->Array:
	if actions.is_empty():return [[]]
	var result:Array=[]
	for i in actions.size():
		var remaining:=actions.duplicate();var head=remaining.pop_at(i)
		for tail in permutations(remaining):result.append([head]+tail)
	return result
static func definition(id:String,formal:=true):
	var source=preload("res://scripts/water_spell_catalog.gd").definition(id) if formal and not preload("res://scripts/water_spell_catalog.gd").row(id).is_empty() else legacy_definition(id)
	if source==null or not formal:return source
	var tuned=source.duplicate()
	for field in BALANCE.spells.get(id,{}):
		if field!="role":tuned.set(field,BALANCE.spells[id][field])
	return tuned
static func legacy_definition(id:String):
	match id:
		"MANA_BOLT":return preload("res://data/spells/mana_bolt.tres")
		"ICE_CRYSTAL_NEEDLE":return preload("res://data/spells/ice_crystal_needle.tres")
		"WIND_PRESSURE_BOLT":return preload("res://data/spells/wind_pressure_bolt.tres")
	return preload("res://scripts/m1_spell_catalog.gd").find(id)
