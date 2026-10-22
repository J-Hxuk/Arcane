extends RefCounted
## v0.5 source IDs coexist with legacy save IDs. No stored recipe or mapping is rewritten.
static var SOURCE: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m1_spells_v05.json"))
static var CONFIG: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m1_runtime_prototype.json"))
static var PROFILES:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/m1_state_profiles.json"))
const LEGACY := {
	"OH-001": preload("res://data/spells/wood_bind.tres"),
	"OH-016": preload("res://data/spells/fire_ember.tres"),
	"OH-031": preload("res://data/spells/earth_barrier.tres"),
	"OH-046": preload("res://data/spells/metal_lance.tres"),
	"OH-061": preload("res://data/spells/water_push.tres"),
}
const Definition = preload("res://scripts/spell_definition.gd")
static var _definitions: Array = []
static func definitions() -> Array:
	if not _definitions.is_empty(): return _definitions
	for source in SOURCE["spells"]:
		var definition: Definition = LEGACY.get(source["id"])
		if definition == null:
			definition = Definition.new()
			definition.spell_id = source["id"]
			definition.display_name = source["english_name"]
			definition.attribute = source["element"]
			definition.requires_elements = PackedStringArray([source["element"]])
			definition.mana_cost = source["mana_cost"]
			definition.damage = source["damage"]
			definition.min_cohesion = 0; definition.min_form = 0
			for key in source["runtime"]: definition.set(key, source["runtime"][key])
		definition.catalog_id = source["id"]
		definition.english_name = source["english_name"]
		definition.display_name = source["english_name"]
		if definition.effect==&"projectile" and definition.attribute==&"WATER":definition.projectile_radius=5.0 if definition.visual_style==&"DROPLET" else 9.0
		_definitions.append(definition)
	return _definitions

static func find(id: String) -> Definition:
	for definition in definitions():
		if str(definition.catalog_id) == id or str(definition.spell_id) == id: return definition
	return null

static func variant(state: Dictionary, element: String) -> int:
	var chosen=select(state,element)
	if chosen==null:return -1
	var index:=0
	for definition in definitions():
		if str(definition.attribute)!=element:continue
		if chosen.catalog_id==definition.catalog_id:return index
		index+=1
	return -1

static func conditions(state: Dictionary,id:="") -> Dictionary:
	var result:Dictionary={"안정 유지":state.get("stability",0)>=45,"에너지 손실 억제":state.get("energy_loss",0)<=6,"기초 구조 유지":not state.get("advanced_used",false) and state.get("branches",1)==1}
	var labels={"mana_amount":"마나 총량","cohesion":"응집 밀도","form_integrity":"형상 윤곽","coupling":"공명 결합","persistence":"형상 유지","flow_strength":"흐름 추진력","spread":"에너지 분포"}
	for field in PROFILES["profiles"].get(id,{}):
		var range_value:Array=PROFILES["profiles"][id][field]
		var amount:float=state.get(field,0)
		result[labels.get(field,field)]=amount>=range_value[0] and amount<=range_value[1]
	return result

static func select(state: Dictionary, element: String) -> Definition:
	if state.get("phase")=="FAILED":return null
	var best:Definition=null
	var best_distance:=INF
	for definition in definitions():
		if str(definition.attribute)!=element or false in conditions(state,str(definition.catalog_id)).values():continue
		var distance:=0.0
		for field in PROFILES["profiles"][str(definition.catalog_id)]:
			var interval:Array=PROFILES["profiles"][str(definition.catalog_id)][field]
			distance+=absf(float(state.get(field,0))-(interval[0]+interval[1])*0.5)/maxf(1,interval[1]-interval[0])
		if distance<best_distance:best=definition;best_distance=distance
	return best

static func tuned(source: Definition, state: Dictionary) -> Definition:
	var curve: Dictionary = CONFIG["tuning"]
	var extra: float = maxf(0, float(state["mana_amount"]) - CONFIG["limits"]["min_mana"]) / curve["amount_step"]
	var density: float = maxf(0, float(state["cohesion"]) - CONFIG["structures"]["compact"]) / curve["density_step"]
	var width: float = maxf(0, float(state["form_integrity"]) - CONFIG["structures"]["formed"]) / curve["form_step"]
	if extra == 0 and density == 0 and width == 0: return source
	var definition: Definition = source.duplicate()
	# Experimental curves, not final v0.5 balance. Canonical source numbers remain
	# unchanged; every cast records the actual variant values.
	if definition.effect != &"barrier":
		definition.damage *= 1.0 + density * curve["damage_per_density"]
		if definition.status_effect in [&"root", &"burn"]: definition.duration *= 1.0 + extra * curve["duration_per_amount"]
		if definition.knockback != 0: definition.knockback *= 1.0 + extra * curve["push_per_amount"]
		if density > 1 and definition.effect == &"projectile": definition.lifetime /= 1.0 + (density - 1) * curve["range_loss_per_density"]
	if definition.radius > 0: definition.radius *= 1.0 + width * curve["area_per_form"]
	if definition.effect == &"projectile": definition.projectile_width = width * curve["projectile_width_per_form"] / (1.0 + density * 0.25)
	return definition
