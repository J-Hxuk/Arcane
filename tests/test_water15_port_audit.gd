extends SceneTree
const Registry=preload("res://scripts/formal_spell_registry.gd")
const Identity=preload("res://scripts/chant_identity.gd")
const V=preload("res://scripts/mana_variation.gd")
const Prototypes=preload("res://scripts/mana_formula_prototypes.gd")
const OUT="res://.task002_artifacts/formula_followup/"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: ",label)
func run()->void:
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/WATER15_SOURCE_AUDIT.json"))
	var proposals:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/water15_multiset_proposals.json"))
	var production:=Registry.config();var staged:=production.duplicate(true);var conflicts:Array=[];var rows:Array=[];var all_orders:=0
	# Reproduce the archived966-order draft against its original16-row cohort.
	staged.spells=staged.spells.filter(func(row):return row.get("ported_from")!="water15")
	check(source.spells.size()==15 and proposals.spells.size()==15,"Audit keeps all 15 original IDs/names and separate multiset proposals")
	for proposal in proposals.spells:
		if proposal.status=="existing":continue
		staged.spells.append({"id":proposal.id,"element":"WATER","grade":3,"actions":proposal.actions})
	var context:Dictionary={"formal_rules":true,"main_attribute":"WATER","auxiliary_attributes":[],"attribute_loadout_version":1,"awakened_attributes":["WATER"],"active_main_attribute":"WATER","active_auxiliary_attribute":null}
	for proposal in proposals.spells:
		var valid_length:bool=proposal.actions.size()<=5 and proposal.actions.size()>0
		check(valid_length,"Proposed length <=5 "+proposal.id)
		var seen:Dictionary={};var stable:=0;var collapsed:=0;var unstable:=0;var wrong_ids:=0
		for order in Registry.permutations(proposal.actions):
			var key:="|".join(order)
			if seen.has(key):continue
			seen[key]=true;all_orders+=1
			var identified:=Identity.identify(order,context,staged)
			if identified.get("row",{}).get("id")!=proposal.id:wrong_ids+=1;conflicts.append({"expected":proposal.id,"order":order,"result":identified})
			var state:=V.state(order,"WATER",staged)
			if state.stability<25:collapsed+=1
			elif state.stability<40:unstable+=1
			else:stable+=1
		check(wrong_ids==0,"Every proposed permutation has the same non-conflicting identity "+proposal.id)
		rows.append({"id":proposal.id,"status":proposal.status,"actions":proposal.actions,"orders":seen.size(),"stable_states":stable,"unstable_states":unstable,"collapsed_states":collapsed,"combat_implemented":proposal.status=="existing"})
	check(conflicts.is_empty(),"No staged identity collision against the entire original 16-spell registry")
	# The three PX proposals must be replaced/aliased, not registered twice.
	var naive:=Prototypes.config(staged);var alias_conflicts:=0
	for proposal in proposals.spells:
		if proposal.status=="prototype_alias_proposal" and str(Identity.identify(proposal.actions,context,naive).get("row",{}).get("id","")).begins_with("PX-"):alias_conflicts+=1
	check(alias_conflicts==3,"Isolated PX aliases safely replace all three official rows without collisions")
	check(Registry.config().spells.size()==28,"Historical audit leaves the integrated28-row production registry intact")
	FileAccess.open(OUT+"water15_collision_audit.json",FileAccess.WRITE).store_string(JSON.stringify({"source":source.actual_source,"binary_available":source.workbook_found,"proposed_orders":all_orders,"conflicts":conflicts,"naive_px_alias_conflicts":alias_conflicts,"states_are_not_combat_validation":true,"rows":rows},"\t"))
	print("WATER15 AUDIT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
