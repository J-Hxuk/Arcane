extends SceneTree
const E=preload("res://scripts/chant_engine_v2.gd")
const I=preload("res://scripts/chant_identity.gd")
const C=preload("res://scripts/m1_spell_catalog.gd")
func _initialize()->void:
	var names:Dictionary=preload("res://scripts/spell_names.gd").SOURCE.by_catalog_id
	var rows:Array=[];var prior:Dictionary={};var active:Dictionary={};var registered:Dictionary={}
	for row in E.CONFIG.spells:
		var signature:=I.multiset(row.actions)
		if not active.has(signature):active[signature]=[]
		active[signature].append(row.id);registered[row.id]=row.actions
	for id in names:
		var legacy:Array=C.PROFILES.examples.get(id,[])
		var entry={"id":id,"name":names[id],"prototype_actions":registered.get(id,[]),"status":"prototype" if registered.has(id) else "unconfirmed_not_registered"}
		if not legacy.is_empty():
			var signature:=I.multiset(legacy)
			if not prior.has(signature):prior[signature]=[]
			prior[signature].append(id)
			entry["legacy_actions"]=legacy;entry["legacy_inputs_including_declaration"]=legacy.size()+1
			entry["old_predicate_total"]=C.PROFILES.profiles[id].size()+5
		rows.append(entry)
	var old_collisions:Array=[];var new_collisions:Array=[]
	for signature in prior:
		if prior[signature].size()>1:old_collisions.append({"signature":signature,"ids":prior[signature]})
	for signature in active:
		if active[signature].size()>1:new_collisions.append({"signature":signature,"ids":active[signature]})
	var result={"canonical_catalog_size":names.size(),"registered_single_spells":5,"unconfirmed_single_spells":70,"registered_fusion_prototypes":1,"M1_unconfirmed_new_compositions":10,"legacy_M1_multiset_collisions":old_collisions,"prototype_multiset_collisions":new_collisions,"catalog":rows}
	var f=FileAccess.open("res://.task002_artifacts/phase4_qa_v2/collision_analysis.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	print("CHANT ANALYSIS: %d canonical names; 5 single + 1 fusion registered; %d old M1 collisions; %d prototype collisions"%[names.size(),old_collisions.size(),new_collisions.size()]);quit()
