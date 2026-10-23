extends SceneTree
const O = preload("res://scripts/mana_observation.gd")
const E = preload("res://scripts/chant_engine_v2.gd")
const R = preload("res://scripts/formal_spell_registry.gd")
const P = preload("res://scripts/chant_profile.gd")
const V = preload("res://scripts/mana_variation.gd")
const J = preload("res://scripts/experiment_journal.gd")
const M = preload("res://scripts/mana_overdraw.gd")
const Equal = preload("res://tests/test_chant.gd")
var checks := 0
var failures := 0
var profile = P.new()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+label)

static func signature(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	var spell = copy.get("spell")
	copy.erase("spell")
	if spell!=null:
		var values: Dictionary={}
		for field in spell.get_property_list():
			if (int(field.usage)&PROPERTY_USAGE_STORAGE)!=0 and field.name!="script": values[field.name]=spell.get(field.name)
		copy["spell_values"]=values
	return copy

static func context(row: Dictionary = {}) -> Dictionary:
	var main: String=row.get("element","WATER")
	if main.is_empty(): main="WATER"
	var aux = null
	if row.has("elements"): main=row.elements[0]; aux=row.elements[1]
	return {"formal_rules":true,"laboratory":true,"attribute_loadout_version":1,"awakened_attributes":["WOOD","FIRE","EARTH","METAL","WATER"],"main_attribute":main,"active_main_attribute":main,"auxiliary_attributes":[] if aux==null else [aux],"active_auxiliary_attribute":aux,"observation_element":main}

func inspect(actions: Array, ctx: Dictionary = context()) -> Dictionary:
	return E.resolve(profile,E.inputs(profile,actions),ctx)

func run() -> void:
	profile.load_data(P.generate_current(78431))
	var original_map: Dictionary=profile.to_data()
	var original_config: Dictionary=E.CONFIG.duplicate(true)
	var original_registry: Dictionary=R.config().duplicate(true)
	var total_orders := 0; var total_frames := 0; var varying := 0
	for row in R.config().spells:
		var seen: Dictionary={}; var raw_variants: Dictionary={}; var correct := true; var passive := true; var frames_ok := true
		for order in R.permutations(row.actions):
			var key: String="|".join(order)
			if seen.has(key): continue
			seen[key]=true; total_orders+=1
			var first := inspect(order,context(row)); var baseline := signature(first)
			var sim_before: Dictionary=first.simulation.duplicate(true)
			var observed := O.capture(first.simulation)
			passive=passive and Equal.equal(first.simulation,sim_before) and Equal.equal(signature(first),baseline) and Equal.equal(signature(inspect(order,context(row))),baseline)
			correct=correct and observed.size()==order.size() and first.identity==row.id
			for i in observed.size():
				total_frames+=1
				var frame: Dictionary=observed[i]; var step: Dictionary=first.simulation.casting_steps[i]
				frames_ok=frames_ok and frame.index==i+1 and frame.sequence==order.slice(0,i+1) and frame.operator==order[i] and frame.before==O.numbers(step.before) and frame.after==O.numbers(step.after) and frame.delta==O.difference(O.numbers(step.before),O.numbers(step.after))
				frames_ok=frames_ok and frame.B==O.numbers(step.after.variation_vector.reference) and frame.raw==O.numbers(step.after.variation_vector) and frame.terms_available
				frames_ok=frames_ok and frame.projection==V.projection(step.after,E.CONFIG)
				for field in frame.raw:
					var reconstructed: float=frame.B[field]+frame.O[field]+frame.T[field]+frame.adjustment.get(field,0)
					frames_ok=frames_ok and absf(reconstructed-float(frame.raw[field]))<0.00001
				var words := 0
				for count in frame.multiset.values(): words+=count
				frames_ok=frames_ok and words==i+1 and frame.context.nature==null
				raw_variants[JSON.stringify(observed.back().raw)]=true
				frames_ok=frames_ok and not JSON.stringify(frame).contains(row.id) and not frame.has("spell") and not frame.has("candidate_ids")
			passive=passive and M.quote(0,1000,first.mana_cost,4)==M.quote(0,1000,baseline.mana_cost,4)
		if raw_variants.size()>1: varying+=1
		check(correct,row.id+" every permutation retains identity and has incomplete-prefix observations")
		check(passive,row.id+" observation ON/OFF leaves all engine/spell/cost values identical")
		check(frames_ok,row.id+" every frame matches actual before/after/B/raw/projection and O+T accounting")
	check(varying>0,"Same-multiset order differences are visible")
	check(R.config().spells.size()==28 and Equal.equal(R.config(),original_registry),"Observation never registers 270 designs or mutates production definitions")
	check(Equal.equal(profile.to_data(),original_map) and Equal.equal(E.CONFIG,original_config),"Private keymap and formula configuration are unchanged")
	var pair := inspect(["ACCUMULATE","COMPRESS"])
	var frames := O.capture(pair.simulation)
	var f: Dictionary=frames.back()
	check(is_equal_approx(f.O.cohesion,3.22) and is_equal_approx(f.T.cohesion,1.84),"Known independent two-input position/adjacency calculation")
	check(is_equal_approx(f.adjustment.stability,-2.8),"Existing water compression risk displayed separately")
	check(f.raw.flow_strength<0 and f.after.flow_strength==0,"Negative raw is preserved separately from clipped state")
	check(f.context.attributes==["WATER"] and f.context.nature==null,"Current applied element, no invented Yin/Yang")
	check(not O.describe(f).contains("OH-") and O.describe(f).contains("↑"),"Observed direction without recipe/ID advice")
	var repeat := inspect(["COMPRESS","COMPRESS","COMPRESS","COMPRESS","COMPRESS"])
	var last: Dictionary=O.capture(repeat.simulation).back()
	var zero := true
	for field in last.O: zero=zero and absf(last.O[field])<0.00000001 and absf(last.T[field])<0.00000001
	check(zero and last.after.stability==0 and last.raw.stability<0,"Repeated identical operators have zero order bonus, real collapse retained")
	check(last.delta.cohesion==0 and is_equal_approx(last.raw_delta.cohesion,28) and O.describe(last).contains("응집 raw↑"),"Raw-only changes are explicit when clipping hides a visible-state delta")
	check(O.band(last)=="붕괴 구간","Actual stability threshold is used without declaring a spell success")
	var fake := E.CONFIG.duplicate(true); fake.r=2.0
	check(not O.capture(pair.simulation,fake).back().terms_available,"Wrong/current-changed coefficients cannot masquerade as recorded O/T")
	var journal := J.new(); var sim: Dictionary=repeat.simulation.duplicate(true); var sim_copy:=sim.duplicate(true)
	journal.append(sim,"failed",2,500,2)
	check(Equal.equal(sim,sim_copy),"Journal attachment never modifies engine result")
	var record: Dictionary=journal.records().back()
	check(record.mana_observation_version==1 and record.steps.size()==5 and record.steps.back().mana_observation==last,"Failed cast stores exact telemetry next to the authoritative snapshots")
	var frame_before := O.from_record(record,4); var rendered_copy := O.from_record(record,4); rendered_copy.after.stability=99
	check(O.from_record(record,4)==frame_before,"View edits cannot mutate saved telemetry")
	var roundtrip:=J.new()
	check(roundtrip.load_data(JSON.parse_string(JSON.stringify(journal.to_data()))).is_empty() and Equal.equal(roundtrip.records(),journal.records()),"Old journal schema accepts new optional telemetry losslessly")
	var old := record.duplicate(true)
	old.erase("mana_observation_version")
	for step in old.steps: step.erase("mana_observation")
	old.steps[4].after.mana_amount=37.123; old.steps[4].after.variation_vector.mana_amount=-812.0
	var old_copy := old.duplicate(true); var historic := O.from_record(old,4)
	check(historic.after.mana_amount==37.123 and historic.raw.mana_amount==-812.0 and not historic.terms_available and historic.O.is_empty() and historic.projection.is_empty(),"Old snapshots show only their stored values, never today's formula")
	check(historic.operator=="" and historic.multiset.is_empty() and Equal.equal(old,old_copy),"Old operators are not guessed from today's map, original record untouched")
	var future := record.duplicate(true); future.steps[4].mana_observation.version=999
	check(not O.from_record(future,4).terms_available,"Unsupported telemetry version falls back to stored snapshots")
	var damaged := record.duplicate(true); damaged.steps[4].mana_observation={"version":1,"before":{},"after":{}}
	check(not O.from_record(damaged,4).terms_available and O.from_record(damaged,4).after.stability==0,"Incomplete optional diagnostics fall back safely without rewriting old data")
	damaged=record.duplicate(true); damaged.steps[4].mana_observation.after.stability=NAN
	check(O.from_record(damaged,4).after.stability==0,"Non-finite optional diagnostics cannot replace the actual snapshot")
	var malformed := E.resolve(profile,[{"key":"?","at_ms":0,"hold_ms":0}],context())
	check(O.capture(malformed.simulation).size()==1 and not O.capture(malformed.simulation)[0].terms_available,"Invalid input remains observable without fabricated terms")
	var school_context := context(); school_context.magic_school_id="EAST_WATER_YANG"
	check(O.capture(inspect(["ACCUMULATE"],school_context).simulation).is_empty(),"New20 school block remains intact, no invented coefficient readings")
	check(O.from_record(record,-1).is_empty() and O.from_record(record,99).is_empty(),"Invalid playback indices are safe")
	print("Observation audit: %d existing spell permutations, %d actual prefix snapshots" % [total_orders,total_frames])
	print("MANA OBSERVATION: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
