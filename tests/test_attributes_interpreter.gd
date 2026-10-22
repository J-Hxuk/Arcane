extends "res://tests/attribute_helpers.gd"
const Loadout=preload("res://scripts/attribute_loadout.gd")
const Identity=preload("res://scripts/chant_identity.gd")
func context(main:String,aux:Variant=null,bindings:Array=[])->Dictionary:
	return {"formal_rules":true,"attribute_loadout_version":1,"awakened_attributes":Loadout.ORDER.duplicate(),"active_main_attribute":main,"active_auxiliary_attribute":aux,"main_attribute":main,"auxiliary_attributes":[] if aux==null else [aux],"binding_pairs":bindings}
func run()->void:
	fresh();await process_frame;var profile=game._active_profile();var ports:Array=[]
	for row in Registry.config().spells:
		var pair:Array=row.get("elements",[]);var main:String=row.get("element","WATER");var aux:Variant=null;var bindings:Array=[]
		if pair.size()==2:main=pair[0];aux=pair[1];bindings=[game.CharacterResearch.Fusion.pair(pair)]
		if main.is_empty():main="WATER"
		var ctx:=context(main,aux,bindings);var success:Array=[]
		for order in Registry.permutations(row.actions):
			var result:=E.resolve(profile,E.inputs(profile,order),ctx)
			if result.get("spell")!=null and result.identity==row.id:success.append(result)
		check(not success.is_empty(),"Existing formal spell manifests through explicit loadout "+row.id)
		var differing:=false
		for result in success:
			if not is_equal_approx(result.mana_cost,success[0].mana_cost) or not is_equal_approx(result.spell.damage,success[0].spell.damage):differing=true
		check(differing,"Order-based physical variation remains "+row.id)
		ports.append({"id":row.id,"manifestable_orders":success.size(),"variation":differing})
	var shared:Array=["ACCUMULATE","COMPRESS","DIRECT"]
	check(E.resolve(profile,E.inputs(profile,shared),context("METAL")).identity=="OH-046" and E.resolve(profile,E.inputs(profile,shared),context("WOOD")).identity=="OH-003","Identical personal keys resolve as Ironlance or Splinter by active main")
	var tide:Array=["ACCUMULATE","SHAPE","DIRECT"]
	var water:=E.resolve(profile,E.inputs(profile,tide),context("WATER"));var with_aux:=E.resolve(profile,E.inputs(profile,tide),context("WATER","METAL",["METAL+WATER"]))
	check(water.identity=="OH-061" and with_aux.identity=="OH-061" and water.final_state==with_aux.final_state,"Auxiliary selection alone never transforms single-element spell or cost")
	var ice:Array=["ACCUMULATE","STABILIZE","BIND","SHAPE"]
	# Use the registered composition, never guessed personal keys.
	for row in Registry.config().spells:
		if row.id=="ICE_CRYSTAL_NEEDLE":ice=row.actions
	check(E.resolve(profile,E.inputs(profile,ice),context("WATER","METAL")).get("spell")!=null,"Awakened equipped pair can manifest without any binding history")
	var left:=E.resolve(profile,E.inputs(profile,ice),context("WATER","METAL",["METAL+WATER"]));var right:=E.resolve(profile,E.inputs(profile,ice),context("METAL","WATER",["METAL+WATER"]))
	check(left.identity=="ICE_CRYSTAL_NEEDLE" and right.identity==left.identity and left.final_state==right.final_state and left.mana_cost==right.mana_cost,"Reversing equipped fusion declaration order preserves structure, identity and price")
	var invalid:=context("WATER","METAL",["METAL+WATER"]);invalid.awakened_attributes=["WATER"]
	check(E.resolve(profile,E.inputs(profile,ice),invalid).get("spell")==null,"Forged auxiliary outside permanent awakenings is rejected")
	check(E.resolve(profile,E.inputs(profile,["ACCUMULATE","DIRECT"]),invalid).state=="locked","Neutral spell cannot bypass a malformed explicit loadout request")
	for row in Registry.config().spells:
		if not row.has("elements"):continue
		var elements:Array=row.elements;var binding:Array=[game.CharacterResearch.Fusion.pair(elements)]
		var a:=E.resolve(profile,E.inputs(profile,row.actions),context(elements[0],elements[1],binding));var b:=E.resolve(profile,E.inputs(profile,row.actions),context(elements[1],elements[0],binding))
		check(a.identity==row.id and b.identity==a.identity and a.final_state==b.final_state,"Every fusion keeps identical state in both equipped orders "+row.id)
		check(E.resolve(profile,E.inputs(profile,row.actions),context("WOOD",elements[0],binding)).get("spell")==null,"Fusion requires its actual main element "+row.id)
	for main in Loadout.ORDER:
		var single:Dictionary=Registry.config().spells.filter(func(row):return row.get("element")==main and not row.has("elements"))[0]
		for aux in [null]+Loadout.ORDER:
			if aux==main:continue
			var manifested:=false
			for order in Registry.permutations(single.actions):
				var outcome:=E.resolve(profile,E.inputs(profile,order),context(main,aux,["METAL+WATER","FIRE+WATER"]))
				if outcome.get("spell")!=null and outcome.identity==single.id and outcome.final_state.base_attributes==[main]:manifested=true;break
			check(manifested,"Single spell remains main-element-only for equipment combination "+str([main,aux]))
	var over_limit:=context("WATER");over_limit.merge({"laboratory":true,"observation_element":"WATER","research_only":true})
	check(E.resolve(profile,E.inputs(profile,["ACCUMULATE","SHAPE","STABILIZE","SHAPE","STABILIZE","DIRECT"]),over_limit).state=="failed","Laboratory observation cannot bypass the unchanged five-input limit")
	var config:Dictionary=Registry.config().duplicate(true);var original:Dictionary=config.spells.filter(func(row):return row.id=="OH-061")[0];var duplicate:Dictionary=original.duplicate(true);duplicate.id="TEST_COLLISION";config.spells.append(duplicate)
	var collision:=Identity.identify(tide,context("WATER"),config);config.spells.reverse();var reverse:=Identity.identify(tide,context("WATER"),config)
	check(collision.state=="ambiguous" and collision.candidate_ids==reverse.candidate_ids,"Overlapping same-priority candidates reject deterministically independent of registry order")
	duplicate.structure={"mana_amount":[1000,2000]};config.spells=config.spells.filter(func(row):return row.id!="TEST_COLLISION");config.spells.append(duplicate)
	check(Identity.identify(tide,context("WATER"),config).state=="ambiguous","Identity collision remains a registry error even when one candidate cannot manifest")
	var locked:Dictionary=original.duplicate(true);locked.id="TEST_LOCKED";locked.grade=5;config.spells.push_front(locked)
	check(Identity.identify(tide,context("WATER"),config).state=="ambiguous","Research grade cannot hide a formal identity collision")
	FileAccess.open(OUT+"spell_ports.json",FileAccess.WRITE).store_string(JSON.stringify(ports,"\t"));await finish("ATTRIBUTES INTERPRETER")
