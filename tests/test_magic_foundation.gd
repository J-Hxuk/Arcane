extends SceneTree
const Schools = preload("res://scripts/magic_schools.gd")
const Model = preload("res://scripts/magic_attunement.gd")
const Catalog = preload("res://scripts/magic_design_catalog.gd")
const Registry = preload("res://scripts/formal_spell_registry.gd")
const ChantEngine = preload("res://scripts/chant_engine_v2.gd")
const Profile = preload("res://scripts/chant_profile.gd")
const Save = preload("res://scripts/character_save.gd")
const Upgrade = preload("res://scripts/save_upgrade.gd")
const Equal = preload("res://tests/test_chant.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + label)

func run() -> void:
	check(Schools.validate().is_empty() and Schools.all().size()==20, "20 validated schools")
	check(Save.SCHEMA_VERSION==6, "Foundation does not bump or migrate the character schema")
	for element in Schools.EAST_ELEMENTS:
		check(not Schools.east_id(element,"YANG").is_empty() and not Schools.east_id(element,"YIN").is_empty(), "Two natures for " + element)
	for pair in [["FIRE","WATER","WEST_STEAM"],["FIRE","AIR","WEST_LIGHTNING"],["FIRE","EARTH","WEST_LAVA"],["WATER","AIR","WEST_ICE"],["WATER","EARTH","WEST_SWAMP"],["AIR","EARTH","WEST_SAND"]]:
		check(Schools.west_fusion([pair[0],pair[1]])==pair[2] and Schools.west_fusion([pair[1],pair[0]])==pair[2], "Unordered western lineage " + pair[2])
	check(Schools.west_fusion(["WATER","METAL"])=="" and Schools.west_fusion(["FIRE","FIRE"])=="", "No old eastern/duplicate fusion in west")
	check(Schools.west_fusion([1,"FIRE"])=="", "Malformed element request fails closed")
	var catalog := Catalog.load_file()
	check(catalog.ok, "270 source CSV loads: " + str(catalog.errors))
	if not catalog.ok: print("MAGIC FOUNDATION: %d checks, %d failures" % [checks,failures]); quit(1); return
	check(catalog.rows.size()==270 and catalog.by_id.size()==270 and catalog.by_identity.size()==270, "No ID, school multiset collision or omission")
	check(catalog.legacy_ids.size()==75, "75 legacy aliases excluding em-dash sentinel")
	var model := Model.new()
	check(not model.select_school("EAST_WATER_YANG") and not model.choose_east("WATER","YANG"), "Unopened school denied without mutation")
	check(not model.grant_school("WEST_ICE"), "Fusion grant requires both basic western elements")
	for school in Schools.all(): check(model.grant_school(school.id), "Grant fixture school " + school.id)
	check(model.to_data().unlocked_schools.size()==20, "Both natures can coexist for future progression without a story unlock policy")
	check(model.select_school("EAST_WATER_YANG") and model.choose_east("WOOD","YIN"), "Independent wood Yin / water Yang")
	check(model.to_data().east_choices.WATER=="YANG" and model.to_data().east_choices.WOOD=="YIN", "No global Yin/Yang choice")
	check(model.choose_east("WATER","YIN") and model.to_data().active_school=="EAST_WATER_YIN" and model.to_data().east_choices.WOOD=="YIN", "Switch acquired opposite nature without erasing qualifications")
	var original := {"schema_version":6,"magic":83,"research":{"innate_affinity":{"WATER":91}},"active_chant":Profile.generate_current(78431),"laboratory":{"future_field":"keep"},"unknown":{"value":3}}
	var legacy := Model.new()
	check(legacy.load_document(original) and Equal.equal(legacy.document(original),original), "No implicit new save field or guessed nature on legacy load")
	var untouched := original.duplicate(true)
	var extended := model.document(original)
	extended.magic_attunement["future_metadata"] = {"cycle_policy":"not decided"}
	var restored := Model.new()
	check(restored.load_document(extended) and Equal.equal(restored.document(extended),extended), "Optional extension losslessly roundtrips unknown metadata")
	check(Equal.equal(original,untouched), "Pure document adapter never mutates source or keymap")
	check(Model.valid(restored.to_data()) and Save.valid_resources(extended), "Schema6 accepts independently versioned optional data")
	var invalid := extended.duplicate(true); invalid.magic_attunement.unlocked_schools.append("UNKNOWN")
	var before := restored.to_data()
	check(not restored.load_document(invalid) and Equal.equal(restored.to_data(),before) and not Save.valid_resources(invalid), "Bad optional data rejected without resetting existing model")
	invalid = extended.duplicate(true); invalid.magic_attunement.version=2
	check(not Save.valid_resources(invalid), "Future attunement version fails closed")
	var only_fusion := Model.defaults(); only_fusion.unlocked_schools=["WEST_ICE"]
	check(not Model.valid(only_fusion), "Save boundary rejects unearned fusion")
	check(not Model.context_valid({"magic_school_id":"EAST_WATER_YANG","magic_attunement":model.to_data()}), "Context cannot spoof active school")
	check(Equal.equal(Upgrade.document(extended),Upgrade.document(Upgrade.document(extended))), "Existing upgrade remains idempotent with extension")
	var profile := Profile.new(); profile.load_data(original.active_chant)
	var profile_before := profile.to_data()
	var orders := 0
	for row in catalog.rows:
		check(model.select_school(row.school_id), "Select " + row.school_id)
		var seen: Dictionary = {}; var invariant := true
		for order in Registry.permutations(row.actions):
			var ordered_key: String = "|".join(order)
			if seen.has(ordered_key): continue
			seen[ordered_key]=true; orders+=1
			var result := Catalog.identify(catalog,row.school_id,order,model.context())
			if result.state!="design_only" or result.identity!=row.spell_id or result.castable or result.has("spell"): invariant=false
		check(invariant, "All unique permutations identify design only: " + row.spell_id)
		var inputs := ChantEngine.inputs(profile,row.actions)
		check(inputs.size()==row.actions.size() and inputs.map(func(e):return profile.manipulation(e.key))==row.actions, "Existing private key map decodes " + row.spell_id)
	check(Equal.equal(profile_before,profile.to_data()), "Catalog inspection never rerolls private map")
	check(Schools.identity_key("EAST_WATER_YANG",["DIRECT","DIRECT"])!=Schools.identity_key("EAST_WATER_YANG",["DIRECT"]), "Multiplicity retained")
	check(Schools.identity_key("WEST_WATER",["DIRECT"])!=Schools.identity_key("EAST_WATER_YANG",["DIRECT"]), "Cross-world identity is namespaced")
	check(Schools.identity_key("WEST_WATER",["DIRECT","DIRECT","DIRECT","DIRECT","DIRECT","DIRECT"])=="", "Six inputs denied")
	check(Schools.identity_key("WEST_WATER",["UNKNOWN"])=="", "Unknown operator denied")
	var rows: Array = catalog.rows.duplicate(true); rows[1].spell_id=rows[0].spell_id
	check(not Catalog.validate(rows).ok, "Duplicate ID rejected")
	rows=catalog.rows.duplicate(true); rows[1].chant_multiset=rows[0].chant_multiset
	check(not Catalog.validate(rows).ok, "Same-school multiset collision rejected")
	rows=catalog.rows.duplicate(true); rows.remove_at(0)
	check(not Catalog.validate(rows).ok, "Missing design row rejected")
	rows=catalog.rows.duplicate(true); rows[0].school="Unknown"
	check(not Catalog.validate(rows).ok, "Unknown school rejected")
	rows=catalog.rows.duplicate(true); rows[0].nature_or_fusion="陰"
	check(not Catalog.validate(rows).ok, "Mismatched nature rejected")
	rows=catalog.rows.duplicate(true); rows[0].base_element="水"
	check(not Catalog.validate(rows).ok, "Mismatched base element rejected")
	rows=catalog.rows.duplicate(true); rows[0].design_mp="nan"
	check(not Catalog.validate(rows).ok, "Invalid test number rejected")
	rows=catalog.rows.duplicate(true); rows[0].focus_order_example="DIRECT"
	check(not Catalog.validate(rows).ok, "Mismatched example rejected")
	rows=catalog.rows.duplicate(true)
	for row in rows:
		if row.school_id=="WEST_STEAM": row.chant_multiset=row.chant_multiset.replace("BIND","SHAPE"); break
	check(not Catalog.validate(rows).ok, "Fusion without BIND rejected")
	check(not Catalog.load_file("res://missing_design_catalog.csv").ok, "Missing CSV fails closed")
	check(Registry.config().spells.size()==28 and Registry.config().spells.filter(func(r):return r.id.begins_with("E-") or r.id.begins_with("W-")).is_empty(), "270 designs never register as production spells")
	var ctx := {"formal_rules":true,"developer_all":true,"main_attribute":"WATER","magic_school_id":"WEST_WATER"}
	var blocked := ChantEngine.resolve(profile,ChantEngine.inputs(profile,["ACCUMULATE","DIRECT"]),ctx)
	check(blocked.state=="locked" and not blocked.has("spell") and blocked.mana_cost==0, "New-school context never falls through to old/neutral spell, including developer bypass")
	ctx.merge({"laboratory":true,"movement_research":true,"research_only":true},true)
	blocked=ChantEngine.resolve(profile,ChantEngine.inputs(profile,["ACCUMULATE","DIRECT"]),ctx)
	check(blocked.state=="locked" and blocked.final_state.is_empty() and blocked.mana_cost==0, "Lab observation/movement research cannot bypass unsupported-school boundary or invent coefficients")
	print("Unique design permutations checked: ",orders)
	print("MAGIC FOUNDATION: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
