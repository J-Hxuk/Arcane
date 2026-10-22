extends SceneTree
const E=preload("res://scripts/chant_engine_v2.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: "+label)
func _initialize()->void:
	var profile=preload("res://scripts/chant_profile.gd").new();profile.load_data(profile.generate_current(1787453028))
	for lab in [false,true]:
		var context={"formal_rules":true,"attribute_loadout_version":1,"awakened_attributes":["WOOD","FIRE"],"active_main_attribute":"WOOD","active_auxiliary_attribute":null,"main_attribute":"WOOD","auxiliary_attributes":[],"binding_pairs":[],"laboratory":lab,"observation_element":"WOOD"}
		var events:=E.inputs(profile,["ACCUMULATE","RESONATE","DIRECT"]);var rejected:=E.resolve(profile,events,context)
		check(rejected.state=="locked" and rejected.get("spell")==null and rejected.mana_cost==0,"Wrong-element composition is rejected without a cost in lab="+str(lab))
		check(rejected.message.contains("조작 구성") and not rejected.message.contains("결속"),"Failure describes the actual attribute-composition mismatch")
		var wood:=E.resolve(profile,E.inputs(profile,["ACCUMULATE","SHAPE","STABILIZE"]),context)
		check(wood.identity=="OH-001" and wood.get("spell")!=null and wood.risk=="normal","Wood bind remains valid in lab="+str(lab))
		context.active_main_attribute="FIRE";context.main_attribute="FIRE";context.observation_element="FIRE"
		var fire:=E.resolve(profile,events,context)
		check(fire.identity=="OH-016" and fire.get("spell")!=null,"Same sequence is valid for fire in lab="+str(lab))
		context.active_main_attribute="WOOD";context.main_attribute="WOOD";context.observation_element="WOOD";context.developer_all=true
		check(E.resolve(profile,events,context).identity=="OH-016","Explicit developer permission bypass is distinct from normal rules in lab="+str(lab))
	print("CHANT ATTRIBUTE DIAGNOSTICS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
